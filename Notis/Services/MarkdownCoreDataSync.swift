//
//  MarkdownCoreDataSync.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import Foundation
import CoreData

/// Service to sync changes from markdown files back to CoreData
/// This handles external file edits (e.g., user renames file in Finder)
class MarkdownCoreDataSync {

    static let shared = MarkdownCoreDataSync()

    private let indexService = NotesIndexService.shared

    private init() {}

    /// Sync metadata from markdown files back to CoreData sheets
    /// Call this after FileSyncService updates the SQLite index
    func syncMarkdownToCoreData(context: NSManagedObjectContext) {
        print("🔄 Starting CoreData sync from markdown files...")

        let allNotes = indexService.getAllNotes()
        print("📊 Found \(allNotes.count) notes in SQLite index to sync")

        // Perform CoreData operations on the context's thread
        context.performAndWait {
            var updatedCount = 0
            var errorCount = 0
            var notFoundCount = 0

            for note in allNotes {
                // Find corresponding CoreData Sheet by UUID
                guard let sheetUUID = UUID(uuidString: note.uuid) else {
                    print("⚠️ Invalid UUID in note: \(note.uuid)")
                    continue
                }

                let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", sheetUUID as CVarArg)
                fetchRequest.fetchLimit = 1

                do {
                    let results = try context.fetch(fetchRequest)

                    if results.first == nil {
                        // Sheet doesn't exist in CoreData - create it from external file
                        print("📥 Importing external file as new sheet: '\(note.title)'")

                        let newSheet = Sheet(context: context)
                        newSheet.id = sheetUUID
                        newSheet.title = note.title
                        newSheet.createdAt = note.created
                        newSheet.modifiedAt = note.modified
                        newSheet.isFavorite = (note.status == "favorite")
                        newSheet.isInTrash = false

                        // Set fileURL to the markdown file path
                        if let notePath = note.path {
                            let fileURL = MarkdownFileService.shared.getNotesDirectory()
                                .appendingPathComponent(notePath)
                            newSheet.fileURL = fileURL.path
                        }

                        // Set group based on folder path
                        if let notePath = note.path {
                            newSheet.group = findOrCreateGroup(fromPath: notePath, context: context)
                        }

                        updatedCount += 1
                        continue
                    }

                    let sheet = results.first!
                    var changed = false

                    // Update fileURL if not set or different
                    if let notePath = note.path {
                        let expectedFileURL = MarkdownFileService.shared.getNotesDirectory()
                            .appendingPathComponent(notePath).path

                        if sheet.fileURL != expectedFileURL {
                            print("📎 Updating fileURL for '\(note.title)'")
                            sheet.fileURL = expectedFileURL
                            changed = true
                        }
                    }

                    // Check if title needs updating
                    if sheet.title != note.title {
                        print("📝 Syncing title change: '\(sheet.title ?? "")' → '\(note.title)'")
                        sheet.title = note.title
                        changed = true
                    }

                    // Update modified date if newer
                    if note.modified > (sheet.modifiedAt ?? Date.distantPast) {
                        sheet.modifiedAt = note.modified
                        changed = true
                    }

                    // Update favorite status
                    let isFavorite = note.status == "favorite"
                    if sheet.isFavorite != isFavorite {
                        sheet.isFavorite = isFavorite
                        changed = true
                    }

                    // Update group based on folder path
                    if let notePath = note.path {
                        let newGroup = findOrCreateGroup(fromPath: notePath, context: context)

                        if sheet.group != newGroup {
                            print("📁 Moving '\(note.title)': '\(sheet.group?.name ?? "root")' → '\(newGroup?.name ?? "root")'")
                            sheet.group = newGroup
                            changed = true
                        }
                    }

                    if changed {
                        updatedCount += 1
                    }

                } catch {
                    print("❌ Failed to sync sheet \(note.uuid): \(error)")
                    errorCount += 1
                }
            }

            // Clean up orphaned groups (no sheets, no subgroups, and no matching folder in filesystem)
            let deletedGroups = deleteOrphanedGroups(context: context)
            if deletedGroups > 0 {
                print("🗑️ Deleted \(deletedGroups) orphaned group(s)")
            }

            // Save changes
            if updatedCount > 0 || deletedGroups > 0 {
                do {
                    try context.save()
                    if updatedCount > 0 {
                        print("✅ Synced \(updatedCount) sheet(s) from markdown files to CoreData")
                    }
                } catch {
                    print("❌ Failed to save CoreData context: \(error)")
                }
            } else {
                print("ℹ️ No CoreData sheets needed updating (\(notFoundCount) notes have no matching sheet)")
            }

            if errorCount > 0 {
                print("⚠️ Encountered \(errorCount) error(s) during sync")
            }
        } // end context.performAndWait
    }

