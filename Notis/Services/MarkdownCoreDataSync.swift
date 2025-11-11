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
                    guard let sheet = results.first else {
                        // Sheet doesn't exist in CoreData - this is OK, might be external file
                        print("⚠️ No CoreData sheet found for: '\(note.title)' (path: \(note.path ?? "no path"))")
                        notFoundCount += 1
                        continue
                    }

                    var changed = false

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
                        print("🔍 Checking folder for '\(note.title)': path='\(notePath)'")
                        let newGroup = findOrCreateGroup(fromPath: notePath, context: context)
                        print("   Current group: '\(sheet.group?.name ?? "root")', New group: '\(newGroup?.name ?? "root")'")

                        if sheet.group != newGroup {
                            print("📁 Syncing folder change: '\(sheet.group?.name ?? "root")' → '\(newGroup?.name ?? "root")'")
                            sheet.group = newGroup
                            changed = true
                        } else {
                            print("   ✓ Group already correct")
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

            // Clean up empty groups (folders with no sheets)
            let deletedGroups = deleteEmptyGroups(context: context)
            if deletedGroups > 0 {
                print("🗑️ Deleted \(deletedGroups) empty group(s)")
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

    /// Delete groups that have no sheets or subgroups
    /// Returns the number of deleted groups
    private func deleteEmptyGroups(context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<Group> = Group.fetchRequest()

        var deletedCount = 0

        do {
            let allGroups = try context.fetch(fetchRequest)

            for group in allGroups {
                // Check if group has any sheets
                let hasSheets = (group.sheets?.count ?? 0) > 0

                // Check if group has any subgroups
                let hasSubgroups = (group.subgroups?.count ?? 0) > 0

                // Delete if empty
                if !hasSheets && !hasSubgroups {
                    print("🗑️ Deleting empty group: '\(group.name ?? "Unknown")'")
                    context.delete(group)
                    deletedCount += 1
                }
            }
        } catch {
            print("❌ Failed to fetch groups for cleanup: \(error)")
        }

        return deletedCount
    }
}
