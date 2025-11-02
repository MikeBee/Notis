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
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 1.4
    
    var body: some View {
        ZStack {
            if let selectedSheet = appState.selectedSheet {
                VStack(spacing: 0) {
                    // Stats Overlay (shown when pulled down)
                    if showStats {
                        StatsOverlay(sheet: selectedSheet)
                            .transition(.move(edge: .top))
                    }
                    
                    // Editor Content
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
                        showStats: $showStats
                    )
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
    }
}

struct MarkdownEditor: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var sheet: Sheet
    @ObservedObject var appState: AppState
    @Binding var fontSize: CGFloat
    @Binding var lineSpacing: CGFloat
    @Binding var showStats: Bool
    
    @State private var content: String = ""
    @State private var saveTimer: Timer?
    @State private var isEditingTitle: Bool = false
    @FocusState private var titleFocused: Bool
    @FocusState private var contentFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title Field
                    TextField("Untitled", text: Binding(
                        get: { sheet.title ?? "" },
                        set: { newTitle in
                            sheet.title = newTitle
                            scheduleAutoSave()
                        }
                    ))
                    .font(.system(size: CGFloat(fontSize + 4), weight: .semibold, design: .default))
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($titleFocused)
                    .onSubmit {
                        // When return is pressed in title, move to content
                        titleFocused = false
                        contentFocused = true
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    // Content Editor
                    MarkdownTextEditor(
                        text: $content,
                        isTypewriterMode: $appState.isTypewriterMode,
                        isFocusMode: $appState.isFocusMode,
                        fontSize: CGFloat(fontSize),
                        lineSpacing: CGFloat(lineSpacing)
                    ) { newText in
                        content = newText
                        updateWordCount()
                        updatePreview()
                        scheduleAutoSave()
                    }
                    .padding(.horizontal, 40)
                    .frame(minHeight: geometry.size.height - 120)
                    .id(sheet.id ?? UUID())
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
        }
        .onChange(of: sheet) { oldSheet, newSheet in
            // Save content to the OLD sheet before switching
            saveContentToSheet(oldSheet)
            // Load content from the NEW sheet
            loadSheetContent()
        }
        .onDisappear {
            saveContent()
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
        
        // Check if this is a new sheet (empty content and title is "Untitled")
        if (sheet.title?.isEmpty == true || sheet.title == "Untitled") && (sheet.content?.isEmpty == true) {
            // Focus on title for new sheets
            titleFocused = true
            contentFocused = false
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
    
    private func saveContent() {
        saveContentToSheet(sheet)
    }
    
    private func saveContentToSheet(_ targetSheet: Sheet) {
        targetSheet.content = content
        targetSheet.modifiedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("❌ Failed to save sheet: \(error)")
        }
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