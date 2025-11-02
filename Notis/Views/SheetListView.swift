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
    
    @State private var searchText = ""
    
    private var headerTitle: String {
        if let selectedGroup = appState.selectedGroup {
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
    
    var fetchRequest: FetchRequest<Sheet> {
        let sortDescriptors: [NSSortDescriptor]
        let predicate: NSPredicate?
        
        if let selectedGroup = appState.selectedGroup {
            // Show sheets from specific group
            sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.sortOrder, ascending: true)]
            predicate = NSPredicate(format: "group == %@ AND isInTrash == NO", selectedGroup)
        } else if let selectedEssential = appState.selectedEssential {
            switch selectedEssential {
            case "all":
                sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)]
                predicate = NSPredicate(format: "isInTrash == NO")
            case "recent":
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)]
                predicate = NSPredicate(format: "modifiedAt >= %@ AND isInTrash == NO", sevenDaysAgo as NSDate)
            case "trash":
                sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.deletedAt, ascending: false)]
                predicate = NSPredicate(format: "isInTrash == YES")
            default:
                // For inbox, projects, open files, etc.
                sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)]
                predicate = NSPredicate(format: "isInTrash == NO")
            }
        } else {
            // Default: show all non-trashed sheets
            sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)]
            predicate = NSPredicate(format: "isInTrash == NO")
        }
        
        return FetchRequest<Sheet>(
            sortDescriptors: sortDescriptors,
            predicate: predicate,
            animation: .default
        )
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
                    
                    Button(action: createNewSheet) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
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
            SheetsListContent(
                fetchRequest: fetchRequest,
                appState: appState,
                searchText: searchText
            )
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
            newSheet.content = ""
            newSheet.preview = ""
            newSheet.group = targetGroup
            newSheet.createdAt = Date()
            newSheet.modifiedAt = Date()
            newSheet.isInTrash = false
            newSheet.wordCount = 0
            newSheet.goalCount = 0
            newSheet.goalType = "words"
            newSheet.sortOrder = Int32(targetGroup.sheets?.count ?? 0)
            
            do {
                try viewContext.save()
                // Select the new sheet and clear any essential selection
                appState.selectedSheet = newSheet
                appState.selectedEssential = nil
                // Also select the target group so user can see the new sheet
                appState.selectedGroup = targetGroup
            } catch {
                print("Failed to create sheet: \(error)")
            }
        }
    }
}

struct SheetsListContent: View {
    let fetchRequest: FetchRequest<Sheet>
    @ObservedObject var appState: AppState
    let searchText: String
    
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
                ForEach(filteredSheets, id: \.self) { sheet in
                    SheetRowView(sheet: sheet, appState: appState)
                }
            }
            .padding(.top, 8)
        }
    }
}

struct SheetRowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var sheet: Sheet
    @ObservedObject var appState: AppState
    
    @State private var isEditing = false
    @State private var editingTitle = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
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
                            .lineLimit(2)
                    }
                    
                    // Stats
                    HStack(spacing: 12) {
                        Label("\(sheet.wordCount)", systemImage: "doc.text")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        if sheet.goalCount > 0 {
                            Label("\(sheet.goalCount) \(sheet.goalType ?? "words")", systemImage: "target")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
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
                    .fill(appState.selectedSheet == sheet ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .onTapGesture {
                appState.selectedSheet = sheet
            }
            .contextMenu {
                Button("Rename") { startEditing() }
                Button(sheet.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                    toggleFavorite()
                }
                Button("Duplicate") { duplicateSheet() }
                Divider()
                if sheet.isInTrash {
                    Button("Restore") { restoreFromTrash() }
                    Button("Delete Permanently", role: .destructive) { deleteSheetPermanently() }
                } else {
                    Button("Move to Trash", role: .destructive) { moveToTrash() }
                }
            }
            
            // Divider
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5)
                .padding(.leading, 16)
        }
    }
    
    private func startEditing() {
        isEditing = true
        editingTitle = sheet.title ?? ""
    }
    
    private func finishEditing() {
        sheet.title = editingTitle.isEmpty ? "Untitled" : editingTitle
        sheet.modifiedAt = Date()
        
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
            newSheet.title = (sheet.title ?? "Untitled") + " Copy"
            newSheet.content = sheet.content
            newSheet.preview = sheet.preview
            newSheet.group = sheet.group
            newSheet.createdAt = Date()
            newSheet.modifiedAt = Date()
            newSheet.isInTrash = false
            newSheet.wordCount = sheet.wordCount
            newSheet.goalCount = sheet.goalCount
            newSheet.goalType = sheet.goalType
            newSheet.sortOrder = sheet.sortOrder + 1
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to duplicate sheet: \(error)")
            }
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

#Preview {
    SheetListView(appState: AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 400, height: 600)
}