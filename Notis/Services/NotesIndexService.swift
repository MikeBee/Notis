//
//  NotesIndexService.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import Foundation
import SQLite3

/// Service for managing the SQLite notes index with FTS5 full-text search
class NotesIndexService {

    // MARK: - Singleton

    static let shared = NotesIndexService()

    // MARK: - Properties

    private var db: OpaquePointer?
    private let dbURL: URL
    private let queue = DispatchQueue(label: "com.notis.notesindex", qos: .userInitiated)

    // MARK: - Initialization

    private init() {
        // Determine database location
        #if os(iOS)
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let baseDir = documentsDir.appendingPathComponent("Notis", isDirectory: true)
        #else
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baseDir = appSupport.appendingPathComponent("Notis", isDirectory: true)
        #endif

        dbURL = baseDir.appendingPathComponent("notes_index.db")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        // Open database
        openDatabase()
        createTables()
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Management

    /// Open the SQLite database
    private func openDatabase() {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("❌ Failed to open database at: \(dbURL.path)")
            db = nil
        } else {
            print("✓ Opened notes index database at: \(dbURL.path)")
        }
    }

    /// Close the database
    private func closeDatabase() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    /// Create database tables and indexes
    private func createTables() {
        guard let db = db else { return }

        // Drop old FTS5 table if it exists (migration for content column removal)
        let dropOldFTS = "DROP TABLE IF EXISTS notes_fts;"
        if sqlite3_exec(db, dropOldFTS, nil, nil, nil) == SQLITE_OK {
            print("✓ Dropped old FTS5 table for migration")
        }

        // Drop old triggers
        let dropTriggers = """
        DROP TRIGGER IF EXISTS notes_ai;
        DROP TRIGGER IF EXISTS notes_au;
        DROP TRIGGER IF EXISTS notes_ad;
        """
        sqlite3_exec(db, dropTriggers, nil, nil, nil)

        // Main notes table
        let createNotesTable = """
        CREATE TABLE IF NOT EXISTS notes (
            uuid TEXT PRIMARY KEY,
            path TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            tags TEXT,
            created TEXT NOT NULL,
            modified TEXT NOT NULL,
            progress REAL DEFAULT 0.0,
            status TEXT DEFAULT 'draft',
            word_count INTEGER,
            char_count INTEGER,
            content_hash TEXT,
            excerpt TEXT,
            folder_path TEXT,
            filename TEXT
        );
        """

        // FTS5 virtual table for full-text search
        let createFTSTable = """
        CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
            uuid UNINDEXED,
            title,
            tags,
            excerpt,
            content='notes',
            content_rowid='rowid'
        );
        """

        // Trigger to keep FTS table in sync
        let createInsertTrigger = """
        CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
            INSERT INTO notes_fts(rowid, uuid, title, tags, excerpt)
            VALUES (new.rowid, new.uuid, new.title, new.tags, new.excerpt);
        END;
        """

        let createUpdateTrigger = """
        CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
            UPDATE notes_fts SET
                title = new.title,
                tags = new.tags,
                excerpt = new.excerpt
            WHERE rowid = new.rowid;
        END;
        """

        let createDeleteTrigger = """
        CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
            DELETE FROM notes_fts WHERE rowid = old.rowid;
        END;
        """

        // Create indexes
        let createTagsIndex = "CREATE INDEX IF NOT EXISTS idx_tags ON notes(tags);"
        let createModifiedIndex = "CREATE INDEX IF NOT EXISTS idx_modified ON notes(modified DESC);"
        let createFolderIndex = "CREATE INDEX IF NOT EXISTS idx_folder ON notes(folder_path);"
        let createStatusIndex = "CREATE INDEX IF NOT EXISTS idx_status ON notes(status);"

        // Execute all statements
        let statements = [
            createNotesTable,
            createFTSTable,
            createInsertTrigger,
            createUpdateTrigger,
            createDeleteTrigger,
            createTagsIndex,
            createModifiedIndex,
            createFolderIndex,
            createStatusIndex
        ]

        for statement in statements {
            var errorMessage: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, statement, nil, nil, &errorMessage) != SQLITE_OK {
                let error = errorMessage.map { String(cString: $0) } ?? "Unknown error"
                print("❌ Failed to execute SQL: \(error)")
                sqlite3_free(errorMessage)
            }
        }

        // Repopulate FTS5 table from existing notes data
        let repopulateFTS = """
        INSERT INTO notes_fts(rowid, uuid, title, tags, excerpt)
        SELECT rowid, uuid, title, tags, excerpt FROM notes;
        """
        if sqlite3_exec(db, repopulateFTS, nil, nil, nil) == SQLITE_OK {
            print("✓ Repopulated FTS5 table with existing data")
        }