    // MARK: - Helper Methods

    /// Find or create a Group hierarchy from a file path
    /// Example: "Folder A/Subfolder/file.md" → Creates/finds "Folder A" and its child "Subfolder"
    /// Returns nil if file is at root (no folders in path)
    private func findOrCreateGroup(fromPath filePath: String, context: NSManagedObjectContext) -> Group? {
        // Extract folder path from file path
        let pathComponents = (filePath as NSString).pathComponents
        guard pathComponents.count > 1 else {
            // File is at root, no group
            return nil
        }

        // Remove the filename, leaving just the folder path components
        let folderComponents = Array(pathComponents.dropLast())

        var currentParent: Group? = nil

        // Traverse/create the group hierarchy
        for folderName in folderComponents {
            // Try to find existing group with this name and parent
            let fetchRequest: NSFetchRequest<Group> = Group.fetchRequest()
            if let parent = currentParent {
                fetchRequest.predicate = NSPredicate(format: "name == %@ AND parent == %@", folderName, parent)
            } else {
                fetchRequest.predicate = NSPredicate(format: "name == %@ AND parent == nil", folderName)
            }
            fetchRequest.fetchLimit = 1

            do {
                let results = try context.fetch(fetchRequest)
                if let existingGroup = results.first {
                    // Group exists, move to next level
                    currentParent = existingGroup
                } else {
                    // Group doesn't exist, create it
                    let newGroup = Group(context: context)
                    newGroup.id = UUID()
                    newGroup.name = folderName
                    newGroup.parent = currentParent
                    newGroup.createdAt = Date()
                    newGroup.modifiedAt = Date()
                    newGroup.sortOrder = Int32(currentParent?.subgroups?.count ?? 0)

                    print("📁 Created group from file path: \(folderName)")
                    currentParent = newGroup
                }
            } catch {
                print("❌ Failed to find/create group '\(folderName)': \(error)")
                return nil
            }
        }

        return currentParent
    }

    /// Delete orphaned groups - groups with no sheets, no subgroups, and no matching folder in filesystem
    /// This preserves intentional empty folders while cleaning up stale renamed folders
    /// Returns the number of deleted groups
    private func deleteOrphanedGroups(context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<Group> = Group.fetchRequest()
        let fileService = MarkdownFileService.shared

        // Get all folders that exist in filesystem
        let filesystemFolders = fileService.getAllFolders()

        var deletedCount = 0

        do {
            let allGroups = try context.fetch(fetchRequest)

            for group in allGroups {
                // Check if group has any sheets
                let hasSheets = (group.sheets?.count ?? 0) > 0

                // Check if group has any subgroups
                let hasSubgroups = (group.subgroups?.count ?? 0) > 0

                // Only consider deleting if empty
                if !hasSheets && !hasSubgroups {
                    // Build the folder path for this group
                    let groupFolderPath = group.folderPath()

                    // Check if this folder exists in filesystem
                    let existsInFilesystem = filesystemFolders.contains(groupFolderPath)

                    // Delete if no matching folder in filesystem
                    if !existsInFilesystem {
                        print("🗑️ Deleting orphaned group (no filesystem folder): '\(group.name ?? "Unknown")'")
                        context.delete(group)
                        deletedCount += 1
                    } else {
                        print("✓ Preserving empty group (folder exists): '\(group.name ?? "Unknown")'")
                    }
                }
            }
        } catch {
            print("❌ Failed to fetch groups for cleanup: \(error)")
        }

        return deletedCount
    }

