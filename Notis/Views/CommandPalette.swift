//
//  CommandPalette.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI

struct CommandPalette: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var searchText = ""
    
    var filteredCommands: [Command] {
        let allCommands = availableCommands
        if searchText.isEmpty {
            return allCommands
        }
        return allCommands.filter { command in
            command.title.localizedCaseInsensitiveContains(searchText) ||
            command.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var availableCommands: [Command] {
        var commands: [Command] = [
            Command(
                id: "new-group",
                title: "New Group",
                description: "Create a new group",
                icon: "folder.badge.plus",
                action: { createNewGroup() }
            ),
            Command(
                id: "new-sheet",
                title: "New Sheet",
                description: "Create a new sheet in selected group",
                icon: "doc.badge.plus",
                action: { createNewSheet() },
                isEnabled: appState.selectedGroup != nil
            ),
            Command(
                id: "toggle-typewriter",
                title: appState.isTypewriterMode ? "Disable Typewriter Mode" : "Enable Typewriter Mode",
                description: "Keep cursor centered while typing",
                icon: "text.aligncenter",
                action: { appState.isTypewriterMode.toggle() }
            ),
            Command(
                id: "toggle-focus",
                title: appState.isFocusMode ? "Disable Focus Mode" : "Enable Focus Mode",
                description: "Dim inactive paragraphs",
                icon: "eye",
                action: { appState.isFocusMode.toggle() }
            ),
            Command(
                id: "toggle-library",
                title: appState.showLibrary ? "Hide Library" : "Show Library",
                description: "Toggle library sidebar visibility",
                icon: "sidebar.left",
                action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState.showLibrary.toggle()
                    }
                }
            ),
            Command(
                id: "toggle-sheet-list",
                title: appState.showSheetList ? "Hide Sheet List" : "Show Sheet List",
                description: "Toggle sheet list visibility",
                icon: "list.bullet",
                action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState.showSheetList.toggle()
                    }
                }
            ),
            Command(
                id: "settings",
                title: "Settings",
                description: "Open app settings",
                icon: "gear",
                action: { openSettings() }
            ),
            Command(
                id: "advanced-search",
                title: "Advanced Search",
                description: "Search with filters and options",
                icon: "magnifyingglass.circle",
                action: { openAdvancedSearch() }
            )
        ]
        
        if let selectedSheet = appState.selectedSheet {
            commands.append(contentsOf: [
                Command(
                    id: "export-markdown",
                    title: "Export as Markdown",
                    description: "Export current sheet as .md file",
                    icon: "square.and.arrow.up",
                    action: { exportSheet(selectedSheet, format: .markdown) }
                ),
                Command(
                    id: "export-text",
                    title: "Export as Plain Text",
                    description: "Export current sheet as .txt file",
                    icon: "doc.plaintext",
                    action: { exportSheet(selectedSheet, format: .plainText) }
                ),
                Command(
                    id: "copy-markdown",
                    title: "Copy Markdown to Clipboard",
                    description: "Copy formatted content to clipboard",
                    icon: "doc.on.clipboard",
                    action: { copyToClipboard(selectedSheet.content ?? "") }
                ),
                Command(
                    id: "duplicate-sheet",
                    title: "Duplicate Sheet",
                    description: "Create a copy of current sheet",
                    icon: "doc.on.doc",
                    action: { duplicateSheet(selectedSheet) }
                ),
                Command(
                    id: "favorite-sheet",
                    title: selectedSheet.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    description: "Toggle favorite status",
                    icon: selectedSheet.isFavorite ? "star.slash" : "star",
                    action: { toggleFavorite(selectedSheet) }
                )
            ])
        }
        
        return commands.filter { $0.isEnabled }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search commands...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            
            // Commands List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCommands, id: \.id) { command in
                        CommandRow(command: command) {
                            command.action()
                            isPresented = false
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .frame(width: 500)
        .onAppear {
            searchText = ""
        }
    }
    
    // MARK: - Command Actions
    
    private func createNewGroup() {
        withAnimation {
            let newGroup = Group(context: viewContext)
            newGroup.id = UUID()
            newGroup.name = "New Group"
            newGroup.createdAt = Date()
            newGroup.modifiedAt = Date()
            newGroup.sortOrder = 0
            
            do {
                try viewContext.save()
                appState.selectedGroup = newGroup
            } catch {
                print("Failed to create group: \(error)")
            }
        }
    }
    
    private func createNewSheet() {
        guard let selectedGroup = appState.selectedGroup else { return }
        
        withAnimation {
            let newSheet = Sheet(context: viewContext)
            newSheet.id = UUID()
            newSheet.title = "Untitled"
            // Don't set content - will use file storage
            newSheet.group = selectedGroup
            newSheet.createdAt = Date()
            newSheet.modifiedAt = Date()
            newSheet.sortOrder = Int32(selectedGroup.sheets?.count ?? 0)

            // Initialize file storage for new sheet
            newSheet.initializeFileStorage()

            do {
                try viewContext.save()
                appState.selectedSheet = newSheet
            } catch {
                print("Failed to create sheet: \(error)")
            }
        }
    }
    
    private func exportSheet(_ sheet: Sheet, format: ExportFormat) {
        ExportService.shared.exportSheet(sheet, format: format)
    }
    
    private func copyToClipboard(_ content: String) {
        ExportService.shared.copyToClipboard(content)
    }
    
    private func duplicateSheet(_ sheet: Sheet) {
        withAnimation {
            let newSheet = Sheet(context: viewContext)
            newSheet.id = UUID()
            newSheet.title = (sheet.title ?? "Untitled") + " Copy"

            // Copy content using hybrid accessor and initialize file storage
            let contentToCopy = sheet.hybridContent
            newSheet.initializeFileStorage()
            newSheet.hybridContent = contentToCopy

            newSheet.group = sheet.group
            newSheet.createdAt = Date()
            newSheet.modifiedAt = Date()
            newSheet.wordCount = sheet.wordCount
            newSheet.goalCount = sheet.goalCount
            newSheet.goalType = sheet.goalType
            newSheet.sortOrder = sheet.sortOrder + 1

            do {
                try viewContext.save()
                appState.selectedSheet = newSheet
            } catch {
                print("Failed to duplicate sheet: \(error)")
            }
        }
    }
    
    private func toggleFavorite(_ sheet: Sheet) {
        sheet.isFavorite.toggle()
        sheet.modifiedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }
    
    private func openSettings() {
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }
    
    private func openAdvancedSearch() {
        NotificationCenter.default.post(name: .showAdvancedSearch, object: nil)
    }
}

struct CommandRow: View {
    let command: Command
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: command.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(command.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(Color(.systemGray5).opacity(0.5))
                .opacity(0)
        )
    }
}

struct Command {
    let id: String
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    let isEnabled: Bool
    
    init(id: String, title: String, description: String, icon: String, action: @escaping () -> Void, isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.action = action
        self.isEnabled = isEnabled
    }
}

enum ExportFormat {
    case markdown
    case plainText
    case obsidian
}

#Preview {
    @Previewable @State var isPresented = true
    
    return ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        CommandPalette(appState: AppState(), isPresented: $isPresented)
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}