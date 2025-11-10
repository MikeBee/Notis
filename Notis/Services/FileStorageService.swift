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
        // Get Application Support directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        // Create Notis directory
        baseDirectory = appSupport.appendingPathComponent("Notis", isDirectory: true)

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

    /// Generate a file URL for a sheet
    /// Format: {sheetsDirectory}/{sheetID}.md
    func fileURL(for sheet: Sheet) -> URL? {
        guard let id = sheet.id else {
            print("❌ Sheet has no ID")
            return nil
        }

        return sheetsDirectory.appendingPathComponent("\(id.uuidString).md")
    }

    /// Get file path string for storage in Core Data
    func fileURLString(for sheet: Sheet) -> String? {
        return fileURL(for: sheet)?.path
    }

    /// Check if a file exists for a sheet
    func fileExists(for sheet: Sheet) -> Bool {
        guard let url = fileURL(for: sheet) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Content Operations

    /// Read content from file
    /// Returns nil if file doesn't exist or can't be read
    func readContent(from sheet: Sheet) -> String? {
        guard let url = fileURL(for: sheet) else {
            print("❌ Cannot generate file URL for sheet")
            return nil
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return content
        } catch {
            print("❌ Failed to read file for sheet \(sheet.title ?? "Untitled"): \(error)")
            return nil
        }
    }

    /// Write content to file
    /// Creates the file if it doesn't exist
    /// Updates sheet's fileURL if successful
    @discardableResult
    func writeContent(_ content: String, to sheet: Sheet) -> Bool {
        guard let url = fileURL(for: sheet) else {
            print("❌ Cannot generate file URL for sheet")
            return false
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)

            // Update sheet's fileURL if not set
            if sheet.fileURL == nil || sheet.fileURL!.isEmpty {
                sheet.fileURL = url.path
            }

            return true
        } catch {
            print("❌ Failed to write file for sheet \(sheet.title ?? "Untitled"): \(error)")
            return false
        }
    }

    /// Delete file for a sheet
    @discardableResult
    func deleteFile(for sheet: Sheet) -> Bool {
        guard let url = fileURL(for: sheet) else {
            print("❌ Cannot generate file URL for sheet")
            return false
        }

        guard fileManager.fileExists(atPath: url.path) else {
            print("⚠️ File doesn't exist, nothing to delete")
            return true
        }

        do {
            try fileManager.removeItem(at: url)
            print("✓ Deleted file for sheet: \(sheet.title ?? "Untitled")")
            return true
        } catch {
            print("❌ Failed to delete file: \(error)")
            return false
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
