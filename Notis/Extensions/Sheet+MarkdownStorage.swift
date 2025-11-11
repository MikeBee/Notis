//
//  Sheet+MarkdownStorage.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import Foundation
import CoreData

/// Extension to provide markdown-based storage for Sheet entities
/// Integrates with the new file-based system (YAML frontmatter + SQLite index)
extension Sheet {

    // MARK: - Markdown Storage Properties

    /// Check if this sheet uses the new markdown storage system
    var usesMarkdownStorage: Bool {
        // Check if there's an entry in the SQLite index
        guard let uuid = id?.uuidString else { return false }
        return NotesIndexService.shared.getNote(uuid: uuid) != nil
    }

    /// Get the markdown metadata for this sheet
    var markdownMetadata: NoteMetadata? {
        guard let uuid = id?.uuidString else { return nil }
        return NotesIndexService.shared.getNote(uuid: uuid)
    }

    // MARK: - Unified Content Access

    /// Get content from markdown file, or fall back to CoreData/old file storage
    /// Priority: Markdown file → Old file storage → CoreData → Empty string
    var unifiedContent: String {
        get {
            // First check new markdown system
            if let metadata = markdownMetadata,
               let path = metadata.path,
               let (_, content) = MarkdownFileService.shared.readFile(path: path) {
                return content
            }

            // Fall back to old hybrid system
            return hybridContent
        }
        set {
            // Don't save to filesystem if sheet is in trash
            if isInTrash {
                // Just update in-memory content, don't persist to file
                return
            }

            // If already using markdown storage, update it
            if let metadata = markdownMetadata {
                updateMarkdownFile(content: newValue, existingMetadata: metadata)
            }
            // Otherwise, migrate to markdown storage on first edit
            else {
                migrateToMarkdownStorage(content: newValue)
            }
        }
    }

    // MARK: - Markdown Storage Operations

    /// Migrate this sheet to the new markdown storage system
    private func migrateToMarkdownStorage(content newContent: String) {
        // Don't migrate if sheet is in trash
        if isInTrash {
            return
        }

        // Don't migrate empty or whitespace-only content
        let trimmedContent = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            // Fall back to old storage for empty sheets
            print("⊘ Sheet has no content, keeping in CoreData: \(title ?? "Untitled")")
            hybridContent = newContent
            return
        }

        guard let uuid = id?.uuidString else {
            print("❌ Cannot migrate sheet without UUID")
            return
        }

        // Build metadata from CoreData sheet
        var metadata = buildNoteMetadata()

        print("🔄 Migrating sheet: '\(metadata.title)' with \(trimmedContent.count) chars")

        // Auto-generate better title if it's "Untitled" or empty
        if metadata.title.isEmpty || metadata.title == "Untitled" {
            let generatedTitle = generateTitleFromContent(trimmedContent)
            print("  📝 Auto-generated title: '\(generatedTitle)' from content")
            metadata.title = generatedTitle
            // Update CoreData title too
            title = generatedTitle
        }

        // Determine folder path from group hierarchy
        let folderPath = buildFolderPath()

        // Create markdown file
        print("  📄 Creating file: '\(metadata.title).md'")
        let result = MarkdownFileService.shared.createFile(
            title: metadata.title,
            content: newContent,
            folderPath: folderPath,
            tags: metadata.tags,
            metadata: metadata
        )

        guard result.success, let finalMetadata = result.metadata else {
            print("❌ Failed to create markdown file for: \(title ?? "Untitled")")
            // Fall back to old storage
            hybridContent = newContent
            return
        }

        // Add to SQLite index
        _ = NotesIndexService.shared.upsertNote(finalMetadata)

        // Clear old CoreData content to save space
        content = nil
        fileURL = nil

        // Update CoreData metadata
        updateMetadata(with: newContent)

