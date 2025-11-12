//
//  LibrarySidebar.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI
import CoreData

struct LibrarySidebar: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var appState: AppState
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.sortOrder, ascending: true)],
        predicate: NSPredicate(format: "parent == nil"),
        animation: .default
    )
    private var rootGroups: FetchedResults<Group>
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isCommandButtonHovering = false
    @State private var isPlusButtonHovering = false
    @State private var showingNewGroupDialog = false
    @State private var newGroupName = ""
    @State private var newGroupIcon = "folder"
    @State private var selectedTab: LibraryTab = .groups
    
    enum LibraryTab: String, CaseIterable {
        case groups = "Groups"
        case tags = "Tags"
        
        var icon: String {
            switch self {
            case .groups: return "folder"
            case .tags: return "tag"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Ulysses style
            VStack(spacing: 0) {
                HStack(spacing: UlyssesDesign.Spacing.md) {
                    Text("Library")
                        .font(UlyssesDesign.Typography.libraryTitle)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    Spacer()
                    
                    Button(action: openCommandPalette) {
                        Image(systemName: "command")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            .scaleEffect(isCommandButtonHovering ? 1.05 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 33, height: 33)
                    .background(UlyssesDesign.Colors.hover.opacity(isCommandButtonHovering ? 1 : 0))
                    .cornerRadius(UlyssesDesign.CornerRadius.small)
                    .scaleEffect(isCommandButtonHovering ? 1.02 : 1.0)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isCommandButtonHovering = hovering
                        }
                    }
                    .onTapGesture {
                        HapticService.shared.buttonTap()
                    }
                    
                    Button(action: { 
                        if selectedTab == .groups {
                            showingNewGroupDialog = true 
                        } else {
                            // Handle new tag creation in TagTreeView
                        }
                    }) {
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
                    .scaleEffect(isPlusButtonHovering ? 1.02 : 1.0)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isPlusButtonHovering = hovering
                        }
                    }
                    .onTapGesture {
                        HapticService.shared.buttonTap()
                    }
                }
                .padding(.horizontal, UlyssesDesign.Spacing.lg)
                .padding(.top, UlyssesDesign.Spacing.lg)
                .padding(.bottom, UlyssesDesign.Spacing.sm)
                
                // Tab Picker
                HStack(spacing: 0) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                                // Clear selections when switching tabs
                                if tab == .tags {
                                    appState.selectedGroup = nil
                                    appState.selectedEssential = nil
                                } else {
                                    TagService.shared.selectedTags.removeAll()
                                    TagService.shared.isTagMode = false
                                }
                            }
                        }) {
                            HStack(spacing: UlyssesDesign.Spacing.xs) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 14, weight: .medium))
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(
                                selectedTab == tab 
                                    ? UlyssesDesign.Colors.accent 
                                    : UlyssesDesign.Colors.secondary(for: colorScheme)
                            )
                            .padding(.horizontal, UlyssesDesign.Spacing.md)
                            .padding(.vertical, UlyssesDesign.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                                    .fill(selectedTab == tab ? UlyssesDesign.Colors.accent.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, UlyssesDesign.Spacing.lg)
                .padding(.bottom, UlyssesDesign.Spacing.sm)
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
            
            // Content based on selected tab
            if selectedTab == .groups {
                // Groups List
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Essential Library Sections (Ulysses-style)
                        LibraryEssentialsSection(appState: appState)
                            .onReceive(appState.$selectedGroup) { group in
                                // Clear essential selection when a group is selected
                                if group != nil {
                                    // This will be handled by the essentials section internally
                                }
                            }
                        
                        // Divider
                        Rectangle()
                            .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme))
                            .frame(height: 0.5)
                            .padding(.horizontal, UlyssesDesign.Spacing.lg)
                            .padding(.vertical, UlyssesDesign.Spacing.md)
                        
                        // User Groups
                        ForEach(rootGroups, id: \.self) { group in
                            GroupRowView(
                                group: group, 
                                appState: appState, 
                                level: 0,
                                moveGroupUp: moveGroupUp,
                                moveGroupDown: moveGroupDown,
                                indentGroup: indentGroup,
                                outdentGroup: outdentGroup,
                                moveGroupToParent: moveGroupToParent,
                                reorderSubgroups: reorderSubgroups
                            )
                                .onDrag {
                                    return NSItemProvider(object: group.id?.uuidString as NSString? ?? NSString())
                                }
                                .onDrop(of: [.text], delegate: GroupDropDelegate(
                                    targetGroup: group,
                                    reorderAction: reorderGroups,
                                    rootGroups: Array(rootGroups)
                                ))
                        }
                    }
                    .padding(.top, UlyssesDesign.Spacing.sm)
                }
            } else {
                // Tags View
                TagTreeView(appState: appState)
                    .transition(.opacity)
            }
            
            Spacer()
        }
        .background(
            // Invisible buttons for keyboard shortcuts
            VStack {
                Button("Move Up") {
                    if let selectedGroup = appState.selectedGroup {
                        moveGroupUp(selectedGroup)
                    }
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .hidden()
                
                Button("Move Down") {
                    if let selectedGroup = appState.selectedGroup {
                        moveGroupDown(selectedGroup)
                    }
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .hidden()
                
                Button("Indent") {
                    if let selectedGroup = appState.selectedGroup {
                        indentGroup(selectedGroup)
                    }
                }
                .keyboardShortcut("]", modifiers: .command)
                .hidden()
                
                Button("Outdent") {
                    if let selectedGroup = appState.selectedGroup {
                        outdentGroup(selectedGroup)
                    }
                }
                .keyboardShortcut("[", modifiers: .command)
                .hidden()
            }
        )
        .sheet(isPresented: $showingNewGroupDialog) {
            NewGroupDialog(
                groupName: $newGroupName,
                groupIcon: $newGroupIcon,
                isPresented: $showingNewGroupDialog,
                onCreate: createNewGroupWithDetails
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .showTagFilter)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = .tags
                appState.selectedGroup = nil
                appState.selectedEssential = nil
            }
        }
    }
    
    private func openCommandPalette() {
        NotificationCenter.default.post(name: .showCommandPalette, object: nil)
    }
    
    private func createNewGroupWithDetails() {
        withAnimation {
            let newGroup = Group(context: viewContext)
            newGroup.id = UUID()
            newGroup.name = newGroupName.isEmpty ? "New Group" : newGroupName
            newGroup.createdAt = Date()
            newGroup.modifiedAt = Date()
            newGroup.sortOrder = Int32(rootGroups.count)
            
            // Set the icon
            if let groupId = newGroup.id?.uuidString {
                UserDefaults.standard.set(newGroupIcon, forKey: "group_icon_\(groupId)")
            }
            
            do {
                try viewContext.save()
                appState.selectedGroup = newGroup

                // Create the actual filesystem folder
                let folderPath = newGroup.folderPath()
                if !MarkdownFileService.shared.createFolder(path: folderPath) {
                    Logger.shared.warning("Failed to create folder: \(folderPath)", category: .fileSystem)
                }

                // Reset dialog state
                newGroupName = ""
                newGroupIcon = "folder"
            } catch {
                Logger.shared.error("Failed to create group", error: error, category: .general, userMessage: "Could not create group")
            }
        }
    }
    
    private func reorderGroups(droppedGroup: Group, targetGroup: Group) {
        withAnimation {
            // Ensure all objects are in the context and not deleted
            guard !droppedGroup.isDeleted && !targetGroup.isDeleted else {
                Logger.shared.warning("Attempted to reorder deleted groups", category: .general)
                return
            }
            
            let sortedGroups = Array(rootGroups).filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
            
            guard let droppedIndex = sortedGroups.firstIndex(of: droppedGroup),
                  let targetIndex = sortedGroups.firstIndex(of: targetGroup) else { return }
            
            if droppedIndex == targetIndex { return }
            
            // Remove the dropped group from its current position
            var reorderedGroups = sortedGroups
            reorderedGroups.remove(at: droppedIndex)
            
            // Insert the dropped group at the target position
            let newTargetIndex = droppedIndex < targetIndex ? targetIndex - 1 : targetIndex
            reorderedGroups.insert(droppedGroup, at: newTargetIndex)
            
            // Update sort orders safely using proper Core Data methods
            do {
                for (index, group) in reorderedGroups.enumerated() {
                    // Check if the object is still valid before modifying
                    guard !group.isDeleted && group.managedObjectContext != nil else { continue }
                    
                    group.sortOrder = Int32(index)
                    group.modifiedAt = Date()
                }
                
                try viewContext.save()
            } catch {
                Logger.shared.error("Failed to reorder groups", error: error, category: .general)
                // Rollback to avoid corrupt state
                viewContext.rollback()
            }
        }
    }
    
    private func moveGroupUp(_ group: Group) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let parent = group.parent {
                // Moving subgroup up within parent
                guard let subgroups = parent.subgroups?.allObjects as? [Group] else { return }
                let sortedSubgroups = subgroups.filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
                guard let currentIndex = sortedSubgroups.firstIndex(of: group), currentIndex > 0 else { return }
                
                let targetGroup = sortedSubgroups[currentIndex - 1]
                reorderSubgroups(droppedGroup: group, targetGroup: targetGroup, parentGroup: parent)
            } else {
                // Moving root group up
                let sortedGroups = Array(rootGroups).filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
                guard let currentIndex = sortedGroups.firstIndex(of: group), currentIndex > 0 else { return }
                
                let targetGroup = sortedGroups[currentIndex - 1]
                reorderGroups(droppedGroup: group, targetGroup: targetGroup)
            }
            HapticService.shared.buttonTap()
        }
    }
    
    private func moveGroupDown(_ group: Group) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let parent = group.parent {
                // Moving subgroup down within parent
                guard let subgroups = parent.subgroups?.allObjects as? [Group] else { return }
                let sortedSubgroups = subgroups.filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
                guard let currentIndex = sortedSubgroups.firstIndex(of: group), 
                      currentIndex < sortedSubgroups.count - 1 else { return }
                
                let targetGroup = sortedSubgroups[currentIndex + 1]
                reorderSubgroups(droppedGroup: group, targetGroup: targetGroup, parentGroup: parent)
            } else {
                // Moving root group down
                let sortedGroups = Array(rootGroups).filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
                guard let currentIndex = sortedGroups.firstIndex(of: group), 
                      currentIndex < sortedGroups.count - 1 else { return }
                
                let targetGroup = sortedGroups[currentIndex + 1]
                reorderGroups(droppedGroup: group, targetGroup: targetGroup)
            }
            HapticService.shared.buttonTap()
        }
    }
    
    private func indentGroup(_ group: Group) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Can only indent if there's a previous group at the same level to become parent
            if let parent = group.parent {
                // This is a subgroup - find previous sibling to become new parent
                guard let subgroups = parent.subgroups?.allObjects as? [Group] else { return }
                let sortedSubgroups = subgroups.filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
                guard let currentIndex = sortedSubgroups.firstIndex(of: group), currentIndex > 0 else { return }
                
                let newParent = sortedSubgroups[currentIndex - 1]
                moveGroupToParent(droppedGroup: group, newParent: newParent)
            } else {
                // This is a root group - find previous root group to become parent
                let sortedGroups = Array(rootGroups).filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
                guard let currentIndex = sortedGroups.firstIndex(of: group), currentIndex > 0 else { return }
                
                let newParent = sortedGroups[currentIndex - 1]
                moveGroupToParent(droppedGroup: group, newParent: newParent)
            }
            HapticService.shared.buttonTap()
        }
    }
    
    private func outdentGroup(_ group: Group) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Can only outdent if group has a parent
            guard let currentParent = group.parent else { return }
            
            if let grandparent = currentParent.parent {
                // Move to grandparent (make it a sibling of current parent)
                moveGroupToParent(droppedGroup: group, newParent: grandparent)
            } else {
                // Move to root level (remove parent)
                do {
                    group.setValue(nil, forKey: "parent")
                    group.setValue(Date(), forKey: "modifiedAt")
                    
                    // Set sort order to be last among root groups
                    group.setValue(Int32(rootGroups.count), forKey: "sortOrder")
                    
                    try viewContext.save()
                } catch {
                    print("❌ Failed to outdent group: \(error)")
                    viewContext.refresh(group, mergeChanges: false)
                }
            }
            HapticService.shared.buttonTap()
        }
    }
    
    private func reorderSubgroups(droppedGroup: Group, targetGroup: Group, parentGroup: Group) {
        withAnimation {
            // Ensure all objects are in the context and not deleted
            guard !droppedGroup.isDeleted && !targetGroup.isDeleted && !parentGroup.isDeleted else {
                print("⚠️ Attempted to reorder deleted groups")
                return
            }
            
            guard let subgroups = parentGroup.subgroups?.allObjects as? [Group] else { return }
            let sortedSubgroups = subgroups.filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
            
            guard let droppedIndex = sortedSubgroups.firstIndex(of: droppedGroup),
                  let targetIndex = sortedSubgroups.firstIndex(of: targetGroup) else { return }
            
            if droppedIndex == targetIndex { return }
            
            // Remove the dropped group from its current position
            var reorderedSubgroups = sortedSubgroups
            reorderedSubgroups.remove(at: droppedIndex)
            
            // Insert the dropped group at the target position
            let newTargetIndex = droppedIndex < targetIndex ? targetIndex - 1 : targetIndex
            reorderedSubgroups.insert(droppedGroup, at: newTargetIndex)
            
            // Update sort orders safely using proper Core Data methods
            do {
                for (index, subgroup) in reorderedSubgroups.enumerated() {
                    // Check if the object is still valid before modifying
                    guard !subgroup.isDeleted && subgroup.managedObjectContext != nil else { continue }
                    
                    subgroup.sortOrder = Int32(index)
                    subgroup.modifiedAt = Date()
                }
                
                try viewContext.save()
            } catch {
                print("❌ Failed to reorder subgroups: \(error)")
                // Rollback to avoid corrupt state
                viewContext.rollback()
            }
        }
    }
    
    private func moveGroupToParent(droppedGroup: Group, newParent: Group) {
        withAnimation {
            // Prevent creating circular references
            var currentParent = newParent.parent
            while let parent = currentParent {
                if parent == droppedGroup {
                    print("⚠️ Prevented circular reference in group hierarchy")
                    return // Would create a circular reference
                }
                currentParent = parent.parent
            }
            
            // Safely move the group to the new parent using setValue
            do {
                droppedGroup.setValue(newParent, forKey: "parent")
                droppedGroup.setValue(Date(), forKey: "modifiedAt")
                
                // Update sort order to be last in the new parent
                let existingSubgroups = newParent.subgroups?.allObjects as? [Group] ?? []
                droppedGroup.setValue(Int32(existingSubgroups.count), forKey: "sortOrder")
                
                try viewContext.save()
            } catch {
                print("❌ Failed to move group to new parent: \(error)")
                // Refresh the context to avoid corrupt state
                viewContext.refresh(droppedGroup, mergeChanges: false)
                viewContext.refresh(newParent, mergeChanges: false)
            }
        }
    }
}

