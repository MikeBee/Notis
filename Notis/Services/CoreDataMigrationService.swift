//
//  CoreDataMigrationService.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import Foundation
import CoreData

/// Service for migrating CoreData sheets to file-based markdown storage
class CoreDataMigrationService {

    // MARK: - Singleton

    static let shared = CoreDataMigrationService()

    // MARK: - Properties

    private let markdownService = MarkdownFileService.shared
    private let indexService = NotesIndexService.shared
    private let yamlService = YAMLFrontmatterService.shared
    private let fileManager = FileManager.default

    private var isMigrating = false

    // MARK: - Migration Statistics

    struct MigrationStats {
        var totalSheets: Int = 0
        var migratedSheets: Int = 0
        var skippedSheets: Int = 0
        var failedSheets: Int = 0
        var errors: [String] = []

        var progress: Double {
            guard totalSheets > 0 else { return 0 }
            return Double(migratedSheets + skippedSheets + failedSheets) / Double(totalSheets)
        }
    }

    // MARK: - Migration Result

    struct MigrationResult {
        let success: Bool
        let stats: MigrationStats
        let backupPath: String?
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Migration Methods

    /// Perform a dry run to preview what will be migrated
    func performDryRun(context: NSManagedObjectContext) -> MigrationStats {
        print("🔍 Performing dry run migration preview...")

        var stats = MigrationStats()

        // Fetch all non-trashed sheets
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isInTrash == NO OR isInTrash == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)]

        do {
            let sheets = try context.fetch(fetchRequest)
            stats.totalSheets = sheets.count

            print("📊 Found \(sheets.count) sheets to migrate")

            for sheet in sheets {
                // Check if sheet has content
                let content = sheet.hybridContent
                if content.isEmpty {
                    stats.skippedSheets += 1
                    print("  ⊘ Skip: \(sheet.title ?? "Untitled") (no content)")
                } else {
                    stats.migratedSheets += 1
                    print("  ✓ Will migrate: \(sheet.title ?? "Untitled") (\(content.count) chars)")
                }
            }

            print("\n📊 Dry Run Summary:")
            print("  Total: \(stats.totalSheets)")
            print("  To migrate: \(stats.migratedSheets)")
            print("  To skip: \(stats.skippedSheets)")

        } catch {
            print("❌ Failed to fetch sheets: \(error)")
            stats.errors.append("Failed to fetch sheets: \(error.localizedDescription)")
        }

