//
//  FileStorageService.swift
//  Notis
//
//  Created by Claude on 11/9/25.
//

import Foundation
import CoreData

/// Service for managing file-based storage of sheet content
/// Provides migration support from Core Data to file storage
class FileStorageService {

    // MARK: - Singleton

    static let shared = FileStorageService()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let sheetsDirectory: URL

    // MARK: - Initialization

    private init() {
        #if os(iOS)
        // On iOS/iPadOS: Use Documents directory (accessible in Files app)
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        baseDirectory = documentsDir.appendingPathComponent("Notis", isDirectory: true)
        #else
        // On macOS: Use Application Support directory (standard for app data)
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDirectory = appSupport.appendingPathComponent("Notis", isDirectory: true)
        #endif

        // Create Sheets directory
        sheetsDirectory = baseDirectory.appendingPathComponent("Sheets", isDirectory: true)

        // Create directories if they don't exist
        createDirectories()
    }

    // MARK: - Directory Management

    /// Create necessary directories
    private func createDirectories() {
        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: sheetsDirectory, withIntermediateDirectories: true)
            print("✓ File storage directories created at: \(sheetsDirectory.path)")
        } catch {
            print("❌ Failed to create directories: \(error)")
        }
    }

    /// Get the base directory URL
    func getBaseDirectory() -> URL {
        return baseDirectory
    }

    /// Get the sheets directory URL
    func getSheetsDirectory() -> URL {
        return sheetsDirectory
    }

    // MARK: - File Path Management

    /// Sanitize a filename by removing invalid characters
    private func sanitizeFilename(_ filename: String) -> String {
        // Remove or replace characters not allowed in filenames
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let sanitized = filename.components(separatedBy: invalidCharacters).joined(separator: "-")

        // Trim whitespace and dots from ends
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        // Ensure not empty
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    /// Get the folder path for a group (recursive for nested groups)
    private func folderPath(for group: Group) -> String {
        var pathComponents: [String] = []
        var currentGroup: Group? = group

        // Build path from leaf to root
        while let group = currentGroup {
            let sanitizedName = sanitizeFilename(group.name ?? "Untitled")
            pathComponents.insert(sanitizedName, at: 0)
            currentGroup = group.parent
        }

        return pathComponents.joined(separator: "/")
    }

    /// Get the directory URL for a group
    private func directoryURL(for group: Group?) -> URL {
        guard let group = group else {
            return sheetsDirectory
        }

        let path = folderPath(for: group)
        return sheetsDirectory.appendingPathComponent(path, isDirectory: true)
    }

    /// Ensure directory exists for a group
    private func ensureDirectoryExists(for group: Group?) -> Bool {
        let dirURL = directoryURL(for: group)

        guard !fileManager.fileExists(atPath: dirURL.path) else {
            return true
        }

        do {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
            return true
        } catch {
            print("❌ Failed to create directory for group: \(error)")
            return false
        }
    }

    /// Generate a unique filename for a sheet (handles duplicates)
    private func uniqueFilename(for sheet: Sheet, in directory: URL) -> String {
        let title = sheet.title?.isEmpty == false ? sheet.title! : "Untitled"
        let baseName = sanitizeFilename(title)
        var filename = "\(baseName).md"
        var counter = 1

        // Check for duplicates and add number suffix if needed
        while fileManager.fileExists(atPath: directory.appendingPathComponent(filename).path) {
            // Skip if this is the current sheet's file
            if let currentURL = URL(string: sheet.fileURL ?? ""),
               currentURL.lastPathComponent == filename {
                break
            }
            filename = "\(baseName) \(counter).md"
            counter += 1
        }

        return filename
    }

    /// Generate a file URL for a sheet
    /// Format: {sheetsDirectory}/{group_path}/{title}.md
    func fileURL(for sheet: Sheet) -> URL? {
        guard sheet.id != nil else {
            print("❌ Sheet has no ID")
            return nil
        }

        // Ensure directory exists for the group
        guard ensureDirectoryExists(for: sheet.group) else {
            return nil
        }

        let directory = directoryURL(for: sheet.group)
        let filename = uniqueFilename(for: sheet, in: directory)

        return directory.appendingPathComponent(filename)
    }

    /// Get file path string for storage in Core Data
    func fileURLString(for sheet: Sheet) -> String? {
        return fileURL(for: sheet)?.path
    }

    /// Check if a file exists for a sheet
    func fileExists(for sheet: Sheet) -> Bool {
        // Check stored fileURL first
        if let storedPath = sheet.fileURL, !storedPath.isEmpty {
            return fileManager.fileExists(atPath: storedPath)
        }
        // Fall back to generated URL
        guard let url = fileURL(for: sheet) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Content Operations

    /// Read content from file
    /// Returns nil if file doesn't exist or can't be read
    func readContent(from sheet: Sheet) -> String? {
        // Try stored fileURL first (handles old location)
        if let storedPath = sheet.fileURL, !storedPath.isEmpty {
            let storedURL = URL(fileURLWithPath: storedPath)
            if fileManager.fileExists(atPath: storedPath) {
                do {
                    let content = try String(contentsOf: storedURL, encoding: .utf8)
                    return content
                } catch {
                    print("❌ Failed to read file at stored path: \(error)")
                }
            }
        }

        // Fall back to newly generated URL
        guard let newURL = fileURL(for: sheet) else {
            print("❌ Cannot generate file URL for sheet")
            return nil
        }

        do {
            let content = try String(contentsOf: newURL, encoding: .utf8)
            return content
        } catch {
            print("❌ Failed to read file for sheet \(sheet.title ?? "Untitled"): \(error)")
            return nil
        }
    }

    /// Write content to file
    /// Creates the file if it doesn't exist
    /// Handles file renames/moves when title or group changes
    /// Includes annotations and notes in markdown format
    /// Updates sheet's fileURL if successful
    @discardableResult
    func writeContent(_ content: String, to sheet: Sheet) -> Bool {
        guard let newURL = fileURL(for: sheet) else {
            print("❌ Cannot generate file URL for sheet")
            return false
        }

        // Check if file needs to be renamed/moved
        if let oldPath = sheet.fileURL, !oldPath.isEmpty {
            let oldURL = URL(fileURLWithPath: oldPath)

            // If path changed (title or group changed), move the file
            if oldURL.path != newURL.path && fileManager.fileExists(atPath: oldURL.path) {
                do {
                    // Ensure new directory exists
                    let newDir = newURL.deletingLastPathComponent()
                    if !fileManager.fileExists(atPath: newDir.path) {
                        try fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
                    }

                    // Move file to new location
                    try fileManager.moveItem(at: oldURL, to: newURL)
                    print("✓ Moved file from \(oldURL.lastPathComponent) to \(newURL.lastPathComponent)")

                    // Update stored path
                    sheet.fileURL = newURL.path
                } catch {
                    print("❌ Failed to move file: \(error)")
                    // Fall through to write content anyway
                }
            }
        }

        // Build full markdown content including annotations and notes
        let fullContent = buildFullMarkdownContent(content, for: sheet)

        // Write content to file
        do {
            try fullContent.write(to: newURL, atomically: true, encoding: .utf8)

            // Update sheet's fileURL
            sheet.fileURL = newURL.path

            return true
        } catch {
            print("❌ Failed to write file for sheet \(sheet.title ?? "Untitled"): \(error)")
            return false
        }
    }

    /// Build full markdown content including annotations and notes
    private func buildFullMarkdownContent(_ baseContent: String, for sheet: Sheet) -> String {
        var markdown = baseContent

        // Add annotations if any exist
        if let annotations = sheet.annotations?.allObjects as? [Annotation], !annotations.isEmpty {
            markdown += "\n\n---\n\n"
            markdown += "## Annotations\n\n"

            for annotation in annotations.sorted(by: { ($0.position) < ($1.position) }) {
                if let annotatedText = annotation.annotatedText, !annotatedText.isEmpty {
                    markdown += "### \(annotatedText)\n\n"
                }
                if let content = annotation.content, !content.isEmpty {
                    markdown += "\(content)\n\n"
                }
            }
        }

        // Add notes if any exist
        if let notes = sheet.notes?.allObjects as? [Note], !notes.isEmpty {
            markdown += "\n\n---\n\n"
            markdown += "## Notes\n\n"

            for note in notes.sorted(by: { ($0.sortOrder) < ($1.sortOrder) }) {
                if let content = note.content, !content.isEmpty {
                    markdown += "- \(content)\n"
                }
            }
        }

        return markdown
    }

    /// Delete file for a sheet
    @discardableResult
    func deleteFile(for sheet: Sheet) -> Bool {
        // Try stored path first
        var pathToDelete: String? = nil
        if let storedPath = sheet.fileURL, !storedPath.isEmpty, fileManager.fileExists(atPath: storedPath) {
            pathToDelete = storedPath
        } else if let url = fileURL(for: sheet) {
            pathToDelete = url.path
        }

        guard let path = pathToDelete, fileManager.fileExists(atPath: path) else {
            print("⚠️ File doesn't exist, nothing to delete")
            return true
        }

        do {
            let url = URL(fileURLWithPath: path)
            let parentDir = url.deletingLastPathComponent()

            try fileManager.removeItem(at: url)
            print("✓ Deleted file for sheet: \(sheet.title ?? "Untitled")")

            // Clean up empty parent directories
            cleanupEmptyDirectories(startingAt: parentDir)

            return true
        } catch {
            print("❌ Failed to delete file: \(error)")
            return false
        }
    }

    /// Clean up empty directories (recursive up to sheetsDirectory)
    private func cleanupEmptyDirectories(startingAt directory: URL) {
        var currentDir = directory

        // Don't delete the base sheets directory
        while currentDir.path != sheetsDirectory.path {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: currentDir.path)
                if contents.isEmpty {
                    try fileManager.removeItem(at: currentDir)
                    print("✓ Removed empty directory: \(currentDir.lastPathComponent)")
                    currentDir = currentDir.deletingLastPathComponent()
                } else {
                    // Directory not empty, stop cleanup
                    break
                }
            } catch {
                // Error or can't delete, stop cleanup
                break
            }
        }
    }

    // MARK: - Migration Support

    /// Migrate a single sheet from Core Data to file storage
    /// - Reads content from Core Data
    /// - Writes to file
    /// - Sets fileURL
    /// - Clears Core Data content field
    /// - Saves context
    func migrateSheet(_ sheet: Sheet, context: NSManagedObjectContext) -> Bool {
        // Check if already migrated
        if sheet.fileURL != nil && !sheet.fileURL!.isEmpty {
            print("⚠️ Sheet already migrated: \(sheet.title ?? "Untitled")")
            return true
        }

        // Get content from Core Data
        guard let content = sheet.content else {
            print("⚠️ Sheet has no content to migrate: \(sheet.title ?? "Untitled")")
            return false
        }

        // Write to file
        guard writeContent(content, to: sheet) else {
            return false
        }

        // Clear Core Data content to save space
        sheet.content = nil

        // Save context
        do {
            try context.save()
            print("✓ Migrated sheet to file storage: \(sheet.title ?? "Untitled")")
            return true
        } catch {
            print("❌ Failed to save context after migration: \(error)")
            return false
        }
    }

    /// Migrate all sheets to file storage
    func migrateAllSheets(context: NSManagedObjectContext, progressHandler: ((Int, Int) -> Void)? = nil) -> (success: Int, failed: Int) {
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()

        do {
            let sheets = try context.fetch(fetchRequest)
            var successCount = 0
            var failedCount = 0

            for (index, sheet) in sheets.enumerated() {
                // Skip if already migrated
                if sheet.fileURL != nil && !sheet.fileURL!.isEmpty {
                    successCount += 1
                    progressHandler?(index + 1, sheets.count)
                    continue
                }

                // Migrate sheet
                if migrateSheet(sheet, context: context) {
                    successCount += 1
                } else {
                    failedCount += 1
                }

                progressHandler?(index + 1, sheets.count)
            }

            print("✓ Migration complete: \(successCount) success, \(failedCount) failed")
            return (successCount, failedCount)

        } catch {
            print("❌ Failed to fetch sheets for migration: \(error)")
            return (0, 0)
        }
    }

    /// Revert a sheet from file storage back to Core Data
    /// Useful for rollback or troubleshooting
    func revertSheet(_ sheet: Sheet, context: NSManagedObjectContext) -> Bool {
        // Check if using file storage
        guard let fileURLString = sheet.fileURL, !fileURLString.isEmpty else {
            print("⚠️ Sheet not using file storage: \(sheet.title ?? "Untitled")")
            return true
        }

        // Read content from file
        guard let content = readContent(from: sheet) else {
            print("❌ Failed to read file content for revert")
            return false
        }

        // Write to Core Data
        sheet.content = content

        // Clear fileURL
        sheet.fileURL = nil

        // Save context
        do {
            try context.save()
            print("✓ Reverted sheet to Core Data storage: \(sheet.title ?? "Untitled")")
            return true
        } catch {
            print("❌ Failed to save context after revert: \(error)")
            return false
        }
    }

    /// Migrate old UUID-based files to new title-based folder structure
    /// This moves files from {UUID}.md to {GroupPath}/{Title}.md
    func migrateToNewFileStructure(context: NSManagedObjectContext, progressHandler: ((Int, Int) -> Void)? = nil) -> (success: Int, failed: Int, skipped: Int) {
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()

        do {
            let sheets = try context.fetch(fetchRequest)
            var successCount = 0
            var failedCount = 0
            var skippedCount = 0

            for (index, sheet) in sheets.enumerated() {
                defer {
                    progressHandler?(index + 1, sheets.count)
                }

                // Skip sheets without fileURL
                guard let oldPath = sheet.fileURL, !oldPath.isEmpty else {
                    skippedCount += 1
                    continue
                }

                let oldURL = URL(fileURLWithPath: oldPath)

                // Check if file exists at old location
                guard fileManager.fileExists(atPath: oldURL.path) else {
                    print("⚠️ File not found at old location: \(oldURL.lastPathComponent)")
                    failedCount += 1
                    continue
                }

                // Generate new URL based on current title and group
                guard let newURL = fileURL(for: sheet) else {
                    print("❌ Cannot generate new URL for sheet: \(sheet.title ?? "Untitled")")
                    failedCount += 1
                    continue
                }

                // Skip if already in correct location
                if oldURL.path == newURL.path {
                    skippedCount += 1
                    continue
                }

                // Move file to new location
                do {
                    // Ensure destination directory exists
                    let newDir = newURL.deletingLastPathComponent()
                    if !fileManager.fileExists(atPath: newDir.path) {
                        try fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
                    }

                    // Handle existing file at destination
                    if fileManager.fileExists(atPath: newURL.path) {
                        // If destination exists and is different, add a number suffix
                        print("⚠️ File already exists at new location, will create unique name")
                    }

                    // Move the file
                    try fileManager.moveItem(at: oldURL, to: newURL)

                    // Update fileURL in Core Data
                    sheet.fileURL = newURL.path

                    // Save context
                    try context.save()

                    print("✓ Migrated: \(oldURL.lastPathComponent) → \(newURL.lastPathComponent)")
                    successCount += 1

                    // Clean up empty old directory
                    let oldDir = oldURL.deletingLastPathComponent()
                    cleanupEmptyDirectories(startingAt: oldDir)

                } catch {
                    print("❌ Failed to migrate \(sheet.title ?? "Untitled"): \(error)")
                    failedCount += 1
                }
            }

            print("\n✓ File structure migration complete:")
            print("  - Migrated: \(successCount)")
            print("  - Failed: \(failedCount)")
            print("  - Skipped: \(skippedCount)")

            return (successCount, failedCount, skippedCount)

        } catch {
            print("❌ Failed to fetch sheets for migration: \(error)")
            return (0, 0, 0)
        }
    }

    // MARK: - Diagnostics

    /// Get storage statistics
    func getStorageStats(context: NSManagedObjectContext) -> (total: Int, fileStorage: Int, coreData: Int, hybrid: Int) {
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()

        do {
            let sheets = try context.fetch(fetchRequest)
            let total = sheets.count

            var fileStorage = 0
            var coreData = 0
            var hybrid = 0

            for sheet in sheets {
                let hasFileURL = sheet.fileURL != nil && !sheet.fileURL!.isEmpty
                let hasContent = sheet.content != nil && !sheet.content!.isEmpty

                if hasFileURL && hasContent {
                    hybrid += 1
                } else if hasFileURL {
                    fileStorage += 1
                } else if hasContent {
                    coreData += 1
                }
            }

            return (total, fileStorage, coreData, hybrid)

        } catch {
            print("❌ Failed to fetch sheets for stats: \(error)")
            return (0, 0, 0, 0)
        }
    }

    /// Print storage statistics
    func printStorageStats(context: NSManagedObjectContext) {
        let stats = getStorageStats(context: context)
        print("""

        📊 Storage Statistics:
        ├─ Total sheets: \(stats.total)
        ├─ File storage: \(stats.fileStorage)
        ├─ Core Data: \(stats.coreData)
        └─ Hybrid: \(stats.hybrid)

        """)
    }

    /// Verify file integrity for all sheets
    func verifyFileIntegrity(context: NSManagedObjectContext) -> (valid: Int, missing: Int) {
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()

        do {
            let sheets = try context.fetch(fetchRequest)
            var validCount = 0
            var missingCount = 0

            for sheet in sheets {
                // Skip sheets not using file storage
                guard let fileURLString = sheet.fileURL, !fileURLString.isEmpty else {
                    continue
                }

                // Check if file exists
                if fileExists(for: sheet) {
                    validCount += 1
                } else {
                    missingCount += 1
                    print("⚠️ Missing file for sheet: \(sheet.title ?? "Untitled")")
                }
            }

            print("✓ File integrity check: \(validCount) valid, \(missingCount) missing")
            return (validCount, missingCount)

        } catch {
            print("❌ Failed to verify file integrity: \(error)")
            return (0, 0)
        }
    }
}
