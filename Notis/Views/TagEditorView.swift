//
//  TagEditorView.swift
//  Notis
//
//  Created by Claude on 11/7/25.
//

import SwiftUI
import CoreData

struct TagEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var sheet: Sheet
    @StateObject private var tagService = TagService.shared
    
    @State private var tagInput = ""
    @State private var showingSuggestions = false
    @State private var showingTagPicker = false
    @FocusState private var isInputFocused: Bool
    
    private var currentTags: [Tag] {
        tagService.getSheetTags(for: sheet)
    }
    
    private var suggestions: [Tag] {
        if tagInput.isEmpty {
            return tagService.suggestRelatedTags(for: sheet)
        } else {
            return tagService.searchTags(query: tagInput)
                .filter { tag in
                    !currentTags.contains(tag)
                }
                .prefix(10)
                .map { $0 }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.md) {
            // Current Tags
            if !currentTags.isEmpty {
                VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                    Text("Tags")
                        .font(UlyssesDesign.Typography.caption)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        .textCase(.uppercase)
                    
                    FlowLayout(spacing: UlyssesDesign.Spacing.xs) {
                        ForEach(currentTags, id: \.self) { tag in
                            TagChip(tag: tag, isSelected: true) {
                                removeTag(tag)
                            }
                            .contextMenu {
                                Button(tag.isPinned ? "Unpin Tag" : "Pin Tag") {
                                    TagService.shared.toggleTagPin(tag)
                                }
                                Divider()
                                Button("Remove from Sheet", role: .destructive) {
                                    removeTag(tag)
                                }
                            }
                        }
                    }
                }
            }
            
            // Tag Input
            VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.xs) {
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        .frame(width: 20)
                    
                    TextField("Add tags (e.g., #research/ai)", text: $tagInput)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(UlyssesDesign.Typography.sheetPreview)
                        .focused($isInputFocused)
                        .onSubmit {
                            addTagFromInput()
                        }
                        .onChange(of: tagInput) { _ in
                            showingSuggestions = !tagInput.isEmpty || !suggestions.isEmpty
                        }
                    
                    Button(action: { showingTagPicker = true }) {
                        Image(systemName: "tag")
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, UlyssesDesign.Spacing.md)
                .padding(.vertical, UlyssesDesign.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.medium)
                        .fill(UlyssesDesign.Colors.background(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.medium)
                                .strokeBorder(
                                    isInputFocused ? UlyssesDesign.Colors.accent : UlyssesDesign.Colors.dividerColor(for: colorScheme),
                                    lineWidth: isInputFocused ? 2 : 1
                                )
                        )
                )
                
                // Help text
                if tagInput.isEmpty && currentTags.isEmpty {
                    Text("Type # followed by tag name, or use / for hierarchy (e.g., #project/ai/ethics)")
                        .font(UlyssesDesign.Typography.caption)
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                }
            }
            
            // Suggestions
            if showingSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                    Text(tagInput.isEmpty ? "Suggested Tags" : "Matching Tags")
                        .font(UlyssesDesign.Typography.caption)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        .textCase(.uppercase)
                    
                    FlowLayout(spacing: UlyssesDesign.Spacing.xs) {
                        ForEach(suggestions, id: \.self) { tag in
                            TagChip(tag: tag, isSelected: false) {
                                addTag(tag)
                            }
                            .contextMenu {
                                Button(tag.isPinned ? "Unpin Tag" : "Pin Tag") {
                                    TagService.shared.toggleTagPin(tag)
                                }
                                Button("Add to Sheet") {
                                    addTag(tag)
                                }
                            }
                        }
                    }
                }
                .transition(.move(edge: .top))
            }
        }
        .sheet(isPresented: $showingTagPicker) {
            TagPickerView(sheet: sheet, isPresented: $showingTagPicker)
        }
        .onAppear {
            // Process any inline tags in the content
            if let content = sheet.content {
                tagService.processInlineTags(in: content, for: sheet)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusTagInput)) { _ in
            isInputFocused = true
        }
    }
    
    private func addTagFromInput() {
        let input = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        // Remove # prefix if present
        let tagPath = input.hasPrefix("#") ? String(input.dropFirst()) : input
        
        if let tag = tagService.createTagFromPath(tagPath) {
            tagService.addTag(tag, to: sheet)
            tagInput = ""
            showingSuggestions = false
            HapticService.shared.itemSelected()
        }
    }
    
    private func addTag(_ tag: Tag) {
        tagService.addTag(tag, to: sheet)
        HapticService.shared.itemSelected()
    }
    
    private func removeTag(_ tag: Tag) {
        tagService.removeTag(tag, from: sheet)
        HapticService.shared.buttonTap()
    }
}

