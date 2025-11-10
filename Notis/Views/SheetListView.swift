//
//  SheetListView.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI
import CoreData

struct SheetListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var appState: AppState
    @StateObject private var tagService = TagService.shared
    
    @State private var searchText = ""
    @State private var showingRenameAlert = false
    @State private var renameText = ""
    @State private var isEditingOrder = false
    @AppStorage("previewLines") private var previewLines: Int = 2
    
    private var headerTitle: String {
        if tagService.isTagMode && !tagService.selectedTags.isEmpty {
            let tagNames = tagService.selectedTags.map { $0.displayName }
            return tagNames.count == 1 ? "#\(tagNames.first!)" : "Tags (\(tagNames.count))"
        } else if let selectedGroup = appState.selectedGroup {
            return selectedGroup.name ?? "Untitled"
        } else if let selectedEssential = appState.selectedEssential {
            switch selectedEssential {
            case "all": return "All"
            case "recent": return "Last 7 Days"
            case "trash": return "Trash"
            case "inbox": return "Inbox"
            case "projects": return "My Projects"
            case "open": return "Open Files"
            default: return "All Sheets"
            }
        } else {
            return "All Sheets"
        }
    }
    
    private var sortDescriptors: [NSSortDescriptor] {
        let ascending = appState.sheetSortAscending
        
        let descriptors: [NSSortDescriptor]
        switch appState.sheetSortOption {
        case .manual:
            // Use sortOrder as primary, and createdAt as secondary to ensure stable sorting
            descriptors = [
                NSSortDescriptor(keyPath: \Sheet.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \Sheet.createdAt, ascending: true)
            ]
        case .alphabetical:
            descriptors = [NSSortDescriptor(keyPath: \Sheet.title, ascending: ascending)]
        case .creationDate:
            descriptors = [NSSortDescriptor(keyPath: \Sheet.createdAt, ascending: ascending)]
        case .modificationDate:
            descriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: ascending)]
        }
        
        return descriptors
    }
    
    var fetchRequest: FetchRequest<Sheet> {
        let predicate: NSPredicate?
        
        if let selectedGroup = appState.selectedGroup {
            // Show sheets from specific group (but not from subgroups)
            predicate = NSPredicate(format: "group == %@ AND isInTrash == NO", selectedGroup)
        } else if let selectedEssential = appState.selectedEssential {
            switch selectedEssential {
            case "all":
                predicate = NSPredicate(format: "isInTrash == NO")
            case "recent":
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                predicate = NSPredicate(format: "modifiedAt >= %@ AND isInTrash == NO", sevenDaysAgo as NSDate)
            case "trash":
                predicate = NSPredicate(format: "isInTrash == YES")
            case "open":
                // Show files modified in the last day
                let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                predicate = NSPredicate(format: "modifiedAt >= %@ AND isInTrash == NO", oneDayAgo as NSDate)
            case "inbox":
                // Show sheets from Inbox group
                predicate = NSPredicate(format: "group.name == %@ AND isInTrash == NO", "Inbox")
            case "projects":
                // Show sheets from all groups except Inbox
                predicate = NSPredicate(format: "group.name != %@ AND isInTrash == NO", "Inbox")
            default:
                predicate = NSPredicate(format: "isInTrash == NO")
            }
        } else {
            // Default: show all non-trashed sheets
            predicate = NSPredicate(format: "isInTrash == NO")
        }
        
        return FetchRequest<Sheet>(
            sortDescriptors: sortDescriptors,
            predicate: predicate,
            animation: .default
        )
    }
    
    // For tag-based filtering, we need to handle it differently since Core Data 
    // doesn't support complex many-to-many queries easily
    private var tagFilteredSheets: [Sheet] {
        if tagService.isTagMode && !tagService.selectedTags.isEmpty {
            return tagService.getFilteredSheets(tags: tagService.selectedTags, operation: .and)
        }
        return []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    Text(headerTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Options Menu
                    Menu {
                        Menu("Preview Lines") {
                            ForEach([1, 2, 3, 4], id: \.self) { lines in
                                Button {
                                    previewLines = lines
                                } label: {
                                    HStack {
                                        Text("\(lines) line\(lines == 1 ? "" : "s")")
                                        Spacer()
                                        if previewLines == lines {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Menu("Sort by") {
                            ForEach(AppState.SheetSortOption.allCases, id: \.self) { option in
                                Button {
                                    print("🔄 Sort option tapped: \(option.rawValue), current: \(appState.sheetSortOption.rawValue)")
                                    if appState.sheetSortOption == option {
                                        appState.sheetSortAscending.toggle()
                                        print("🔄 Toggled sort direction: \(appState.sheetSortAscending)")
                                    } else {
                                        appState.sheetSortOption = option
                                        appState.sheetSortAscending = (option == .alphabetical)
                                        print("🔄 Changed sort to: \(option.rawValue), ascending: \(appState.sheetSortAscending)")
                                        
                                        // Repair sort order when switching to manual mode
                                        if option == .manual {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                repairSortOrderIfNeeded()
                                            }
                                        }
                                    }
                                } label: {
                                    let isSelected = appState.storedSortOption == option.rawValue
                                    let sortIndicator = if isSelected {
                                        if option == .manual {
                                            " ✓"
                                        } else {
                                            appState.sheetSortAscending ? " ✓ ↑" : " ✓ ↓"
                                        }
                                    } else {
                                        ""
                                    }
                                    
                                    Label {
                                        Text(option.rawValue + sortIndicator)
                                    } icon: {
                                        Image(systemName: option.systemImage)
                                    }
                                }
                            }
                        }
                        
                        if appState.selectedGroup != nil {
                            Divider()
                            Button("Rename") {
                                if let group = appState.selectedGroup {
                                    renameText = group.name ?? ""
                                    showingRenameAlert = true
                                }
                            }
                            
                            if appState.sheetSortOption == .manual {
                                Button("🔧 Repair Sort Order") {
                                    repairSortOrderIfNeeded()
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 21, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .menuStyle(BorderlessButtonMenuStyle())
                    
                    // Edit Order Button (for manual sorting)
                    if appState.sheetSortOption == .manual {
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditingOrder.toggle()
                            }
                        }) {
                            Image(systemName: isEditingOrder ? "checkmark" : "line.3.horizontal")
                                .font(.system(size: 21, weight: .medium))
                                .foregroundColor(isEditingOrder ? .green : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(isEditingOrder ? "Done Editing" : "Edit Sheet Order")
                    }
                    
                    Button(action: createNewSheet) {
                        Image(systemName: "plus")
                            .font(.system(size: 21, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    TextField("Search sheets...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray4))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(Color.clear)
            
            // Sheets List
            if tagService.isTagMode && !tagService.selectedTags.isEmpty {
                // Tag-filtered sheets
                TagFilteredSheetsContent(
                    sheets: tagFilteredSheets,
                    appState: appState,
                    searchText: searchText,
                    previewLines: previewLines,
                    isEditingOrder: isEditingOrder
                )
            } else {
                // Regular fetch request sheets
                SheetsListContent(
                    fetchRequest: fetchRequest,
                    appState: appState,
                    searchText: searchText,
                    previewLines: previewLines,
                    isEditingOrder: isEditingOrder
                )
            }
        }
        .onAppear {
            // Repair sort order if in manual mode
            if appState.sheetSortOption == .manual {
                repairSortOrderIfNeeded()
            }
        }
        .alert("Rename Group", isPresented: $showingRenameAlert) {
            TextField("Group Name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                if let group = appState.selectedGroup {
                    group.name = renameText.isEmpty ? "Untitled" : renameText
                    group.modifiedAt = Date()
                    
                    do {
                        try viewContext.save()
                    } catch {
                        print("Failed to rename group: \(error)")
                    }
                }
            }
        }
    }
    
    private func createNewSheet() {
        withAnimation {
            // Get or create a default group for new sheets
            let targetGroup: Group
            
            if let selectedGroup = appState.selectedGroup {
                targetGroup = selectedGroup
            } else {
                // Create or find default "Inbox" group
                let fetchRequest: NSFetchRequest<Group> = Group.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@ AND parent == nil", "Inbox")
                
                if let existingInbox = try? viewContext.fetch(fetchRequest).first {
                    targetGroup = existingInbox
                } else {
                    // Create new Inbox group
                    let inboxGroup = Group(context: viewContext)
                    inboxGroup.id = UUID()
                    inboxGroup.name = "Inbox"
                    inboxGroup.createdAt = Date()
                    inboxGroup.modifiedAt = Date()
                    inboxGroup.sortOrder = 0
                    targetGroup = inboxGroup
                }
            }
            
            let newSheet = Sheet(context: viewContext)
            newSheet.id = UUID()
            newSheet.title = "Untitled"
            // Don't set content - will use file storage
            newSheet.preview = ""
            newSheet.group = targetGroup
            newSheet.createdAt = Date()
            newSheet.modifiedAt = Date()
            newSheet.isInTrash = false
            newSheet.wordCount = 0
            newSheet.goalCount = 0
            newSheet.goalType = "words"
            newSheet.sortOrder = Int32(targetGroup.sheets?.count ?? 0)

            // Initialize file storage for new sheet
            newSheet.initializeFileStorage()

            do {
                try viewContext.save()
                // Select the new sheet and clear any essential selection
                appState.selectSheet(newSheet)
                appState.selectedEssential = nil
                // Also select the target group so user can see the new sheet
                appState.selectedGroup = targetGroup
            } catch {
                print("Failed to create sheet: \(error)")
            }
        }
    }
    
    private func repairSortOrderIfNeeded() {
        guard let selectedGroup = appState.selectedGroup else { return }
        
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "group == %@ AND isInTrash == NO", selectedGroup)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.sortOrder, ascending: true)]
        
        guard let sheets = try? viewContext.fetch(fetchRequest) else { return }
        
        // Check if sort orders are sequential and unique
        var needsRepair = false
        var sortOrders = Set<Int32>()
        
        for sheet in sheets {
            if sortOrders.contains(sheet.sortOrder) {
                needsRepair = true
                break
            }
            sortOrders.insert(sheet.sortOrder)
        }
        
        // Also check if they're not sequential (0, 1, 2, 3...)
        if !needsRepair {
            for (index, sheet) in sheets.enumerated() {
                if sheet.sortOrder != Int32(index) {
                    needsRepair = true
                    break
                }
            }
        }
        
        if needsRepair {
            withAnimation {
                for (index, sheet) in sheets.enumerated() {
                    sheet.sortOrder = Int32(index)
                }
                
                do {
                    try viewContext.save()
                } catch {
                    print("Failed to repair sort order: \(error)")
                }
            }
        }
    }
}

struct SheetsListContent: View {
    @Environment(\.managedObjectContext) private var viewContext
    let fetchRequest: FetchRequest<Sheet>
    @ObservedObject var appState: AppState
    let searchText: String
    let previewLines: Int
    let isEditingOrder: Bool
    
    var subgroups: [Group] {
        guard let selectedGroup = appState.selectedGroup,
              let subgroups = selectedGroup.subgroups?.allObjects as? [Group] else {
            return []
        }
        return subgroups.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var filteredSheets: [Sheet] {
        let sheets = Array(fetchRequest.wrappedValue)
        
        if searchText.isEmpty {
            return sheets
        }
        return sheets.filter { sheet in
            (sheet.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (sheet.content?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Show subgroups first (if any)
                ForEach(subgroups, id: \.self) { subgroup in
                    SubgroupRowView(subgroup: subgroup, appState: appState)
                }
                
                // Add separator if we have both subgroups and sheets
                if !subgroups.isEmpty && !filteredSheets.isEmpty {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 0.5)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                
                // Then show direct sheets
                ForEach(filteredSheets, id: \.self) { sheet in
                    SheetRowView(
                        sheet: sheet, 
                        appState: appState, 
                        previewLines: previewLines,
                        isEditingOrder: isEditingOrder
                    )
                    .onDrop(of: [.text], delegate: SheetDropDelegate(
                        targetSheet: sheet,
                        appState: appState,
                        reorderAction: reorderSheets,
                        isEditingOrder: isEditingOrder
                    ))
                }
            }
            .padding(.top, 8)
        }
        .background(
            // Subtle background change when in edit mode
            isEditingOrder ? Color.accentColor.opacity(0.02) : Color.clear
        )
    }
    
    private func reorderSheets(draggedSheet: Sheet, targetSheet: Sheet) {
        guard appState.sheetSortOption == .manual,
              let selectedGroup = appState.selectedGroup else { return }
        
        withAnimation {
            // Get all sheets in the current group
            let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "group == %@ AND isInTrash == NO", selectedGroup)
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.sortOrder, ascending: true)]
            
            guard let sheets = try? viewContext.fetch(fetchRequest) else { return }
            
            guard let draggedIndex = sheets.firstIndex(of: draggedSheet),
                  let targetIndex = sheets.firstIndex(of: targetSheet) else { return }
            
            if draggedIndex == targetIndex { return }
            
            // Reorder the sheets array
            var reorderedSheets = sheets
            reorderedSheets.remove(at: draggedIndex)
            reorderedSheets.insert(draggedSheet, at: draggedIndex < targetIndex ? targetIndex - 1 : targetIndex)
            
            // Update sort orders (don't update modifiedAt for manual reordering)
            for (index, sheet) in reorderedSheets.enumerated() {
                sheet.sortOrder = Int32(index)
            }
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to reorder sheets: \(error)")
            }
        }
    }
}

struct SubgroupRowView: View {
    @ObservedObject var subgroup: Group
    @ObservedObject var appState: AppState
    
    private var groupIcon: String {
        if let groupId = subgroup.id?.uuidString {
            return UserDefaults.standard.string(forKey: "group_icon_\(groupId)") ?? "folder"
        }
        return "folder"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Folder Icon
            Image(systemName: groupIcon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                // Group Name
                Text(subgroup.name ?? "Untitled")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Sheet Count
                if let sheetsCount = subgroup.sheets?.count, sheetsCount > 0 {
                    Text("\(sheetsCount) sheet\(sheetsCount == 1 ? "" : "s")")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    Text("Empty folder")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.clear)
        )
        .onTapGesture {
            // Select the subgroup
            appState.selectedGroup = subgroup
            appState.selectedSheet = nil
        }
        .contextMenu {
            Button("Rename") {
                // TODO: Add rename functionality
            }
            Button("Delete", role: .destructive) {
                // TODO: Add delete functionality
            }
        }
    }
}

struct SheetRowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var sheet: Sheet
    @ObservedObject var appState: AppState
    let previewLines: Int
    let isEditingOrder: Bool
    
    @State private var isEditing = false
    @State private var editingTitle = ""
    @State private var showingMoveDialog = false
    @State private var isDraggedOver = false
    @State private var isDragging = false
    @State private var isHoveringDragHandle = false
    @State private var showingLongPressMenu = false
    
    private var shouldShowGroupLocation: Bool {
        return appState.selectedEssential == "all" || appState.selectedEssential == "recent"
    }
    
    private func groupIcon(for group: Group) -> String {
        if let groupId = group.id?.uuidString {
            return UserDefaults.standard.string(forKey: "group_icon_\(groupId)") ?? "folder"
        }
        return "folder"
    }
    
    private func groupPath(for group: Group) -> String {
        var pathComponents: [String] = []
        var currentGroup: Group? = group
        
        while let group = currentGroup {
            pathComponents.insert(group.name ?? "Unknown", at: 0)
            currentGroup = group.parent
        }
        
        return pathComponents.joined(separator: " > ")
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: Date())?.contains(date) == true {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Drag Handle (only visible in edit mode)
                if isEditingOrder {
                    VStack {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isHoveringDragHandle ? .accentColor : .secondary)
                            .padding(.top, 4)
                    }
                    .frame(width: 20, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHoveringDragHandle ? Color.accentColor.opacity(0.1) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHoveringDragHandle = hovering
                        }
                    }
                    .onDrag {
                        print("🔄 Dragging sheet: \(sheet.title ?? "Untitled")")
                        isDragging = true
                        return NSItemProvider(object: sheet.id?.uuidString as NSString? ?? NSString())
                    }
                    .onChange(of: isDragging) { _, newValue in
                        if !newValue {
                            // Reset drag state after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isDragging = false
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    if isEditing {
                        TextField("Sheet Title", text: $editingTitle, onCommit: finishEditing)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .medium))
                            .onAppear { editingTitle = sheet.title ?? "" }
                    } else {
                        Text(sheet.title?.isEmpty == false ? sheet.title! : "Untitled")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(appState.selectedSheet == sheet ? .accentColor : .primary)
                            .lineLimit(1)
                    }
                    
                    // Preview
                    if let preview = sheet.preview, !preview.isEmpty {
                        Text(preview)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(previewLines)
                    }
                    
                    // Stats
                    HStack(spacing: 12) {
                        Label("\(sheet.wordCount)", systemImage: "doc.text")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(sheet.modifiedAt))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        if sheet.goalCount > 0 {
                            Label("\(sheet.goalCount) \(sheet.goalType ?? "words")", systemImage: "target")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        // Group Location (for All/Recent views)
                        if shouldShowGroupLocation, let group = sheet.group {
                            HStack(spacing: 4) {
                                Image(systemName: groupIcon(for: group))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(groupPath(for: group))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        if sheet.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                Spacer()
                
                // Goal Progress Ring
                if sheet.goalCount > 0 {
                    GoalProgressRing(
                        progress: min(1.0, Double(sheet.wordCount) / Double(sheet.goalCount)),
                        size: 24
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(
                        isDraggedOver && isEditingOrder ? Color.accentColor.opacity(0.3) :
                        appState.selectedSheet == sheet ? Color.accentColor.opacity(0.1) : Color.clear
                    )
            )
            .onTapGesture {
                if !isEditingOrder {
                    appState.selectSheet(sheet)
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                if !isEditingOrder {
                    HapticService.shared.impact(.medium)
                    showLongPressMenu()
                }
            }
            .contextMenu {
                if !isEditingOrder {
                    Button("Open in Secondary Editor") {
                        appState.openSecondaryEditor(with: sheet)
                    }
                    Button("Duplicate") { duplicateSheet() }
                    Divider()
                    Button("Rename") { startEditing() }
                    Button(sheet.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                        toggleFavorite()
                    }
                    Button("Move") { showingMoveDialog = true }
                    Divider()
                    if sheet.isInTrash {
                        Button("Restore") { restoreFromTrash() }
                        Button("Delete Permanently", role: .destructive) { deleteSheetPermanently() }
                    } else {
                        Button("Move to Trash", role: .destructive) { moveToTrash() }
                    }
                }
            }
            
            // Divider
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5)
                .padding(.leading, 16)
        }
        .sheet(isPresented: $showingMoveDialog) {
            MoveSheetDialog(
                sheet: sheet,
                isPresented: $showingMoveDialog,
                appState: appState
            )
        }
        .confirmationDialog("Sheet Actions", isPresented: $showingLongPressMenu, titleVisibility: .visible) {
            Button("Open in Secondary Editor") {
                appState.openSecondaryEditor(with: sheet)
            }
            Button("Duplicate") {
                duplicateSheet()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose an action for '\(sheet.title ?? "Untitled")'")
        }
    }
    
    private func showLongPressMenu() {
        showingLongPressMenu = true
    }
    
    private func startEditing() {
        isEditing = true
        editingTitle = sheet.title ?? ""
    }
    
    private func finishEditing() {
        let newTitle = editingTitle.isEmpty ? "Untitled" : editingTitle
        let hasChanged = sheet.title != newTitle
        
        sheet.title = newTitle
        
        if hasChanged {
            sheet.modifiedAt = Date()
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to rename sheet: \(error)")
        }
        
        isEditing = false
    }
    
    private func toggleFavorite() {
        sheet.isFavorite.toggle()
        sheet.modifiedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }
    
    private func duplicateSheet() {
        withAnimation {
            let newSheet = Sheet(context: viewContext)
            newSheet.id = UUID()

            // Generate a unique copy name
            let baseName = sheet.title ?? "Untitled"
            newSheet.title = generateCopyName(baseName)

            // Copy content using hybrid accessor and initialize file storage
            let contentToCopy = sheet.hybridContent
            newSheet.initializeFileStorage()
            newSheet.hybridContent = contentToCopy

            newSheet.preview = sheet.preview
            newSheet.group = sheet.group // Ensures duplicate is in same folder
            newSheet.createdAt = Date()
            newSheet.modifiedAt = Date()
            newSheet.isInTrash = false
            newSheet.isFavorite = false // Don't copy favorite status
            newSheet.wordCount = sheet.wordCount
            newSheet.goalCount = sheet.goalCount
            newSheet.goalType = sheet.goalType

            // Set sort order to appear after the original sheet
            newSheet.sortOrder = sheet.sortOrder + 1
            
            // Update sort orders of sheets that come after
            if let group = sheet.group,
               let sheets = group.sheets?.allObjects as? [Sheet] {
                let sheetsToUpdate = sheets.filter { $0.sortOrder > sheet.sortOrder }
                for sheetToUpdate in sheetsToUpdate {
                    sheetToUpdate.sortOrder += 1
                }
            }
            
            do {
                try viewContext.save()
                HapticService.shared.actionCompleted()
                
                // Select the new duplicate
                appState.selectSheet(newSheet)
            } catch {
                print("Failed to duplicate sheet: \(error)")
                HapticService.shared.actionFailed()
            }
        }
    }
    
    private func generateCopyName(_ baseName: String) -> String {
        guard let group = sheet.group,
              let sheets = group.sheets?.allObjects as? [Sheet] else {
            return "\(baseName) Copy"
        }
        
        let existingTitles = Set(sheets.compactMap { $0.title })
        
        // Try "Copy" first
        let copyName = "\(baseName) Copy"
        if !existingTitles.contains(copyName) {
            return copyName
        }
        
        // Try "Copy 2", "Copy 3", etc.
        var counter = 2
        while true {
            let numberedCopyName = "\(baseName) Copy \(counter)"
            if !existingTitles.contains(numberedCopyName) {
                return numberedCopyName
            }
            counter += 1
        }
    }
    
    private func moveToTrash() {
        withAnimation {
            sheet.isInTrash = true
            sheet.deletedAt = Date()
            sheet.modifiedAt = Date()
            
            if appState.selectedSheet == sheet {
                appState.selectedSheet = nil
            }
            appState.clearLastOpenedSheetIfNeeded(sheet)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to move sheet to trash: \(error)")
            }
        }
    }
    
    private func restoreFromTrash() {
        withAnimation {
            sheet.isInTrash = false
            sheet.deletedAt = nil
            sheet.modifiedAt = Date()
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to restore sheet from trash: \(error)")
            }
        }
    }
    
    private func deleteSheetPermanently() {
        withAnimation {
            if appState.selectedSheet == sheet {
                appState.selectedSheet = nil
            }
            appState.clearLastOpenedSheetIfNeeded(sheet)
            viewContext.delete(sheet)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to permanently delete sheet: \(error)")
            }
        }
    }
}

struct GoalProgressRing: View {
    let progress: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

struct SheetDropDelegate: DropDelegate {
    let targetSheet: Sheet
    let appState: AppState
    let reorderAction: (Sheet, Sheet) -> Void
    let isEditingOrder: Bool
    
    func performDrop(info: DropInfo) -> Bool {
        print("🎯 Drop attempted on sheet: \(targetSheet.title ?? "Untitled")")
        guard appState.sheetSortOption == .manual,
              isEditingOrder,
              let item = info.itemProviders(for: [.text]).first else { 
            print("❌ Drop failed - conditions not met")
            return false 
        }
        
        print("✅ Drop conditions met, processing...")
        item.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let draggedSheetId = String(data: data, encoding: .utf8),
                  let draggedUUID = UUID(uuidString: draggedSheetId) else { 
                print("❌ Failed to decode dragged sheet ID")
                return 
            }
            
            print("🔍 Looking for dragged sheet with ID: \(draggedSheetId)")
            // Find the dragged sheet - we need to search through Core Data
            DispatchQueue.main.async {
                // We'll rely on the reorderAction to handle finding the sheet
                // by using a placeholder sheet with the correct ID
                if let draggedSheet = findSheetWithId(draggedUUID) {
                    print("✅ Found dragged sheet: \(draggedSheet.title ?? "Untitled"), reordering...")
                    reorderAction(draggedSheet, targetSheet)
                } else {
                    print("❌ Could not find dragged sheet with ID: \(draggedSheetId)")
                }
            }
        }
        return true
    }
    
    func dropEntered(info: DropInfo) {
        if isEditingOrder && appState.sheetSortOption == .manual {
            // Visual feedback when drag enters
        }
    }
    
    func dropExited(info: DropInfo) {
        if isEditingOrder && appState.sheetSortOption == .manual {
            // Visual feedback when drag exits
        }
    }
    
    private func findSheetWithId(_ id: UUID) -> Sheet? {
        // This is a simplified approach - in a real implementation you'd want
        // to pass the sheets array or use a more efficient lookup
        return targetSheet.managedObjectContext?.registeredObjects
            .compactMap { $0 as? Sheet }
            .first { $0.id == id }
    }
}

struct MoveSheetDialog: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var sheet: Sheet
    @Binding var isPresented: Bool
    @ObservedObject var appState: AppState
    
    @State private var selectedGroup: Group?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.name, ascending: true)],
        predicate: NSPredicate(format: "parent == nil"),
        animation: .default
    )
    private var rootGroups: FetchedResults<Group>
    
    private func getAllGroups() -> [Group] {
        var allGroups: [Group] = []
        
        func addGroupAndSubgroups(_ group: Group, level: Int = 0) {
            allGroups.append(group)
            if let subgroups = group.subgroups?.allObjects as? [Group] {
                let sortedSubgroups = subgroups.sorted { $0.sortOrder < $1.sortOrder }
                for subgroup in sortedSubgroups {
                    addGroupAndSubgroups(subgroup, level: level + 1)
                }
            }
        }
        
        for rootGroup in rootGroups {
            addGroupAndSubgroups(rootGroup)
        }
        
        return allGroups
    }
    
    private func groupIcon(for group: Group) -> String {
        if let groupId = group.id?.uuidString {
            return UserDefaults.standard.string(forKey: "group_icon_\(groupId)") ?? "folder"
        }
        return "folder"
    }
    
    private func indentationLevel(for group: Group) -> Int {
        var level = 0
        var currentGroup = group
        while let parent = currentGroup.parent {
            level += 1
            currentGroup = parent
        }
        return level
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current location info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Location")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: groupIcon(for: sheet.group!))
                            .foregroundColor(.accentColor)
                        Text(sheet.group?.name ?? "Unknown")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
                
                Divider()
                
                // Group selection list
                Text("Move to")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(getAllGroups(), id: \.self) { group in
                            GroupSelectionRow(
                                group: group,
                                isSelected: selectedGroup == group,
                                isCurrentLocation: group == sheet.group,
                                indentationLevel: indentationLevel(for: group)
                            ) {
                                selectedGroup = group
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Move") {
                        moveSheet()
                    }
                    .disabled(selectedGroup == nil || selectedGroup == sheet.group)
                }
            }
        }
    }
    
    private func moveSheet() {
        guard let targetGroup = selectedGroup else { return }
        
        withAnimation {
            sheet.group = targetGroup
            sheet.modifiedAt = Date()
            sheet.sortOrder = Int32(targetGroup.sheets?.count ?? 0)
            
            do {
                try viewContext.save()
                appState.selectedGroup = targetGroup
                isPresented = false
            } catch {
                print("Failed to move sheet: \(error)")
            }
        }
    }
}

