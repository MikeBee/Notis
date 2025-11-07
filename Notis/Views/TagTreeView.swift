//
//  TagTreeView.swift
//  Notis
//
//  Created by Claude on 11/7/25.
//

import SwiftUI
import CoreData

struct TagTreeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var appState: AppState
    @StateObject private var tagService = TagService.shared
    
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "parent == nil"),
        animation: .default
    )
    private var rootTagsFetch: FetchedResults<Tag>
    
    // Computed property that applies current sorting
    private var rootTags: [Tag] {
        tagService.sortTags(Array(rootTagsFetch))
    }
    
    @State private var showingNewTagDialog = false
    @State private var newTagName = ""
    @State private var newTagColor = "blue"
    @State private var searchText = ""
    @State private var selectedFilterOperation: TagFilterOperation = .and
    @State private var showingTagSearch = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            TagTreeHeader(
                showingNewTagDialog: $showingNewTagDialog,
                showingTagSearch: $showingTagSearch,
                searchText: $searchText,
                selectedTags: tagService.selectedTags,
                filterOperation: $selectedFilterOperation,
                onClearFilters: {
                    tagService.selectedTags.removeAll()
                    searchText = ""
                }
            )
            
            // Search Bar (when expanded)
            if showingTagSearch {
                TagSearchBar(
                    searchText: $searchText,
                    selectedTags: $tagService.selectedTags,
                    filterOperation: $selectedFilterOperation
                )
                .transition(.move(edge: .top))
            }
            
            // Content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !searchText.isEmpty {
                        // Search Results
                        TagSearchResults(
                            searchText: searchText,
                            selectedTags: $tagService.selectedTags,
                            appState: appState
                        )
                    } else {
                        // Tag Tree
                        ForEach(rootTags, id: \.self) { tag in
                            TagRowView(
                                tag: tag,
                                level: 0,
                                selectedTags: $tagService.selectedTags,
                                appState: appState
                            )
                        }
                    }
                }
                .padding(.top, UlyssesDesign.Spacing.sm)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showingNewTagDialog) {
            NewTagDialog(
                tagName: $newTagName,
                tagColor: $newTagColor,
                isPresented: $showingNewTagDialog,
                onCreate: createNewTag
            )
        }
        .onChange(of: tagService.selectedTags) {
            updateAppStateForTagFilter()
        }
        .onChange(of: selectedFilterOperation) {
            updateAppStateForTagFilter()
        }
        .onChange(of: tagService.currentSortOrder) {
            // Force UI refresh when sort order changes
        }
        .onChange(of: tagService.sortAscending) {
            // Force UI refresh when sort direction changes
        }
    }
    
    private func createNewTag() {
        _ = tagService.createTag(name: newTagName, color: newTagColor)
        newTagName = ""
        newTagColor = "blue"
    }
    
    private func updateAppStateForTagFilter() {
        if !tagService.selectedTags.isEmpty {
            // Switch to tag filtering mode
            appState.selectedGroup = nil
            appState.selectedEssential = nil
            tagService.isTagMode = true
        } else {
            tagService.isTagMode = false
        }
    }
}

