//
//  FolderPickerView.swift
//  Notis
//
//  Created by Claude on 11/4/25.
//

import SwiftUI
import CoreData

struct FolderPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    let selectedFolderName: String?
    let onFolderSelected: (String?) -> Void
    
    @State private var searchText = ""
    @State private var expandedGroups = Set<UUID>()
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Group.parent, ascending: true),
            NSSortDescriptor(keyPath: \Group.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Group.name, ascending: true)
        ],
        animation: .default
    )
    private var allGroups: FetchedResults<Group>
    
    private var rootGroups: [Group] {
        allGroups.filter { $0.parent == nil }
    }
    
    private var filteredGroups: [Group] {
        if searchText.isEmpty {
            return Array(allGroups)
        }
        return allGroups.filter { group in
            group.name?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Folder list
                List {
                    // None option
                    FolderPickerRow(
                        name: "None (use selected folder)",
                        icon: "minus.circle",
                        level: 0,
                        isSelected: selectedFolderName == nil,
                        onSelect: {
                            onFolderSelected(nil)
                            dismiss()
                        }
                    )
                    
                    Divider()
                    
                    if searchText.isEmpty {
                        // Hierarchical view when not searching
                        ForEach(rootGroups, id: \.self) { group in
                            FolderHierarchyView(
                                group: group,
                                selectedFolderName: selectedFolderName,
                                expandedGroups: $expandedGroups,
                                onFolderSelected: { folderName in
                                    onFolderSelected(folderName)
                                    dismiss()
                                }
                            )
                        }
                    } else {
                        // Flat list when searching
                        ForEach(filteredGroups, id: \.self) { group in
                            FolderPickerRow(
                                name: group.name ?? "Untitled",
                                icon: groupIcon(for: group),
                                color: groupColor(for: group),
                                level: 0,
                                isSelected: selectedFolderName == group.name,
                                breadcrumb: breadcrumbPath(for: group),
                                onSelect: {
                                    onFolderSelected(group.name)
                                    dismiss()
                                }
                            )
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Choose Target Folder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Expand groups that contain the selected folder
            if let selectedName = selectedFolderName {
                expandToSelectedFolder(selectedName)
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search folders...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func groupIcon(for group: Group) -> String {
        if let groupId = group.id?.uuidString {
            return UserDefaults.standard.string(forKey: "group_icon_\(groupId)") ?? "folder"
        }
        return "folder"
    }

    private func groupColor(for group: Group) -> String {
        if let groupId = group.id?.uuidString {
            return UserDefaults.standard.string(forKey: "group_color_\(groupId)") ?? "default"
        }
        return "default"
    }

    private func breadcrumbPath(for group: Group) -> String {
        var path: [String] = []
        var currentGroup: Group? = group.parent
        
        while let parent = currentGroup {
            path.insert(parent.name ?? "Untitled", at: 0)
            currentGroup = parent.parent
        }
        
        return path.isEmpty ? "" : path.joined(separator: " › ")
    }
    
    private func expandToSelectedFolder(_ folderName: String) {
        guard let selectedGroup = allGroups.first(where: { $0.name == folderName }) else { return }
        
        // Expand all parent groups
        var currentGroup: Group? = selectedGroup.parent
        while let parent = currentGroup {
            if let id = parent.id {
                expandedGroups.insert(id)
            }
            currentGroup = parent.parent
        }
    }
}

struct FolderHierarchyView: View {
    @ObservedObject var group: Group
    let selectedFolderName: String?
    @Binding var expandedGroups: Set<UUID>
    let onFolderSelected: (String) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var isExpanded: Bool {
        guard let id = group.id else { return false }
        return expandedGroups.contains(id)
    }
    
    private var hasSubgroups: Bool {
        return (group.subgroups?.count ?? 0) > 0
    }
    
    private var subgroups: [Group] {
        guard let subgroupsSet = group.subgroups else { return [] }
        return (subgroupsSet.allObjects as? [Group])?.sorted { group1, group2 in
            return (group1.name ?? "") < (group2.name ?? "")
        } ?? []
    }
    
    private func groupIcon(for group: Group) -> String {
        if let groupId = group.id?.uuidString {
            return UserDefaults.standard.string(forKey: "group_icon_\(groupId)") ?? "folder"
        }
        return "folder"
    }

    private func groupColor(for group: Group) -> String {
        if let groupId = group.id?.uuidString {
            return UserDefaults.standard.string(forKey: "group_color_\(groupId)") ?? "default"
        }
        return "default"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group row
            FolderPickerRow(
                name: group.name ?? "Untitled",
                icon: groupIcon(for: group),
                color: groupColor(for: group),
                level: groupLevel(group),
                isSelected: selectedFolderName == group.name,
                hasSubgroups: hasSubgroups,
                isExpanded: isExpanded,
                onSelect: {
                    onFolderSelected(group.name ?? "")
                },
                onToggleExpansion: {
                    toggleExpansion()
                }
            )
            
            // Subgroups
            if isExpanded {
                ForEach(subgroups, id: \.self) { subgroup in
                    FolderHierarchyView(
                        group: subgroup,
                        selectedFolderName: selectedFolderName,
                        expandedGroups: $expandedGroups,
                        onFolderSelected: onFolderSelected
                    )
                }
            }
        }
    }
    
    private func groupLevel(_ group: Group) -> Int {
        var level = 0
        var currentGroup: Group? = group.parent
        while currentGroup != nil {
            level += 1
            currentGroup = currentGroup?.parent
        }
        return level
    }
    
    private func toggleExpansion() {
        guard let id = group.id else { return }
        
        if expandedGroups.contains(id) {
            expandedGroups.remove(id)
        } else {
            expandedGroups.insert(id)
        }
    }
}

struct FolderPickerRow: View {
    let name: String
    let icon: String
    let color: String
    let level: Int
    let isSelected: Bool
    let breadcrumb: String?
    let hasSubgroups: Bool
    let isExpanded: Bool
    let onSelect: () -> Void
    let onToggleExpansion: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    init(
        name: String,
        icon: String,
        color: String = "default",
        level: Int,
        isSelected: Bool,
        breadcrumb: String? = nil,
        hasSubgroups: Bool = false,
        isExpanded: Bool = false,
        onSelect: @escaping () -> Void,
        onToggleExpansion: (() -> Void)? = nil
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.level = level
        self.isSelected = isSelected
        self.breadcrumb = breadcrumb
        self.hasSubgroups = hasSubgroups
        self.isExpanded = isExpanded
        self.onSelect = onSelect
        self.onToggleExpansion = onToggleExpansion
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray": return .gray
        default: return isSelected ? .accentColor : .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Indentation
            Rectangle()
                .fill(Color.clear)
                .frame(width: CGFloat(level) * 20)
            
            // Expansion indicator
            if hasSubgroups {
                Button(action: {
                    onToggleExpansion?()
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 12, height: 12)
            }
            
            // Icon with custom color
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(colorFromName(color))
                .frame(width: 16)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .lineLimit(1)
                
                if let breadcrumb = breadcrumb, !breadcrumb.isEmpty {
                    Text(breadcrumb)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovering ? Color(.systemGray6) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    FolderPickerView(selectedFolderName: "Journal") { folderName in
        print("Selected folder: \(folderName ?? "None")")
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}