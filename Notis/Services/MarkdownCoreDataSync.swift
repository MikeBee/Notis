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
        let allNotes = indexService.getAllNotes()

        var updatedCount = 0
        var errorCount = 0

        for note in allNotes {
            // Find corresponding CoreData Sheet by UUID
            guard let sheetUUID = UUID(uuidString: note.uuid) else {
                continue
            }

            let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", sheetUUID as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                let results = try context.fetch(fetchRequest)
                guard let sheet = results.first else {
                    // Sheet doesn't exist in CoreData - this is OK, might be external file
                    continue
                }

                // Check if title needs updating
                if sheet.title != note.title {
                    print("📝 Syncing title change: '\(sheet.title ?? "")' → '\(note.title)'")
                    sheet.title = note.title
                    updatedCount += 1
                }

                // Update modified date if newer
                if note.modified > (sheet.modifiedAt ?? Date.distantPast) {
                    sheet.modifiedAt = note.modified
                }

                // Update favorite status
                let isFavorite = note.status == "favorite"
                if sheet.isFavorite != isFavorite {
                    sheet.isFavorite = isFavorite
                }

            } catch {
                print("❌ Failed to sync sheet \(note.uuid): \(error)")
                errorCount += 1
            }
        }

        // Save changes
        if updatedCount > 0 {
            do {
                try context.save()
                print("✓ Synced \(updatedCount) sheet(s) from markdown files to CoreData")
            } catch {
                print("❌ Failed to save CoreData context: \(error)")
            }
        }

        if errorCount > 0 {
            print("⚠️ Encountered \(errorCount) error(s) during sync")
        }
    }
}
