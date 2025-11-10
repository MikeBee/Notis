//
//  TagsBrowserView.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import CoreData

/// View for browsing markdown files by tags
struct TagsBrowserView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState

    @State private var tags: [(tag: String, count: Int)] = []
    @State private var selectedTag: String?
    @State private var notesForSelectedTag: [NoteMetadata] = []
    @State private var searchText: String = ""

    private let indexService = NotesIndexService.shared

    var body: some View {
        HStack(spacing: 0) {
            // Tags list (left sidebar)
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Tags")
                        .font(.headline)

                    Spacer()

                    Text("\(tags.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter tags...", text: $searchText)
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

                // Tags list
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredTags, id: \.tag) { item in
                            TagRowView(
                                tag: item.tag,
                                count: item.count,
                                isSelected: selectedTag == item.tag,
                                onSelect: { selectTag(item.tag) }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(width: 250)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Notes for selected tag (right side)
            if let tag = selectedTag {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.accentColor)

                        Text(tag)
                            .font(.headline)

                        Spacer()

                        Text("\(notesForSelectedTag.count) notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    // Notes list
                    if notesForSelectedTag.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("No notes with this tag")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(notesForSelectedTag, id: \.uuid) { note in
                                    TagNoteRowView(note: note) {
                                        selectNote(note)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            } else {
                // No tag selected
                VStack(spacing: 16) {
                    Image(systemName: "tag")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("Select a tag")
                        .font(.title2)

                    Text("Choose a tag from the list to see related notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: loadTags)
    }

    // MARK: - Computed Properties

    private var filteredTags: [(tag: String, count: Int)] {
        if searchText.isEmpty {
            return tags
        }
        return tags.filter { $0.tag.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Actions

    private func loadTags() {
        let allTags = indexService.getAllTags()

        // Count notes for each tag
        var tagCounts: [(tag: String, count: Int)] = []
        for tag in allTags {
            let notes = indexService.getNotes(byTag: tag)
            tagCounts.append((tag: tag, count: notes.count))
        }

        // Sort by count descending, then alphabetically
        tags = tagCounts.sorted { first, second in
            if first.count == second.count {
                return first.tag < second.tag
            }
            return first.count > second.count
        }
    }

    private func selectTag(_ tag: String) {
        selectedTag = tag
        notesForSelectedTag = indexService.getNotes(byTag: tag)
    }

    private func selectNote(_ note: NoteMetadata) {
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
}

// MARK: - Tag Row View

struct TagRowView: View {
    let tag: String
    let count: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 16)

                Text(tag)
                    .lineLimit(1)

                Spacer()

                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Note Row View

struct TagNoteRowView: View {
    let note: NoteMetadata
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
                        .lineLimit(2)
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

                    // Show other tags
                    let otherTags = note.tags.filter { $0 != note.tags.first }
                    if !otherTags.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.caption2)
                            Text(otherTags.prefix(2).joined(separator: ", "))
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
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
