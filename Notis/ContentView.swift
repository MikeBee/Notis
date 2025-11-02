//
//  ContentView.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var appState = AppState()
    @State private var showCommandPalette = false
    @State private var showSettings = false
    @State private var showDashboard = false
    @State private var dashboardType: DashboardType = .overview
    
    private var colorScheme: ColorScheme? {
        switch appState.theme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Navigation Bar
                NavigationBar(appState: appState)
                
                // Main Content
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Library Sidebar (Pane 1) - Ulysses style
                        if appState.showLibrary {
                            LibrarySidebar(appState: appState)
                                .frame(width: UlyssesDesign.Spacing.libraryWidth)
                                .background(UlyssesDesign.Colors.libraryBg(for: colorScheme ?? .light))
                                .overlay(
                                    Rectangle()
                                        .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme ?? .light))
                                        .frame(width: 0.5)
                                        .opacity(0.6),
                                    alignment: .trailing
                                )
                        }
                        
                        // Sheet List (Pane 2) - Ulysses style (now has the lighter background)
                        if appState.showSheetList {
                            SheetListView(appState: appState)
                                .frame(width: UlyssesDesign.Spacing.sheetListWidth)
                                .background(UlyssesDesign.Colors.background(for: colorScheme ?? .light))
                                .overlay(
                                    Rectangle()
                                        .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme ?? .light))
                                        .frame(width: 0.5)
                                        .opacity(0.6),
                                    alignment: .trailing
                                )
                        }
                        
                        // Editor Pane (Pane 3) - Ulysses style
                        EditorView(appState: appState)
                            .frame(maxWidth: .infinity)
                            .background(UlyssesDesign.Colors.background(for: colorScheme ?? .light))
                    }
                }
            }
            
            // Command Palette Overlay
            if showCommandPalette {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showCommandPalette = false
                    }
                
                CommandPalette(appState: appState, isPresented: $showCommandPalette)
            }
            
            // Dashboard Side Panel
            if showDashboard, let selectedSheet = appState.selectedSheet {
                HStack(spacing: 0) {
                    // Overlay to close dashboard when clicking on main content
                    Color.clear
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showDashboard = false
                            }
                        }
                    
                    // Dashboard Panel
                    DashboardSidePanel(
                        sheet: selectedSheet,
                        dashboardType: dashboardType,
                        isPresented: $showDashboard
                    )
                    .frame(width: UlyssesDesign.Spacing.dashboardWidth)
                    .transition(.move(edge: .trailing))
                }
                .ignoresSafeArea(.all, edges: .trailing)
            }
        }
        .environmentObject(appState)
        .environment(\.managedObjectContext, viewContext)
        .preferredColorScheme(colorScheme)
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState, isPresented: $showSettings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
            showCommandPalette = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showDashboard)) { notification in
            if let type = notification.object as? DashboardType {
                dashboardType = type
                withAnimation(.easeInOut(duration: 0.25)) {
                    showDashboard = true
                }
            }
        }
        .onAppear {
            // Keyboard shortcuts are now implemented via SwiftUI modifiers
        }
        // Keyboard Shortcuts
        .onKeyPress(.init("k", modifiers: .command)) {
            showCommandPalette = true
            return .handled
        }
        .onKeyPress(.init("n", modifiers: .command)) {
            createNewSheet()
            return .handled
        }
        .onKeyPress(.init(",", modifiers: .command)) {
            showSettings = true
            return .handled
        }
        .onKeyPress(.init("l", modifiers: [.command, .shift])) {
            appState.showLibrary.toggle()
            return .handled
        }
        .onKeyPress(.init("r", modifiers: [.command, .shift])) {
            appState.showSheetList.toggle()
            return .handled
        }
        .onKeyPress(.init("d", modifiers: [.command, .shift])) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showDashboard.toggle()
            }
            return .handled
        }
        .onKeyPress(.init("f", modifiers: .command)) {
            appState.isFocusMode.toggle()
            return .handled
        }
        .onKeyPress(.init("t", modifiers: .command)) {
            appState.isTypewriterMode.toggle()
            return .handled
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
            newSheet.content = ""
            newSheet.group = selectedGroup
            newSheet.createdAt = Date()
            newSheet.modifiedAt = Date()
            newSheet.isInTrash = false
            newSheet.sortOrder = Int32(selectedGroup.sheets?.count ?? 0)
            
            do {
                try viewContext.save()
                // Select the new sheet and clear any essential selection
                appState.selectedSheet = newSheet
                appState.selectedEssential = nil
            } catch {
                print("Failed to create sheet: \(error)")
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var selectedGroup: Group?
    @Published var selectedSheet: Sheet?
    @Published var selectedEssential: String? = nil
    @AppStorage("showLibrary") var showLibrary: Bool = true
    @AppStorage("showSheetList") var showSheetList: Bool = true
    @AppStorage("isTypewriterMode") var isTypewriterMode: Bool = false
    @AppStorage("isFocusMode") var isFocusMode: Bool = false
    
    @AppStorage("appTheme") private var storedTheme: String = AppTheme.system.rawValue
    @AppStorage("viewMode") private var storedViewMode: String = ViewMode.threePane.rawValue
    
    var theme: AppTheme {
        get {
            AppTheme(rawValue: storedTheme) ?? .system
        }
        set {
            storedTheme = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var viewMode: ViewMode {
        get {
            ViewMode(rawValue: storedViewMode) ?? .threePane
        }
        set {
            storedViewMode = newValue.rawValue
            // Update pane visibility based on view mode
            switch newValue {
            case .libraryOnly:
                showLibrary = true
                showSheetList = false
            case .sheetsOnly:
                showLibrary = false
                showSheetList = true
            case .editorOnly:
                showLibrary = false
                showSheetList = false
            case .threePane:
                showLibrary = true
                showSheetList = true
            }
            objectWillChange.send()
        }
    }
    
    enum AppTheme: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case system = "System"
    }
    
    enum ViewMode: String, CaseIterable {
        case libraryOnly = "Library"
        case sheetsOnly = "Sheets"
        case editorOnly = "Editor"
        case threePane = "All"
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