struct GroupRowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var group: Group
    @ObservedObject var appState: AppState
    let level: Int
    let moveGroupUp: (Group) -> Void
    let moveGroupDown: (Group) -> Void
    let indentGroup: (Group) -> Void
    let outdentGroup: (Group) -> Void
    let moveGroupToParent: (Group, Group) -> Void
    let reorderSubgroups: (Group, Group, Group) -> Void
    
    @State private var isExpanded = true
    @State private var isEditing = false
    @State private var editingName = ""
    @State private var isHovering = false
    @State private var isDraggedOver = false
    @State private var showingIconPicker = false
    @State private var showingSubgroupDialog = false
    @State private var newSubgroupName = ""
    @State private var newSubgroupIcon = "folder"
    @State private var isPerformingOperation = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var groupIcon: String {
        if let groupId = group.id?.uuidString {
            return UserDefaults.standard.string(forKey: "group_icon_\(groupId)") ?? "folder"
        }
        return "folder"
    }
    
    private func setGroupIcon(_ icon: String) {
        if let groupId = group.id?.uuidString {
            UserDefaults.standard.set(icon, forKey: "group_icon_\(groupId)")
        }
    }
    
    private let availableIcons = [
        "folder", "folder.fill", "doc.text", "book", "book.fill", "briefcase", "briefcase.fill",
        "heart", "heart.fill", "star", "star.fill", "flag", "flag.fill", "tag", "tag.fill",
        "bookmark", "bookmark.fill", "gear", "paperplane", "paperplane.fill", "house", "house.fill",
        "person", "person.fill", "globe", "globe.americas", "camera", "camera.fill", "photo", "photo.fill"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group Row - Ulysses style
            HStack(spacing: UlyssesDesign.Spacing.xs) {
                // Indentation
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(level) * UlyssesDesign.Spacing.lg)
                
                // Folder Icon & Expansion
                HStack(spacing: UlyssesDesign.Spacing.xs) {
                    if hasSubgroups {
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
                    
                    // Folder Icon
                    Image(systemName: groupIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(
                            appState.selectedGroup == group 
                                ? UlyssesDesign.Colors.accent 
                                : UlyssesDesign.Colors.secondary(for: colorScheme)
                        )
                }
                
                // Group Name
                if isEditing {
                    TextField("Group Name", text: $editingName, onCommit: finishEditing)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(UlyssesDesign.Typography.groupName)
                        .focused($isTextFieldFocused)
                        .onAppear { 
                            editingName = group.name ?? ""
                        }
                } else {
                    Text(group.name ?? "Untitled")
                        .font(UlyssesDesign.Typography.groupName)
                        .foregroundColor(
                            appState.selectedGroup == group 
                                ? UlyssesDesign.Colors.accent 
                                : UlyssesDesign.Colors.primary(for: colorScheme)
                        )
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Sheet Count (non-trashed only)
                if let sheets = group.sheets?.allObjects as? [Sheet] {
                    let nonTrashedCount = sheets.filter { !$0.isInTrash }.count
                    if nonTrashedCount > 0 {
                        let countColor = UlyssesDesign.Colors.tertiary(for: colorScheme)
                        Text("\(nonTrashedCount)")
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
            }
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
            .padding(.vertical, UlyssesDesign.Spacing.sm)
            .background(backgroundColorForGroup)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                HapticService.shared.itemSelected()
                appState.selectedGroup = group
                appState.selectedSheet = nil
            }
            .onLongPressGesture {
                startEditing()
            }
            .onDrop(of: [.text], delegate: GroupParentDropDelegate(
                newParentGroup: group,
                moveAction: moveGroupToParent,
                allGroups: Array(viewContext.registeredObjects.compactMap { $0 as? Group })
            ))
            .contextMenu {
                Button("Rename") { startEditing() }
                Button("Change Icon") { showingIconPicker = true }
                Button("Add Subgroup") { showingSubgroupDialog = true }
                Divider()
                Menu("Move") {
                    Button("Move Up") { moveGroupUp(group) }
                        .keyboardShortcut(.upArrow, modifiers: .command)
                    Button("Move Down") { moveGroupDown(group) }
                        .keyboardShortcut(.downArrow, modifiers: .command)
                    Divider()
                    Button("Indent") { indentGroup(group) }
                        .keyboardShortcut("]", modifiers: .command)
                    Button("Outdent") { outdentGroup(group) }
                        .keyboardShortcut("[", modifiers: .command)
                }
                Divider()
                Button("Delete", role: .destructive) { deleteGroup() }
            }
            
            // Subgroups
            if isExpanded, let subgroups = group.subgroups?.sortedArray(using: [NSSortDescriptor(keyPath: \Group.sortOrder, ascending: true)]) as? [Group] {
                ForEach(subgroups, id: \.self) { subgroup in
                    GroupRowView(
                        group: subgroup, 
                        appState: appState, 
                        level: level + 1,
                        moveGroupUp: moveGroupUp,
                        moveGroupDown: moveGroupDown,
                        indentGroup: indentGroup,
                        outdentGroup: outdentGroup,
                        moveGroupToParent: moveGroupToParent,
                        reorderSubgroups: reorderSubgroups
                    )
                        .onDrag {
                            return NSItemProvider(object: subgroup.id?.uuidString as NSString? ?? NSString())
                        }
                        .onDrop(of: [.text], delegate: SubgroupDropDelegate(
                            targetSubgroup: subgroup,
                            parentGroup: group,
                            reorderAction: reorderSubgroups
                        ))
                }
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            NavigationView {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                setGroupIcon(icon)
                                showingIconPicker = false
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(groupIcon == icon ? .accentColor : .primary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(groupIcon == icon ? Color.accentColor.opacity(0.1) : Color.clear)
                                        )
                                    
                                    Text(icon)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .navigationTitle("Choose Icon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showingIconPicker = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSubgroupDialog) {
            NewGroupDialog(
                groupName: $newSubgroupName,
                groupIcon: $newSubgroupIcon,
                isPresented: $showingSubgroupDialog,
                onCreate: createSubgroupWithDetails,
                title: "New Subgroup"
            )
        }
    }
    
    private var hasSubgroups: Bool {
        return group.subgroups?.count ?? 0 > 0
    }
    
    private var backgroundColorForGroup: Color {
        if appState.selectedGroup == group {
            return UlyssesDesign.Colors.selection
        } else if isPerformingOperation {
            return UlyssesDesign.Colors.accent.opacity(0.15)
        } else if isDraggedOver {
            return UlyssesDesign.Colors.accent.opacity(0.2)
        } else if isHovering {
            return UlyssesDesign.Colors.hover
        } else {
            return Color.clear
        }
    }
    
    private func startEditing() {
        isEditing = true
        editingName = group.name ?? ""
        isTextFieldFocused = true
    }
    
    private func finishEditing() {
        let oldName = group.name ?? "Untitled"
        let newName = editingName.isEmpty ? "Untitled" : editingName

        // Only proceed if name actually changed
        guard oldName != newName else {
            isEditing = false
            isTextFieldFocused = false
            return
        }

        group.name = newName
        group.modifiedAt = Date()

        do {
            try viewContext.save()

            // Rename the folder on disk and update file paths
            MarkdownCoreDataSync.shared.renameGroupFolder(
                group: group,
                oldName: oldName,
                newName: newName,
                context: viewContext
            )
        } catch {
            print("Failed to rename group: \(error)")
        }

        isEditing = false
        isTextFieldFocused = false
    }
    
    private func createSubgroupWithDetails() {
        withAnimation {
            let subgroup = Group(context: viewContext)
            subgroup.id = UUID()
            subgroup.name = newSubgroupName.isEmpty ? "New Subgroup" : newSubgroupName
            subgroup.parent = group
            subgroup.createdAt = Date()
            subgroup.modifiedAt = Date()
            subgroup.sortOrder = Int32(group.subgroups?.count ?? 0)
            
            // Set the icon
            if let subgroupId = subgroup.id?.uuidString {
                UserDefaults.standard.set(newSubgroupIcon, forKey: "group_icon_\(subgroupId)")
            }
            
            do {
                try viewContext.save()
                appState.selectedGroup = subgroup

                // Create the actual filesystem folder
                let folderPath = subgroup.folderPath()
                if !MarkdownFileService.shared.createFolder(path: folderPath) {
                    print("⚠️ Failed to create folder: \(folderPath)")
                }

                // Reset dialog state
                newSubgroupName = ""
                newSubgroupIcon = "folder"
            } catch {
                print("Failed to create subgroup: \(error)")
            }
        }
    }
    
    private func deleteGroup() {
        // Get all sheets count for backup description
        let sheetsToTrash = getAllSheetsInGroup(group)
        let groupName = group.name ?? "Untitled"

        // Create safety backup before destructive operation
        Task { @MainActor in
            let backupSuccess = await BackupService.shared.createSafetyBackup(for: "Delete Group '\(groupName)' - \(sheetsToTrash.count) sheets")

            if !backupSuccess {
                Logger.shared.warning("Safety backup failed before deleting group - proceeding anyway", category: .backup)
            }

            withAnimation {
                // Move all sheets to trash
                let fileService = MarkdownFileService.shared
                var movedCount = 0
                for sheet in sheetsToTrash {
                    // Physically move the file to .Trash folder
                    if let fileURLString = sheet.fileURL, !fileURLString.isEmpty {
                        let fileURL = URL(fileURLWithPath: fileURLString)

                        let (success, trashURL) = fileService.moveFileToTrash(at: fileURL)
                        if success, let trashURL = trashURL {
                            // Update fileURL to point to trash location
                            sheet.fileURL = trashURL.path

                            // Update SQLite index with new trash location
                            if let uuid = sheet.id?.uuidString,
                               var metadata = NotesIndexService.shared.getNote(uuid: uuid),
                               let relativePath = fileService.relativePath(for: trashURL) {
                                metadata.path = relativePath
                                _ = NotesIndexService.shared.upsertNote(metadata)
                            }

                            movedCount += 1
                        } else {
                            Logger.shared.warning("Failed to move '\(sheet.title ?? "Untitled")' to trash", category: .fileSystem)
                        }
                    } else {
                        Logger.shared.warning("Sheet '\(sheet.title ?? "Untitled")' has no fileURL", category: .fileSystem)
                    }

                    // Mark sheet as trashed
                    sheet.isInTrash = true
                    sheet.deletedAt = Date()
                    sheet.modifiedAt = Date()
                    // Clear group reference BEFORE deleting the group to prevent cascade deletion
                    sheet.group = nil
                }

                // Delete the group folder from filesystem (including subgroups)
                deleteGroupFolderRecursively(group)

                // Delete the group from CoreData (sheets remain in trash)
                viewContext.delete(group)

                do {
                    try viewContext.save()
                } catch {
                    Logger.shared.error("Failed to delete group", error: error, category: .general, userMessage: "Could not delete group")
                }
            }
        }
    }

    /// Recursively delete the group's folder and all subgroup folders from the filesystem
    private func deleteGroupFolderRecursively(_ group: Group) {
        let fileService = MarkdownFileService.shared
        let folderPath = group.folderPath()
        let folderURL = fileService.getNotesDirectory().appendingPathComponent(folderPath, isDirectory: true)

        // Check if folder exists
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            // Folder already deleted (likely by cleanupEmptyDirectories), which is fine
            return
        }

        // Delete the folder and all its contents
        do {
            try FileManager.default.removeItem(at: folderURL)
            Logger.shared.debug("Deleted group folder: \(folderPath)", category: .fileSystem)
        } catch {
            Logger.shared.error("Failed to delete folder '\(folderPath)'", error: error, category: .fileSystem)
        }
    }

    /// Recursively get all sheets in a group and its subgroups
    private func getAllSheetsInGroup(_ group: Group) -> [Sheet] {
        var allSheets: [Sheet] = []

        // Add direct sheets in this group
        if let sheets = group.sheets as? Set<Sheet> {
            allSheets.append(contentsOf: sheets)
        }

        // Recursively add sheets from subgroups
        if let subgroups = group.subgroups as? Set<Group> {
            for subgroup in subgroups {
                allSheets.append(contentsOf: getAllSheetsInGroup(subgroup))
            }
        }

        return allSheets
    }
    
    
}

#Preview {
    LibrarySidebar(appState: AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 300, height: 600)
}

struct GroupDropDelegate: DropDelegate {
    let targetGroup: Group
    let reorderAction: (Group, Group) -> Void
    let rootGroups: [Group]
    
    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else { return false }
        
        item.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let draggedGroupId = String(data: data, encoding: .utf8),
                  let draggedUUID = UUID(uuidString: draggedGroupId),
                  let draggedGroup = rootGroups.first(where: { $0.id == draggedUUID }) else { return }
            
            DispatchQueue.main.async {
                reorderAction(draggedGroup, targetGroup)
            }
        }
        return true
    }
}

