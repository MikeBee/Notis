//
//  FileBasedStorageTestView.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import CoreData

/// Test view for Phase 1-3: YAML + SQLite + File Sync + Migration
struct FileBasedStorageTestView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var notes: [NoteMetadata] = []
    @State private var searchQuery: String = ""
    @State private var searchResults: [NoteMetadata] = []
    @State private var totalCount: Int = 0
    @State private var allTags: [String] = []
    @State private var allFolders: [String] = []
    @State private var statusMessage: String = ""
    @State private var notesDirectory: String = ""
    @State private var isSyncing: Bool = false
    @State private var isMonitoring: Bool = false
    @State private var lastSyncDate: Date?
    @State private var syncStats: FileSyncService.SyncStats?

    // Migration state
    @State private var isMigrating: Bool = false
    @State private var migrationStats: CoreDataMigrationService.MigrationStats?
    @State private var dryRunStats: CoreDataMigrationService.MigrationStats?
    @State private var showMigrationConfirmation: Bool = false

    private let markdownService = MarkdownFileService.shared
    private let indexService = NotesIndexService.shared
    private let syncService = FileSyncService.shared
    private let migrationService = CoreDataMigrationService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("File-Based Storage Test")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Phase 3: CoreData Migration")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                // Sync Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sync Status")
                        .font(.headline)

                    HStack {
                        Text("Monitoring:")
                        Spacer()
                        Text(isMonitoring ? "Active" : "Inactive")
                            .foregroundColor(isMonitoring ? .green : .secondary)
                            .fontWeight(.semibold)
                    }

                    if let lastSync = lastSyncDate {
                        HStack {
                            Text("Last Sync:")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let stats = syncStats, stats.totalChanges > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Sync Changes:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if stats.filesAdded > 0 {
                                Text("  • Files added: \(stats.filesAdded)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            if stats.indexEntriesUpdated > 0 {
                                Text("  • Index updated: \(stats.indexEntriesUpdated)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            if stats.indexEntriesDeleted > 0 {
                                Text("  • Index deleted: \(stats.indexEntriesDeleted)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            if stats.conflicts > 0 {
                                Text("  • Conflicts resolved: \(stats.conflicts)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            if stats.errors > 0 {
                                Text("  • Errors: \(stats.errors)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Sync Actions
                VStack(spacing: 12) {
                    Text("Sync Actions")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Button(action: performFullSync) {
                            HStack {
                                if isSyncing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    Text("Full Sync")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSyncing)

                        Button(action: performQuickSync) {
                            HStack {
                                if isSyncing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "bolt.circle.fill")
                                    Text("Quick Sync")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSyncing)
                    }

                    Button(action: performDeepSync) {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("Deep Sync")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isSyncing)

                    Button(action: toggleMonitoring) {
                        HStack {
                            Image(systemName: isMonitoring ? "stop.circle.fill" : "play.circle.fill")
                            Text(isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isMonitoring ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }

                // CoreData Migration
                VStack(alignment: .leading, spacing: 12) {
                    Text("CoreData Migration")
                        .font(.headline)

                    if let stats = migrationStats {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Total Sheets:")
                                Spacer()
                                Text("\(stats.totalSheets)")
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Text("Migrated:")
                                Spacer()
                                Text("\(stats.migratedSheets)")
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Text("Skipped:")
                                Spacer()
                                Text("\(stats.skippedSheets)")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Text("Failed:")
                                Spacer()
                                Text("\(stats.failedSheets)")
                                    .foregroundColor(.red)
                                    .fontWeight(.semibold)
                            }

                            if stats.totalSheets > 0 {
                                ProgressView(value: stats.progress)
                                    .progressViewStyle(LinearProgressViewStyle())
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    } else if let dryRun = dryRunStats {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dry Run Preview:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("  • \(dryRun.migratedSheets) sheets will be migrated")
                                .font(.caption)
                                .foregroundColor(.green)

                            Text("  • \(dryRun.skippedSheets) sheets will be skipped")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }

                    VStack(spacing: 12) {
                        Button(action: performDryRun) {
                            HStack {
                                if isMigrating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "eye.circle.fill")
                                    Text("Preview Migration (Dry Run)")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isMigrating)

                        Button(action: { showMigrationConfirmation = true }) {
                            HStack {
                                if isMigrating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Migrate All Sheets")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isMigrating)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Index Statistics
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

                // Test Actions
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
                        .background(Color.orange)
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
            updateSyncStatus()
        }
        .alert("Migrate All Sheets?", isPresented: $showMigrationConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Migrate", role: .destructive) {
                performMigration()
            }
        } message: {
            Text("This will convert all CoreData sheets to markdown files. A backup will be created automatically. This action cannot be undone.")
        }
    }

    // MARK: - Sync Actions

    private func performFullSync() {
        isSyncing = true
        statusMessage = "Performing full sync..."

        DispatchQueue.global(qos: .userInitiated).async {
            let stats = syncService.performFullSyncWithCoreData(context: viewContext)

            DispatchQueue.main.async {
                self.isSyncing = false
                self.syncStats = stats
                self.lastSyncDate = syncService.lastSyncDate
                self.statusMessage = "✓ Full sync complete: \(stats.totalChanges) changes"
                self.loadStats()
                self.loadAllNotes()
            }
        }
    }

    private func performQuickSync() {
        isSyncing = true
        statusMessage = "Performing quick sync..."

        DispatchQueue.global(qos: .userInitiated).async {
            let stats = syncService.performQuickSync()

            DispatchQueue.main.async {
                self.isSyncing = false
                self.syncStats = stats
                self.lastSyncDate = syncService.lastSyncDate
                self.statusMessage = "✓ Quick sync complete: \(stats.totalChanges) changes"
                self.loadStats()
                self.loadAllNotes()
            }
        }
    }

    private func performDeepSync() {
        isSyncing = true
        statusMessage = "Performing deep sync (reading all file content)..."

        DispatchQueue.global(qos: .userInitiated).async {
            let stats = syncService.performDeepSync(context: viewContext)

            DispatchQueue.main.async {
                self.isSyncing = false
                self.syncStats = stats
                self.lastSyncDate = syncService.lastSyncDate
                self.statusMessage = "✓ Deep sync complete: \(stats.totalChanges) changes"
                self.loadStats()
                self.loadAllNotes()
            }
        }
    }

    private func toggleMonitoring() {
        if isMonitoring {
            syncService.stopMonitoring()
            isMonitoring = false
            statusMessage = "Monitoring stopped"
        } else {
            syncService.startMonitoring()
            isMonitoring = true
            #if os(macOS)
            statusMessage = "File watcher started (macOS)"
            #else
            statusMessage = "Background sync started (30s interval)"
            #endif
        }
    }

    private func updateSyncStatus() {
        lastSyncDate = syncService.lastSyncDate
        syncStats = syncService.lastSyncStats
    }

    // MARK: - Test Actions

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

    // MARK: - Migration Actions

    private func performDryRun() {
        isMigrating = true
        dryRunStats = nil
        statusMessage = "Running migration preview..."

        DispatchQueue.global(qos: .userInitiated).async {
            let stats = migrationService.performDryRun(context: viewContext)

            DispatchQueue.main.async {
                self.isMigrating = false
                self.dryRunStats = stats
                self.statusMessage = "✓ Dry run complete: \(stats.migratedSheets) sheets ready to migrate"
            }
        }
    }

    private func performMigration() {
        isMigrating = true
        migrationStats = nil
        statusMessage = "Migrating CoreData sheets to markdown..."

        DispatchQueue.global(qos: .userInitiated).async {
            let result = migrationService.performMigration(
                context: viewContext,
                createBackup: true
            ) { stats in
                DispatchQueue.main.async {
                    self.migrationStats = stats
                }
            }

            DispatchQueue.main.async {
                self.isMigrating = false
                self.migrationStats = result.stats

                if result.success {
                    self.statusMessage = "✅ Migration complete! \(result.stats.migratedSheets) sheets migrated successfully"
                    if let backupPath = result.backupPath {
                        self.statusMessage += "\nBackup saved: \(backupPath)"
                    }
                } else {
                    self.statusMessage = "⚠️ Migration completed with \(result.stats.failedSheets) failures"
                }

                // Refresh everything
                self.loadStats()
                self.loadAllNotes()
            }
        }
    }
}

#Preview {
    FileBasedStorageTestView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
