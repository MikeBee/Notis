//
//  FileSyncService.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import Foundation
import CoreData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Service for syncing markdown files with SQLite index
/// Handles bidirectional sync, change detection, and conflict resolution
class FileSyncService {

    // MARK: - Singleton

    static let shared = FileSyncService()

    // MARK: - Properties

    private let markdownService = MarkdownFileService.shared
    private let indexService = NotesIndexService.shared
    private let yamlService = YAMLFrontmatterService.shared
    private let fileManager = FileManager.default

    private var isSyncing = false
    private var fileSystemWatcher: DispatchSourceFileSystemObject?
    private var backgroundSyncTimer: Timer?

    // Sync statistics
    private(set) var lastSyncDate: Date?
    private(set) var lastSyncStats: SyncStats?

    // MARK: - Initialization

    private init() {
        // Will be initialized when startMonitoring() is called
    }

    // MARK: - Sync Statistics

    struct SyncStats {
        var filesScanned: Int = 0
        var filesAdded: Int = 0
        var filesUpdated: Int = 0
        var filesDeleted: Int = 0
        var indexEntriesAdded: Int = 0
        var indexEntriesUpdated: Int = 0
        var indexEntriesDeleted: Int = 0
        var conflicts: Int = 0
        var errors: Int = 0

        var totalChanges: Int {
            return filesAdded + filesUpdated + filesDeleted + indexEntriesAdded + indexEntriesUpdated + indexEntriesDeleted
        }
    }

    // MARK: - Public Sync Methods

    /// Perform a full sync between files and index
    @discardableResult
    func performFullSync() -> SyncStats {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return lastSyncStats ?? SyncStats()
        }

        isSyncing = true
        defer { isSyncing = false }

        print("🔄 Starting full sync...")
        var stats = SyncStats()

        // Step 1: Scan all markdown files
        let files = markdownService.scanAllFiles()
        stats.filesScanned = files.count
        print("📁 Found \(files.count) markdown files")

        // Step 2: Build map of files by UUID and path, detect filename/title mismatches
        var filesByUUID: [String: URL] = [:]
        var filesByPath: [String: URL] = [:]

        for fileURL in files {
            guard let (metadata, content) = markdownService.readFile(at: fileURL) else {
                continue
            }

            // Check if filename matches YAML title
            let filenameTitle = extractTitleFromFilename(fileURL)
            if filenameTitle != metadata.title && !filenameTitle.isEmpty {
                // Filename changed externally, update YAML to match
                print("📝 Detected filename/title mismatch: file='\(filenameTitle)' yaml='\(metadata.title)'")
                print("   Updating YAML title to match filename: '\(filenameTitle)'")

                var updatedMetadata = metadata
                updatedMetadata.title = filenameTitle
                updatedMetadata.modified = Date()

                // Re-write file with updated YAML
                if markdownService.updateFile(metadata: updatedMetadata, content: content) {
                    print("   ✓ Updated YAML title in file")
                    // Use updated metadata for indexing
                    filesByUUID[updatedMetadata.uuid] = fileURL
                    if let path = updatedMetadata.path {
                        filesByPath[path] = fileURL
                    }
                    continue
                } else {
                    print("   ❌ Failed to update YAML title")
                }
            }

            filesByUUID[metadata.uuid] = fileURL
            if let path = metadata.path {
                filesByPath[path] = fileURL
            }
        }

        // Step 3: Get all notes from index
        let indexedNotes = indexService.getAllNotes()
        print("📊 Found \(indexedNotes.count) notes in index")

        // Build map of indexed notes
        var indexedByUUID: [String: NoteMetadata] = [:]
        var indexedByPath: [String: NoteMetadata] = [:]

        for note in indexedNotes {
            indexedByUUID[note.uuid] = note
            if let path = note.path {
                indexedByPath[path] = note
            }
        }

        // Step 4: Sync files → index (new or modified files)
        for fileURL in files {
            guard let (metadata, content) = markdownService.readFile(at: fileURL) else {
                stats.errors += 1
                continue
            }

            // Check if file exists in index
            if let indexedNote = indexedByUUID[metadata.uuid] {
                // File exists in index, check if modified
                let result = syncFileToIndex(metadata: metadata, content: content, existingNote: indexedNote, fileURL: fileURL)

                switch result {
                case .noChange:
                    break
                case .updated:
                    stats.indexEntriesUpdated += 1
                case .conflict:
                    stats.conflicts += 1
                case .error:
                    stats.errors += 1
                }
            } else {
                // New file, add to index
                if indexService.upsertNote(metadata) {
                    stats.indexEntriesAdded += 1
                    print("✓ Added new file to index: \(metadata.title)")
                } else {
                    stats.errors += 1
                }
            }

            // Remove from maps (we've processed it)
            indexedByUUID.removeValue(forKey: metadata.uuid)
            if let path = metadata.path {
                indexedByPath.removeValue(forKey: path)
            }
        }

        // Step 5: Handle orphaned index entries (files deleted from disk)
        for (uuid, note) in indexedByUUID {
            print("⚠️ File deleted from disk, removing from index: \(note.title)")
            _ = indexService.deleteNote(uuid: uuid)
            stats.indexEntriesDeleted += 1
        }

        // Update sync stats
        lastSyncDate = Date()
        lastSyncStats = stats

        print("✓ Sync complete: \(stats.totalChanges) changes")
        printSyncStats(stats)

