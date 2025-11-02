//
//  LibraryEssentialsSection.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI
import CoreData

struct LibraryEssentialsSection: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var appState: AppState
    
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)],
        predicate: NSPredicate(format: "isInTrash == NO"),
        animation: .default
    )
    private var allSheets: FetchedResults<Sheet>
    
    private static var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)],
        predicate: NSPredicate(format: "modifiedAt >= %@ AND isInTrash == NO", sevenDaysAgo as NSDate),
        animation: .default
    )
    private var recentSheets: FetchedResults<Sheet>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Sheet.deletedAt, ascending: false)],
        predicate: NSPredicate(format: "isInTrash == YES"),
        animation: .default
    )
    private var trashedSheets: FetchedResults<Sheet>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Essential Library Items
            LibraryEssentialRow(
                icon: "doc.text",
                title: "All",
                count: allSheets.count,
                isSelected: appState.selectedEssential == "all" && appState.selectedGroup == nil,
                appState: appState,
                action: { selectAllSheets() }
            )
            
            LibraryEssentialRow(
                icon: "clock",
                title: "Last 7 Days",
                count: recentSheets.count,
                isSelected: appState.selectedEssential == "recent" && appState.selectedGroup == nil,
                appState: appState,
                action: { selectRecentSheets() }
            )
            
            LibraryEssentialRow(
                icon: "doc.badge.gearshape",
                title: "Open Files",
                count: 0,
                isSelected: appState.selectedEssential == "open" && appState.selectedGroup == nil,
                appState: appState,
                action: { selectOpenFiles() }
            )
            
            LibraryEssentialRow(
                icon: "trash",
                title: "Trash",
                count: trashedSheets.count,
                isSelected: appState.selectedEssential == "trash" && appState.selectedGroup == nil,
                appState: appState,
                action: { selectTrash() }
            )
            
            // Spacer
            Rectangle()
                .fill(Color.clear)
                .frame(height: UlyssesDesign.Spacing.md)
            
            // Project Group Header
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                
                Text("Projects")
                    .font(UlyssesDesign.Typography.groupName)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Spacer()
            }
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
            .padding(.vertical, UlyssesDesign.Spacing.xs)
            
            // Project Sub-items
            LibraryEssentialRow(
                icon: "tray",
                title: "Inbox",
                count: 0,
                isSelected: appState.selectedEssential == "inbox" && appState.selectedGroup == nil,
                appState: appState,
                level: 1,
                action: { selectInbox() }
            )
            
            LibraryEssentialRow(
                icon: "folder",
                title: "My Projects",
                count: 0,
                isSelected: appState.selectedEssential == "projects" && appState.selectedGroup == nil,
                appState: appState,
                level: 1,
                action: { selectMyProjects() }
            )
        }
        .onReceive(appState.$selectedGroup) { group in
            // Clear essential selection when a regular group is selected
            if group != nil {
                appState.selectedEssential = nil
            }
        }
    }
    
    private func selectAllSheets() {
        appState.selectedEssential = "all"
        appState.selectedGroup = nil
        appState.selectedSheet = nil
    }
    
    private func selectRecentSheets() {
        appState.selectedEssential = "recent"
        appState.selectedGroup = nil
        appState.selectedSheet = nil
    }
    
    private func selectOpenFiles() {
        appState.selectedEssential = "open"
        appState.selectedGroup = nil
        appState.selectedSheet = nil
    }
    
    private func selectTrash() {
        appState.selectedEssential = "trash"
        appState.selectedGroup = nil
        appState.selectedSheet = nil
    }
    
    private func selectInbox() {
        appState.selectedEssential = "inbox"
        appState.selectedGroup = nil
        appState.selectedSheet = nil
    }
    
    private func selectMyProjects() {
        appState.selectedEssential = "projects"
        appState.selectedGroup = nil
        appState.selectedSheet = nil
    }
}

struct LibraryEssentialRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool
    let appState: AppState
    let level: Int
    let action: () -> Void
    
    @State private var isHovering = false
    
    init(icon: String, title: String, count: Int, isSelected: Bool, appState: AppState, level: Int = 0, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.appState = appState
        self.level = level
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: UlyssesDesign.Spacing.xs) {
            // Indentation for sub-items
            Rectangle()
                .fill(Color.clear)
                .frame(width: CGFloat(level) * UlyssesDesign.Spacing.lg)
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(
                    isSelected 
                        ? UlyssesDesign.Colors.accent 
                        : UlyssesDesign.Colors.secondary(for: colorScheme)
                )
                .frame(width: 16)
            
            // Title
            Text(title)
                .font(UlyssesDesign.Typography.groupName)
                .foregroundColor(
                    isSelected 
                        ? UlyssesDesign.Colors.accent 
                        : UlyssesDesign.Colors.primary(for: colorScheme)
                )
                .lineLimit(1)
            
            Spacer()
            
            // Count (if > 0)
            if count > 0 {
                let countColor = UlyssesDesign.Colors.tertiary(for: colorScheme)
                Text("\(count)")
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
        .background(
            Rectangle()
                .fill(
                    isSelected 
                        ? UlyssesDesign.Colors.selection
                        : (isHovering ? UlyssesDesign.Colors.hover : Color.clear)
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            HapticService.shared.itemSelected()
            action()
        }
    }
}

#Preview {
    LibraryEssentialsSection(appState: AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 280)
}