        return stats
    }

    /// Perform full migration from CoreData to markdown files
    func performMigration(
        context: NSManagedObjectContext,
        createBackup: Bool = true,
        progressHandler: ((MigrationStats) -> Void)? = nil
    ) -> MigrationResult {

        guard !isMigrating else {
            print("⚠️ Migration already in progress")
            return MigrationResult(success: false, stats: MigrationStats(), backupPath: nil)
        }

        isMigrating = true
        defer { isMigrating = false }

        var stats = MigrationStats()
        var backupPath: String? = nil

        // Step 1: Create backup if requested
        if createBackup {
            print("💾 Creating backup before migration...")
            backupPath = createBackup(context: context)
            if backupPath == nil {
                print("⚠️ Backup creation failed, but continuing with migration")
            } else {
                print("✓ Backup created at: \(backupPath!)")
            }
        }

        // Step 2: Fetch all sheets to migrate
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isInTrash == NO OR isInTrash == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)]

        do {
            let sheets = try context.fetch(fetchRequest)
            stats.totalSheets = sheets.count

            print("\n🔄 Starting migration of \(sheets.count) sheets...")

            // Step 3: Migrate each sheet
            for (index, sheet) in sheets.enumerated() {
                let result = migrateSheet(sheet, context: context)

                switch result {
                case .success:
                    stats.migratedSheets += 1
                case .skipped(let reason):
                    stats.skippedSheets += 1
                    print("  ⊘ Skipped: \(sheet.title ?? "Untitled") - \(reason)")
                case .failed(let error):
                    stats.failedSheets += 1
                    stats.errors.append("\(sheet.title ?? "Untitled"): \(error)")
                    print("  ❌ Failed: \(sheet.title ?? "Untitled") - \(error)")
                }

                // Report progress
                progressHandler?(stats)

                // Log progress every 10 sheets
                if (index + 1) % 10 == 0 {
                    print("  Progress: \(index + 1)/\(sheets.count) sheets processed")
                }
            }

            // Step 4: Sync all new files to index
            print("\n📊 Syncing migrated files to index...")
            _ = FileSyncService.shared.performFullSync()

            // Step 5: Print summary
            printMigrationSummary(stats)

            return MigrationResult(
                success: stats.failedSheets == 0,
                stats: stats,
                backupPath: backupPath
            )

        } catch {
            print("❌ Failed to fetch sheets for migration: \(error)")
            stats.errors.append("Failed to fetch sheets: \(error.localizedDescription)")
            return MigrationResult(success: false, stats: stats, backupPath: backupPath)
        }
    }

    // MARK: - Private Migration Methods

    /// Migrate a single sheet to markdown file
    private func migrateSheet(_ sheet: Sheet, context: NSManagedObjectContext) -> MigrationSheetResult {

        // Get content
        let content = sheet.hybridContent
        guard !content.isEmpty else {
            return .skipped("No content")
        }

        // Build metadata
        guard let metadata = buildMetadata(from: sheet) else {
            return .failed("Failed to build metadata")
        }

        // Build full markdown content with annotations and notes
        let fullContent = buildFullContent(from: sheet, baseContent: content)

        // Determine folder path from group hierarchy
        let folderPath = buildFolderPath(from: sheet.group)

        // Create markdown file
        let result = markdownService.createFile(
            title: metadata.title,
            content: fullContent,
            folderPath: folderPath,
            tags: metadata.tags,
            metadata: metadata
        )

        guard result.success, let finalMetadata = result.metadata else {
            return .failed("Failed to create markdown file")
        }

        // Add to index
        guard indexService.upsertNote(finalMetadata) else {
            return .failed("Failed to add to index")
        }

        print("  ✓ Migrated: \(metadata.title)")
        return .success
    }

    /// Build NoteMetadata from CoreData Sheet
    private func buildMetadata(from sheet: Sheet) -> NoteMetadata? {

        guard let uuid = sheet.id?.uuidString else {
            print("❌ Sheet has no UUID")
            return nil
        }

        let title = sheet.title ?? "Untitled"
        let created = sheet.createdAt ?? Date()
        let modified = sheet.modifiedAt ?? Date()

        // Extract tags from relationships
        var tags: [String] = []
        if let sheetTags = sheet.tags?.allObjects as? [SheetTag] {
            for sheetTag in sheetTags {
                if let tag = sheetTag.tag, let tagName = tag.name {
                    tags.append(tagName)
                }
            }
        }

        // Calculate progress from goals if available
        var progress: Double = 0.0
        if let goals = sheet.goals?.allObjects as? [Goal], let firstGoal = goals.first {
            if firstGoal.targetCount > 0 {
                progress = Double(firstGoal.currentCount) / Double(firstGoal.targetCount)
                progress = max(0.0, min(1.0, progress)) // Clamp to 0-1
            }
        }

        // Determine status
        let status = sheet.isFavorite ? "favorite" : "draft"

        return NoteMetadata(
            uuid: uuid,
            title: title,
            tags: tags,
            created: created,
            modified: modified,
            progress: progress,
            status: status
        )
    }

    /// Build full markdown content including annotations and notes
    private func buildFullContent(from sheet: Sheet, baseContent: String) -> String {
        var markdown = baseContent

        // Add annotations if any exist
        if let annotations = sheet.annotations?.allObjects as? [Annotation], !annotations.isEmpty {
            markdown += "\n\n---\n\n"
            markdown += "## Annotations\n\n"

            let sortedAnnotations = annotations.sorted { $0.position < $1.position }

            for annotation in sortedAnnotations {
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

            let sortedNotes = notes.sorted { $0.sortOrder < $1.sortOrder }

            for note in sortedNotes {
                if let content = note.content, !content.isEmpty {
                    markdown += "- \(content)\n"
                }
            }
        }

        return markdown
    }

    /// Build folder path from group hierarchy
    private func buildFolderPath(from group: Group?) -> String? {
        guard let group = group else { return nil }

        var pathComponents: [String] = []
        var currentGroup: Group? = group

        // Build path from leaf to root
        while let g = currentGroup {
            if let name = g.name, !name.isEmpty {
                pathComponents.insert(name, at: 0)
            }
            currentGroup = g.parent
        }

        guard !pathComponents.isEmpty else { return nil }
        return pathComponents.joined(separator: "/")
    }

    // MARK: - Backup

    /// Create a backup of the CoreData database
    private func createBackup(context: NSManagedObjectContext) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let backupDir = markdownService.getNotesDirectory()
            .deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)

        // Create backups directory
        do {
            try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create backup directory: \(error)")
            return nil
        }

        let backupFile = backupDir.appendingPathComponent("coredata_backup_\(timestamp).json")

        // Export all sheets to JSON
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isInTrash == NO OR isInTrash == nil")

        do {
            let sheets = try context.fetch(fetchRequest)

            let backupData = sheets.map { sheet in
                return [
                    "id": sheet.id?.uuidString ?? "",
                    "title": sheet.title ?? "",
                    "content": sheet.hybridContent,
                    "createdAt": ISO8601DateFormatter().string(from: sheet.createdAt ?? Date()),
                    "modifiedAt": ISO8601DateFormatter().string(from: sheet.modifiedAt ?? Date()),
                    "groupName": sheet.group?.name ?? "",
                    "wordCount": sheet.wordCount,
                    "isFavorite": sheet.isFavorite
                ] as [String : Any]
            }

            let jsonData = try JSONSerialization.data(withJSONObject: backupData, options: .prettyPrinted)
            try jsonData.write(to: backupFile)

            return backupFile.path

        } catch {
            print("❌ Failed to create backup: \(error)")
            return nil
        }
    }

    // MARK: - Utilities

    private func printMigrationSummary(_ stats: MigrationStats) {
        print("""

        ✅ Migration Complete!

        📊 Summary:
        ├─ Total sheets: \(stats.totalSheets)
        ├─ Migrated: \(stats.migratedSheets) ✓
        ├─ Skipped: \(stats.skippedSheets) ⊘
        └─ Failed: \(stats.failedSheets) ❌

        """)

        if !stats.errors.isEmpty {
            print("⚠️ Errors encountered:")
            for error in stats.errors {
                print("  • \(error)")
            }
        }
    }

    // MARK: - Migration Result Enum

    private enum MigrationSheetResult {
        case success
        case skipped(String)
        case failed(String)
    }
}
