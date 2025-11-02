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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Ulysses style
            HStack(spacing: UlyssesDesign.Spacing.md) {
                Text("Library")
                    .font(UlyssesDesign.Typography.libraryTitle)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Spacer()
                
                Button(action: openCommandPalette) {
                    Image(systemName: "command")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 22, height: 22)
                .background(UlyssesDesign.Colors.hover.opacity(0))
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                .onHover { hovering in
                    // Add hover effect
                }
                .onTapGesture {
                    HapticService.shared.buttonTap()
                }
                
                Button(action: createNewGroup) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 22, height: 22)
                .background(UlyssesDesign.Colors.hover.opacity(0))
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                .onTapGesture {
                    HapticService.shared.buttonTap()
                }
            }
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
            .padding(.vertical, UlyssesDesign.Spacing.lg)
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
                        GroupRowView(group: group, appState: appState, level: 0)
                    }
                }
                .padding(.top, UlyssesDesign.Spacing.sm)
            }
            
            Spacer()
        }
    }
    
    private func openCommandPalette() {
        NotificationCenter.default.post(name: .showCommandPalette, object: nil)
    }
    
    private func createNewGroup() {
        withAnimation {
            let newGroup = Group(context: viewContext)
            newGroup.id = UUID()
            newGroup.name = "New Group"
            newGroup.createdAt = Date()
            newGroup.modifiedAt = Date()
            newGroup.sortOrder = Int32(rootGroups.count)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to create group: \(error)")
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
    
    @State private var isExpanded = true
    @State private var isEditing = false
    @State private var editingName = ""
    @State private var isHovering = false
    
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
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 12, height: 12)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 12)
                    }
                    
                    // Folder Icon
                    Image(systemName: hasSubgroups ? (isExpanded ? "folder.fill" : "folder") : "folder")
                        .font(.system(size: 11, weight: .medium))
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
                        .onAppear { editingName = group.name ?? "" }
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
                
                // Sheet Count
                if let sheetsCount = group.sheets?.count, sheetsCount > 0 {
                    let countColor = UlyssesDesign.Colors.tertiary(for: colorScheme)
                    Text("\(sheetsCount)")
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
            .contextMenu {
                Button("Rename") { startEditing() }
                Button("Add Subgroup") { createSubgroup() }
                Divider()
                Button("Delete", role: .destructive) { deleteGroup() }
            }
            
            // Subgroups
            if isExpanded, let subgroups = group.subgroups?.sortedArray(using: [NSSortDescriptor(keyPath: \Group.sortOrder, ascending: true)]) as? [Group] {
                ForEach(subgroups, id: \.self) { subgroup in
                    GroupRowView(group: subgroup, appState: appState, level: level + 1)
                }
            }
        }
    }
    
    private var hasSubgroups: Bool {
        return group.subgroups?.count ?? 0 > 0
    }
    
    private var backgroundColorForGroup: Color {
        if appState.selectedGroup == group {
            return UlyssesDesign.Colors.selection
        } else if isHovering {
            return UlyssesDesign.Colors.hover
        } else {
            return Color.clear
        }
    }
    
    private func startEditing() {
        isEditing = true
        editingName = group.name ?? ""
    }
    
    private func finishEditing() {
        group.name = editingName.isEmpty ? "Untitled" : editingName
        group.modifiedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to rename group: \(error)")
        }
        
        isEditing = false
    }
    
    private func createSubgroup() {
        withAnimation {
            let subgroup = Group(context: viewContext)
            subgroup.id = UUID()
            subgroup.name = "New Subgroup"
            subgroup.parent = group
            subgroup.createdAt = Date()
            subgroup.modifiedAt = Date()
            subgroup.sortOrder = Int32(group.subgroups?.count ?? 0)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to create subgroup: \(error)")
            }
        }
    }
    
    private func deleteGroup() {
        withAnimation {
            viewContext.delete(group)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to delete group: \(error)")
            }
        }
    }
}

#Preview {
    LibrarySidebar(appState: AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 300, height: 600)
}