//
//  DashboardView.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI
import CoreData

struct DashboardSidePanel: View {
    @ObservedObject var sheet: Sheet
    let dashboardType: DashboardType
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(dashboardType.title)
                    .font(UlyssesDesign.Typography.sheetTitle)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
                .background(UlyssesDesign.Colors.hover.opacity(0.5))
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                .scaleEffect(1.0)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        // Subtle hover feedback for close button
                    }
                }
            }
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
            .padding(.vertical, UlyssesDesign.Spacing.md)
            .background(
                UlyssesDesign.Colors.libraryBg(for: colorScheme)
                    .overlay(
                        Rectangle()
                            .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme))
                            .frame(height: 0.5)
                            .opacity(0.6),
                        alignment: .bottom
                    )
            )
            
            // Content
            ScrollView {
                VStack(spacing: UlyssesDesign.Spacing.lg) {
                    switch dashboardType {
                    case .overview:
                        OverviewContent(sheet: sheet)
                    case .progress:
                        ProgressContent(sheet: sheet)
                    case .outline:
                        OutlineContent(sheet: sheet)
                    case .goals:
                        GoalsContent(sheet: sheet)
                    }
                }
                .padding(UlyssesDesign.Spacing.lg)
            }
            .background(UlyssesDesign.Colors.libraryBg(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UlyssesDesign.Colors.libraryBg(for: colorScheme))
        .overlay(
            Rectangle()
                .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme))
                .frame(width: 0.5)
                .opacity(0.6),
            alignment: .leading
        )
    }
}

struct DashboardView: View {
    @ObservedObject var sheet: Sheet
    let dashboardType: DashboardType
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(dashboardType.title)
                    .font(UlyssesDesign.Typography.sheetTitle)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
                .background(UlyssesDesign.Colors.hover.opacity(0.5))
                .cornerRadius(UlyssesDesign.CornerRadius.small)
            }
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
            .padding(.vertical, UlyssesDesign.Spacing.md)
            .background(
                UlyssesDesign.Colors.background(for: colorScheme)
                    .overlay(
                        Rectangle()
                            .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme))
                            .frame(height: 0.5)
                            .opacity(0.6),
                        alignment: .bottom
                    )
            )
            
            // Content
            ScrollView {
                VStack(spacing: UlyssesDesign.Spacing.lg) {
                    switch dashboardType {
                    case .overview:
                        OverviewContent(sheet: sheet)
                    case .progress:
                        ProgressContent(sheet: sheet)
                    case .outline:
                        OutlineContent(sheet: sheet)
                    case .goals:
                        GoalsContent(sheet: sheet)
                    }
                }
                .padding(UlyssesDesign.Spacing.lg)
            }
            .background(UlyssesDesign.Colors.background(for: colorScheme))
        }
        .frame(width: 320, height: 480)
        .background(UlyssesDesign.Colors.background(for: colorScheme))
        .cornerRadius(UlyssesDesign.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.large)
                .stroke(UlyssesDesign.Colors.dividerColor(for: colorScheme), lineWidth: 0.5)
        )
        .shadow(color: UlyssesDesign.Shadows.medium, radius: 20, x: 0, y: 10)
    }
}

struct OverviewContent: View {
    @ObservedObject var sheet: Sheet
    @Environment(\.colorScheme) private var colorScheme
    
    private var statistics: SheetStatistics {
        SheetStatistics(content: sheet.content ?? "")
    }
    