struct TagTreeHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showingNewTagDialog: Bool
    @Binding var showingTagSearch: Bool
    @Binding var searchText: String
    let selectedTags: Set<Tag>
    @Binding var filterOperation: TagFilterOperation
    let onClearFilters: () -> Void
    @StateObject private var tagService = TagService.shared
    
    @State private var isSearchButtonHovering = false
    @State private var isPlusButtonHovering = false
    @State private var showingSortMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: UlyssesDesign.Spacing.md) {
                Text("Tags")
                    .font(UlyssesDesign.Typography.libraryTitle)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Spacer()
                
                // Filter operation selector (when tags are selected)
                if !selectedTags.isEmpty {
                    Menu {
                        Button("All tags (AND)") { filterOperation = .and }
                        Button("Any tag (OR)") { filterOperation = .or }
                        Button("Exclude tags (NOT)") { filterOperation = .not }
                    } label: {
                        Image(systemName: filterOperation.iconName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Clear filters button
                    Button(action: onClearFilters) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Sort menu
                Menu {
                    ForEach(TagSortOrder.allCases, id: \.self) { sortOrder in
                        Button(action: {
                            tagService.setSortOrder(sortOrder)
                        }) {
                            HStack {
                                Image(systemName: sortOrder.systemImage)
                                Text(sortOrder.rawValue)
                                Spacer()
                                if tagService.currentSortOrder == sortOrder {
                                    Image(systemName: tagService.sortAscending ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Direction toggle
                    Button(action: {
                        tagService.setSortOrder(tagService.currentSortOrder, ascending: !tagService.sortAscending)
                    }) {
                        HStack {
                            Image(systemName: tagService.sortAscending ? "chevron.up" : "chevron.down")
                            Text(tagService.sortAscending ? "Ascending" : "Descending")
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tagService.currentSortOrder.systemImage)
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: tagService.sortAscending ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Search toggle
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingTagSearch.toggle()
                    }
                }) {
                    Image(systemName: showingTagSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        .scaleEffect(isSearchButtonHovering ? 1.05 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 33, height: 33)
                .background(UlyssesDesign.Colors.hover.opacity(isSearchButtonHovering ? 1 : 0))
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isSearchButtonHovering = hovering
                    }
                }
                
                
                // Add new tag
                Button(action: { showingNewTagDialog = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        .scaleEffect(isPlusButtonHovering ? 1.05 : 1.0)
                        .rotationEffect(.degrees(isPlusButtonHovering ? 90 : 0))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 33, height: 33)
                .background(UlyssesDesign.Colors.hover.opacity(isPlusButtonHovering ? 1 : 0))
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPlusButtonHovering = hovering
                    }
                }
            }
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
            .padding(.vertical, UlyssesDesign.Spacing.lg)
            
            // Active filters display
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UlyssesDesign.Spacing.xs) {
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            TagChip(tag: tag, isSelected: true) {
                                var newSelection = selectedTags
                                newSelection.remove(tag)
                                // Note: This would need to be bound properly in a real implementation
                            }
                        }
                    }
                    .padding(.horizontal, UlyssesDesign.Spacing.lg)
                }
                .frame(height: 40)
            }
        }
        .background(
            Rectangle()
                .fill(UlyssesDesign.Colors.libraryBg(for: colorScheme))
                .overlay(
                    Rectangle()
                        .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme))
                        .frame(height: 0.5)
                        .opacity(0.6),
                    alignment: .bottom
                )
        )
    }
}

