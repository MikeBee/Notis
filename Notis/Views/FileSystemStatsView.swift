//
//  FileSystemStatsView.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import CoreData

/// View showing file system storage statistics and sync status
struct FileSystemStatsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var totalSheets: Int = 0
    @State private var markdownSheets: Int = 0
    @State private var coreDataSheets: Int = 0
    @State private var fileCount: Int = 0
    @State private var folderCount: Int = 0
    @State private var totalSize: String = "0 KB"
    @State private var totalWords: Int = 0
    @State private var lastSyncTime: Date?
    @State private var isSyncing: Bool = false

    private let syncService = FileSyncService.shared
    private let indexService = NotesIndexService.shared
    private let fileService = MarkdownFileService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("File Storage Statistics")
                        .font(.title2)
                        .bold()

                    if let lastSync = lastSyncTime {
                        Text("Last synced: \(lastSync, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                // Storage Overview
                GroupBox(label: Label("Storage Overview", systemImage: "internaldrive")) {
                    VStack(spacing: 12) {
                        StatRow(label: "Total Files", value: "\(fileCount)", icon: "doc.text")
                        StatRow(label: "Total Folders", value: "\(folderCount)", icon: "folder")
                        StatRow(label: "Total Size", value: totalSize, icon: "externaldrive")
                        StatRow(label: "Total Words", value: totalWords.formatted(), icon: "textformat")
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)

                // Sheets Distribution
                GroupBox(label: Label("Sheets Distribution", systemImage: "chart.pie")) {
                    VStack(spacing: 12) {
                        StatRow(label: "Total Sheets", value: "\(totalSheets)", icon: "doc.on.doc")
                        StatRow(
                            label: "Markdown Storage",
                            value: "\(markdownSheets) (\(markdownPercentage)%)",
                            icon: "doc.text",
                            color: .green
                        )
                        StatRow(
                            label: "CoreData Storage",
                            value: "\(coreDataSheets) (\(coreDataPercentage)%)",
                            icon: "opticaldiscdrive",
                            color: .orange
                        )
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)

                // Sync Status
                GroupBox(label: Label("Sync Status", systemImage: "arrow.triangle.2.circlepath")) {
                    VStack(spacing: 12) {
                        if isSyncing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("All files synced")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }

                        Divider()

                        // Sync actions
                        HStack(spacing: 12) {
                            Button(action: performFullSync) {
                                Label("Full Sync", systemImage: "arrow.clockwise")
                            }
                            .disabled(isSyncing)

                            Button(action: performQuickSync) {
                                Label("Quick Sync", systemImage: "bolt.fill")
                            }
                            .disabled(isSyncing)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)

                // Quick Actions
                GroupBox(label: Label("Quick Actions", systemImage: "bolt.circle")) {
                    VStack(spacing: 12) {
                        Button(action: openNotesFolder) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Open Notes Folder")
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)

                        Divider()

                        Button(action: refreshStats) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Statistics")
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
        .onAppear(perform: refreshStats)
    }

    // MARK: - Computed Properties

    private var markdownPercentage: Int {
        guard totalSheets > 0 else { return 0 }
        return Int((Double(markdownSheets) / Double(totalSheets)) * 100)
    }

    private var coreDataPercentage: Int {
        guard totalSheets > 0 else { return 0 }
        return Int((Double(coreDataSheets) / Double(totalSheets)) * 100)
    }

    // MARK: - Actions

    private func refreshStats() {
        // Count sheets by storage type
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isInTrash == NO")

        do {
            let sheets = try viewContext.fetch(fetchRequest)
            totalSheets = sheets.count

            markdownSheets = sheets.filter { $0.usesMarkdownStorage }.count
            coreDataSheets = totalSheets - markdownSheets
        } catch {
            print("❌ Failed to count sheets: \(error)")
        }

        // Count markdown files
        let files = fileService.scanAllFiles()
        fileCount = files.count

        // Count folders
        folderCount = indexService.getAllFolders().count

        // Calculate total size
        var size: Int64 = 0
        for fileURL in files {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                size += fileSize
            }
        }
        totalSize = formatBytes(size)

        // Count total words
        let notes = indexService.getAllNotes()
        totalWords = notes.compactMap { $0.wordCount }.reduce(0, +)

        // Get last sync time
        lastSyncTime = syncService.lastSyncTime
    }

    private func performFullSync() {
        isSyncing = true

        DispatchQueue.global(qos: .userInitiated).async {
            let stats = syncService.performFullSync()

            DispatchQueue.main.async {
                isSyncing = false
                lastSyncTime = Date()
                refreshStats()

                print("✓ Full sync completed: \(stats.filesAdded) added, \(stats.filesUpdated) updated, \(stats.filesDeleted) deleted")
            }
        }
    }

    private func performQuickSync() {
        isSyncing = true

        DispatchQueue.global(qos: .userInitiated).async {
            let stats = syncService.performQuickSync()

            DispatchQueue.main.async {
                isSyncing = false
                lastSyncTime = Date()
                refreshStats()

                print("✓ Quick sync completed: \(stats.filesAdded) added, \(stats.filesUpdated) updated")
            }
        }
    }

    private func openNotesFolder() {
        let notesDirectory = fileService.getNotesDirectory()
        #if os(macOS)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: notesDirectory.path)
        #else
        // On iOS, we can't directly open Files app to a specific folder
        // But the files are in Documents/Notis/Notes which is accessible via Files app
        print("📁 Notes folder location: \(notesDirectory.path)")
        #endif
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .bold()
                .foregroundColor(color)
        }
    }
}

// MARK: - Extensions

extension FileSyncService {
    var lastSyncTime: Date? {
        UserDefaults.standard.object(forKey: "lastSyncTime") as? Date
    }
}
