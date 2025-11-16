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
    @State private var showKeyboardShortcuts = false
    @State private var showAdvancedSearch = false
    @State private var showTemplates = false
    @State private var dashboardType: DashboardType = .overview
    @StateObject private var templateService = TemplateService.shared
    
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
                // Navigation Bar (hidden in full screen)
                if !appState.isFullScreen {
                    NavigationBar(appState: appState)
                }
                
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
                        
                        // Editor Pane(s) (Pane 3) - Ulysses style
                        if appState.showSecondaryEditor {
                            // Dual editor layout
                            HStack(spacing: 0) {
                                // Primary Editor
                                EditorView(appState: appState)
                                    .background(UlyssesDesign.Colors.background(for: colorScheme ?? .light))
                                    .onTapGesture {
                                        if appState.showLibrary {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                appState.showLibrary = false
                                            }
                                        }
                                    }
                                
                                // Divider
                                Rectangle()
                                    .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme ?? .light))
                                    .frame(width: 0.5)
                                    .opacity(0.6)
                                
                                // Secondary Editor
                                SecondaryEditorView(appState: appState)
                                    .background(UlyssesDesign.Colors.background(for: colorScheme ?? .light))
                                    .onTapGesture {
                                        if appState.showLibrary {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                appState.showLibrary = false
                                            }
                                        }
                                    }
                            }
                        } else {
                            // Single editor layout
                            EditorView(appState: appState)
                                .frame(maxWidth: showDashboard ? .infinity : .infinity)
                                .background(UlyssesDesign.Colors.background(for: colorScheme ?? .light))
                                .onTapGesture {
                                    if appState.showLibrary {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            appState.showLibrary = false
                                        }
                                    }
                                }
                        }
                        
                        // Outline Pane (Pane 4) - persistent outline panel
                        if appState.showOutlinePane, let selectedSheet = appState.selectedSheet {
                            DashboardSidePanel(
                                sheet: selectedSheet,
                                dashboardType: .outline,
                                isPresented: $appState.showOutlinePane
                            )
                            .frame(width: UlyssesDesign.Spacing.dashboardWidth)
                            .background(UlyssesDesign.Colors.libraryBg(for: colorScheme ?? .light))
                            .overlay(
                                Rectangle()
                                    .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme ?? .light))
                                    .frame(width: 0.5)
                                    .opacity(0.6),
                                alignment: .leading
                            )
                            .transition(.move(edge: .trailing))
                        }
                        
                        // Dashboard Pane (temporary modal) - when Progress/Overview is selected
                        if showDashboard && dashboardType != .outline, let selectedSheet = appState.selectedSheet {
                            DashboardSidePanel(
                                sheet: selectedSheet,
                                dashboardType: dashboardType,
                                isPresented: $showDashboard
                            )
                            .frame(width: UlyssesDesign.Spacing.dashboardWidth)
                            .background(UlyssesDesign.Colors.libraryBg(for: colorScheme ?? .light))
                            .overlay(
                                Rectangle()
                                    .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme ?? .light))
                                    .frame(width: 0.5)
                                    .opacity(0.6),
                                alignment: .leading
                            )
                            .transition(.move(edge: .trailing))
                        }
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
            
            // Keyboard Shortcuts Help Overlay
            if showKeyboardShortcuts {
                KeyboardShortcutsHelp(isPresented: $showKeyboardShortcuts)
            }
            
            // Dashboard Side Panel (moved to be inline with other panes)
        }
        .environmentObject(appState)
        .environment(\.managedObjectContext, viewContext)
        .preferredColorScheme(colorScheme)
        .overlay(
            ToastOverlay()
                .allowsHitTesting(false)
                .zIndex(999)
        )
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState, isPresented: $showSettings)
        }
        .sheet(isPresented: $showAdvancedSearch) {
            AdvancedSearchView(appState: appState)
        }
        .sheet(isPresented: $showTemplates) {
            TemplateSelectionView(selectedGroup: appState.selectedGroup) { template in
                createSheetFromTemplate(template)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
            showCommandPalette = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAdvancedSearch)) { _ in
            showAdvancedSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in
            showKeyboardShortcuts = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showDashboard)) { notification in
            if let type = notification.object as? DashboardType {
                dashboardType = type
                withAnimation(.easeInOut(duration: 0.25)) {
                    showDashboard = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showTemplates)) { _ in
            showTemplates = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .createFromTemplate)) { notification in
            if let template = notification.object as? Template {
                createSheetFromTemplate(template)
            }
        }
        .onAppear {
            // Initialize app with 3-pane view and last opened sheet
            appState.initializeApp(context: viewContext)
        }
        // Hidden keyboard shortcut buttons
        .background(
            VStack {
                Button("Command Palette") { showCommandPalette = true }
                    .keyboardShortcut("k", modifiers: .command)
                Button("New Sheet") { createNewSheet() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Settings") { showSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
                Button("Toggle Library") { appState.showLibrary.toggle() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Toggle Sheet List") { appState.showSheetList.toggle() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Toggle Outline") { 
                    withAnimation(.easeInOut(duration: 0.25)) {
                        appState.showOutlinePane.toggle()
                    }
                }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Toggle Dashboard") { 
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showDashboard.toggle()
                    }
                }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Toggle Focus Mode") { appState.isFocusMode.toggle() }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Toggle Typewriter Mode") { appState.isTypewriterMode.toggle() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Show Keyboard Shortcuts") { showKeyboardShortcuts = true }
                    .keyboardShortcut("/", modifiers: .command)
                Button("All Panes") { appState.viewMode = .threePane }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Sheets & Editor") { appState.viewMode = .sheetsOnly }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Editor Only") { appState.viewMode = .editorOnly }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Close Secondary Editor") { 
                    if appState.showSecondaryEditor {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appState.closeSecondaryEditor()
                        }
                    }
                }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                Button("Open in Secondary Editor") { 
                    if let selectedSheet = appState.selectedSheet {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appState.openSecondaryEditor(with: selectedSheet)
                        }
                    }
                }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Show Templates") { showTemplates = true }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                
                Button("Tag Sheet") { 
                    // Focus tag input in TagEditorView
                    NotificationCenter.default.post(name: .focusTagInput, object: nil)
                }
                    .keyboardShortcut("t", modifiers: .command)
                
                Button("Filter by Tags") { 
                    // Switch to tags view in library
                    NotificationCenter.default.post(name: .showTagFilter, object: nil)
                }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                
                Button("Next Sheet") { 
                    appState.navigateToNextSheet()
                }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
                
                Button("Previous Sheet") { 
                    appState.navigateToPreviousSheet()
                }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                
                // Individual template shortcuts
                ForEach(templateService.getTemplatesWithShortcuts(), id: \.id) { template in
                    if let shortcut = template.keyboardShortcut?.lowercased().first {
                        Button("Template: \(template.displayName)") {
                            createSheetFromTemplate(template)
                        }
                        .keyboardShortcut(KeyEquivalent(shortcut), modifiers: .command)
                    }
                }
            }
            .hidden()
        )
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
                appState.selectSheet(newSheet)
                appState.selectedEssential = nil
                // Also select the target group so user can see the new sheet
                appState.selectedGroup = targetGroup
            } catch {
                print("Failed to create sheet: \(error)")
            }
        }
    }
    
    private func createSheetFromTemplate(_ template: Template) {
        withAnimation {
            let newSheet = templateService.createSheetFromTemplate(template, selectedGroup: appState.selectedGroup)
            
            // Select the new sheet and clear any essential selection
            appState.selectSheet(newSheet)
            appState.selectedEssential = nil
            
            // Select the group that contains the new sheet
            if let group = newSheet.group {
                appState.selectedGroup = group
            }
            
            // Show a success toast
            ExportService.shared.toastManager.show("Created '\(newSheet.title ?? "Untitled")' from \(template.displayName)")
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
    
}

class AppState: ObservableObject {
    @Published var selectedGroup: Group?
    @Published var selectedSheet: Sheet?
    @Published var selectedEssential: String? = nil
    @Published var secondarySheet: Sheet? = nil
    @Published var showSecondaryEditor: Bool = false
    @AppStorage("showLibrary") var showLibrary: Bool = true
    @AppStorage("showSheetList") var showSheetList: Bool = true
    @AppStorage("showOutlinePane") var showOutlinePane: Bool = false
    @AppStorage("isTypewriterMode") var isTypewriterMode: Bool = false
    @AppStorage("isFocusMode") var isFocusMode: Bool = false
    @AppStorage("showMarkdownHeaderSymbols") var showMarkdownHeaderSymbols: Bool = true
    @AppStorage("hideShortcutBar") var hideShortcutBar: Bool = false
    @AppStorage("showSheetNavigation") var showSheetNavigation: Bool = true
    @Published var isFullScreen: Bool = false

    // Icon Visibility Settings
    @AppStorage("showTemplateIcon") var showTemplateIcon: Bool = true
    @AppStorage("showDashboardIcon") var showDashboardIcon: Bool = true
    @AppStorage("showHelpIcon") var showHelpIcon: Bool = true
    @AppStorage("showOutlineIcon") var showOutlineIcon: Bool = true
    @AppStorage("showFavoriteIcon") var showFavoriteIcon: Bool = true
    @AppStorage("showReadOnlyIcon") var showReadOnlyIcon: Bool = true
    @AppStorage("showFullScreenIcon") var showFullScreenIcon: Bool = true
    @AppStorage("showNavigationButtons") var showNavigationButtons: Bool = true
    @AppStorage("showEditorOnlyIcon") var showEditorOnlyIcon: Bool = true
    @AppStorage("showWordCounter") var showWordCounter: Bool = true

    // Pane State Management (for 3-state cycling)
    @AppStorage("paneState") private var storedPaneState: String = PaneState.allPanes.rawValue

    var paneState: PaneState {
        get {
            PaneState(rawValue: storedPaneState) ?? .allPanes
        }
        set {
            storedPaneState = newValue.rawValue
            applyPaneState(newValue)
            objectWillChange.send()
        }
    }

    enum PaneState: String, CaseIterable {
        case allPanes = "All Panes"
        case middleAndEditor = "Middle & Editor"
        case editorOnly = "Editor Only"

        var icon: String {
            switch self {
            case .allPanes:
                return "sidebar.left"
            case .middleAndEditor:
                return "sidebar.left.and.right"
            case .editorOnly:
                return "rectangle"
            }
        }
    }

    func cyclePaneState() {
        withAnimation(.easeInOut(duration: 0.25)) {
            switch paneState {
            case .allPanes:
                paneState = .middleAndEditor
            case .middleAndEditor:
                paneState = .editorOnly
            case .editorOnly:
                paneState = .allPanes
            }
        }
    }

    func applyPaneState(_ state: PaneState) {
        switch state {
        case .allPanes:
            showLibrary = true
            showSheetList = true
        case .middleAndEditor:
            showLibrary = false
            showSheetList = true
        case .editorOnly:
            showLibrary = false
            showSheetList = false
        }
    }

    // Last opened sheet for restoration
    @AppStorage("lastOpenedSheetID") private var lastOpenedSheetID: String = ""
    
    // Navigation history for browser-style back/forward
    @Published var navigationHistory: [Sheet] = []
    @Published var currentHistoryIndex: Int = -1
    private let maxHistorySize = 10
    
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
    
    func initializeApp(context: NSManagedObjectContext) {
        // Ensure 3-pane view mode
        if viewMode != .threePane {
            viewMode = .threePane
        }
        
        // Restore last opened sheet
        restoreLastOpenedSheet(context: context)
    }
    
    private func restoreLastOpenedSheet(context: NSManagedObjectContext) {
        guard !lastOpenedSheetID.isEmpty,
              let uuid = UUID(uuidString: lastOpenedSheetID) else {
            // No valid last sheet ID, try to open the most recently modified sheet
            openMostRecentSheet(context: context)
            return
        }
        
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND isInTrash == NO", uuid as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let sheets = try context.fetch(fetchRequest)
            if let lastSheet = sheets.first {
                selectedSheet = lastSheet
                addToNavigationHistory(lastSheet)
                
                // Also select the group that contains this sheet
                if let group = lastSheet.group {
                    selectedGroup = group
                } else {
                    // Clear group selection if sheet is not in a group
                    selectedGroup = nil
                }
            } else {
                // Sheet no longer exists, try to open the most recent sheet
                openMostRecentSheet(context: context)
            }
        } catch {
            print("Failed to restore last opened sheet: \(error)")
            openMostRecentSheet(context: context)
        }
    }
    
    private func openMostRecentSheet(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isInTrash == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let sheets = try context.fetch(fetchRequest)
            if let mostRecentSheet = sheets.first {
                selectedSheet = mostRecentSheet
                addToNavigationHistory(mostRecentSheet)
                lastOpenedSheetID = mostRecentSheet.id?.uuidString ?? ""
                
                // Also select the group that contains this sheet
                if let group = mostRecentSheet.group {
                    selectedGroup = group
                } else {
                    selectedGroup = nil
                }
            }
        } catch {
            print("Failed to open most recent sheet: \(error)")
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
    
    enum SheetSortOption: String, CaseIterable {
        case manual = "Manual"
        case alphabetical = "Alphabetical"
        case creationDate = "Creation Date"
        case modificationDate = "Modified Date"
        
        var systemImage: String {
            switch self {
            case .manual: return "hand.raised"
            case .alphabetical: return "textformat.abc"
            case .creationDate: return "calendar.badge.plus"
            case .modificationDate: return "calendar.badge.clock"
            }
        }
    }
    
    @AppStorage("sheetSortOption") var storedSortOption: String = SheetSortOption.modificationDate.rawValue
    @AppStorage("sheetSortAscending") var sheetSortAscending: Bool = false
    
    var sheetSortOption: SheetSortOption {
        get {
            SheetSortOption(rawValue: storedSortOption) ?? .modificationDate
        }
        set {
            storedSortOption = newValue.rawValue
        }
    }
    
    func openSecondaryEditor(with sheet: Sheet) {
        secondarySheet = sheet
        showSecondaryEditor = true
    }
    
    func closeSecondaryEditor() {
        secondarySheet = nil
        showSecondaryEditor = false
    }
    
    func navigateToNextSheet() -> Bool {
        guard let currentSheet = selectedSheet else { return false }
        
        let sheets = getSortedSheets()
        guard let currentIndex = sheets.firstIndex(of: currentSheet),
              currentIndex < sheets.count - 1 else { return false }
        
        selectSheet(sheets[currentIndex + 1])
        return true
    }
    
    func navigateToPreviousSheet() -> Bool {
        guard let currentSheet = selectedSheet else { return false }
        
        let sheets = getSortedSheets()
        guard let currentIndex = sheets.firstIndex(of: currentSheet),
              currentIndex > 0 else { return false }
        
        selectSheet(sheets[currentIndex - 1])
        return true
    }
    
    func canNavigateNext() -> Bool {
        guard let currentSheet = selectedSheet else { return false }
        
        let sheets = getSortedSheets()
        guard let currentIndex = sheets.firstIndex(of: currentSheet) else { return false }
        
        return currentIndex < sheets.count - 1
    }
    
    func canNavigatePrevious() -> Bool {
        guard let currentSheet = selectedSheet else { return false }
        
        let sheets = getSortedSheets()
        guard let currentIndex = sheets.firstIndex(of: currentSheet) else { return false }
        
        return currentIndex > 0
    }
    
    // MARK: - Browser-style Navigation History
    
    func addToNavigationHistory(_ sheet: Sheet) {
        // Don't add if it's the same as the current sheet
        if currentHistoryIndex >= 0 && currentHistoryIndex < navigationHistory.count,
           navigationHistory[currentHistoryIndex] == sheet {
            return
        }
        
        // Remove any forward history when navigating to a new sheet
        if currentHistoryIndex >= 0 && currentHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
        }
        
        // Add the new sheet
        navigationHistory.append(sheet)
        currentHistoryIndex = navigationHistory.count - 1
        
        // Keep history within maxHistorySize
        if navigationHistory.count > maxHistorySize {
            navigationHistory.removeFirst()
            currentHistoryIndex = navigationHistory.count - 1
        }
    }
    
    func navigateBackInHistory() -> Bool {
        guard currentHistoryIndex > 0 else { return false }
        
        currentHistoryIndex -= 1
        let targetSheet = navigationHistory[currentHistoryIndex]
        
        // Check if the sheet still exists and is not in trash
        if !targetSheet.isInTrash {
            // Set directly without adding to history
            selectedSheet = targetSheet
            return true
        } else {
            // Remove invalid sheet and try again
            navigationHistory.remove(at: currentHistoryIndex)
            if currentHistoryIndex >= navigationHistory.count {
                currentHistoryIndex = navigationHistory.count - 1
            }
            return navigateBackInHistory()
        }
    }
    
    func navigateForwardInHistory() -> Bool {
        guard currentHistoryIndex < navigationHistory.count - 1 else { return false }
        
        currentHistoryIndex += 1
        let targetSheet = navigationHistory[currentHistoryIndex]
        
        // Check if the sheet still exists and is not in trash
        if !targetSheet.isInTrash {
            // Set directly without adding to history
            selectedSheet = targetSheet
            return true
        } else {
            // Remove invalid sheet and try again
            navigationHistory.remove(at: currentHistoryIndex)
            currentHistoryIndex = min(currentHistoryIndex, navigationHistory.count - 1)
            return navigateForwardInHistory()
        }
    }
    
    func canNavigateBackInHistory() -> Bool {
        return currentHistoryIndex > 0
    }
    
    func canNavigateForwardInHistory() -> Bool {
        return currentHistoryIndex < navigationHistory.count - 1
    }
    
    func selectSheet(_ sheet: Sheet) {
        selectedSheet = sheet
        addToNavigationHistory(sheet)
        // Save as last opened sheet
        lastOpenedSheetID = sheet.id?.uuidString ?? ""
    }
    
    func clearLastOpenedSheetIfNeeded(_ sheet: Sheet) {
        // Clear the stored last opened sheet ID if this sheet is being deleted
        if lastOpenedSheetID == sheet.id?.uuidString {
            lastOpenedSheetID = ""
        }
    }
    
    func getSortedSheets() -> [Sheet] {
        guard let context = selectedSheet?.managedObjectContext else { return [] }
        
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        
        let predicate: NSPredicate?
        if let selectedGroup = selectedGroup {
            predicate = NSPredicate(format: "group == %@ AND isInTrash == NO", selectedGroup)
        } else if let selectedEssential = selectedEssential {
            switch selectedEssential {
            case "all":
                predicate = NSPredicate(format: "isInTrash == NO")
            case "recent":
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                predicate = NSPredicate(format: "modifiedAt >= %@ AND isInTrash == NO", sevenDaysAgo as NSDate)
            case "trash":
                predicate = NSPredicate(format: "isInTrash == YES")
            case "open":
                let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                predicate = NSPredicate(format: "modifiedAt >= %@ AND isInTrash == NO", oneDayAgo as NSDate)
            case "inbox":
                predicate = NSPredicate(format: "group.name == %@ AND isInTrash == NO", "Inbox")
            case "projects":
                predicate = NSPredicate(format: "group.name != %@ AND isInTrash == NO", "Inbox")
            default:
                predicate = NSPredicate(format: "isInTrash == NO")
            }
        } else {
            predicate = NSPredicate(format: "isInTrash == NO")
        }
        
        fetchRequest.predicate = predicate
        
        let ascending = sheetSortAscending
        let sortDescriptors: [NSSortDescriptor]
        switch sheetSortOption {
        case .manual:
            sortDescriptors = [
                NSSortDescriptor(keyPath: \Sheet.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \Sheet.createdAt, ascending: true)
            ]
        case .alphabetical:
            sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.title, ascending: ascending)]
        case .creationDate:
            sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.createdAt, ascending: ascending)]
        case .modificationDate:
            sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: ascending)]
        }
        
        fetchRequest.sortDescriptors = sortDescriptors
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch sheets for navigation: \(error)")
            return []
        }
    }
}