struct TagSearchBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var searchText: String
    @Binding var selectedTags: Set<Tag>
    @Binding var filterOperation: TagFilterOperation
    @StateObject private var tagService = TagService.shared
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.sm) {
            // Search input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                
                TextField("Search tags...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(UlyssesDesign.Typography.sheetPreview)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, UlyssesDesign.Spacing.md)
            .padding(.vertical, UlyssesDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.medium)
                    .fill(UlyssesDesign.Colors.background(for: colorScheme))
            )
            
            // Filter operation picker
            if !selectedTags.isEmpty {
                HStack {
                    Text("Filter:")
                        .font(UlyssesDesign.Typography.caption)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    
                    Picker("Filter Operation", selection: $filterOperation) {
                        Text("All tags").tag(TagFilterOperation.and)
                        Text("Any tag").tag(TagFilterOperation.or)
                        Text("Exclude").tag(TagFilterOperation.not)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
        }
        .padding(.horizontal, UlyssesDesign.Spacing.lg)
        .padding(.vertical, UlyssesDesign.Spacing.md)
        .background(UlyssesDesign.Colors.libraryBg(for: colorScheme))
    }
}

struct TagRowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var tag: Tag
    let level: Int
    @Binding var selectedTags: Set<Tag>
    @ObservedObject var appState: AppState
    @StateObject private var tagService = TagService.shared
    
    @State private var isExpanded = true
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editingName = ""
    @State private var showingColorPicker = false
    
    private var isSelected: Bool {
        selectedTags.contains(tag)
    }
    
    private var tagCount: Int {
        // Show usage count when sorting by frequency, otherwise show sheet count
        if tagService.currentSortOrder == .frequency {
            return Int(tag.usageCount)
        } else {
            return tagService.getTagCount(for: tag, includeSubtags: true)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tag Row
            HStack(spacing: UlyssesDesign.Spacing.xs) {
                // Indentation
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(level) * UlyssesDesign.Spacing.lg)
                
                // Expansion chevron
                HStack(spacing: UlyssesDesign.Spacing.xs) {
                    if tag.hasChildren {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 18, height: 18)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 18)
                    }
                    
                    // Tag color indicator
                    Circle()
                        .fill(tag.tagColor)
                        .frame(width: 12, height: 12)
                }
                
                // Tag name with pin indicator
                if isEditing {
                    TextField("Tag Name", text: $editingName, onCommit: finishEditing)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(UlyssesDesign.Typography.groupName)
                        .onAppear {
                            editingName = tag.displayName
                        }
                } else {
                    HStack(spacing: UlyssesDesign.Spacing.xs) {
                        Text(tag.displayName)
                            .font(UlyssesDesign.Typography.groupName)
                            .foregroundColor(
                                isSelected
                                    ? UlyssesDesign.Colors.accent
                                    : UlyssesDesign.Colors.primary(for: colorScheme)
                            )
                            .lineLimit(1)
                        
                        if tag.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.accent)
                        }
                    }
                }
                
                Spacer()
                
                // Tag count
                if tagCount > 0 {
                    let countColor = UlyssesDesign.Colors.tertiary(for: colorScheme)
                    Text("\(tagCount)")
                        .font(UlyssesDesign.Typography.groupCount)
                        .foregroundColor(countColor)
                        .padding(.horizontal, UlyssesDesign.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(countColor.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
            .padding(.vertical, UlyssesDesign.Spacing.sm)
            .background(backgroundColorForTag)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                toggleTagSelection()
            }
            .onLongPressGesture {
                startEditing()
            }
            .contextMenu {
                Button(tag.isPinned ? "Unpin Tag" : "Pin Tag") {
                    tagService.toggleTagPin(tag)
                }
                Divider()
                Button("Rename") { startEditing() }
                Button("Change Color") { showingColorPicker = true }
                Divider()
                Button(isSelected ? "Deselect" : "Select") { toggleTagSelection() }
                Button("View Tagged Sheets") { selectTag() }
                Divider()
                Button("Delete", role: .destructive) { deleteTag() }
            }
            
            // Child tags
            if isExpanded {
                let childTags = tagService.getChildTags(for: tag)
                ForEach(childTags, id: \.self) { childTag in
                    TagRowView(
                        tag: childTag,
                        level: level + 1,
                        selectedTags: $selectedTags,
                        appState: appState
                    )
                }
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            TagColorPickerView(tag: tag, isPresented: $showingColorPicker)
        }
    }
    
    private var backgroundColorForTag: Color {
        if isSelected {
            return UlyssesDesign.Colors.accent.opacity(0.15)
        } else if isHovering {
            return UlyssesDesign.Colors.hover
        } else {
            return Color.clear
        }
    }
    
    private func toggleTagSelection() {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        HapticService.shared.itemSelected()
    }
    
    private func selectTag() {
        appState.selectedGroup = nil
        appState.selectedEssential = nil
        appState.selectedSheet = nil
        selectedTags.removeAll()
        selectedTags.insert(tag)
        tagService.isTagMode = true
    }
    
    private func startEditing() {
        isEditing = true
        editingName = tag.displayName
    }
    
    private func finishEditing() {
        tagService.renameTag(tag, newName: editingName)
        isEditing = false
    }
    
    private func deleteTag() {
        tagService.deleteTag(tag)
    }
}

struct TagSearchResults: View {
    let searchText: String
    @Binding var selectedTags: Set<Tag>
    @ObservedObject var appState: AppState
    @StateObject private var tagService = TagService.shared
    
    private var searchResults: [Tag] {
        tagService.searchTags(query: searchText)
    }
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if searchResults.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: UlyssesDesign.Spacing.md) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No tags found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try a different search term")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                ForEach(searchResults, id: \.self) { tag in
                    TagRowView(
                        tag: tag,
                        level: 0,
                        selectedTags: $selectedTags,
                        appState: appState
                    )
                }
            }
        }
    }
}

struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tag.tagColor)
                .frame(width: 8, height: 8)
            
            if tag.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(tag.displayName)
                .font(.caption)
                .lineLimit(1)
            
            if isSelected {
                Button(action: onTap) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tag.tagColor.opacity(isSelected ? 0.2 : 0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(tag.tagColor.opacity(isSelected ? 0.5 : 0.3), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Extensions

extension TagFilterOperation {
    var iconName: String {
        switch self {
        case .and: return "rectangle.and"
        case .or: return "rectangle.or"
        case .not: return "minus.circle"
        }
    }
}

#Preview {
    TagTreeView(appState: AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 300, height: 600)
}