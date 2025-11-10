//
//  EnhancedSearchView.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import CoreData

/// Enhanced search view using FTS5 full-text search on markdown files
struct EnhancedSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState

    @State private var searchQuery: String = ""
    @State private var searchResults: [NoteMetadata] = []
    @State private var isSearching: Bool = false
    @State private var selectedTag: String?
    @State private var selectedFolder: String?
    @State private var availableTags: [String] = []
    @State private var availableFolders: [String] = []

    private let indexService = NotesIndexService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Search Markdown Files")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))

            Divider()

            // Search bar
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search content, titles, tags...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .onSubmit(performSearch)

                    if !searchQuery.isEmpty {
                        Button(action: clearSearch) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }

                    Button(action: performSearch) {
                        Text("Search")
                    }
                    .disabled(searchQuery.isEmpty)
                }
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(6)

                // Filters
                HStack(spacing: 12) {
                    // Tag filter
                    Menu {
                        Button("All Tags") {
                            selectedTag = nil
                            performSearch()
                        }
                        Divider()
                        ForEach(availableTags, id: \.self) { tag in
                            Button(tag) {
                                selectedTag = tag
                                performSearch()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "tag")
                            Text(selectedTag ?? "All Tags")
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    // Folder filter
                    Menu {
                        Button("All Folders") {
                            selectedFolder = nil
                            performSearch()
                        }
                        Divider()
                        ForEach(availableFolders, id: \.self) { folder in
                            Button(folder.isEmpty ? "Root" : folder) {
                                selectedFolder = folder
                                performSearch()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text(selectedFolder == nil ? "All Folders" : (selectedFolder!.isEmpty ? "Root" : selectedFolder!))
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if selectedTag != nil || selectedFolder != nil {
                        Button("Clear Filters") {
                            selectedTag = nil
                            selectedFolder = nil
                            performSearch()
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            // Results
            if isSearching {
                ProgressView()
                    .padding()
                Spacer()
            } else if searchQuery.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Search your markdown files")
                        .font(.headline)

                    Text("Use full-text search to find content across all your notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                Spacer()
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No results found")
                        .font(.headline)

                    Text("Try different keywords or check your filters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Results header
                        HStack {
                            Text("\(searchResults.count) results")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Results list
                        ForEach(searchResults, id: \.uuid) { note in
                            MarkdownSearchResultRow(note: note, query: searchQuery) {
                                selectNote(note)
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
        }
        .onAppear(perform: loadFilters)
    }

    // MARK: - Actions

    private func loadFilters() {
        availableTags = indexService.getAllTags()
        availableFolders = indexService.getAllFolders()
    }

    private func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        DispatchQueue.global(qos: .userInitiated).async {
            var results = indexService.search(query: searchQuery, limit: 100)

            // Apply tag filter
            if let tag = selectedTag {
                results = results.filter { $0.tags.contains(tag) }
            }

            // Apply folder filter
            if let folder = selectedFolder {
                results = results.filter {
                    if let path = $0.path {
                        let noteFolder = (path as NSString).deletingLastPathComponent
                        return noteFolder == folder
                    }
                    return folder.isEmpty
                }
            }

            DispatchQueue.main.async {
                searchResults = results
                isSearching = false
            }
        }
    }

    private func clearSearch() {
        searchQuery = ""
        searchResults = []
        selectedTag = nil
        selectedFolder = nil
    }

    private func selectNote(_ note: NoteMetadata) {
        // Find the corresponding Sheet in CoreData
        guard let uuid = UUID(uuidString: note.uuid) else {
            print("❌ Invalid UUID: \(note.uuid)")
            return
        }

        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
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
}

// MARK: - Markdown Search Result Row

struct MarkdownSearchResultRow: View {
    let note: NoteMetadata
    let query: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Title
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.accentColor)

                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if note.status == "favorite" {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }

                // Excerpt
                if let excerpt = note.excerpt {
                    Text(excerpt)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                // Metadata
                HStack(spacing: 12) {
                    if let folder = folderName {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.caption2)
                            Text(folder)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    if !note.tags.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.caption2)
                            Text(note.tags.prefix(3).joined(separator: ", "))
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }

                    if let wordCount = note.wordCount, wordCount > 0 {
                        Text("\(wordCount) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(note.modified, formatter: dateFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var folderName: String? {
        guard let path = note.path else { return nil }
        let folder = (path as NSString).deletingLastPathComponent
        return folder.isEmpty ? "Root" : folder
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}