struct SecondaryEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var appState: AppState
    
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 1.4
    @AppStorage("paragraphSpacing") private var paragraphSpacing: Double = 8
    @AppStorage("fontFamily") private var fontFamily: String = "system"
    @AppStorage("editorMargins") private var editorMargins: Double = 40
    @AppStorage("hideShortcutBar") private var hideShortcutBar: Bool = false
    @AppStorage("disableQuickType") private var disableQuickType: Bool = false
    
    @State private var showStats = false
    @State private var isReadOnlyMode = false
    @State private var showWordCounterTemporarily = true
    @State private var wordCounterHideTimer: Timer?
    
    var body: some View {
        ZStack {
            if let secondarySheet = appState.secondarySheet {
                VStack(spacing: 0) {
                    // Secondary Editor Header
                    HStack {
                        // Close Secondary Editor Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                appState.closeSecondaryEditor()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Close Secondary Editor")
                        
                        Spacer()
                        
                        // Sheet Title
                        Text(secondarySheet.title ?? "Untitled")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Favorite Button
                        FavoriteButton(sheet: secondarySheet)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    
                    // Stats Overlay (shown when pulled down)
                    if showStats {
                        StatsOverlay(sheet: secondarySheet)
                            .transition(.move(edge: .top))
                    }
                    
                    // Editor Content
                    MarkdownEditor(
                        sheet: secondarySheet,
                        appState: appState,
                        fontSize: Binding(
                            get: { CGFloat(fontSize) },
                            set: { fontSize = Double($0) }
                        ),
                        lineSpacing: Binding(
                            get: { CGFloat(lineSpacing) },
                            set: { lineSpacing = Double($0) }
                        ),
                        paragraphSpacing: Binding(
                            get: { CGFloat(paragraphSpacing) },
                            set: { paragraphSpacing = Double($0) }
                        ),
                        fontFamily: fontFamily,
                        editorMargins: Binding(
                            get: { CGFloat(editorMargins) },
                            set: { editorMargins = Double($0) }
                        ),
                        hideShortcutBar: hideShortcutBar,
                        disableQuickType: disableQuickType,
                        showStats: $showStats,
                        isReadOnlyMode: $isReadOnlyMode,
                        showWordCounterTemporarily: $showWordCounterTemporarily,
                        onWordCounterInteraction: { startWordCounterHideTimer() }
                    )
                }
            } else {
                // Empty State
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.below.doc.text")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("Secondary Editor")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Open a sheet here using long press")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemBackground))
    }

    private func startWordCounterHideTimer() {
        // Auto-hide word counter after 3 seconds of inactivity
        wordCounterHideTimer?.invalidate()
        wordCounterHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                showWordCounterTemporarily = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