struct GroupSelectionRow: View {
    let group: Group
    let isSelected: Bool
    let isCurrentLocation: Bool
    let indentationLevel: Int
    let onTap: () -> Void
    
    private func groupIcon() -> String {
        if let groupId = group.id?.uuidString {
            return UserDefaults.standard.string(forKey: "group_icon_\(groupId)") ?? "folder"
        }
        return "folder"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Indentation
            Rectangle()
                .fill(Color.clear)
                .frame(width: CGFloat(indentationLevel) * 20)
            
            // Group icon
            Image(systemName: groupIcon())
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isCurrentLocation ? .secondary : .accentColor)
                .frame(width: 24)
            
            // Group name
            Text(group.name ?? "Untitled")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isCurrentLocation ? .secondary : .primary)
            
            Spacer()
            
            // Current location indicator
            if isCurrentLocation {
                Text("Current")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onTapGesture {
            if !isCurrentLocation {
                onTap()
            }
        }
    }
}

struct TagFilteredSheetsContent: View {
    @Environment(\.managedObjectContext) private var viewContext
    let sheets: [Sheet]
    @ObservedObject var appState: AppState
    let searchText: String
    let previewLines: Int
    let isEditingOrder: Bool
    
    var filteredSheets: [Sheet] {
        if searchText.isEmpty {
            return sheets
        }
        return sheets.filter { sheet in
            (sheet.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (sheet.content?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Show tag filtering info
                if !sheets.isEmpty {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.accentColor)
                        Text("Showing \(filteredSheets.count) sheet\(filteredSheets.count == 1 ? "" : "s") with selected tags")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.05))
                }
                
                // Show sheets
                ForEach(filteredSheets, id: \.self) { sheet in
                    SheetRowView(
                        sheet: sheet, 
                        appState: appState, 
                        previewLines: previewLines,
                        isEditingOrder: false // No reordering in tag mode
                    )
                    .contextMenu {
                        Button("Open") {
                            appState.selectSheet(sheet)
                        }
                        
                        Button("Copy Title") {
                            UIPasteboard.general.string = sheet.title ?? "Untitled"
                        }
                        
                        Divider()
                        
                        Button("Move to Trash", role: .destructive) {
                            withAnimation {
                                sheet.isInTrash = true
                                sheet.modifiedAt = Date()
                                
                                // Clear selection if this sheet was selected
                                if appState.selectedSheet == sheet {
                                    appState.selectedSheet = nil
                                }
                                
                                do {
                                    try viewContext.save()
                                } catch {
                                    print("Failed to move sheet to trash: \(error)")
                                }
                            }
                        }
                    }
                }
                
                // Empty state for tag filtering
                if filteredSheets.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No sheets found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("No sheets match '\(searchText)' in the selected tags")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else if sheets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tag")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No sheets with these tags")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Create a new sheet and add tags to see it here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                }
            }
        }
    }
}

#Preview {
    SheetListView(appState: AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 400, height: 600)
}