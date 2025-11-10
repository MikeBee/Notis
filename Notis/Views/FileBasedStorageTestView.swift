//
//  FileBasedStorageTestView.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import SwiftUI

/// Test view for Phase 1: YAML frontmatter + SQLite indexing
struct FileBasedStorageTestView: View {
    @State private var notes: [NoteMetadata] = []
    @State private var searchQuery: String = ""
    @State private var searchResults: [NoteMetadata] = []
    @State private var totalCount: Int = 0
    @State private var allTags: [String] = []
    @State private var allFolders: [String] = []
    @State private var statusMessage: String = ""
    @State private var notesDirectory: String = ""

    private let markdownService = MarkdownFileService.shared
    private let indexService = NotesIndexService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("File-Based Storage Test")
                    .font(.title2)
                    .fontWeight(.bold)

                Divider()

                // Statistics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Index Statistics")
                        .font(.headline)

                    HStack {
                        Text("Total Notes in Index:")
                        Spacer()
                        Text("\(totalCount)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Total Tags:")
                        Spacer()
                        Text("\(allTags.count)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Total Folders:")
                        Spacer()
                        Text("\(allFolders.count)")
                            .fontWeight(.semibold)
                    }

                    if !allTags.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tags:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(allTags.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Notes Directory
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes Directory")
                        .font(.headline)

                    Text(notesDirectory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Status Message
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }

                // Actions
                VStack(spacing: 12) {
                    Text("Test Actions")
                        .font(.headline)

                    Button(action: createTestNotes) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create 5 Test Notes")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Button(action: loadAllNotes) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Notes List")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Button(action: syncFilesToIndex) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync Files to Index")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }

                // Search
                VStack(alignment: .leading, spacing: 12) {
                    Text("Full-Text Search (FTS5)")
                        .font(.headline)

                    HStack {
                        TextField("Search notes...", text: $searchQuery)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button(action: performSearch) {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                    }

                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Search Results (\(searchResults.count)):")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(searchResults, id: \.uuid) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if let excerpt = note.excerpt {
                                        Text(excerpt)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    if !note.tags.isEmpty {
                                        Text(note.tags.joined(separator: ", "))
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Notes List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Notes (\(notes.count))")
                        .font(.headline)

                    if notes.isEmpty {
                        Text("No notes yet. Create some test notes!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(notes.prefix(10), id: \.uuid) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(note.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if let wordCount = note.wordCount {
                                        Text("\(wordCount) words")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if !note.tags.isEmpty {
                                    Text(note.tags.map { "#\($0)" }.joined(separator: " "))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }

                                if let excerpt = note.excerpt {
                                    Text(excerpt)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                HStack {
                                    if let path = note.path {
                                        Text(path)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("Modified: \(note.modified, style: .relative)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }

                        if notes.count > 10 {
                            Text("... and \(notes.count - 10) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadStats()
            loadAllNotes()
        }
    }

    // MARK: - Actions

    private func createTestNotes() {
        let testNotes = [
            (title: "Project Planning", content: "# Project Planning\n\nThis is a note about project planning and task management.", tags: ["project", "planning"]),
            (title: "Marketing Strategy", content: "# Marketing Strategy\n\nKey points:\n- Social media campaigns\n- Email marketing\n- Content creation", tags: ["marketing", "strategy", "q1"]),
            (title: "Meeting Notes", content: "# Team Meeting\n\nDiscussed:\n1. Sprint goals\n2. Code review process\n3. Deployment schedule", tags: ["meeting", "team"]),
            (title: "Research Ideas", content: "# Research Ideas\n\nInteresting topics to explore:\n- Machine learning applications\n- User experience patterns", tags: ["research", "ideas"]),
            (title: "Story Concepts", content: "# Story Concepts\n\nA character discovers a hidden world beneath the city...", tags: ["creative", "writing"])
        ]

        var createdCount = 0

        for (index, testNote) in testNotes.enumerated() {
            let folderPath = index < 2 ? "Projects" : nil

            let result = markdownService.createFile(
                title: testNote.title,
                content: testNote.content,
                folderPath: folderPath,
                tags: testNote.tags
            )

            if result.success, let metadata = result.metadata {
                // Add to index
                _ = indexService.upsertNote(metadata)
                createdCount += 1
            }
        }

        statusMessage = "✓ Created \(createdCount) test notes"
        loadStats()
        loadAllNotes()
    }

    private func loadAllNotes() {
        notes = indexService.getRecentlyModified(limit: 50)
    }

    private func loadStats() {
        totalCount = indexService.getTotalCount()
        allTags = indexService.getAllTags()
        allFolders = indexService.getAllFolders()
        notesDirectory = markdownService.getNotesDirectory().path
    }

    private func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }

        searchResults = indexService.search(query: searchQuery, limit: 20)
        statusMessage = "Found \(searchResults.count) results for '\(searchQuery)'"
    }

    private func syncFilesToIndex() {
        // Scan all markdown files
        let files = markdownService.scanAllFiles()
        var syncedCount = 0

        for fileURL in files {
            if let (metadata, _) = markdownService.readFile(at: fileURL) {
                if indexService.upsertNote(metadata) {
                    syncedCount += 1
                }
            }
        }

        statusMessage = "✓ Synced \(syncedCount) files to index"
        loadStats()
        loadAllNotes()
    }
}

#Preview {
    FileBasedStorageTestView()
}
