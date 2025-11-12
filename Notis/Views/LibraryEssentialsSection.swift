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

    @State private var showingEmptyTrashConfirmation = false

    // Performance optimization: Use cached counts instead of multiple FetchRequests
    @State private var allSheetsCount: Int = 0
    @State private var recentSheetsCount: Int = 0
    @State private var trashedSheetsCount: Int = 0
    @State private var ungroupedSheetsCount: Int = 0

    // Single fetch request for trash operations (only when needed)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Sheet.deletedAt, ascending: false)],
        predicate: NSPredicate(format: "isInTrash == YES"),
        animation: .default
    )
    private var trashedSheets: FetchedResults<Sheet>

    private static var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }



    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Essential Library Items
            LibraryEssentialRow(
                icon: "doc.text",
                title: "All",
                count: allSheetsCount,
                isSelected: appState.selectedEssential == "all" && appState.selectedGroup == nil,
                appState: appState,
                action: { selectAllSheets() }
            )

            LibraryEssentialRow(
                icon: "clock",
                title: "Last 7 Days",
                count: recentSheetsCount,
                isSelected: appState.selectedEssential == "recent" && appState.selectedGroup == nil,
                appState: appState,
                action: { selectRecentSheets() }
            )

            LibraryEssentialRow(
                icon: "tray",
                title: "Inbox",
                count: ungroupedSheetsCount,
                isSelected: appState.selectedEssential == "inbox" && appState.selectedGroup == nil,
                appState: appState,
                action: { selectInbox() }
            )

            LibraryEssentialRow(
                icon: "trash",
                title: "Trash",
                count: trashedSheetsCount,
                isSelected: appState.selectedEssential == "trash" && appState.selectedGroup == nil,
                appState: appState,
                action: { selectTrash() },
                onEmptyTrash: trashedSheetsCount > 0 ? { emptyTrash() } : nil
            )
            
            
        }
        .onReceive(appState.$selectedGroup) { group in
            // Clear essential selection when a regular group is selected
            if group != nil {
                appState.selectedEssential = nil
            }
        }
        .onAppear {
            // Initialize counts on appear
            updateCounts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: viewContext)) { _ in
            // Update counts when Core Data changes (debounced)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                updateCounts()
            }
        }
        .alert("Empty Trash", isPresented: $showingEmptyTrashConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Empty Trash", role: .destructive) {
                permanentlyDeleteAllTrashedSheets()
            }
        } message: {
            Text("Are you sure you want to permanently delete all \(trashedSheetsCount) item\(trashedSheetsCount == 1 ? "" : "s") in the trash? This action cannot be undone.")
        }
    }

    // MARK: - Performance Optimization

    /// Update all counts efficiently using count-only fetch requests
    private func updateCounts() {
        let context = viewContext

        // Execute on background to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            // All sheets count
            let allRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            allRequest.predicate = NSPredicate(format: "isInTrash == NO")
            let newAllCount = (try? context.count(for: allRequest)) ?? 0

            // Recent sheets count (last 7 days)
            let recentRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            recentRequest.predicate = NSPredicate(format: "modifiedAt >= %@ AND isInTrash == NO", sevenDaysAgo as NSDate)
            let newRecentCount = (try? context.count(for: recentRequest)) ?? 0

            // Trashed sheets count
            let trashedRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            trashedRequest.predicate = NSPredicate(format: "isInTrash == YES")
            let newTrashedCount = (try? context.count(for: trashedRequest)) ?? 0

            // Ungrouped sheets count
            let ungroupedRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            ungroupedRequest.predicate = NSPredicate(format: "group == nil AND isInTrash == NO")
            let newUngroupedCount = (try? context.count(for: ungroupedRequest)) ?? 0

            // Update UI on main thread
            DispatchQueue.main.async {
                self.allSheetsCount = newAllCount
                self.recentSheetsCount = newRecentCount
                self.trashedSheetsCount = newTrashedCount
                self.ungroupedSheetsCount = newUngroupedCount
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

    private func selectInbox() {
        appState.selectedEssential = "inbox"
        appState.selectedGroup = nil
        appState.selectedSheet = nil
    }

    private func selectTrash() {
        appState.selectedEssential = "trash"
        appState.selectedGroup = nil
        appState.selectedSheet = nil
    }
    
    private func emptyTrash() {
        showingEmptyTrashConfirmation = true
    }
    
    private func permanentlyDeleteAllTrashedSheets() {
        withAnimation {
            // Clear the selected sheet if it's in trash
            if let selectedSheet = appState.selectedSheet, selectedSheet.isInTrash {
                appState.selectedSheet = nil
            }

            let fileService = MarkdownFileService.shared

            // Delete all trashed sheets
            for sheet in trashedSheets {
                let sheetTitle = sheet.title ?? "Untitled"

                // Physically delete the file from trash
                if let fileURLString = sheet.fileURL, !fileURLString.isEmpty {
                    let fileURL = URL(fileURLWithPath: fileURLString)

                    print("🗑️ Emptying trash for '\(sheetTitle)': \(fileURL.path)")

                    // Check if file is in trash
                    if fileURL.path.contains(".Trash") {
                        let success = fileService.permanentlyDeleteFromTrash(at: fileURL)
                        if success {
                            print("✓ Permanently deleted from .Trash: \(fileURL.lastPathComponent)")
                        } else {
                            print("⚠️ Failed to delete from .Trash: \(fileURL.lastPathComponent)")
                        }
                    } else {
                        // File is not in trash, delete from regular location
                        print("⚠️ fileURL not in .Trash, deleting from: \(fileURL.path)")
                        let success = fileService.deleteFile(at: fileURL)
                        if success {
                            print("✓ Deleted file from non-trash location: \(fileURL.lastPathComponent)")
                        } else {
                            print("⚠️ Failed to delete file: \(fileURL.lastPathComponent)")
                        }
                    }
                } else {
                    print("⚠️ No fileURL for trashed sheet: \(sheetTitle)")
                }

                viewContext.delete(sheet)
            }

            do {
                try viewContext.save()
                HapticService.shared.itemDeleted()
                // Update counts after emptying trash
                updateCounts()
            } catch {
                Logger.shared.error("Failed to empty trash", error: error, category: .general, userMessage: "Could not empty trash")
            }
        }
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
    let onEmptyTrash: (() -> Void)?
    
    @State private var isHovering = false
    
    init(icon: String, title: String, count: Int, isSelected: Bool, appState: AppState, level: Int = 0, action: @escaping () -> Void, onEmptyTrash: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.appState = appState
        self.level = level
        self.action = action
        self.onEmptyTrash = onEmptyTrash
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
        .onLongPressGesture(minimumDuration: 0.5) {
            if let onEmptyTrash = onEmptyTrash {
                HapticService.shared.impact(.heavy)
                onEmptyTrash()
            }
        }
        .contextMenu {
            if let onEmptyTrash = onEmptyTrash {
                Button("Empty Trash", role: .destructive) {
                    onEmptyTrash()
                }
            }
        }
    }
}

#Preview {
    LibraryEssentialsSection(appState: AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 280)
}