    private var averageWritingTime: String {
        // Calculate average time based on word count and typical writing speed
        let wordsPerMinute = 40.0 // Average typing speed
        let minutes = Double(sheet.wordCount) / wordsPerMinute
        
        if minutes < 1 {
            return "< 1 min"
        } else if minutes < 60 {
            return "\(Int(minutes)) min"
        } else {
            let hours = Int(minutes / 60)
            let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(remainingMinutes)m"
        }
    }
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.lg) {
            // Title and Creation Info
            VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                Text(sheet.title ?? "Untitled")
                    .font(UlyssesDesign.Typography.editorTitle)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    .lineLimit(2)
                
                if let createdAt = sheet.createdAt {
                    Text("Created \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(UlyssesDesign.Typography.sheetMeta)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                
                if let modifiedAt = sheet.modifiedAt {
                    Text("Modified \(modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(UlyssesDesign.Typography.sheetMeta)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))
            
            // Main Statistics Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: UlyssesDesign.Spacing.md) {
                OverviewStatCard(
                    title: "Characters",
                    value: "\(statistics.characters)",
                    icon: "textformat.abc"
                )
                
                OverviewStatCard(
                    title: "Words",
                    value: "\(statistics.words)",
                    icon: "text.word.spacing"
                )
                
                OverviewStatCard(
                    title: "Paragraphs",
                    value: "\(statistics.paragraphs)",
                    icon: "text.alignleft"
                )
                
                OverviewStatCard(
                    title: "Lines",
                    value: "\(statistics.lines)",
                    icon: "text.line.first.and.arrowtriangle.forward"
                )
            }
            
            Divider()
                .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))
            
            // Writing Time Estimate
            VStack(spacing: UlyssesDesign.Spacing.sm) {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.accent)
                    
                    Text("Average Writing Time")
                        .font(UlyssesDesign.Typography.groupName)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    Spacer()
                }
                
                HStack {
                    Text(averageWritingTime)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(UlyssesDesign.Colors.accent)
                    
                    Spacer()
                    
                    Text("Est. time to write this content")
                        .font(UlyssesDesign.Typography.sheetMeta)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(UlyssesDesign.Spacing.md)
            .background(UlyssesDesign.Colors.accent.opacity(0.05))
            .cornerRadius(UlyssesDesign.CornerRadius.medium)
        }
    }
}

struct ProgressContent: View {
    @ObservedObject var sheet: Sheet
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var goalsService = GoalsService.shared
    @State private var showingGoalEditor = false
    @State private var showingHistory = false
    @State private var editingGoal: Goal?
    
    private var statistics: SheetStatistics {
        SheetStatistics(content: sheet.content ?? "")
    }
    