        return stats
    }

    /// Perform a full sync and update CoreData sheets with file changes
    @discardableResult
    func performFullSyncWithCoreData(context: NSManagedObjectContext) -> SyncStats {
        print("🔄 performFullSyncWithCoreData called - starting full file→SQLite→CoreData sync")

        // First sync files → SQLite index
        let stats = performFullSync()

        print("✅ File→SQLite sync complete, now syncing SQLite→CoreData...")

        // Then sync SQLite index → CoreData sheets
        // This updates CoreData with any external file changes
        MarkdownCoreDataSync.shared.syncMarkdownToCoreData(context: context)

        print("✅ Full sync with CoreData complete")

        return stats
    }

    /// Sync a single file to the index
    private func syncFileToIndex(metadata: NoteMetadata, content: String, existingNote: NoteMetadata, fileURL: URL) -> SyncResult {

        // Check if file has been modified since last sync
        let fileModified = metadata.modified
        let indexModified = existingNote.modified

        // Compare content hashes
        let fileHash = metadata.contentHash ?? yamlService.generateContentHash(content)
        let indexHash = existingNote.contentHash

        if fileHash == indexHash {
            // No change
            return .noChange
        }

        // File has changed
        if fileModified > indexModified {
            // File is newer, update index
            if indexService.upsertNote(metadata) {
                print("✓ Updated index from file: \(metadata.title)")
                return .updated
            } else {
                print("❌ Failed to update index: \(metadata.title)")
                return .error
            }
        } else {
            // Potential conflict (index newer than file, but hashes differ)
            // For now, trust the file (it's the source of truth)
            if indexService.upsertNote(metadata) {
                print("⚠️ Resolved conflict (file wins): \(metadata.title)")
                return .conflict
            } else {
                return .error
            }
        }
    }

    /// Quick sync - only check modified files
    @discardableResult
    func performQuickSync() -> SyncStats {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return lastSyncStats ?? SyncStats()
        }

        isSyncing = true
        defer { isSyncing = false }

        var stats = SyncStats()

        // Get files modified since last sync
        let files = markdownService.scanAllFiles()
        stats.filesScanned = files.count

        let cutoffDate = lastSyncDate ?? Date.distantPast

        for fileURL in files {
            // Check file modification date
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modDate = attributes[.modificationDate] as? Date,
                  modDate > cutoffDate else {
                continue
            }

            // File modified since last sync, process it
            guard let (metadata, content) = markdownService.readFile(at: fileURL) else {
                stats.errors += 1
                continue
            }

            // Check if in index
            if let existingNote = indexService.getNote(uuid: metadata.uuid) {
                let result = syncFileToIndex(metadata: metadata, content: content, existingNote: existingNote, fileURL: fileURL)

                switch result {
                case .updated:
                    stats.indexEntriesUpdated += 1
                case .conflict:
                    stats.conflicts += 1
                case .error:
                    stats.errors += 1
                case .noChange:
                    break
                }
            } else {
                // New file
                if indexService.upsertNote(metadata) {
                    stats.indexEntriesAdded += 1
                }
            }
        }

        lastSyncDate = Date()
        lastSyncStats = stats

        return stats
    }

    // MARK: - Monitoring

    /// Start monitoring the Notes directory for changes
    func startMonitoring() {
        #if os(macOS)
        startFileWatcher()
        #else
        startBackgroundSync()
        #endif
    }

    /// Stop monitoring
    func stopMonitoring() {
        #if os(macOS)
        stopFileWatcher()
        #else
        stopBackgroundSync()
        #endif
    }

    #if os(macOS)
    /// Start file system watcher (macOS only)
    private func startFileWatcher() {
        let notesDir = markdownService.getNotesDirectory()

        guard fileManager.fileExists(atPath: notesDir.path) else {
            print("⚠️ Notes directory doesn't exist, cannot start file watcher")
            return
        }

        let fileDescriptor = open(notesDir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("❌ Failed to open directory for watching")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .background)
        )

        source.setEventHandler { [weak self] in
            print("📁 File system change detected, performing quick sync...")
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
                self?.performQuickSync()
            }
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        fileSystemWatcher = source

        print("✓ File watcher started for: \(notesDir.path)")
    }

    /// Stop file system watcher
    private func stopFileWatcher() {
        fileSystemWatcher?.cancel()
        fileSystemWatcher = nil
        print("✓ File watcher stopped")
    }
    #endif

    #if os(iOS)
    /// Start background sync timer (iOS only)
    private func startBackgroundSync() {
        // Sync every 30 seconds in background
        backgroundSyncTimer?.invalidate()
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            print("⏰ Background sync triggered...")
            self?.performQuickSync()
        }

        print("✓ Background sync started (30s interval)")
    }

    /// Stop background sync timer
    private func stopBackgroundSync() {
        backgroundSyncTimer?.invalidate()
        backgroundSyncTimer = nil
        print("✓ Background sync stopped")
    }
    #endif

    // MARK: - Helper Methods

    /// Extract title from filename (remove .md extension)
    private func extractTitleFromFilename(_ fileURL: URL) -> String {
        let filename = fileURL.lastPathComponent

        // Remove .md extension
        guard filename.hasSuffix(".md") else {
            return filename
        }

        let title = String(filename.dropLast(3)) // Remove ".md"
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func printSyncStats(_ stats: SyncStats) {
        print("""

        📊 Sync Statistics:
        ├─ Files scanned: \(stats.filesScanned)
        ├─ Files added: \(stats.filesAdded)
        ├─ Files updated: \(stats.filesUpdated)
        ├─ Files deleted: \(stats.filesDeleted)
        ├─ Index entries added: \(stats.indexEntriesAdded)
        ├─ Index entries updated: \(stats.indexEntriesUpdated)
        ├─ Index entries deleted: \(stats.indexEntriesDeleted)
        ├─ Conflicts: \(stats.conflicts)
        ├─ Errors: \(stats.errors)
        └─ Total changes: \(stats.totalChanges)

        """)
    }

    // MARK: - Sync Result

    private enum SyncResult {
        case noChange
        case updated
        case conflict
        case error
    }
}