    // MARK: - Group Folder Management

    /// Rename a group's folder on the filesystem and update all file paths
    /// Call this when a group is renamed in the UI
    func renameGroupFolder(group: Group, oldName: String, newName: String, context: NSManagedObjectContext) {
        print("📁 Renaming group folder: '\(oldName)' → '\(newName)'")

        let fileService = MarkdownFileService.shared
        let indexService = NotesIndexService.shared
        let notesDirectory = fileService.getNotesDirectory()

        // Build old and new folder paths
        let oldFolderPath = buildFolderPath(group: group, overrideName: oldName)
        let newFolderPath = buildFolderPath(group: group, overrideName: newName)

        let oldFolderURL = notesDirectory.appendingPathComponent(oldFolderPath, isDirectory: true)
        let newFolderURL = notesDirectory.appendingPathComponent(newFolderPath, isDirectory: true)

        // Check if old folder exists
        guard FileManager.default.fileExists(atPath: oldFolderURL.path) else {
            print("⚠️ Old folder doesn't exist: \(oldFolderPath)")
            return
        }

        // Check if new folder already exists (conflict)
        if FileManager.default.fileExists(atPath: newFolderURL.path) {
            print("❌ Cannot rename - folder already exists: \(newFolderPath)")
            return
        }

        // Ensure parent directory exists
        let newParentDirectory = newFolderURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: newParentDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: newParentDirectory, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create parent directory: \(error)")
                return
            }
        }

        // Rename the folder
        do {
            try FileManager.default.moveItem(at: oldFolderURL, to: newFolderURL)
            print("✓ Renamed folder on disk: \(oldFolderPath) → \(newFolderPath)")
        } catch {
            print("❌ Failed to rename folder: \(error)")
            return
        }

        // Update all file paths in this folder and subfolders
        updateFilePathsAfterFolderRename(oldBasePath: oldFolderPath, newBasePath: newFolderPath)

        // Trigger a sync to update CoreData
        MarkdownCoreDataSync.shared.syncMarkdownToCoreData(context: context)

        print("✓ Group folder rename complete")
    }

    /// Build the folder path for a group with an optional name override
    private func buildFolderPath(group: Group, overrideName: String? = nil) -> String {
        var pathComponents: [String] = []
        var currentGroup: Group? = group

        // Build path from leaf to root
        while let g = currentGroup {
            let name = (currentGroup == group && overrideName != nil) ? overrideName! : (g.name ?? "Untitled")
            pathComponents.insert(name, at: 0)
            currentGroup = g.parent
        }

        return pathComponents.joined(separator: "/")
    }

    /// Update all file paths after a folder rename
    private func updateFilePathsAfterFolderRename(oldBasePath: String, newBasePath: String) {
        let indexService = NotesIndexService.shared
        let fileService = MarkdownFileService.shared

        let allNotes = indexService.getAllNotes()

        for note in allNotes {
            guard let notePath = note.path else { continue }

            // Check if this file is in the renamed folder or a subfolder
            if notePath.hasPrefix(oldBasePath + "/") || notePath == oldBasePath {
                // Build new path by replacing the old base with the new base
                let newPath = notePath.replacingOccurrences(of: oldBasePath, with: newBasePath)

                // Read the file
                let oldFileURL = fileService.getNotesDirectory().appendingPathComponent(notePath)
                let newFileURL = fileService.getNotesDirectory().appendingPathComponent(newPath)

                guard let (metadata, content) = fileService.readFile(at: newFileURL) else {
                    print("⚠️ Failed to read file at new location: \(newPath)")
                    continue
                }

                // Update metadata with new path
                var updatedMetadata = metadata
                updatedMetadata.path = newPath
                updatedMetadata.modified = Date()

                // Write the file back with updated metadata
                let markdown = YAMLFrontmatterService.shared.serialize(metadata: updatedMetadata, content: content)
                do {
                    try markdown.write(to: newFileURL, atomically: true, encoding: .utf8)
                } catch {
                    print("❌ Failed to update file: \(error)")
                }

                // Update the index
                _ = indexService.upsertNote(updatedMetadata)
            }
        }
    }
}