    private var sheetGoals: [Goal] {
        goalsService.getGoals(for: sheet)
    }
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.lg) {
            // Goals Section
            VStack(spacing: UlyssesDesign.Spacing.md) {
                HStack {
                    Text("🎯 Goals")
                        .font(UlyssesDesign.Typography.editorTitle)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))

                    Spacer()

                    // History button
                    Button(action: {
                        showingHistory = true
                    }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 20, height: 20)
                    .background(UlyssesDesign.Colors.hover.opacity(0.3))
                    .cornerRadius(4)

                    // Add goal button
                    Button(action: {
                        editingGoal = nil
                        showingGoalEditor = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 20, height: 20)
                    .background(UlyssesDesign.Colors.accent.opacity(0.1))
                    .cornerRadius(4)
                }
                
                if sheetGoals.isEmpty {
                    VStack(spacing: UlyssesDesign.Spacing.sm) {
                        Image(systemName: "target")
                            .font(.system(size: 24))
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        
                        Text("No Goals Set")
                            .font(UlyssesDesign.Typography.sheetMeta)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        
                        Text("Click + to set your first writing goal")
                            .font(.caption)
                            .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, UlyssesDesign.Spacing.md)
                } else {
                    LazyVStack(spacing: UlyssesDesign.Spacing.sm) {
                        ForEach(sheetGoals, id: \.id) { goal in
                            GoalProgressCard(goal: goal) {
                                editingGoal = goal
                                showingGoalEditor = true
                            }
                        }
                    }
                }
            }
            
            Divider()
                .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))
            
            // Title
            Text("📊 Text Statistics")
                .font(UlyssesDesign.Typography.editorTitle)
                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Detailed Statistics
            VStack(spacing: UlyssesDesign.Spacing.sm) {
                ProgressStatRow(label: "Characters", value: "\(statistics.characters)")
                ProgressStatRow(label: "Without Spaces", value: "\(statistics.charactersWithoutSpaces)")
                ProgressStatRow(label: "Words", value: "\(statistics.words)")
                ProgressStatRow(label: "Sentences", value: "\(statistics.sentences)")
                ProgressStatRow(label: "Words/Sentence", value: String(format: "%.1f", statistics.wordsPerSentence))
                ProgressStatRow(label: "Paragraphs", value: "\(statistics.paragraphs)")
                ProgressStatRow(label: "Lines", value: "\(statistics.lines)")
                ProgressStatRow(label: "Pages", value: "\(statistics.pages)")
            }
            
            Divider()
                .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))
            
            // Reading Time
            VStack(spacing: UlyssesDesign.Spacing.sm) {
                HStack {
                    Text("Reading Time")
                        .font(UlyssesDesign.Typography.groupName)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    Spacer()
                    
                    Text(statistics.readingTime)
                        .font(UlyssesDesign.Typography.groupName)
                        .foregroundColor(UlyssesDesign.Colors.accent)
                }
                
                Text("Based on 200 words per minute average reading speed")
                    .font(UlyssesDesign.Typography.sheetMeta)
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(UlyssesDesign.Spacing.md)
            .background(UlyssesDesign.Colors.hover.opacity(0.3))
            .cornerRadius(UlyssesDesign.CornerRadius.medium)
        }
        .sheet(isPresented: $showingGoalEditor) {
            GoalEditorView(
                sheet: sheet,
                existingGoal: editingGoal,
                onSave: { title, description, targetCount, type, deadline in
                    if let goal = editingGoal {
                        goalsService.updateGoal(goal, title: title, description: description, targetCount: targetCount, deadline: deadline)
                    } else {
                        _ = goalsService.createGoal(
                            title: title,
                            description: description,
                            targetCount: targetCount,
                            type: type,
                            deadline: deadline,
                            sheet: sheet
                        )
                    }
                    editingGoal = nil
                },
                onDelete: {
                    if let goal = editingGoal {
                        goalsService.deleteGoal(goal)
                        editingGoal = nil
                    }
                }
            )
        }
        
        .sheet(isPresented: $showingHistory) {
            GoalHistoryView()
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .goalCompleted)) { notification in
            if let goal = notification.object as? Goal, goal.sheet == sheet {
                // Could show celebration animation here
                print("Goal completed: \(goal.displayTitle)")
            }
        }
        .onAppear {
            // Update goal progress when view appears
            for goal in sheetGoals {
                goalsService.updateCurrentCount(for: goal)
            }
        }
    }
}

struct GoalsContent: View {
    @ObservedObject var sheet: Sheet
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var goalsService = GoalsService.shared
    @State private var showingGoalEditor = false
    @State private var editingGoal: Goal?
    @State private var selectedGoalScope: GoalScope = .currentSheet
    
    private var currentSheetGoals: [Goal] {
        goalsService.getGoals(for: sheet)
    }
    
    private var activeGoals: [Goal] {
        goalsService.getActiveGoals()
    }
    
