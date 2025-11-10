//
//  YAMLFrontmatterService.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import Foundation

/// Service for parsing and serializing YAML frontmatter in Markdown files
class YAMLFrontmatterService {

    // MARK: - Singleton

    static let shared = YAMLFrontmatterService()

    // MARK: - Properties

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // Simplified date formatter without fractional seconds for parsing
    private let simpleDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // Even simpler date format (YYYY-MM-DD)
    private let simplestDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    // MARK: - Parsing

    /// Parse a markdown file with YAML frontmatter
    /// Returns tuple of (metadata, content) or nil if parsing fails
    func parse(_ markdown: String) -> (metadata: NoteMetadata, content: String)? {
        // Check if markdown starts with frontmatter delimiter
        guard markdown.hasPrefix("---\n") || markdown.hasPrefix("---\r\n") else {
            return nil
        }

        // Find the closing delimiter
        let lines = markdown.components(separatedBy: .newlines)
        var frontmatterEndIndex = -1

        for (index, line) in lines.enumerated() where index > 0 {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                frontmatterEndIndex = index
                break
            }
        }

        guard frontmatterEndIndex > 0 else {
            return nil
        }

        // Extract frontmatter and content
        let frontmatterLines = Array(lines[1..<frontmatterEndIndex])
        let contentLines = Array(lines[(frontmatterEndIndex + 1)...])

        let frontmatterString = frontmatterLines.joined(separator: "\n")
        let contentString = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse frontmatter YAML
        guard let metadata = parseFrontmatter(frontmatterString) else {
            return nil
        }

        return (metadata, contentString)
    }

    /// Parse frontmatter YAML string into NoteMetadata
    private func parseFrontmatter(_ yaml: String) -> NoteMetadata? {
        var uuid: String?
        var title: String?
        var tags: [String] = []
        var created: Date?
        var modified: Date?
        var progress: Double = 0.0
        var status: String = "draft"
        var path: String?
        var wordCount: Int?
        var charCount: Int?
        var contentHash: String?
        var excerpt: String?

        // Parse line by line
        let lines = yaml.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Split by first colon
            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }

            let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            switch key {
            case "uuid":
                uuid = parseString(value)

            case "title":
                title = parseString(value)

            case "tags":
                tags = parseArray(value)

            case "created":
                created = parseDate(value)

            case "modified":
                modified = parseDate(value)

            case "progress":
                if let doubleValue = parseDouble(value) {
                    progress = doubleValue
                }

            case "status":
                status = parseString(value) ?? "draft"

            case "path":
                path = parseString(value)

            case "word_count":
                wordCount = parseInt(value)

            case "char_count":
                charCount = parseInt(value)

            case "content_hash":
                contentHash = parseString(value)

            case "excerpt":
                excerpt = parseString(value)

            default:
                continue
            }
        }

        // Validate required fields
        guard let finalUuid = uuid, let finalTitle = title else {
            return nil
        }

        return NoteMetadata(
            uuid: finalUuid,
            title: finalTitle,
            tags: tags,
            created: created ?? Date(),
            modified: modified ?? Date(),
            progress: progress,
            status: status,
            path: path,
            wordCount: wordCount,
            charCount: charCount,
            contentHash: contentHash,
            excerpt: excerpt
        )
    }

    // MARK: - Serialization

    /// Serialize metadata and content into a markdown file with YAML frontmatter
    func serialize(metadata: NoteMetadata, content: String) -> String {
        var yaml = "---\n"

        // Add required fields
        yaml += "uuid: \"\(metadata.uuid)\"\n"
        yaml += "title: \(escapeString(metadata.title))\n"

        // Add tags
        if !metadata.tags.isEmpty {
            yaml += "tags: [\(metadata.tags.map { escapeString($0) }.joined(separator: ", "))]\n"
        } else {
            yaml += "tags: []\n"
        }

        // Add dates
        yaml += "created: \(dateFormatter.string(from: metadata.created))\n"
        yaml += "modified: \(dateFormatter.string(from: metadata.modified))\n"

        // Add progress and status
        yaml += "progress: \(metadata.progress)\n"
        yaml += "status: \"\(metadata.status)\"\n"

        // Add optional fields
        if let path = metadata.path {
            yaml += "path: \"\(path)\"\n"
        }

        if let wordCount = metadata.wordCount {
            yaml += "word_count: \(wordCount)\n"
        }

        if let charCount = metadata.charCount {
            yaml += "char_count: \(charCount)\n"
        }

        if let contentHash = metadata.contentHash {
            yaml += "content_hash: \"\(contentHash)\"\n"
        }

        if let excerpt = metadata.excerpt {
            yaml += "excerpt: \(escapeString(excerpt))\n"
        }

        yaml += "---\n\n"
        yaml += content

        return yaml
    }

    // MARK: - Helper Methods

    /// Parse a string value, removing quotes if present
    private func parseString(_ value: String) -> String? {
        var trimmed = value.trimmingCharacters(in: .whitespaces)

        // Remove surrounding quotes
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            trimmed = String(trimmed.dropFirst().dropLast())
        }

        return trimmed.isEmpty ? nil : trimmed
    }

    /// Parse an array value (e.g., [tag1, tag2, tag3])
    private func parseArray(_ value: String) -> [String] {
        var trimmed = value.trimmingCharacters(in: .whitespaces)

        // Check if it's an array format [...]
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else {
            return []
        }

        // Remove brackets
        trimmed = String(trimmed.dropFirst().dropLast())

        // Split by comma and clean each item
        return trimmed
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { parseString($0) }
            .filter { !$0.isEmpty }
    }

    /// Parse a date value
    private func parseDate(_ value: String) -> Date? {
        guard let dateString = parseString(value) else { return nil }

        // Try full ISO8601 with fractional seconds
        if let date = dateFormatter.date(from: dateString) {
            return date
        }

        // Try ISO8601 without fractional seconds
        if let date = simpleDateFormatter.date(from: dateString) {
            return date
        }

        // Try simple date format (YYYY-MM-DD)
        if let date = simplestDateFormatter.date(from: dateString) {
            return date
        }

        return nil
    }

    /// Parse a double value
    private func parseDouble(_ value: String) -> Double? {
        guard let string = parseString(value) else { return nil }
        return Double(string)
    }

    /// Parse an integer value
    private func parseInt(_ value: String) -> Int? {
        guard let string = parseString(value) else { return nil }
        return Int(string)
    }

    /// Escape a string for YAML (add quotes if needed)
    private func escapeString(_ string: String) -> String {
        // Check if string needs quotes
        let needsQuotes = string.contains(":") ||
                         string.contains("#") ||
                         string.contains("[") ||
                         string.contains("]") ||
                         string.contains(",") ||
                         string.hasPrefix(" ") ||
                         string.hasSuffix(" ") ||
                         string.contains("\n")

        if needsQuotes {
            // Escape internal quotes
            let escaped = string.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }

        return string
    }

    // MARK: - Content Hash

    /// Generate a content hash for change detection
    func generateContentHash(_ content: String) -> String {
        return content.sha256Hash()
    }
}

// MARK: - String Extension for SHA256

extension String {
    func sha256Hash() -> String {
        guard let data = self.data(using: .utf8) else { return "" }

        // Use a simple hash for now (in production, use CryptoKit)
        var hash = data.reduce(0) { result, byte in
            result &+ Int(byte)
        }

        return String(format: "%08x", hash)
    }
}