struct TagPickerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var sheet: Sheet
    @Binding var isPresented: Bool
    @StateObject private var tagService = TagService.shared
    
    @State private var searchText = ""
    @State private var selectedTags: Set<Tag> = []
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.path, ascending: true)],
        animation: .default
    )
    private var allTags: FetchedResults<Tag>
    
    private var filteredTags: [Tag] {
        if searchText.isEmpty {
            return Array(allTags)
        } else {
            return allTags.filter { tag in
                tag.fullPath.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var currentTags: Set<Tag> {
        Set(tagService.getSheetTags(for: sheet))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    
                    TextField("Search tags...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, UlyssesDesign.Spacing.md)
                .padding(.vertical, UlyssesDesign.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.medium)
                        .fill(UlyssesDesign.Colors.background(for: colorScheme))
                )
                .padding()
                
                // Tags list
                List {
                    ForEach(filteredTags, id: \.self) { tag in
                        TagPickerRow(
                            tag: tag,
                            isSelected: selectedTags.contains(tag),
                            isCurrentlyTagged: currentTags.contains(tag)
                        ) {
                            toggleTag(tag)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        applyChanges()
                        isPresented = false
                    }
                    .disabled(selectedTags.isEmpty)
                }
            }
        }
        .onAppear {
            selectedTags = currentTags
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func applyChanges() {
        // Remove tags that are no longer selected
        for tag in currentTags {
            if !selectedTags.contains(tag) {
                tagService.removeTag(tag, from: sheet)
            }
        }
        
        // Add new tags
        for tag in selectedTags {
            if !currentTags.contains(tag) {
                tagService.addTag(tag, to: sheet)
            }
        }
    }
}

struct TagPickerRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let tag: Tag
    let isSelected: Bool
    let isCurrentlyTagged: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Tag color and name
            HStack(spacing: UlyssesDesign.Spacing.sm) {
                Circle()
                    .fill(tag.tagColor)
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.displayName)
                        .font(UlyssesDesign.Typography.sheetPreview)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    if let path = tag.path, path != tag.displayName {
                        Text(path)
                            .font(UlyssesDesign.Typography.caption)
                            .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                    }
                }
            }
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            } else if isCurrentlyTagged {
                Image(systemName: "circle.fill")
                    .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
            } else {
                Image(systemName: "circle")
                    .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct TagColorPickerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var tag: Tag
    @Binding var isPresented: Bool
    
    private let colors = [
        ("Red", "red", Color.red),
        ("Orange", "orange", Color.orange),
        ("Yellow", "yellow", Color.yellow),
        ("Green", "green", Color.green),
        ("Blue", "blue", Color.blue),
        ("Purple", "purple", Color.purple),
        ("Pink", "pink", Color.pink),
        ("Gray", "gray", Color.gray)
    ]
    
    var body: some View {
        NavigationView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                ForEach(colors, id: \.1) { colorInfo in
                    Button {
                        tag.color = colorInfo.1
                        tag.modifiedAt = Date()
                        
                        do {
                            try viewContext.save()
                        } catch {
                            print("Failed to update tag color: \(error)")
                        }
                        
                        isPresented = false
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(colorInfo.2)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            tag.color == colorInfo.1 ? Color.primary : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                            
                            Text(colorInfo.0)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct NewTagDialog: View {
    @Binding var tagName: String
    @Binding var tagColor: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    private let colors = [
        ("Red", "red", Color.red),
        ("Orange", "orange", Color.orange),
        ("Yellow", "yellow", Color.yellow),
        ("Green", "green", Color.green),
        ("Blue", "blue", Color.blue),
        ("Purple", "purple", Color.purple),
        ("Pink", "pink", Color.pink),
        ("Gray", "gray", Color.gray)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tag Name")
                        .font(.headline)
                    
                    TextField("Enter tag name (use / for hierarchy)", text: $tagName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Color")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(colors, id: \.1) { colorInfo in
                            Button {
                                tagColor = colorInfo.1
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(colorInfo.2)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    tagColor == colorInfo.1 ? Color.primary : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    
                                    Text(colorInfo.0)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        tagName = ""
                        tagColor = "blue"
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        onCreate()
                        isPresented = false
                    }
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - FlowLayout for tag chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > containerWidth && currentX > 0 {
                currentY += maxHeight + spacing
                currentX = 0
                maxHeight = 0
            }
            
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
        
        return CGSize(width: containerWidth, height: currentY + maxHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentY += maxHeight + spacing
                currentX = bounds.minX
                maxHeight = 0
            }
            
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}

#Preview {
    TagEditorView(sheet: Sheet())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .padding()
}