        print("✓ Migrated sheet to markdown storage: \(title ?? "Untitled")")
    }

    /// Update existing markdown file
    private func updateMarkdownFile(content newContent: String, existingMetadata: NoteMetadata) {
        // Don't update file if sheet is in trash
        if isInTrash {
            return
        }

        // Update metadata
        var updatedMetadata = existingMetadata
        updatedMetadata.modified = Date()

        // Update from current sheet state
        let newTitle = title ?? "Untitled"
        updatedMetadata.title = newTitle
        updatedMetadata.tags = extractTags()

        // Calculate progress from goals
        if let goals = goals?.allObjects as? [Goal], let firstGoal = goals.first {
            if firstGoal.targetCount > 0 {
                updatedMetadata.progress = Double(firstGoal.currentCount) / Double(firstGoal.targetCount)
                updatedMetadata.progress = max(0.0, min(1.0, updatedMetadata.progress))
            }
        }

        // Update status
        updatedMetadata.status = isFavorite ? "favorite" : "draft"

        // Check if title changed and file needs to be renamed
        let titleChanged = existingMetadata.title != newTitle
        if titleChanged, let oldPath = existingMetadata.path {
            // Generate new file path with new title
            let oldURL = MarkdownFileService.shared.getNotesDirectory().appendingPathComponent(oldPath)
            let folder = (oldPath as NSString).deletingLastPathComponent
            let folderPath = folder.isEmpty ? nil : folder

            // Generate unique filename for new title
            let newURL = MarkdownFileService.shared.uniqueFileURL(title: newTitle, folderPath: folderPath)

            // Move the file to new name
            if MarkdownFileService.shared.moveFile(from: oldURL, to: newURL),
               let newRelativePath = MarkdownFileService.shared.relativePath(for: newURL) {
                // Update path in metadata
                updatedMetadata.path = newRelativePath
                print("✓ Renamed file from \(oldURL.lastPathComponent) to \(newURL.lastPathComponent)")
            } else {
                print("❌ Failed to rename file, keeping original path")
            }
        }

        // Write to markdown file
        if MarkdownFileService.shared.updateFile(metadata: updatedMetadata, content: newContent) {
            // Update SQLite index
            _ = NotesIndexService.shared.upsertNote(updatedMetadata)

            // Update CoreData metadata
            updateMetadata(with: newContent)
        } else {
            print("❌ Failed to update markdown file: \(title ?? "Untitled")")
        }
    }

    /// Save content using unified storage (convenience method)
    func saveUnifiedContent(_ newContent: String, context: NSManagedObjectContext) {
        self.unifiedContent = newContent

        // Save CoreData context (for metadata)
        do {
            try context.save()
        } catch {
            print("❌ Failed to save context: \(error)")
        }
    }

    // MARK: - Migration Helpers

    /// Build NoteMetadata from this CoreData sheet
    private func buildNoteMetadata() -> NoteMetadata {
        let uuid = id?.uuidString ?? UUID().uuidString
        let title = self.title ?? "Untitled"
        let created = createdAt ?? Date()
        let modified = modifiedAt ?? Date()
        let tags = extractTags()

        // Calculate progress from goals
        var progress: Double = 0.0
        if let goals = goals?.allObjects as? [Goal], let firstGoal = goals.first {
            if firstGoal.targetCount > 0 {
                progress = Double(firstGoal.currentCount) / Double(firstGoal.targetCount)
                progress = max(0.0, min(1.0, progress))
            }
        }

        let status = isFavorite ? "favorite" : "draft"

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

    /// Extract tags from CoreData relationships
    private func extractTags() -> [String] {
        var tagNames: [String] = []

        if let sheetTags = tags?.allObjects as? [SheetTag] {
            for sheetTag in sheetTags {
                if let tag = sheetTag.tag, let tagName = tag.name {
                    tagNames.append(tagName)
                }
            }
        }

        return tagNames
    }

    /// Build folder path from group hierarchy
    private func buildFolderPath() -> String? {
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

    /// Generate a title from content (first heading or first line)
    private func generateTitleFromContent(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)

        // Look for first markdown heading
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                // Extract heading text (remove # symbols and trim)
                let title = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    return String(title.prefix(100)) // Limit to 100 chars
                }
            }
        }

        // Fall back to first non-empty line
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return String(trimmed.prefix(100)) // Limit to 100 chars
            }
        }

        // Last resort
        return "Untitled"
    }
}