    private var completedGoals: [Goal] {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 10
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    private var todaysGoals: [Goal] {
        goalsService.getTodaysGoals()
    }
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.lg) {
            // Header with scope selector
            VStack(spacing: UlyssesDesign.Spacing.md) {
                HStack {
                    Text("🎯 Goals Tracker")
                        .font(UlyssesDesign.Typography.editorTitle)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    Spacer()
                    
                    // Add Goal button
                    Button(action: { 
                        editingGoal = nil
                        showingGoalEditor = true 
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 20, height: 20)
                    .background(UlyssesDesign.Colors.accent.opacity(0.1))
                    .cornerRadius(4)
                }
                
                // Scope selector
                Picker("Goal Scope", selection: $selectedGoalScope) {
                    ForEach(GoalScope.allCases, id: \.self) { scope in
                        Text(scope.displayName)
                            .tag(scope)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: .infinity)
            }
            
            ScrollView {
                VStack(spacing: UlyssesDesign.Spacing.lg) {
                    switch selectedGoalScope {
                    case .currentSheet:
                        goalsSection(title: "Sheet Goals", goals: currentSheetGoals, emptyMessage: "No goals for this sheet")
                    case .active:
                        goalsSection(title: "Active Goals", goals: activeGoals, emptyMessage: "No active goals")
                    case .today:
                        goalsSection(title: "Today's Goals", goals: todaysGoals, emptyMessage: "No goals due today")
                    case .completed:
                        goalsSection(title: "Recently Completed", goals: completedGoals, emptyMessage: "No completed goals")
                    }
                }
                .padding(.horizontal, UlyssesDesign.Spacing.lg)
            }
        }
        .sheet(isPresented: $showingGoalEditor) {
            GoalEditorView(
                sheet: selectedGoalScope == .currentSheet ? sheet : nil,
                existingGoal: editingGoal,
                onSave: { title, description, targetCount, type, deadline in
                    if let goal = editingGoal {
                        goalsService.updateGoal(goal, title: title, description: description, targetCount: targetCount, deadline: deadline)
                    } else {
                        let targetSheet = selectedGoalScope == .currentSheet ? sheet : nil
                        _ = goalsService.createGoal(
                            title: title,
                            description: description,
                            targetCount: targetCount,
                            type: type,
                            deadline: deadline,
                            sheet: targetSheet
                        )
                    }
                    editingGoal = nil
                },
                onDelete: {
                    if let goal = editingGoal {
                        goalsService.deleteGoal(goal)
                        editingGoal = nil
                    }
                }
            )
        }
        .onAppear {
            // Update all goals when view appears
            goalsService.updateAllGoals()
        }
    }
    
    @ViewBuilder
    private func goalsSection(title: String, goals: [Goal], emptyMessage: String) -> some View {
        VStack(spacing: UlyssesDesign.Spacing.md) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Spacer()
                
                Text("\(goals.count)")
                    .font(.caption)
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(UlyssesDesign.Colors.secondary(for: colorScheme).opacity(0.1))
                    .cornerRadius(8)
            }
            
            if goals.isEmpty {
                VStack(spacing: UlyssesDesign.Spacing.sm) {
                    Image(systemName: "target")
                        .font(.system(size: 32))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    
                    Text(emptyMessage)
                        .font(UlyssesDesign.Typography.sheetMeta)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    
                    Text("Click + to create your first goal")
                        .font(.caption)
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, UlyssesDesign.Spacing.xl)
            } else {
                LazyVStack(spacing: UlyssesDesign.Spacing.sm) {
                    ForEach(goals, id: \.id) { goal in
                        GoalProgressCard(goal: goal) {
                            editingGoal = goal
                            showingGoalEditor = true
                        }
                    }
                }
            }
        }
    }
}

enum GoalScope: String, CaseIterable {
    case currentSheet = "current"
    case active = "active"
    case today = "today"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .currentSheet:
            return "This Sheet"
        case .active:
            return "Active"
        case .today:
            return "Today"
        case .completed:
            return "Completed"
        }
    }
}

struct OutlineContent: View {
    @ObservedObject var sheet: Sheet
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var annotationService = AnnotationService.shared
    @StateObject private var notesService = NotesService.shared
    @State private var showingAnnotationEditor = false
    @State private var selectedAnnotation: Annotation?
    @State private var showingNoteEditor = false
    @State private var selectedNote: Note?
    @State private var isAddingNote = false
    
    private var headers: [HeaderItem] {
        HeaderExtractor.extractHeaders(from: sheet.content ?? "")
    }
    
    private var annotations: [Annotation] {
        annotationService.getAnnotations(for: sheet)
    }
    