        print("✓ Created notes index tables and indexes")
    }

    // MARK: - CRUD Operations

    /// Insert or update a note in the index
    func upsertNote(_ metadata: NoteMetadata) -> Bool {
        guard let db = db else { return false }

        let sql = """
        INSERT OR REPLACE INTO notes
        (uuid, path, title, tags, created, modified, progress, status,
         word_count, char_count, content_hash, excerpt, folder_path, filename)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare upsert statement")
            return false
        }

        defer { sqlite3_finalize(statement) }

        // Bind values
        let tagsJSON = (try? JSONEncoder().encode(metadata.tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let dateFormatter = ISO8601DateFormatter()

        sqlite3_bind_text(statement, 1, (metadata.uuid as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, ((metadata.path ?? "") as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (metadata.title as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (tagsJSON as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 5, (dateFormatter.string(from: metadata.created) as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 6, (dateFormatter.string(from: metadata.modified) as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 7, metadata.progress)
        sqlite3_bind_text(statement, 8, (metadata.status as NSString).utf8String, -1, nil)

        if let wordCount = metadata.wordCount {
            sqlite3_bind_int(statement, 9, Int32(wordCount))
        } else {
            sqlite3_bind_null(statement, 9)
        }

        if let charCount = metadata.charCount {
            sqlite3_bind_int(statement, 10, Int32(charCount))
        } else {
            sqlite3_bind_null(statement, 10)
        }

        if let hash = metadata.contentHash {
            sqlite3_bind_text(statement, 11, (hash as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 11)
        }

        if let excerpt = metadata.excerpt {
            sqlite3_bind_text(statement, 12, (excerpt as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 12)
        }

        if let folderPath = metadata.folderPath {
            sqlite3_bind_text(statement, 13, (folderPath as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 13)
        }

        if let filename = metadata.filename {
            sqlite3_bind_text(statement, 14, (filename as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 14)
        }

        let result = sqlite3_step(statement) == SQLITE_DONE
        if !result {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to upsert note '\(metadata.title)': \(error)")
        }

        return result
    }

    /// Delete a note from the index by UUID
    func deleteNote(uuid: String) -> Bool {
        guard let db = db else { return false }

        let sql = "DELETE FROM notes WHERE uuid = ?;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (uuid as NSString).utf8String, -1, nil)

        return sqlite3_step(statement) == SQLITE_DONE
    }

    /// Delete a note from the index by path
    func deleteNote(path: String) -> Bool {
        guard let db = db else { return false }

        let sql = "DELETE FROM notes WHERE path = ?;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)

        return sqlite3_step(statement) == SQLITE_DONE
    }

    /// Get a note by UUID
    func getNote(uuid: String) -> NoteMetadata? {
        guard let db = db else { return nil }

        let sql = """
        SELECT uuid, path, title, tags, created, modified, progress, status,
               word_count, char_count, content_hash, excerpt
        FROM notes WHERE uuid = ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (uuid as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return extractMetadata(from: statement)
    }

    /// Get a note by path
    func getNote(path: String) -> NoteMetadata? {
        guard let db = db else { return nil }

        let sql = """
        SELECT uuid, path, title, tags, created, modified, progress, status,
               word_count, char_count, content_hash, excerpt
        FROM notes WHERE path = ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return extractMetadata(from: statement)
    }

    // MARK: - Query Operations

    /// Get all notes, optionally sorted
    func getAllNotes(sortBy: SortField = .modified, ascending: Bool = false) -> [NoteMetadata] {
        guard let db = db else { return [] }

        let orderClause = "\(sortBy.rawValue) \(ascending ? "ASC" : "DESC")"
        let sql = """
        SELECT uuid, path, title, tags, created, modified, progress, status,
               word_count, char_count, content_hash, excerpt
        FROM notes ORDER BY \(orderClause);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        var results: [NoteMetadata] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let metadata = extractMetadata(from: statement) {
                results.append(metadata)
            }
        }

        return results
    }

    /// Get notes by tag
    func getNotes(byTag tag: String) -> [NoteMetadata] {
        guard let db = db else { return [] }

        let sql = """
        SELECT uuid, path, title, tags, created, modified, progress, status,
               word_count, char_count, content_hash, excerpt
        FROM notes WHERE tags LIKE ? ORDER BY modified DESC;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        // Search for tag in JSON array
        let searchPattern = "%\"\(tag)\"%"
        sqlite3_bind_text(statement, 1, (searchPattern as NSString).utf8String, -1, nil)

        var results: [NoteMetadata] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let metadata = extractMetadata(from: statement) {
                results.append(metadata)
            }
        }

        return results
    }

    /// Get notes by folder path
    func getNotes(inFolder folderPath: String) -> [NoteMetadata] {
        guard let db = db else { return [] }

        let sql = """
        SELECT uuid, path, title, tags, created, modified, progress, status,
               word_count, char_count, content_hash, excerpt
        FROM notes WHERE folder_path = ? ORDER BY modified DESC;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (folderPath as NSString).utf8String, -1, nil)

        var results: [NoteMetadata] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let metadata = extractMetadata(from: statement) {
                results.append(metadata)
            }
        }

        return results
    }

    /// Get recently modified notes
    func getRecentlyModified(limit: Int = 20) -> [NoteMetadata] {
        guard let db = db else { return [] }

        let sql = """
        SELECT uuid, path, title, tags, created, modified, progress, status,
               word_count, char_count, content_hash, excerpt
        FROM notes ORDER BY modified DESC LIMIT ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var results: [NoteMetadata] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let metadata = extractMetadata(from: statement) {
                results.append(metadata)
            }
        }

        return results
    }

    /// Full-text search using FTS5
    func search(query: String, limit: Int = 50) -> [NoteMetadata] {
        guard let db = db else { return [] }

        let sql = """
        SELECT n.uuid, n.path, n.title, n.tags, n.created, n.modified, n.progress, n.status,
               n.word_count, n.char_count, n.content_hash, n.excerpt
        FROM notes n
        JOIN notes_fts fts ON n.rowid = fts.rowid
        WHERE notes_fts MATCH ?
        ORDER BY rank
        LIMIT ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (query as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var results: [NoteMetadata] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let metadata = extractMetadata(from: statement) {
                results.append(metadata)
            }
        }

        return results
    }

    // MARK: - Statistics

    /// Get total note count
    func getTotalCount() -> Int {
        guard let db = db else { return 0 }

        let sql = "SELECT COUNT(*) FROM notes;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }

        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }

        return Int(sqlite3_column_int(statement, 0))
    }

    /// Get all unique tags
    func getAllTags() -> [String] {
        let notes = getAllNotes()
        var tagSet = Set<String>()

        for note in notes {
            tagSet.formUnion(note.tags)
        }

        return Array(tagSet).sorted()
    }

    /// Get all unique folder paths
    func getAllFolders() -> [String] {
        guard let db = db else { return [] }

        let sql = "SELECT DISTINCT folder_path FROM notes WHERE folder_path IS NOT NULL ORDER BY folder_path;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        var results: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                results.append(String(cString: cString))
            }
        }

        return results
    }

    /// Get all notes from the index
    func getAllNotes() -> [NoteMetadata] {
        guard let db = db else { return [] }

        let sql = "SELECT uuid, path, title, tags, created, modified, progress, status, word_count, char_count, content_hash, excerpt FROM notes ORDER BY modified DESC;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        var results: [NoteMetadata] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let note = extractMetadata(from: statement) {
                results.append(note)
            }
        }

        return results
    }

    // MARK: - Helper Methods

    /// Extract NoteMetadata from a prepared statement result row
    private func extractMetadata(from statement: OpaquePointer?) -> NoteMetadata? {
        guard let statement = statement else { return nil }

        let dateFormatter = ISO8601DateFormatter()

        // Extract values
        let uuid = String(cString: sqlite3_column_text(statement, 0))
        let path = sqlite3_column_text(statement, 1).map { String(cString: $0) }
        let title = String(cString: sqlite3_column_text(statement, 2))
        let tagsJSON = String(cString: sqlite3_column_text(statement, 3))
        let createdString = String(cString: sqlite3_column_text(statement, 4))
        let modifiedString = String(cString: sqlite3_column_text(statement, 5))
        let progress = sqlite3_column_double(statement, 6)
        let status = String(cString: sqlite3_column_text(statement, 7))

        // Parse tags from JSON
        let tags = (try? JSONDecoder().decode([String].self, from: tagsJSON.data(using: .utf8) ?? Data())) ?? []

        // Parse dates
        let created = dateFormatter.date(from: createdString) ?? Date()
        let modified = dateFormatter.date(from: modifiedString) ?? Date()

        // Optional fields
        let wordCount = sqlite3_column_type(statement, 8) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 8)) : nil
        let charCount = sqlite3_column_type(statement, 9) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 9)) : nil
        let contentHash = sqlite3_column_type(statement, 10) != SQLITE_NULL ? String(cString: sqlite3_column_text(statement, 10)) : nil
        let excerpt = sqlite3_column_type(statement, 11) != SQLITE_NULL ? String(cString: sqlite3_column_text(statement, 11)) : nil

        return NoteMetadata(
            uuid: uuid,
            title: title,
            tags: tags,
            created: created,
            modified: modified,
            progress: progress,
            status: status,
            path: path,
            wordCount: wordCount,
            charCount: charCount,
            contentHash: contentHash,
            excerpt: excerpt
        )
    }

    // MARK: - Enums

    enum SortField: String {
        case title
        case modified
        case created
        case progress
    }
}
