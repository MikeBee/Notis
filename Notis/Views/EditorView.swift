//
//  EditorView.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI
import CoreData

struct EditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var appState: AppState
    
    @State private var showStats = false
    @State private var isFullScreen = false
    @State private var showFindReplace = false
    @State private var isReadOnlyMode = false
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 1.4
    @AppStorage("paragraphSpacing") private var paragraphSpacing: Double = 8
    @AppStorage("fontFamily") private var fontFamily: String = "system"
    @AppStorage("editorMargins") private var editorMargins: Double = 40
    @AppStorage("showWordCounter") private var showWordCounter: Bool = true
    // hideShortcutBar now controlled by appState
    @AppStorage("disableQuickType") private var disableQuickType: Bool = false
    @AppStorage("showTagsPane") private var showTagsPane: Bool = true

    // Safe accessors with NaN protection
    private var safeFontSize: Double {
        guard fontSize.isFinite && !fontSize.isNaN && fontSize > 0 else { return 16 }
        return max(10, min(72, fontSize))
    }

    private var safeLineSpacing: Double {
        guard lineSpacing.isFinite && !lineSpacing.isNaN && lineSpacing > 0 else { return 1.4 }
        return max(0.5, min(3.0, lineSpacing))
    }

    private var safeParagraphSpacing: Double {
        guard paragraphSpacing.isFinite && !paragraphSpacing.isNaN && paragraphSpacing >= 0 else { return 8 }
        return max(0, min(24, paragraphSpacing))
    }

    private var safeEditorMargins: Double {
        guard editorMargins.isFinite && !editorMargins.isNaN && editorMargins >= 0 else { return 40 }
        return max(0, min(200, editorMargins))
    }

    var body: some View {
        ZStack {
            if let selectedSheet = appState.selectedSheet {
                VStack(spacing: 0) {
                    // Editor Header
                    HStack {
                        // Navigation Buttons
                        HStack(spacing: 8) {
                            Button(action: {
                                _ = appState.navigateBackInHistory()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(appState.canNavigateBackInHistory() ? .secondary : .secondary.opacity(0.3))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!appState.canNavigateBackInHistory())
                            .keyboardShortcut(.leftArrow, modifiers: [.command])
                            .help("Back in History (⌘←)")
                            
                            Button(action: {
                                _ = appState.navigateForwardInHistory()
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(appState.canNavigateForwardInHistory() ? .secondary : .secondary.opacity(0.3))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!appState.canNavigateForwardInHistory())
                            .keyboardShortcut(.rightArrow, modifiers: [.command])
                            .help("Forward in History (⌘→)")
                        }
                        
                        Spacer()
                        
                        // Favorite Button
                        FavoriteButton(sheet: selectedSheet)
                        
                        // Outline Toggle Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                appState.showOutlinePane.toggle()
                            }
                        }) {
                            Image(systemName: appState.showOutlinePane ? "sidebar.trailing.fill" : "sidebar.trailing")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(appState.showOutlinePane ? .accentColor : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(appState.showOutlinePane ? "Hide Outline (⌘O)" : "Show Outline (⌘O)")
                        
                        // Read-Only Mode Toggle (only show if content exists)
                        if !selectedSheet.unifiedContent.isEmpty {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isReadOnlyMode.toggle()
                                }
                            }) {
                                Image(systemName: isReadOnlyMode ? "pencil" : "eye")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(isReadOnlyMode ? .accentColor : .secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(isReadOnlyMode ? "Switch to Edit Mode" : "Switch to Read-Only View")
                        }
                        
                        // Full Screen Button
                        Button(action: toggleFullScreen) {
                            Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .keyboardShortcut("f", modifiers: [.command, .control])
                        .help(isFullScreen ? "Exit Full Screen" : "Enter Full Screen")
                        
                        // Editor Options Menu
                        Menu {
                            Button("Full Screen") {
                                toggleFullScreen()
                            }
                            
                            Button("Find & Replace") {
                                showFindReplace = true
                            }
                            
                            Divider()
                            
                            Button("Export...") {
                                exportSheet(selectedSheet)
                            }
                            
                            Button("Export to Obsidian") {
                                ExportService.shared.exportToObsidian(sheet: selectedSheet)
                            }
                            
                            Button("Share...") {
                                shareSheet(selectedSheet)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 21, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .menuStyle(BorderlessButtonMenuStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    
                    // Stats Overlay (shown when pulled down)
                    if showStats {
                        StatsOverlay(sheet: selectedSheet)
                            .transition(.move(edge: .top))
                    }
                    
                    // Editor Content
                    VStack(spacing: 0) {
                        MarkdownEditor(
                            sheet: selectedSheet,
                            appState: appState,
                            fontSize: Binding(
                                get: { CGFloat(safeFontSize) },
                                set: { fontSize = Double($0) }
                            ),
                            lineSpacing: Binding(
                                get: { CGFloat(safeLineSpacing) },
                                set: { lineSpacing = Double($0) }
                            ),
                            paragraphSpacing: Binding(
                                get: { CGFloat(safeParagraphSpacing) },
                                set: { paragraphSpacing = Double($0) }
                            ),
                            fontFamily: fontFamily,
                            editorMargins: Binding(
                                get: {
                                    // Only override margins in 3-pane view AND not in full screen
                                    if appState.viewMode == .threePane && !isFullScreen {
                                        return 20
                                    } else {
                                        return CGFloat(safeEditorMargins)
                                    }
                                },
                                set: { newValue in
                                    // Always allow setting changes - they'll take effect in non-3-pane modes
                                    editorMargins = Double(newValue)
                                }
                            ),
                            hideShortcutBar: appState.hideShortcutBar,
                            disableQuickType: disableQuickType,
                            showStats: $showStats,
                            isReadOnlyMode: $isReadOnlyMode
                        )
                        
                        // Word Counter at bottom if enabled
                        if showWordCounter {
                            WordCounterView(sheet: selectedSheet)
                                .padding(.horizontal, (appState.viewMode == .threePane && !isFullScreen) ? 20 : CGFloat(safeEditorMargins))
                                .padding(.bottom, 8)
                                .background(Color(.systemBackground))
                        }
                        
                        // Tag Editor
                        if showTagsPane {
                            TagEditorView(sheet: selectedSheet)
                                .padding(.horizontal, (appState.viewMode == .threePane && !isFullScreen) ? 20 : CGFloat(safeEditorMargins))
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .overlay(
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 0.5),
                                    alignment: .top
                                )
                        }
                        
                        // Bottom Sheet Navigation
                        if appState.showSheetNavigation {
                            SheetNavigationView(selectedSheet: selectedSheet, appState: appState)
                        }
                    }
                }
            } else {
                // Empty State
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("Select a sheet to start writing")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Choose a sheet from the sidebar or create a new one")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showFindReplace) {
            if let selectedSheet = appState.selectedSheet {
                FindReplaceView(text: Binding(
                    get: { selectedSheet.unifiedContent },
                    set: { newValue in
                        selectedSheet.unifiedContent = newValue
                        try? viewContext.save()
                    }
                ))
            }
        }
        .onChange(of: isFullScreen) { _, newValue in
            if !newValue {
                // Restore panes when exiting full screen
                appState.showLibrary = true
                appState.showSheetList = true
            }
        }
    }
    
    private func exportSheet(_ sheet: Sheet) {
        // Implement export functionality
        // This could open a file picker to save as markdown, PDF, etc.
        print("Export sheet: \(sheet.title ?? "Untitled")")
    }
    
    private func shareSheet(_ sheet: Sheet) {
        // Implement share functionality
        // This could use the system share sheet
        print("Share sheet: \(sheet.title ?? "Untitled")")
    }
    
    private func toggleFullScreen() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isFullScreen.toggle()
            if isFullScreen {
                appState.showLibrary = false
                appState.showSheetList = false
            }
        }
    }
    
}

struct WordCounterView: View {
    @ObservedObject var sheet: Sheet
    @ObservedObject private var sessionService = WritingSessionService.shared
    
    private var characterCount: Int {
        sheet.unifiedContent.count
    }
    
    private var readingTime: Int {
        // Approximate reading time: 200 words per minute
        max(1, Int(sheet.wordCount) / 200)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Spacer()

            // Writing session timer (if active)
            if sessionService.isSessionActive {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.green)

                Text(sessionService.formattedSessionTime)
                    .font(.caption)
                    .foregroundColor(.green)

                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("\(sheet.wordCount) words")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(characterCount) characters")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(readingTime) min read")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct FavoriteButton: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var sheet: Sheet
    
    var body: some View {
        Button(action: toggleFavorite) {
            Image(systemName: sheet.isFavorite ? "star.fill" : "star")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(sheet.isFavorite ? .yellow : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .keyboardShortcut("d", modifiers: .command)
        .help(sheet.isFavorite ? "Remove from Favorites" : "Add to Favorites")
    }
    
    private func toggleFavorite() {
        withAnimation(.easeInOut(duration: 0.2)) {
            sheet.isFavorite.toggle()
            sheet.modifiedAt = Date()
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to toggle favorite: \(error)")
                // Revert the change if save failed
                sheet.isFavorite.toggle()
            }
        }
    }
}

struct MarkdownEditor: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var sheet: Sheet
    @ObservedObject var appState: AppState
    @Binding var fontSize: CGFloat
    @Binding var lineSpacing: CGFloat
    @Binding var paragraphSpacing: CGFloat
    let fontFamily: String
    @Binding var editorMargins: CGFloat
    let hideShortcutBar: Bool
    let disableQuickType: Bool
    @Binding var showStats: Bool
    @Binding var isReadOnlyMode: Bool
    
    @State private var content: String = ""
    @State private var saveTimer: Timer?
    @State private var tagProcessingTimer: Timer?
    @State private var isEditingTitle: Bool = false
    @State private var shouldSelectTitleText: Bool = false
    @FocusState private var titleFocused: Bool
    @FocusState private var contentFocused: Bool
    @StateObject private var annotationService = AnnotationService.shared
    
    private func getFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch fontFamily {
        case "serif":
            return .custom("Times New Roman", size: size).weight(weight)
        case "monospace":
            return .custom("Menlo", size: size).weight(weight)
        case "times":
            return .custom("Times", size: size).weight(weight)
        case "helvetica":
            return .custom("Helvetica", size: size).weight(weight)
        case "courier":
            return .custom("Courier", size: size).weight(weight)
        case "avenir":
            return .custom("Avenir", size: size).weight(weight)
        case "georgia":
            return .custom("Georgia", size: size).weight(weight)
        default:
            return .system(size: size, weight: weight, design: .default)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title Field
                    TitleTextField(
                        text: Binding(
                            get: { sheet.title ?? "" },
                            set: { newTitle in
                                sheet.title = newTitle
                                scheduleAutoSave()
                            }
                        ),
                        font: getFont(size: CGFloat(fontSize + 4), weight: .semibold),
                        isNewSheet: shouldSelectTitleText,
                        onReturnOrTab: {
                            // When return/tab is pressed in title, move to content
                            titleFocused = false
                            contentFocused = true
                        }
                    )
                    .focused($titleFocused)
                    .onAppear {
                        // Focus title for new sheets
                        if shouldSelectTitleText {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                titleFocused = true
                            }
                        }
                    }
                    .padding(.horizontal, editorMargins)
                    .padding(.top, 40)
                    .padding(.bottom, paragraphSpacing + 12)

                    // Content Editor
                    MarkdownTextEditor(
                        text: $content,
                        isTypewriterMode: $appState.isTypewriterMode,
                        isFocusMode: $appState.isFocusMode,
                        fontSize: fontSize,
                        lineSpacing: lineSpacing,
                        paragraphSpacing: paragraphSpacing,
                        fontFamily: fontFamily,
                        editorMargins: editorMargins,
                        hideShortcutBar: appState.hideShortcutBar,
                        disableQuickType: disableQuickType,
                        onTextChange: { newText in
                            content = newText
                            updateWordCount()
                            updatePreview()
                            processAnnotations(newText)
                            scheduleTagProcessing(for: newText, sheet: sheet)
                            scheduleAutoSave()
                        }
                    )
                    .focused($contentFocused)
                    .frame(minHeight: geometry.size.height - 120)
                    .id(sheet.id ?? UUID())
                    .overlay(alignment: .topLeading) {
                        if isReadOnlyMode {
                            MarkdownReadOnlyView(
                                text: content,
                                fontSize: fontSize,
                                lineSpacing: lineSpacing,
                                paragraphSpacing: paragraphSpacing,
                                fontFamily: fontFamily,
                                editorMargins: editorMargins
                            )
                            .background(Color(.systemBackground))
                            .onTapGesture {
                                isReadOnlyMode = false
                                contentFocused = true
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .gesture(
                DragGesture()
                    .onEnded { gesture in
                        if gesture.translation.height > 50 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showStats.toggle()
                            }
                        }
                    }
            )
        }
        .onAppear {
            // Force content refresh when view appears
            loadSheetContent()
            // Start writing session for this sheet
            WritingSessionService.shared.startSession(for: sheet)
        }
        .onChange(of: sheet) { oldSheet, newSheet in
            // End session for old sheet
            WritingSessionService.shared.endSession()
            // Save content to the OLD sheet before switching
            saveContentToSheet(oldSheet)
            // Load content from the NEW sheet
            loadSheetContent()
            // Start session for new sheet
            WritingSessionService.shared.startSession(for: newSheet)
        }
        .onDisappear {
            saveContent()
            // End writing session when leaving editor
            WritingSessionService.shared.endSession()
        }
        .onChange(of: appState.showLibrary) { _, _ in
            updateViewModeForPaneVisibility()
        }
        .onChange(of: appState.showSheetList) { _, _ in
            updateViewModeForPaneVisibility()
        }
    }
    
    private func loadSheetContent() {
        // Ensure sheet has an ID - fix any corrupted sheets
        if sheet.id == nil {
            sheet.id = UUID()
            try? viewContext.save()
        }

        // Force Core Data refresh to ensure we have the latest data
        viewContext.refresh(sheet, mergeChanges: true)

        // Load content from the sheet using hybrid content accessor
        content = sheet.unifiedContent

        // Set default view mode based on visible panes
        let isEditorOnlyMode = !appState.showLibrary && !appState.showSheetList
        let isNewSheet = (sheet.title?.isEmpty == true || sheet.title == "Untitled") && sheet.unifiedContent.isEmpty

        if isNewSheet {
            // New sheets always start in edit mode
            isReadOnlyMode = false
            shouldSelectTitleText = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                titleFocused = true
                contentFocused = false
            }
        } else {
            // Existing sheets: read-only for multi-pane, edit for editor-only
            isReadOnlyMode = !isEditorOnlyMode
            shouldSelectTitleText = false
        }
    }
    
    private func updateWordCount() {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        sheet.wordCount = Int32(words.count)
    }
    
    private func updatePreview() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        sheet.preview = trimmed.count <= 200 ? trimmed : String(trimmed.prefix(200)) + "..."
    }
    
    private func scheduleAutoSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            saveContent()
        }
    }
    
    private func scheduleTagProcessing(for text: String, sheet: Sheet) {
        tagProcessingTimer?.invalidate()
        tagProcessingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            TagService.shared.processInlineTags(in: text, for: sheet)
        }
    }
    
    private func saveContent() {
        saveContentToSheet(sheet)
    }
    
    private func saveContentToSheet(_ targetSheet: Sheet) {
        // Only update modifiedAt if content has actually changed
        let hasContentChanged = targetSheet.unifiedContent != content

        // Use hybrid content accessor for saving
        targetSheet.unifiedContent = content

        if hasContentChanged {
            targetSheet.modifiedAt = Date()
        }

        do {
            try viewContext.save()
        } catch {
            print("❌ Failed to save sheet: \(error)")
        }
    }
    
    private func updateViewModeForPaneVisibility() {
        let isEditorOnlyMode = !appState.showLibrary && !appState.showSheetList
        let isNewSheet = (sheet.title?.isEmpty == true || sheet.title == "Untitled") && sheet.unifiedContent.isEmpty

        // Don't change mode for new sheets (they should stay in edit mode)
        if !isNewSheet {
            withAnimation(.easeInOut(duration: 0.2)) {
                isReadOnlyMode = !isEditorOnlyMode
            }
        }
    }
    
    private func processAnnotations(_ text: String) {
        // Parse annotations from the text and save them to the database
        let annotatedRanges = annotationService.parseAnnotations(in: text, for: sheet)
        
        // Get existing annotations for this sheet
        let existingAnnotations = annotationService.getAnnotations(for: sheet)
        
        // Track which annotations we've found in the current text
        var foundAnnotations: Set<UUID> = []
        
        // Process each annotation found in the text
        for range in annotatedRanges {
            if let existingAnnotation = range.annotation {
                // Update position if it has changed
                existingAnnotation.position = Int32(range.range.location)
                existingAnnotation.modifiedAt = Date()
                foundAnnotations.insert(existingAnnotation.id ?? UUID())
            } else {
                // Create new annotation
                let newAnnotation = annotationService.createAnnotation(
                    for: range.text,
                    content: range.text, // For now, use the text itself as content
                    in: sheet,
                    at: range.range.location
                )
                foundAnnotations.insert(newAnnotation.id ?? UUID())
            }
        }
        
        // Remove annotations that are no longer in the text
        for annotation in existingAnnotations {
            if let annotationId = annotation.id, !foundAnnotations.contains(annotationId) {
                annotationService.deleteAnnotation(annotation)
            }
        }
        
        // Trigger UI update for the dashboard
        annotationService.objectWillChange.send()
    }
}

