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

        // Create directories if they don't exist
        createDirectories()
    }

    // MARK: - Directory Management

    /// Create necessary directories
    private func createDirectories() {
        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
            print("✓ Markdown file storage directories created at: \(notesDirectory.path)")
        } catch {
            print("❌ Failed to create directories: \(error)")
        }
    }

    /// Get the notes directory URL
    func getNotesDirectory() -> URL {
        return notesDirectory
    }

    /// Create a subdirectory within notes
    func createFolder(path: String) -> Bool {
        let folderURL = notesDirectory.appendingPathComponent(path, isDirectory: true)

        guard !fileManager.fileExists(atPath: folderURL.path) else {
            return true // Already exists
        }

        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            print("✓ Created folder: \(path)")
            return true
        } catch {
            print("❌ Failed to create folder: \(error)")
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
            print("✓ Created file: \(fileURL.lastPathComponent)")
            return (true, finalMetadata, fileURL)
        } catch {
            print("❌ Failed to write file: \(error)")
            return (false, nil, nil)
        }
    }

    /// Read a markdown file and parse metadata
    func readFile(at url: URL) -> (metadata: NoteMetadata, content: String)? {
        guard fileManager.fileExists(atPath: url.path) else {
            print("❌ File doesn't exist: \(url.lastPathComponent)")
            return nil
        }

        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)

            // Parse frontmatter
            guard let parsed = yamlService.parse(markdown) else {
                print("❌ Failed to parse frontmatter in: \(url.lastPathComponent)")
                return nil
            }

            var metadata = parsed.metadata

            // Ensure path is set
            if metadata.path == nil {
                metadata.path = relativePath(for: url)
            }

            return (metadata, parsed.content)
        } catch {
            print("❌ Failed to read file: \(error)")
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
            print("❌ Metadata has no path")
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
            print("✓ Updated file: \(fileURL.lastPathComponent)")
            return true
        } catch {
            print("❌ Failed to update file: \(error)")
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
            print("✓ Deleted file: \(url.lastPathComponent)")

            // Clean up empty directories
            cleanupEmptyDirectories(startingAt: url.deletingLastPathComponent())

            return true
        } catch {
            print("❌ Failed to delete file: \(error)")
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
            print("❌ Source file doesn't exist")
            return false
        }

        // Ensure destination directory exists
        let newDirectory = newURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: newDirectory.path) {
            do {
                try fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create destination directory: \(error)")
                return false
            }
        }

        // Move file
        do {
            try fileManager.moveItem(at: oldURL, to: newURL)
            print("✓ Moved file: \(oldURL.lastPathComponent) → \(newURL.lastPathComponent)")

            // Clean up old directory if empty
            cleanupEmptyDirectories(startingAt: oldURL.deletingLastPathComponent())

            return true
        } catch {
            print("❌ Failed to move file: \(error)")
            return false
        }
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
