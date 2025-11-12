//
//  MarkdownFileService.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import Foundation

/// Service for managing markdown files with YAML frontmatter
class MarkdownFileService {

    // MARK: - Singleton

    static let shared = MarkdownFileService()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let yamlService = YAMLFrontmatterService.shared
    private let baseDirectory: URL
    private let notesDirectory: URL
    private let trashDirectory: URL

    // MARK: - Initialization

    private init() {
        #if os(iOS)
        // On iOS/iPadOS: Use Documents directory (accessible in Files app)
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        baseDirectory = documentsDir.appendingPathComponent("Notis", isDirectory: true)
        #else
        // On macOS: Use Application Support directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDirectory = appSupport.appendingPathComponent("Notis", isDirectory: true)
        #endif

        // Create Notes directory for markdown files
        notesDirectory = baseDirectory.appendingPathComponent("Notes", isDirectory: true)

        // Create .Trash directory for deleted files
        trashDirectory = baseDirectory.appendingPathComponent(".Trash", isDirectory: true)

        // Create directories if they don't exist
        createDirectories()
    }

    // MARK: - Directory Management

    /// Create necessary directories
    private func createDirectories() {
        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create directories: \(error)")
        }
    }

    /// Get the notes directory URL
    func getNotesDirectory() -> URL {
        return notesDirectory
    }

    /// Get the trash directory URL
    func getTrashDirectory() -> URL {
        return trashDirectory
    }

    /// Create a subdirectory within notes
    func createFolder(path: String) -> Bool {
        let folderURL = notesDirectory.appendingPathComponent(path, isDirectory: true)

        guard !fileManager.fileExists(atPath: folderURL.path) else {
            return true // Already exists
        }

        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            return true
        } catch {
            print("❌ Failed to create folder '\(path)': \(error)")
            return false
        }
    }

    // MARK: - File Path Management

    /// Sanitize a filename by removing invalid characters
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let sanitized = filename.components(separatedBy: invalidCharacters).joined(separator: "-")
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    /// Generate a file URL from metadata
    func fileURL(for metadata: NoteMetadata) -> URL {
        if let path = metadata.path {
            return notesDirectory.appendingPathComponent(path)
        }

        // Generate from title
        let sanitizedTitle = sanitizeFilename(metadata.title)
        let filename = "\(sanitizedTitle).md"
        return notesDirectory.appendingPathComponent(filename)
    }

    /// Generate a unique file URL to avoid conflicts
    func uniqueFileURL(title: String, folderPath: String? = nil) -> URL {
        let sanitizedTitle = sanitizeFilename(title)
        var filename = "\(sanitizedTitle).md"

        let directory: URL
        if let folderPath = folderPath, !folderPath.isEmpty {
            directory = notesDirectory.appendingPathComponent(folderPath, isDirectory: true)
        } else {
            directory = notesDirectory
        }

        var fileURL = directory.appendingPathComponent(filename)
        var counter = 1

        // Check for duplicates and add number suffix if needed
        while fileManager.fileExists(atPath: fileURL.path) {
            filename = "\(sanitizedTitle) \(counter).md"
            fileURL = directory.appendingPathComponent(filename)
            counter += 1
        }

        return fileURL
    }

    /// Get relative path from notes directory
    func relativePath(for url: URL) -> String? {
        guard url.path.hasPrefix(notesDirectory.path) else {
            return nil
        }

        let relativePath = url.path.replacingOccurrences(of: notesDirectory.path + "/", with: "")
        return relativePath
    }

    // MARK: - File Operations

    /// Create a new markdown file with metadata
    func createFile(title: String, content: String, folderPath: String? = nil, tags: [String] = [], metadata: NoteMetadata? = nil) -> (success: Bool, metadata: NoteMetadata?, url: URL?) {

        // Generate or use provided metadata
        var finalMetadata = metadata ?? NoteMetadata(
            title: title,
            tags: tags
        )

        // Generate unique file URL
        let fileURL = uniqueFileURL(title: title, folderPath: folderPath)

        // Set path in metadata
        if let relativePath = relativePath(for: fileURL) {
            finalMetadata.path = relativePath
        }

        // Update computed fields
        finalMetadata = updateComputedFields(metadata: finalMetadata, content: content)

        // Ensure directory exists
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create directory: \(error)")
                return (false, nil, nil)
            }
        }

        // Serialize to markdown with frontmatter
        let markdown = yamlService.serialize(metadata: finalMetadata, content: content)

        // Write to file
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            return (true, finalMetadata, fileURL)
        } catch {
            print("❌ Failed to write file: \(error)")
            return (false, nil, nil)
        }
    }

    /// Read a markdown file and parse metadata
    func readFile(at url: URL) -> (metadata: NoteMetadata, content: String)? {
        guard fileManager.fileExists(atPath: url.path) else {
            // File not existing is normal (e.g., for new notes), so don't log as error
            Logger.shared.debug("File doesn't exist: \(url.lastPathComponent)", category: .fileSystem)
            return nil
        }

        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)

            // Parse frontmatter
            guard let parsed = yamlService.parse(markdown) else {
                Logger.shared.warning("Failed to parse frontmatter in: \(url.lastPathComponent)", category: .fileSystem)
                return nil
            }

            var metadata = parsed.metadata

            // Always use actual file location as source of truth for path
            // This handles external file renames where YAML path may be stale
            metadata.path = relativePath(for: url)

            return (metadata, parsed.content)
        } catch {
            Logger.shared.error("Failed to read file", error: error, category: .fileSystem)
            return nil
        }
    }

    /// Read a markdown file by relative path
    func readFile(path: String) -> (metadata: NoteMetadata, content: String)? {
        let url = notesDirectory.appendingPathComponent(path)
        return readFile(at: url)
    }

    /// Update an existing markdown file
    func updateFile(metadata: NoteMetadata, content: String) -> Bool {
        guard let path = metadata.path else {
            Logger.shared.error("Metadata has no path", category: .fileSystem)
            return false
        }

        let fileURL = notesDirectory.appendingPathComponent(path)

        // Update computed fields
        var updatedMetadata = updateComputedFields(metadata: metadata, content: content)
        updatedMetadata.modified = Date()

        // Serialize to markdown
        let markdown = yamlService.serialize(metadata: updatedMetadata, content: content)

        // Write to file
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            Logger.shared.error("Failed to update file", error: error, category: .fileSystem, userMessage: "Could not save note changes")
            return false
        }
    }

    /// Delete a markdown file
    func deleteFile(at url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return true // Already deleted
        }

        do {
            try fileManager.removeItem(at: url)

            // Clean up empty directories
            cleanupEmptyDirectories(startingAt: url.deletingLastPathComponent())

            return true
        } catch {
            Logger.shared.error("Failed to delete file", error: error, category: .fileSystem, userMessage: "Could not delete note")
            return false
        }
    }

    /// Delete a markdown file by path
    func deleteFile(path: String) -> Bool {
        let url = notesDirectory.appendingPathComponent(path)
        return deleteFile(at: url)
    }

    /// Move or rename a file
    func moveFile(from oldURL: URL, to newURL: URL) -> Bool {
        guard fileManager.fileExists(atPath: oldURL.path) else {
            Logger.shared.warning("Source file doesn't exist for move operation", category: .fileSystem)
            return false
        }

        // Ensure destination directory exists
        let newDirectory = newURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: newDirectory.path) {
            do {
                try fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: true)
            } catch {
                Logger.shared.error("Failed to create destination directory", error: error, category: .fileSystem)
                return false
            }
        }

        // Move file
        do {
            try fileManager.moveItem(at: oldURL, to: newURL)

            // Clean up old directory if empty
            cleanupEmptyDirectories(startingAt: oldURL.deletingLastPathComponent())

            return true
        } catch {
            print("❌ Failed to move file: \(error)")
            return false
        }
    }

    /// Move a file to trash
    /// Returns: (success, trashURL) - the URL where the file was moved in trash
    func moveFileToTrash(at url: URL) -> (success: Bool, trashURL: URL?) {
        guard fileManager.fileExists(atPath: url.path) else {
            Logger.shared.warning("Source file doesn't exist for trash operation", category: .fileSystem)
            return (false, nil)
        }

        // Generate a unique filename in trash to avoid conflicts
        let filename = url.lastPathComponent
        var trashURL = trashDirectory.appendingPathComponent(filename)
        var counter = 1

        // Handle duplicate names in trash
        while fileManager.fileExists(atPath: trashURL.path) {
            let nameWithoutExt = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            let newFilename = "\(nameWithoutExt) \(counter).\(ext)"
            trashURL = trashDirectory.appendingPathComponent(newFilename)
            counter += 1
        }

        // Move file to trash
        do {
            try fileManager.moveItem(at: url, to: trashURL)

            // Clean up old directory if empty
            cleanupEmptyDirectories(startingAt: url.deletingLastPathComponent())

            return (true, trashURL)
        } catch {
            Logger.shared.error("Failed to move '\(filename)' to trash", error: error, category: .fileSystem, userMessage: "Could not move note to trash")
            return (false, nil)
        }
    }

    /// Move a file from trash back to notes directory
    func restoreFileFromTrash(trashURL: URL, toPath relativePath: String) -> Bool {
        guard fileManager.fileExists(atPath: trashURL.path) else {
            Logger.shared.warning("File doesn't exist in trash", category: .fileSystem)
            return false
        }

        let restoreURL = notesDirectory.appendingPathComponent(relativePath)

        // Ensure destination directory exists
        let restoreDirectory = restoreURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: restoreDirectory.path) {
            do {
                try fileManager.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
            } catch {
                Logger.shared.error("Failed to create restore directory", error: error, category: .fileSystem)
                return false
            }
        }

        // Check for conflicts
        if fileManager.fileExists(atPath: restoreURL.path) {
            Logger.shared.warning("File already exists at restore location: \(relativePath)", category: .fileSystem, userMessage: "A file with that name already exists")
            return false
        }

        // Move file back from trash
        do {
            try fileManager.moveItem(at: trashURL, to: restoreURL)
            return true
        } catch {
            print("❌ Failed to restore '\(relativePath)' from trash: \(error)")
            return false
        }
    }

    /// Permanently delete a file from trash
    func permanentlyDeleteFromTrash(at trashURL: URL) -> Bool {
        guard fileManager.fileExists(atPath: trashURL.path) else {
            return true // Already deleted
        }

        do {
            try fileManager.removeItem(at: trashURL)
            return true
        } catch {
            print("❌ Failed to permanently delete '\(trashURL.lastPathComponent)': \(error)")
            return false
        }
    }

    /// Get the relative path for a file in trash (for file manager display)
    func trashRelativePath(for url: URL) -> String? {
        guard url.path.hasPrefix(trashDirectory.path) else {
            return nil
        }

        let relativePath = url.path.replacingOccurrences(of: trashDirectory.path + "/", with: "")
        return relativePath
    }

    // MARK: - Content Processing

    /// Update computed fields (word count, excerpt, hash)
    private func updateComputedFields(metadata: NoteMetadata, content: String) -> NoteMetadata {
        var updated = metadata

        // Word count
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        updated.wordCount = words.count

        // Character count
        updated.charCount = content.count

        // Excerpt
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 200 {
            updated.excerpt = trimmed
        } else {
            updated.excerpt = String(trimmed.prefix(200)) + "..."
        }

        // Content hash
        updated.contentHash = yamlService.generateContentHash(content)

        return updated
    }

    // MARK: - Directory Cleanup

    /// Clean up empty directories (recursive up to notesDirectory)
    private func cleanupEmptyDirectories(startingAt directory: URL) {
        var currentDir = directory

        // Don't delete the base notes directory
        while currentDir.path != notesDirectory.path {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: currentDir.path)
                if contents.isEmpty {
                    try fileManager.removeItem(at: currentDir)
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

    // MARK: - Scanning

    /// Scan notes directory and return all markdown files
    func scanAllFiles() -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: notesDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var markdownFiles: [URL] = []

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "md" {
                markdownFiles.append(fileURL)
            }
        }

        return markdownFiles
    }

    /// Get all folder paths in notes directory
    func getAllFolders() -> [String] {
        guard let enumerator = fileManager.enumerator(
            at: notesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var folders: [String] = []

        for case let fileURL as URL in enumerator {
            if let isDirectory = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
               isDirectory {
                if let relativePath = relativePath(for: fileURL) {
                    folders.append(relativePath)
                }
            }
        }

        return folders.sorted()
    }
}
