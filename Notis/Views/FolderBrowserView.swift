//
//  FolderBrowserView.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import CoreData

/// View for browsing markdown files by folder hierarchy
struct FolderBrowserView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState

    @State private var folders: [String] = []
    @State private var notesByFolder: [String: [NoteMetadata]] = [:]
    @State private var expandedFolders: Set<String> = []
    @State private var selectedNote: NoteMetadata?
    @State private var searchText: String = ""
    @State private var lastRefresh: Date = Date()

    private let indexService = NotesIndexService.shared
    private let fileService = MarkdownFileService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Markdown Files")
                    .font(.headline)

                Spacer()

                Button(action: refreshFolders) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                }
                .buttonStyle(.borderless)
                .help("Refresh folder list")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.top, 8)

            // Folder tree
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if filteredFolders.isEmpty && filteredRootNotes.isEmpty {
                        Text("No markdown files found")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        // Root level notes (no folder)
                        if !filteredRootNotes.isEmpty {
                            FolderSectionView(
                                folderName: "Root",
                                notes: filteredRootNotes,
                                isExpanded: expandedFolders.contains(""),
                                selectedNote: $selectedNote,
                                onToggle: { toggleFolder("") },
                                onSelectNote: selectNote
                            )
                        }

                        // Folders
                        ForEach(filteredFolders, id: \.self) { folder in
                            if let notes = notesByFolder[folder] {
                                FolderSectionView(
                                    folderName: folder,
                                    notes: notes.filter { note in
                                        searchText.isEmpty ||
                                        note.title.localizedCaseInsensitiveContains(searchText)
                                    },
                                    isExpanded: expandedFolders.contains(folder),
                                    selectedNote: $selectedNote,
                                    onToggle: { toggleFolder(folder) },
                                    onSelectNote: selectNote
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Footer stats
            HStack {
                Text("\(totalNotes) files")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Last updated: \(lastRefresh, formatter: timeFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .onAppear(perform: refreshFolders)
    }

    // MARK: - Computed Properties

    private var filteredFolders: [String] {
        if searchText.isEmpty {
            return folders.sorted()
        }
        return folders.filter { folder in
            folder.localizedCaseInsensitiveContains(searchText) ||
            (notesByFolder[folder]?.contains { $0.title.localizedCaseInsensitiveContains(searchText) } ?? false)
        }.sorted()
    }

    private var filteredRootNotes: [NoteMetadata] {
        let rootNotes = notesByFolder[""] ?? []
        if searchText.isEmpty {
            return rootNotes
        }
        return rootNotes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var totalNotes: Int {
        notesByFolder.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Actions

    private func refreshFolders() {
        // Get all folders from index
        folders = indexService.getAllFolders()

        // Group notes by folder
        notesByFolder.removeAll()

        for folder in folders {
            let notes = indexService.getNotes(inFolder: folder)
            notesByFolder[folder] = notes
        }

        // Get root notes (no folder)
        let rootNotes = indexService.getAllNotes().filter {
            $0.path?.contains("/") == false || $0.path == nil
        }
        notesByFolder[""] = rootNotes

        lastRefresh = Date()
    }

    private func toggleFolder(_ folder: String) {
        if expandedFolders.contains(folder) {
            expandedFolders.remove(folder)
        } else {
            expandedFolders.insert(folder)
        }
    }

    private func selectNote(_ note: NoteMetadata) {
        selectedNote = note

        // Find the corresponding Sheet in CoreData
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", UUID(uuidString: note.uuid) as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let sheet = results.first {
                appState.selectedSheet = sheet
            }
        } catch {
            print("❌ Failed to find sheet: \(error)")
        }
    }

    // MARK: - Formatters

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
}

// MARK: - Folder Section View

struct FolderSectionView: View {
    let folderName: String
    let notes: [NoteMetadata]
    let isExpanded: Bool
    @Binding var selectedNote: NoteMetadata?
    let onToggle: () -> Void
    let onSelectNote: (NoteMetadata) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Folder header
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)

                    Text(folderName.isEmpty ? "Root" : folderName)
                        .font(.system(.body, design: .default))

                    Spacer()

                    Text("\(notes.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            // Notes list
            if isExpanded {
                ForEach(notes, id: \.uuid) { note in
                    NoteRowView(
                        note: note,
                        isSelected: selectedNote?.uuid == note.uuid,
                        onSelect: { onSelectNote(note) }
                    )
                }
            }
        }
    }
}

// MARK: - Note Row View

struct NoteRowView: View {
    let note: NoteMetadata
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.system(.body, design: .default))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let wordCount = note.wordCount, wordCount > 0 {
                            Text("\(wordCount) words")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if !note.tags.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.caption2)
                                Text(note.tags.joined(separator: ", "))
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(note.modified, formatter: dateFormatter)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}
