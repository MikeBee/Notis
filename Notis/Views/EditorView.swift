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
    @State private var showEditorSettings = false
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
    
    var body: some View {
        ZStack {
            if let selectedSheet = appState.selectedSheet {
                VStack(spacing: 0) {
                    // Editor Header
                    HStack {
                        // Navigation Buttons
                        HStack(spacing: 8) {
                            Button(action: {
                                appState.navigateToPreviousSheet()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(appState.canNavigatePrevious() ? .secondary : .secondary.opacity(0.3))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!appState.canNavigatePrevious())
                            .keyboardShortcut(.leftArrow, modifiers: [.command])
                            .help("Previous Sheet (⌘←)")
                            
                            Button(action: {
                                appState.navigateToNextSheet()
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(appState.canNavigateNext() ? .secondary : .secondary.opacity(0.3))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!appState.canNavigateNext())
                            .keyboardShortcut(.rightArrow, modifiers: [.command])
                            .help("Next Sheet (⌘→)")
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
                        if !(selectedSheet.content?.isEmpty ?? true) {
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
                            
                            Divider()
                            
                            Button("Editor Settings") {
                                showEditorSettings = true
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
                            hideShortcutBar: appState.hideShortcutBar,
                            disableQuickType: disableQuickType,
                            showStats: $showStats,
                            isReadOnlyMode: $isReadOnlyMode
                        )
                        
                        // Word Counter at bottom if enabled
                        if showWordCounter {
                            WordCounterView(sheet: selectedSheet)
                                .padding(.horizontal, CGFloat(editorMargins))
                                .padding(.bottom, 8)
                                .background(Color(.systemBackground))
                        }
                        
                        // Tag Editor
                        if showTagsPane {
                            TagEditorView(sheet: selectedSheet)
                                .padding(.horizontal, CGFloat(editorMargins))
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .overlay(
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 0.5),
                                    alignment: .top
                                )
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
        .sheet(isPresented: $showEditorSettings) {
            EditorSettingsView(
                fontSize: $fontSize,
                lineSpacing: $lineSpacing,
                paragraphSpacing: $paragraphSpacing,
                fontFamily: $fontFamily,
                editorMargins: $editorMargins,
                showWordCounter: $showWordCounter,
                // hideShortcutBar: removed - now global setting,
                disableQuickType: $disableQuickType,
                theme: $appState.theme,
                isTypewriterMode: $appState.isTypewriterMode,
                isFocusMode: $appState.isFocusMode
            )
        }
        .sheet(isPresented: $showFindReplace) {
            if let selectedSheet = appState.selectedSheet {
                FindReplaceView(text: Binding(
                    get: { selectedSheet.content ?? "" },
                    set: { newValue in
                        selectedSheet.content = newValue
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
        sheet.content?.count ?? 0
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
                    .padding(.bottom, CGFloat(paragraphSpacing + 12))
                    
                    // Content Editor
                    MarkdownTextEditor(
                        text: $content,
                        isTypewriterMode: $appState.isTypewriterMode,
                        isFocusMode: $appState.isFocusMode,
                        fontSize: CGFloat(fontSize),
                        lineSpacing: CGFloat(lineSpacing),
                        paragraphSpacing: CGFloat(paragraphSpacing),
                        fontFamily: fontFamily,
                        editorMargins: CGFloat(editorMargins),
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
                                fontSize: CGFloat(fontSize),
                                lineSpacing: CGFloat(lineSpacing),
                                paragraphSpacing: CGFloat(paragraphSpacing),
                                fontFamily: fontFamily,
                                editorMargins: CGFloat(editorMargins)
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
        
        // Load content from the sheet
        content = sheet.content ?? ""
        
        // Set default view mode based on visible panes
        let isEditorOnlyMode = !appState.showLibrary && !appState.showSheetList
        let isNewSheet = (sheet.title?.isEmpty == true || sheet.title == "Untitled") && (sheet.content?.isEmpty == true)
        
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
        let preview = content.prefix(100)
        sheet.preview = String(preview).trimmingCharacters(in: .whitespacesAndNewlines)
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
        let hasContentChanged = targetSheet.content != content
        
        targetSheet.content = content
        
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
        let isNewSheet = (sheet.title?.isEmpty == true || sheet.title == "Untitled") && (sheet.content?.isEmpty == true)
        
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
    
    var characterCount: Int {
        sheet.content?.count ?? 0
    }
    
    var readingTime: Int {
        // Approximate reading time: 200 words per minute
        max(1, Int(sheet.wordCount) / 200)
    }
    
    var goalProgress: Double {
        guard sheet.goalCount > 0 else { return 0 }
        let current = sheet.goalType == "words" ? Double(sheet.wordCount) : Double(characterCount)
        return min(1.0, current / Double(sheet.goalCount))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 40) {
                StatItem(title: "Words", value: "\(sheet.wordCount)")
                StatItem(title: "Characters", value: "\(characterCount)")
                StatItem(title: "Reading Time", value: "\(readingTime) min")
            }
            
            if sheet.goalCount > 0 {
                VStack(spacing: 8) {
                    HStack {
                        Text("Goal Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(goalProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: goalProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                        .frame(height: 4)
                    
                    HStack {
                        let current = sheet.goalType == "words" ? Int(sheet.wordCount) : characterCount
                        Text("\(current) / \(sheet.goalCount) \(sheet.goalType ?? "words")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
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

#Preview {
    EditorView(appState: AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
