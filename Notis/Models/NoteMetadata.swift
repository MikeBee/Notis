//
//  NoteMetadata.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import Foundation

/// Represents metadata for a note stored in YAML frontmatter
struct NoteMetadata: Codable, Equatable {
    /// Unique identifier for the note
    var uuid: String

    /// Title of the note
    var title: String

    /// Tags associated with the note
    var tags: [String]

    /// Creation timestamp (ISO 8601 format)
    var created: Date

    /// Last modification timestamp (ISO 8601 format)
    var modified: Date

    /// Progress value (0.0 to 1.0)
    var progress: Double

    /// Current status of the note
    var status: String

    /// Relative file path from Notes root
    var path: String?

    /// Word count (computed, not stored in frontmatter)
    var wordCount: Int?

    /// Character count of content
    var charCount: Int?

    /// Content hash for change detection
    var contentHash: String?

    /// Preview excerpt (first ~200 chars)
    var excerpt: String?

    // MARK: - Initialization

    init(
        uuid: String = UUID().uuidString,
        title: String,
        tags: [String] = [],
        created: Date = Date(),
        modified: Date = Date(),
        progress: Double = 0.0,
        status: String = "draft",
        path: String? = nil,
        wordCount: Int? = nil,
        charCount: Int? = nil,
        contentHash: String? = nil,
        excerpt: String? = nil
    ) {
        self.uuid = uuid
        self.title = title
        self.tags = tags
        self.created = created
        self.modified = modified
        self.progress = progress
        self.status = status
        self.path = path
        self.wordCount = wordCount
        self.charCount = charCount
        self.contentHash = contentHash
        self.excerpt = excerpt
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case tags
        case created
        case modified
        case progress
        case status
        case path
        case wordCount = "word_count"
        case charCount = "char_count"
        case contentHash = "content_hash"
        case excerpt
    }
}

// MARK: - Computed Properties

extension NoteMetadata {
    /// Check if metadata is valid
    var isValid: Bool {
        return !uuid.isEmpty && !title.isEmpty
    }

    /// Get folder path from full path
    var folderPath: String? {
        guard let path = path else { return nil }
        return (path as NSString).deletingLastPathComponent
    }

    /// Get filename from path
    var filename: String? {
        guard let path = path else { return nil }
        return (path as NSString).lastPathComponent
    }
}