struct SubgroupDropDelegate: DropDelegate {
    let targetSubgroup: Group
    let parentGroup: Group
    let reorderAction: (Group, Group, Group) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else { return false }
        
        item.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let draggedGroupId = String(data: data, encoding: .utf8),
                  let draggedUUID = UUID(uuidString: draggedGroupId),
                  let subgroups = parentGroup.subgroups?.allObjects as? [Group],
                  let draggedGroup = subgroups.first(where: { $0.id == draggedUUID }) else { return }
            
            DispatchQueue.main.async {
                reorderAction(draggedGroup, targetSubgroup, parentGroup)
            }
        }
        return true
    }
}

struct GroupParentDropDelegate: DropDelegate {
    let newParentGroup: Group
    let moveAction: (Group, Group) -> Void
    let allGroups: [Group]
    
    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else { return false }
        
        item.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let draggedGroupId = String(data: data, encoding: .utf8),
                  let draggedUUID = UUID(uuidString: draggedGroupId),
                  let draggedGroup = allGroups.first(where: { $0.id == draggedUUID }),
                  draggedGroup != newParentGroup else { return }
            
            DispatchQueue.main.async {
                moveAction(draggedGroup, newParentGroup)
            }
        }
        return true
    }
}

struct NewGroupDialog: View {
    @Binding var groupName: String
    @Binding var groupIcon: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void
    var title: String = "New Group"
    
    @FocusState private var isTextFieldFocused: Bool
    
    private let availableIcons = [
        "folder", "folder.fill", "doc.text", "book", "book.fill", "briefcase", "briefcase.fill",
        "heart", "heart.fill", "star", "star.fill", "flag", "flag.fill", "tag", "tag.fill",
        "bookmark", "bookmark.fill", "gear", "paperplane", "paperplane.fill", "house", "house.fill",
        "person", "person.fill", "globe", "globe.americas", "camera", "camera.fill", "photo", "photo.fill"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Group Name")
                        .font(.headline)
                    
                    TextField("Enter group name", text: $groupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Icon")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    groupIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(groupIcon == icon ? .white : .primary)
                                        .frame(width: 48, height: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(groupIcon == icon ? Color.accentColor : Color.gray.opacity(0.1))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .frame(height: 200)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        groupName = ""
                        groupIcon = "folder"
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        onCreate()
                        isPresented = false
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}