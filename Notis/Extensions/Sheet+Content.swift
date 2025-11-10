//
//  Sheet+Content.swift
//  Notis
//
//  Created by Claude on 11/9/25.
//

import Foundation
import CoreData

/// Extension to provide hybrid content access for Sheet entities
/// Seamlessly handles both Core Data and file-based storage
extension Sheet {

    // MARK: - Hybrid Content Access

    /// Get content from either file storage or Core Data
    /// Priority: File storage → Core Data → Empty string
    var hybridContent: String {
        get {
            // If fileURL exists, read from file
            if let fileURLString = fileURL, !fileURLString.isEmpty {
                if let fileContent = FileStorageService.shared.readContent(from: self) {
                    return fileContent
                }
            }

            // Fallback to Core Data content
            return content ?? ""
        }
        set {
            // Don't create files for empty content
            let trimmedContent = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

            // If sheet already has a fileURL, write to file
            if let fileURLString = fileURL, !fileURLString.isEmpty {
                FileStorageService.shared.writeContent(newValue, to: self)
                updateMetadata(with: newValue)
            }
            // If content exists in Core Data (old sheet), keep using Core Data
            else if content != nil {
                content = newValue
                updateMetadata(with: newValue)
            }
            // New sheet with actual content - use Core Data (let unifiedContent handle migration)
            else if !trimmedContent.isEmpty {
                content = newValue
                updateMetadata(with: newValue)
            }
            // New sheet with no content - just store in Core Data
            else {
                content = newValue
                updateMetadata(with: newValue)
            }
        }
    }

    /// Check if this sheet is using file storage
    var usesFileStorage: Bool {
        return fileURL != nil && !fileURL!.isEmpty
    }

    /// Check if this sheet is using Core Data storage
    var usesCoreDataStorage: Bool {
        return !usesFileStorage && content != nil
    }

    /// Get the storage type for display purposes
    var storageType: String {
        if usesFileStorage {
            return "File"
        } else if usesCoreDataStorage {
            return "Database"
        } else {
            return "None"
        }
    }

    // MARK: - Content Operations

    /// Save content with context
    func saveHybridContent(_ newContent: String, context: NSManagedObjectContext) {
        self.hybridContent = newContent

        // Save Core Data context
        do {
            try context.save()
        } catch {
            print("❌ Failed to save context: \(error)")
        }
    }

    /// Initialize file storage for a new sheet
    func initializeFileStorage() {
        guard !usesFileStorage else {
            print("⚠️ Sheet already uses file storage")
            return
        }

        // Get existing content if any
        let existingContent = content ?? ""

        // Write to file
        FileStorageService.shared.writeContent(existingContent, to: self)

        print("✓ Initialized file storage for sheet: \(title ?? "Untitled")")
    }

    /// Migrate this sheet from Core Data to file storage
    func migrateToFileStorage(context: NSManagedObjectContext) -> Bool {
        guard !usesFileStorage else {
            print("⚠️ Sheet already uses file storage")
            return true
        }

        let success = FileStorageService.shared.migrateSheet(self, context: context)

        if success {
            print("✓ Migrated sheet to file storage: \(title ?? "Untitled")")
        } else {
            print("❌ Failed to migrate sheet: \(title ?? "Untitled")")
        }

        return success
    }

    // MARK: - Internal Helpers

    /// Update word count and preview from content
    func updateMetadata(with newContent: String) {
        // Update word count
        let words = newContent.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        wordCount = Int32(words.count)

        // Update preview
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 200 {
            preview = trimmed
        } else {
            preview = String(trimmed.prefix(200)) + "..."
        }

        // Update modified date
        modifiedAt = Date()
    }
}