    private var notes: [Note] {
        notesService.getNotes(for: sheet)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: UlyssesDesign.Spacing.lg) {
                // Document Outline Section
                VStack(spacing: UlyssesDesign.Spacing.md) {
                    HStack {
                        Text("Document Outline")
                            .font(UlyssesDesign.Typography.editorTitle)
                            .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                        
                        Spacer()
                    }
                    
                    if headers.isEmpty {
                        VStack(spacing: UlyssesDesign.Spacing.sm) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 24))
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            
                            Text("No Headers Found")
                                .font(UlyssesDesign.Typography.sheetMeta)
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            
                            Text("Add headers using # markdown syntax")
                                .font(.caption)
                                .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, UlyssesDesign.Spacing.md)
                    } else {
                        LazyVStack(alignment: .leading, spacing: UlyssesDesign.Spacing.xs) {
                            ForEach(headers, id: \.id) { header in
                                OutlineHeaderRow(header: header)
                            }
                        }
                    }
                }
                
                Divider()
                    .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))
                
                // Annotations Section
                VStack(spacing: UlyssesDesign.Spacing.md) {
                    HStack {
                        Text("Annotations")
                            .font(UlyssesDesign.Typography.editorTitle)
                            .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                        
                        Spacer()
                        
                        Text("\(annotations.count)")
                            .font(.caption)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(UlyssesDesign.Colors.secondary(for: colorScheme).opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    if annotations.isEmpty {
                        VStack(spacing: UlyssesDesign.Spacing.sm) {
                            Image(systemName: "note.text")
                                .font(.system(size: 24))
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            
                            Text("No Annotations")
                                .font(UlyssesDesign.Typography.sheetMeta)
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            
                            Text("Use {text} to add annotations")
                                .font(.caption)
                                .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, UlyssesDesign.Spacing.md)
                    } else {
                        LazyVStack(alignment: .leading, spacing: UlyssesDesign.Spacing.xs) {
                            ForEach(annotations, id: \.id) { annotation in
                                AnnotationRow(annotation: annotation) {
                                    selectedAnnotation = annotation
                                    showingAnnotationEditor = true
                                }
                            }
                        }
                    }
                }
                
                Divider()
                    .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))
                
                // Notes Section
                VStack(spacing: UlyssesDesign.Spacing.md) {
                    HStack {
                        Text("Notes")
                            .font(UlyssesDesign.Typography.editorTitle)
                            .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                        
                        Spacer()
                        
                        Text("\(notes.count)")
                            .font(.caption)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(UlyssesDesign.Colors.secondary(for: colorScheme).opacity(0.1))
                            .cornerRadius(8)
                        
                        Button(action: {
                            isAddingNote = true
                            showingNoteEditor = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.accent)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 20, height: 20)
                        .background(UlyssesDesign.Colors.accent.opacity(0.1))
                        .cornerRadius(4)
                    }
                    
                    if notes.isEmpty {
                        VStack(spacing: UlyssesDesign.Spacing.sm) {
                            Image(systemName: "note")
                                .font(.system(size: 24))
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            
                            Text("No Notes")
                                .font(UlyssesDesign.Typography.sheetMeta)
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            
                            Text("Click + to add your first note")
                                .font(.caption)
                                .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, UlyssesDesign.Spacing.md)
                    } else {
                        LazyVStack(alignment: .leading, spacing: UlyssesDesign.Spacing.xs) {
                            ForEach(notes, id: \.id) { note in
                                NoteRow(note: note, onEdit: {
                                    selectedNote = note
                                    isAddingNote = false
                                    showingNoteEditor = true
                                }, onDelete: {
                                    notesService.deleteNote(note)
                                })
                            }
                        }
                    }
                }
                
                Spacer(minLength: UlyssesDesign.Spacing.lg)
            }
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
        }
        .sheet(isPresented: $showingAnnotationEditor) {
            if let annotation = selectedAnnotation {
                AnnotationEditorView(
                    annotatedText: annotation.annotatedText ?? "",
                    sheet: sheet,
                    position: Int(annotation.position),
                    existingAnnotation: annotation,
                    onSave: { _ in
                        // Refresh annotations list
                        annotationService.objectWillChange.send()
                    },
                    onDelete: {
                        annotationService.deleteAnnotation(annotation)
                        selectedAnnotation = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(
                sheet: sheet,
                existingNote: isAddingNote ? nil : selectedNote,
                onSave: { content in
                    if isAddingNote {
                        notesService.createNote(content: content, in: sheet)
                    } else if let note = selectedNote {
                        notesService.updateNote(note, content: content)
                    }
                    selectedNote = nil
                },
                onDelete: {
                    if let note = selectedNote {
                        notesService.deleteNote(note)
                        selectedNote = nil
                    }
                }
            )
        }
    }
}

// MARK: - Supporting Views

struct OverviewStatCard: View {
    let title: String
    let value: String
    let icon: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(UlyssesDesign.Colors.accent)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Text(title)
                    .font(UlyssesDesign.Typography.sheetMeta)
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(UlyssesDesign.Spacing.md)
        .background(UlyssesDesign.Colors.hover.opacity(0.3))
        .cornerRadius(UlyssesDesign.CornerRadius.medium)
    }
}

