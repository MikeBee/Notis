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

            // Fall back to CoreData content
            return content ?? ""
        }
        set {
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
        guard let uuid = id?.uuidString else {
            Logger.shared.error("Cannot migrate sheet without UUID", category: .fileSystem)
            return
        }

        // Build metadata from CoreData sheet
        var metadata = buildNoteMetadata()

        // Check if content is empty for title generation
        let trimmedContent = newContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // Auto-generate better title if it's "Untitled" or empty
        if metadata.title.isEmpty || metadata.title == "Untitled" {
            if trimmedContent.isEmpty {
                // For empty sheets, use a timestamp-based title
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                metadata.title = "Note \(dateFormatter.string(from: Date()))"
            } else {
                let generatedTitle = generateTitleFromContent(trimmedContent)
                metadata.title = generatedTitle
            }
            // Update CoreData title too
            title = metadata.title
        }

        // Determine folder path from group hierarchy or .trash
        let folderPath: String?
        if isInTrash {
            folderPath = ".trash"
            Logger.shared.debug("Migrating trashed sheet to .trash folder: \(title ?? "Untitled")", category: .fileSystem)
        } else {
            folderPath = buildFolderPath()
        }

        // Create markdown file
        let result = MarkdownFileService.shared.createFile(
            title: metadata.title,
            content: newContent,
            folderPath: folderPath,
            tags: metadata.tags,
            metadata: metadata
        )

        guard result.success, let finalMetadata = result.metadata, let createdURL = result.url else {
            Logger.shared.error("Failed to create markdown file for: \(title ?? "Untitled")", category: .fileSystem, userMessage: "Could not save note to file. Data saved in database.")
            // Fall back to CoreData storage
            content = newContent
            updateMetadata(with: newContent)
            return
        }

        // Add to SQLite index
        _ = NotesIndexService.shared.upsertNote(finalMetadata)

        // Set fileURL to the created file's path
        fileURL = createdURL.path

        // Clear old CoreData content field to save space (content now in file)
        content = nil

        // Update CoreData metadata
        updateMetadata(with: newContent)

        if trimmedContent.isEmpty {
            Logger.shared.debug("Migrated empty sheet to filesystem: \(title ?? "Untitled")", category: .fileSystem)
        }
    }

    /// Update existing markdown file
    private func updateMarkdownFile(content newContent: String, existingMetadata: NoteMetadata) {
        guard let oldPath = existingMetadata.path else {
            Logger.shared.error("Cannot update file without path", category: .fileSystem)
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

        let oldURL = MarkdownFileService.shared.getNotesDirectory().appendingPathComponent(oldPath)
        let currentFolder = (oldPath as NSString).deletingLastPathComponent
        let isCurrentlyInTrash = currentFolder == ".trash"

        // Check if trash status changed or title changed
        let trashStatusChanged = isInTrash != isCurrentlyInTrash
        let titleChanged = existingMetadata.title != newTitle

        if trashStatusChanged || titleChanged {
            // Determine target folder
            let targetFolderPath: String?
            if isInTrash {
                targetFolderPath = ".trash"
                Logger.shared.debug("Moving sheet to .trash folder: \(newTitle)", category: .fileSystem)
            } else if trashStatusChanged && !isInTrash {
                // Restored from trash - move back to original group folder
                targetFolderPath = buildFolderPath()
                Logger.shared.debug("Restoring sheet from .trash folder: \(newTitle)", category: .fileSystem)
            } else {
                // Just a rename in same folder
                targetFolderPath = currentFolder.isEmpty ? nil : currentFolder
            }

            // Generate new file path
            let newURL = MarkdownFileService.shared.uniqueFileURL(title: newTitle, folderPath: targetFolderPath)

            // Move the file to new location/name
            if MarkdownFileService.shared.moveFile(from: oldURL, to: newURL),
               let newRelativePath = MarkdownFileService.shared.relativePath(for: newURL) {
                // Update path in metadata
                updatedMetadata.path = newRelativePath
                // Update fileURL in CoreData to point to new location
                self.fileURL = newURL.path
            } else {
                Logger.shared.warning("Failed to move file from '\(oldPath)' to '\(targetFolderPath ?? "")/\(newTitle)', keeping original path", category: .fileSystem)
            }
        }

        // Write to markdown file
        if MarkdownFileService.shared.updateFile(metadata: updatedMetadata, content: newContent) {
            // Update SQLite index
            _ = NotesIndexService.shared.upsertNote(updatedMetadata)

            // Update CoreData metadata
            updateMetadata(with: newContent)
        } else {
            Logger.shared.error("Failed to update markdown file: \(title ?? "Untitled")", category: .fileSystem, userMessage: "Could not save note changes")
        }
    }

    /// Save content using unified storage (convenience method)
    func saveUnifiedContent(_ newContent: String, context: NSManagedObjectContext) {
        self.unifiedContent = newContent

        // Save CoreData context (for metadata)
        do {
            try context.save()
        } catch {
            Logger.shared.error("Failed to save context", error: error, category: .coreData, userMessage: "Could not save note metadata")
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

    /// Update word count and preview from content
    private func updateMetadata(with newContent: String) {
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