struct StatsOverlay: View {
    @ObservedObject var sheet: Sheet
    @StateObject private var goalsService = GoalsService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var characterCount: Int {
        sheet.unifiedContent.count
    }
    
    var readingTime: Int {
        // Approximate reading time: 200 words per minute
        max(1, Int(sheet.wordCount) / 200)
    }
    
    private var activeGoals: [Goal] {
        goalsService.getAllGoals()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 40) {
                StatItem(title: "Words", value: "\(sheet.wordCount)")
                StatItem(title: "Characters", value: "\(characterCount)")
                StatItem(title: "Reading Time", value: "\(readingTime) min")
            }
            
            // Display global goals
            if !activeGoals.isEmpty {
                VStack(spacing: 12) {
                    ForEach(activeGoals.prefix(3), id: \.id) { goal in
                        GlobalGoalDisplayView(goal: goal)
                    }
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 40)
        .padding(.top, 20)
    }
}

struct GlobalGoalDisplayView: View {
    let goal: Goal
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(goal.displayTitle)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(goal.progressPercentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Choose visualization based on goal's visual type
            if goal.visualTypeEnum == .pieChart {
                HStack {
                    GoalPieChartView(goal: goal, size: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(goal.currentCount) / \(goal.targetCount) \(goal.typeEnum.unit)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let _ = goal.deadline {
                            Text(goal.formattedDeadline)
                                .font(.caption2)
                                .foregroundColor(goal.isOverdue ? .red : .secondary)
                        }
                    }
                    
                    Spacer()
                }
            } else {
                // Default progress bar view
                ProgressView(value: goal.progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: goal.isCompleted ? .green : (goal.isOverdue ? .red : .accentColor)))
                    .frame(height: 4)
                
                HStack {
                    Text("\(goal.currentCount) / \(goal.targetCount) \(goal.typeEnum.unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let _ = goal.deadline {
                        Text(goal.formattedDeadline)
                            .font(.caption2)
                            .foregroundColor(goal.isOverdue ? .red : .secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(UlyssesDesign.Colors.surface(for: colorScheme).opacity(0.5))
        .cornerRadius(6)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct PreviousSheetButtonContent: View {
    let previousSheet: Sheet?
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .medium))
            
            VStack(alignment: .leading, spacing: 2) {
                if let previous = previousSheet {
                    Text(previous.title ?? "Untitled")
                        .font(.caption)
                        .lineLimit(1)
                    
                    Text("Previous Sheet")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("No Previous Sheet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(buttonBackground)
        .overlay(buttonBorder)
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(previousSheet != nil ? UlyssesDesign.Colors.surface(for: colorScheme) : Color.clear)
    }
    
    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(UlyssesDesign.Colors.border(for: colorScheme), lineWidth: 0.5)
    }
}

struct NextSheetButtonContent: View {
    let nextSheet: Sheet?
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if let next = nextSheet {
                    Text(next.title ?? "Untitled")
                        .font(.caption)
                        .lineLimit(1)
                    
                    Text("Next Sheet")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("No Next Sheet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(buttonBackground)
        .overlay(buttonBorder)
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(nextSheet != nil ? UlyssesDesign.Colors.surface(for: colorScheme) : Color.clear)
    }
    
    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(UlyssesDesign.Colors.border(for: colorScheme), lineWidth: 0.5)
    }
}

struct SheetNavigationView: View {
    let selectedSheet: Sheet
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    
    private var sortedSheets: [Sheet] {
        appState.getSortedSheets()
    }
    
    private var currentIndex: Int {
        guard let index = sortedSheets.firstIndex(of: selectedSheet) else { return 0 }
        return index
    }
    
    private var previousSheet: Sheet? {
        guard currentIndex > 0 else { return nil }
        return sortedSheets[currentIndex - 1]
    }
    
    private var nextSheet: Sheet? {
        guard currentIndex < sortedSheets.count - 1 else { return nil }
        return sortedSheets[currentIndex + 1]
    }
    
    var body: some View {
        HStack {
            // Previous Sheet Button
            Button(action: {
                if let previous = previousSheet {
                    appState.selectSheet(previous)
                }
            }) {
                PreviousSheetButtonContent(
                    previousSheet: previousSheet,
                    colorScheme: colorScheme
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(previousSheet == nil)
            .help(previousSheet?.title ?? "No previous sheet")
            
            Spacer()
            
            // Current Sheet Info
            VStack(spacing: 2) {
                Text("\(currentIndex + 1) of \(sortedSheets.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(selectedSheet.title ?? "Untitled")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Next Sheet Button
            Button(action: {
                if let next = nextSheet {
                    appState.selectSheet(next)
                }
            }) {
                NextSheetButtonContent(
                    nextSheet: nextSheet,
                    colorScheme: colorScheme
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(nextSheet == nil)
            .help(nextSheet?.title ?? "No next sheet")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(navigationBackground)
    }
    
    private var navigationBackground: some View {
        Rectangle()
            .fill(UlyssesDesign.Colors.surface(for: colorScheme))
            .overlay(
                Rectangle()
                    .fill(UlyssesDesign.Colors.border(for: colorScheme))
                    .frame(height: 0.5),
                alignment: .top
            )
    }
}

#Preview {
    EditorView(appState: AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