struct ProgressStatRow: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            Text(label)
                .font(UlyssesDesign.Typography.groupName)
                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
            
            Spacer()
            
            Text(value)
                .font(UlyssesDesign.Typography.groupName)
                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

struct OutlineHeaderRow: View {
    let header: HeaderItem
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            // Indentation based on header level
            HStack(spacing: 0) {
                ForEach(0..<(header.level - 1), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16)
                }
                
                Circle()
                    .fill(UlyssesDesign.Colors.accent)
                    .frame(width: 6, height: 6)
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8)
            }
            
            Text(header.text)
                .font(.system(size: 14 - CGFloat(header.level - 1), weight: header.level <= 2 ? .semibold : .medium))
                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Data Models and Utilities

struct SheetStatistics {
    let content: String
    
    var characters: Int {
        content.count
    }
    
    var charactersWithoutSpaces: Int {
        content.replacingOccurrences(of: " ", with: "").count
    }
    
    var words: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    var sentences: Int {
        content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
    
    var wordsPerSentence: Double {
        guard sentences > 0 else { return 0 }
        return Double(words) / Double(sentences)
    }
    
    var paragraphs: Int {
        content.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
    
    var lines: Int {
        guard !content.isEmpty else { return 0 }
        return content.components(separatedBy: .newlines).count
    }
    
    var pages: Int {
        // Estimate pages based on ~250 words per page
        max(1, Int(ceil(Double(words) / 250.0)))
    }
    
    var readingTime: String {
        let wordsPerMinute = 200.0
        let minutes = Double(words) / wordsPerMinute
        
        if minutes < 1 {
            return "< 1 min"
        } else if minutes < 60 {
            return "\(Int(minutes)) min"
        } else {
            let hours = Int(minutes / 60)
            let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

struct HeaderItem {
    let id = UUID()
    let level: Int
    let text: String
    let range: NSRange
}

struct HeaderExtractor {
    static func extractHeaders(from text: String) -> [HeaderItem] {
        let pattern = #"^(#{1,6})\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return []
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        return matches.compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            
            let hashRange = match.range(at: 1)
            let textRange = match.range(at: 2)
            
            let level = (text as NSString).substring(with: hashRange).count
            let headerText = (text as NSString).substring(with: textRange)
            
            return HeaderItem(level: level, text: headerText, range: match.range)
        }
    }
}

extension DashboardType {
    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .progress:
            return "Progress"
        case .outline:
            return "Outline"
        case .goals:
            return "Goals"
        }
    }
}

struct AnnotationRow: View {
    let annotation: Annotation
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.xs) {
                // Annotated text
                HStack {
                    Text(annotation.displayText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "note.text")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.accent)
                }
                
                // Annotation content preview
                if !annotation.displayContent.isEmpty {
                    Text(annotation.displayContent)
                        .font(.system(size: 11))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Date
                Text(annotation.formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, UlyssesDesign.Spacing.sm)
            .padding(.vertical, UlyssesDesign.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                    .fill(isHovering ? UlyssesDesign.Colors.hover : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct GoalProgressCard: View {
    let goal: Goal
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var goalsService = GoalsService.shared
    @State private var isHovering = false
    
    private var progressColor: Color {
        if goal.isCompleted {
            return .green
        } else if goal.isOverdue {
            return .red
        } else {
            return UlyssesDesign.Colors.accent
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                // Header with title and type
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.displayTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            .lineLimit(1)
                        
                        if !goal.displayDescription.isEmpty {
                            Text(goal.displayDescription)
                                .font(.system(size: 11))
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: goal.typeEnum.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(progressColor)
                        
                        if goal.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        } else if goal.isOverdue {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Progress visualization (bar or pie chart)
                if goal.visualTypeEnum == .pieChart {
                    // Pie chart view
                    HStack {
                        Spacer()
                        GoalPieChartView(goal: goal, size: 100)
                        Spacer()
                    }
                    .padding(.vertical, UlyssesDesign.Spacing.sm)
                } else {
                    // Progress bar view
                    VStack(spacing: 4) {
                        HStack {
                            Text("\(goal.currentCount) / \(goal.targetCount)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            
                            Spacer()
                            
                            Text("\(Int(goal.progressPercentage * 100))%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(progressColor)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(UlyssesDesign.Colors.hover.opacity(0.3))
                                    .frame(height: 6)
                                    .cornerRadius(3)
                                
                                Rectangle()
                                    .fill(progressColor)
                                    .frame(width: geometry.size.width * goal.progressPercentage, height: 6)
                                    .cornerRadius(3)
                                    .animation(.easeInOut(duration: 0.3), value: goal.progressPercentage)
                            }
                        }
                        .frame(height: 6)
                    }
                }
                
                // Deadline info
                if !goal.formattedDeadline.isEmpty && goal.formattedDeadline != "No deadline" {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(goal.isOverdue ? .red : UlyssesDesign.Colors.tertiary(for: colorScheme))
                        
                        Text(goal.formattedDeadline)
                            .font(.system(size: 10))
                            .foregroundColor(goal.isOverdue ? .red : UlyssesDesign.Colors.tertiary(for: colorScheme))
                        
                        Spacer()
                        
                        Button(action: {
                            goalsService.toggleGoalCompletion(goal)
                        }) {
                            Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(goal.isCompleted ? .green : UlyssesDesign.Colors.secondary(for: colorScheme))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UlyssesDesign.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.medium)
                    .fill(isHovering ? UlyssesDesign.Colors.hover : UlyssesDesign.Colors.hover.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.medium)
                    .stroke(progressColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button(action: {
                toggleVisualType()
            }) {
                Label(
                    goal.visualTypeEnum == .progressBar ? "Switch to Pie Chart" : "Switch to Progress Bar",
                    systemImage: goal.visualTypeEnum == .progressBar ? "chart.pie.fill" : "chart.bar.fill"
                )
            }
            
            Divider()
            
            Button(action: {
                goalsService.pauseResumeGoal(goal)
            }) {
                Label(
                    goal.isActive ? "Pause Goal" : "Resume Goal",
                    systemImage: goal.isActive ? "pause.circle" : "play.circle"
                )
            }
            
            Button(role: .destructive, action: {
                goalsService.deleteGoal(goal)
            }) {
                Label("Delete Goal", systemImage: "trash")
            }
        }
    }

    private func toggleVisualType() {
        let context = PersistenceController.shared.container.viewContext
        goal.visualType = goal.visualTypeEnum == .progressBar ? "pieChart" : "progressBar"
        goal.modifiedAt = Date()

        do {
            try context.save()
            goalsService.objectWillChange.send()
        } catch {
            print("Failed to toggle visual type: \(error)")
        }
    }
    
}

struct GoalEditorView: View {
    let sheet: Sheet?
    let existingGoal: Goal?
    let onSave: (String, String?, Int32, GoalType, Date?) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var targetCount: String = ""
    @State private var goalType: GoalType = .words
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date().addingTimeInterval(86400 * 7) // 1 week from now
    @State private var showingDeleteAlert = false
    
    var isEditing: Bool {
        existingGoal != nil
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: UlyssesDesign.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                    Text(isEditing ? "Edit Goal" : "New Goal")
                        .font(UlyssesDesign.Typography.editorTitle)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    if let sheet = sheet {
                        Text("for \(sheet.title ?? "Untitled")")
                            .font(UlyssesDesign.Typography.sheetMeta)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    VStack(spacing: UlyssesDesign.Spacing.lg) {
                        // Title
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                            Text("Title")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            
                            TextField("e.g., Complete first draft", text: $title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                            Text("Description (Optional)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            
                            TextField("Add more details about this goal...", text: $description, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3, reservesSpace: true)
                        }
                        
                        // Goal Type
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                            Text("Goal Type")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            
                            Picker("Goal Type", selection: $goalType) {
                                ForEach(GoalType.allCases, id: \.self) { type in
                                    HStack {
                                        Image(systemName: type.icon)
                                        Text(type.displayName)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        // Target Count
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                            Text("Target (\(goalType.unit))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            
                            TextField("e.g., 1000", text: $targetCount)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        
                        // Deadline
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                            Toggle("Set Deadline", isOn: $hasDeadline)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            
                            if hasDeadline {
                                DatePicker("Deadline", selection: $deadline, displayedComponents: [.date])
                                    .datePickerStyle(CompactDatePickerStyle())
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(UlyssesDesign.Spacing.lg)
                }
                
                // Action buttons
                HStack {
                    if isEditing {
                        Button("Delete", action: {
                            showingDeleteAlert = true
                        })
                        .foregroundColor(.red)
                        
                        Spacer()
                    }
                    
                    Button("Cancel", action: {
                        dismiss()
                    })
                    
                    Button("Save", action: {
                        let target = Int32(targetCount) ?? 0
                        let finalDeadline = hasDeadline ? deadline : nil
                        onSave(title, description.isEmpty ? nil : description, target, goalType, finalDeadline)
                        dismiss()
                    })
                    .disabled(title.isEmpty || targetCount.isEmpty || Int32(targetCount) == nil || Int32(targetCount)! <= 0)
                    .foregroundColor(UlyssesDesign.Colors.accent)
                }
                .padding(UlyssesDesign.Spacing.lg)
            }
            .background(UlyssesDesign.Colors.background(for: colorScheme))
            .navigationBarHidden(true)
        }
        .frame(width: 400, height: 600)
        .onAppear {
            if let goal = existingGoal {
                title = goal.displayTitle
                description = goal.displayDescription
                targetCount = String(goal.targetCount)
                goalType = goal.typeEnum
                hasDeadline = goal.deadline != nil
                if let deadline = goal.deadline {
                    self.deadline = deadline
                }
            }
        }
        .alert("Delete Goal", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this goal? This action cannot be undone.")
        }
    }
}

struct NoteRow: View {
    let note: Note
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(alignment: .top, spacing: UlyssesDesign.Spacing.sm) {
            VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.xs) {
                // Note content preview
                if !note.displayContent.isEmpty {
                    Text(note.firstLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                        .lineLimit(1)
                    
                    if note.displayContent.contains("\n") || note.displayContent.count > 50 {
                        Text(note.preview)
                            .font(.system(size: 11))
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                } else {
                    Text("Empty note")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                        .italic()
                }
                
                // Date
                Text(note.formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
            }
            
            Spacer()
            
            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 16, height: 16)
                    .background(UlyssesDesign.Colors.accent.opacity(0.1))
                    .cornerRadius(3)
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 16, height: 16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, UlyssesDesign.Spacing.sm)
        .padding(.vertical, UlyssesDesign.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                .fill(isHovering ? UlyssesDesign.Colors.hover : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                .stroke(UlyssesDesign.Colors.accent.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onEdit()
        }
        .alert("Delete Note", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this note? This action cannot be undone.")
        }
    }
}

#Preview {
    let sampleSheet = Sheet()
    sampleSheet.title = "Sample Document"
    sampleSheet.content = """
# Main Header

This is a sample document with some content.

## Secondary Header

More content here with **bold** text and *italic* text.

### Third Level

Some more paragraphs to test the statistics.

Another paragraph here.
"""
    sampleSheet.wordCount = 25
    sampleSheet.createdAt = Date()
    sampleSheet.modifiedAt = Date()
    
    return DashboardSidePanel(
        sheet: sampleSheet,
        dashboardType: .overview,
        isPresented: .constant(true)
    )
    .frame(width: 320, height: 500)
}
