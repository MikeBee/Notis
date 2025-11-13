//
//  DashboardView.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI
import CoreData
import Combine

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
        SheetStatistics(content: sheet.unifiedContent)
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
    @StateObject private var sessionService = SessionManagementService.shared
    @State private var showingGoalEditor = false
    @State private var showingFullHistory = false
    @State private var editingGoal: Goal?
    @State private var showingSessionDialog = false
    @State private var showingEndSessionDialog = false
    @State private var saveSessionAsPreset = false
    @State private var sessionPresetName = ""
    
    private var statistics: SheetStatistics {
        SheetStatistics(content: sheet.unifiedContent)
    }
    
    private var allGoals: [Goal] {
        goalsService.getTodaysGoals()
    }
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.lg) {
            // Active Session Banner
            if sessionService.isSessionActive {
                ActiveSessionBanner(
                    session: sessionService.activeSession,
                    onEndSession: {
                        showingEndSessionDialog = true
                    },
                    sessionService: sessionService
                )
            }

            // Start Session Button (only show when no active session)
            if !sessionService.isSessionActive {
                Button(action: {
                    showingSessionDialog = true
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Start Writing Session")
                            .font(UlyssesDesign.Typography.sheetMeta)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, UlyssesDesign.Spacing.sm)
                    .background(UlyssesDesign.Colors.accent)
                    .cornerRadius(UlyssesDesign.CornerRadius.medium)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Goals Section
            VStack(spacing: UlyssesDesign.Spacing.md) {
                HStack {
                    Text(sessionService.isSessionActive ? "📊 Daily Progress" : "🎯 Daily Goals")
                        .font(sessionService.isSessionActive ? UlyssesDesign.Typography.sheetMeta : UlyssesDesign.Typography.editorTitle)
                        .foregroundColor(sessionService.isSessionActive ? UlyssesDesign.Colors.secondary(for: colorScheme) : UlyssesDesign.Colors.primary(for: colorScheme))

                    Spacer()

                    // History button
                    Button(action: {
                        showingFullHistory = true
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
                
                if allGoals.isEmpty {
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
                        ForEach(allGoals, id: \.id) { goal in
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
                sheet: nil, // Goals are now global
                existingGoal: editingGoal,
                onSave: { title, description, targetCount, type, deadline, visualType in
                    if let goal = editingGoal {
                        let context = PersistenceController.shared.container.viewContext
                        
                        // Update all properties at once
                        goal.title = title
                        goal.goalDescription = description
                        goal.targetCount = targetCount
                        goal.goalType = type.rawValue
                        goal.visualType = visualType.rawValue
                        goal.modifiedAt = Date()
                        
                        do {
                            try context.save()
                            goalsService.updateCurrentCount(for: goal)
                            // Force UI refresh
                            DispatchQueue.main.async {
                                goalsService.objectWillChange.send()
                            }
                        } catch {
                            print("Failed to update goal: \(error)")
                        }
                    } else {
                        _ = goalsService.createGoal(
                            title: title,
                            description: description,
                            targetCount: targetCount,
                            type: type,
                            deadline: deadline,
                            sheet: nil, // Goals are now global
                            visualType: visualType
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
        
        .sheet(isPresented: $showingFullHistory) {
            GoalHistoryView()
        }

        .sheet(isPresented: $showingSessionDialog) {
            SessionStartDialog(
                sessionService: sessionService,
                onStartWithPreset: { preset in
                    sessionService.startSession(withPreset: preset)
                    showingSessionDialog = false
                },
                onStartCustom: { name, goals in
                    sessionService.startSessionWithCustomGoals(name: name, goals: goals)
                    showingSessionDialog = false
                }
            )
        }

        .alert("End Writing Session", isPresented: $showingEndSessionDialog) {
            Button("Cancel", role: .cancel) { }
            Button("End Session") {
                sessionService.endSession(saveAsPreset: saveSessionAsPreset, presetName: sessionPresetName.isEmpty ? nil : sessionPresetName)
                saveSessionAsPreset = false
                sessionPresetName = ""
            }
        } message: {
            Text("Do you want to end your writing session?")
        }

        .onReceive(NotificationCenter.default.publisher(for: .goalCompleted)) { notification in
            if let goal = notification.object as? Goal, goal.sheet == sheet {
                // Could show celebration animation here
                print("Goal completed: \(goal.displayTitle)")
            }
        }
        .onAppear {
            // Update goal progress when view appears
            for goal in allGoals {
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
    @State private var selectedGoalScope: GoalScope = .today
    
    private var todaysGoals: [Goal] {
        goalsService.getTodaysGoals()
    }
    
    private var allGoalHistoryForToday: [(goal: Goal, history: GoalHistory)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return goalsService.getAllGoalHistoryForDate(today)
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
                    case .today:
                        goalsSection(title: "Today's Goals", goals: todaysGoals, emptyMessage: "No daily goals set")
                    case .history:
                        historySection()
                    }
                }
                .padding(.horizontal, UlyssesDesign.Spacing.lg)
            }
        }
        .sheet(isPresented: $showingGoalEditor) {
            GoalEditorView(
                sheet: nil, // All goals are now global
                existingGoal: editingGoal,
                onSave: { title, description, targetCount, type, deadline, visualType in
                    if let goal = editingGoal {
                        let context = PersistenceController.shared.container.viewContext
                        
                        // Update all properties at once
                        goal.title = title
                        goal.goalDescription = description
                        goal.targetCount = targetCount
                        goal.goalType = type.rawValue
                        goal.visualType = visualType.rawValue
                        goal.modifiedAt = Date()
                        
                        do {
                            try context.save()
                            goalsService.updateCurrentCount(for: goal)
                            // Force UI refresh
                            DispatchQueue.main.async {
                                goalsService.objectWillChange.send()
                            }
                        } catch {
                            print("Failed to update goal: \(error)")
                        }
                    } else {
                        _ = goalsService.createGoal(
                            title: title,
                            description: description,
                            targetCount: targetCount,
                            type: type,
                            deadline: deadline,
                            sheet: nil, // Global goals
                            visualType: visualType
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
    
    @ViewBuilder
    private func historySection() -> some View {
        VStack(spacing: UlyssesDesign.Spacing.md) {
            HStack {
                Text("Today's Progress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Spacer()
                
                Button("View All") {
                    // Show full history view
                }
                .font(.caption)
                .foregroundColor(UlyssesDesign.Colors.accent)
            }
            
            if allGoalHistoryForToday.isEmpty {
                VStack(spacing: UlyssesDesign.Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 32))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    
                    Text("No progress today")
                        .font(UlyssesDesign.Typography.sheetMeta)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    
                    Text("Complete your goals to see today's progress")
                        .font(.caption)
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, UlyssesDesign.Spacing.xl)
            } else {
                LazyVStack(spacing: UlyssesDesign.Spacing.xs) {
                    ForEach(allGoalHistoryForToday, id: \.history.id) { item in
                        DailyGoalListRow(goal: item.goal, history: item.history, date: Date())
                    }
                }
            }
        }
    }
}

enum GoalScope: String, CaseIterable {
    case today = "today"
    case history = "history"
    
    var displayName: String {
        switch self {
        case .today:
            return "Today"
        case .history:
            return "History"
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
    @ObservedObject var goal: Goal
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
                
                // Daily goal completion toggle
                HStack {
                    Text("Daily Goal")
                        .font(.system(size: 10))
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                    
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
    let onSave: (String, String?, Int32, GoalType, Date?, GoalVisualType) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var targetCount: String = ""
    @State private var goalType: GoalType = .words
    @State private var visualType: GoalVisualType = .progressBar
    @State private var showingDeleteAlert = false
    
    var isEditing: Bool {
        existingGoal != nil
    }
    
    private var saveButtonDisabled: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetNumber = Int32(targetCount)
        
        return trimmedTitle.isEmpty || 
               targetCount.isEmpty || 
               targetNumber == nil || 
               targetNumber! <= 0
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: UlyssesDesign.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                    Text(isEditing ? "Edit Goal" : "New Goal")
                        .font(UlyssesDesign.Typography.editorTitle)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    Text("Global Daily Goal - resets every day")
                        .font(UlyssesDesign.Typography.sheetMeta)
                        .foregroundColor(UlyssesDesign.Colors.accent.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    VStack(spacing: UlyssesDesign.Spacing.lg) {
                        // Title
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                            Text("Title")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            
                            TextField("e.g., Write 1000 words daily", text: $title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disableAutocorrection(true)
                            
                            if !title.isEmpty && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Title cannot be empty")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                            Text("Description (Optional)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            
                            TextField("Add more details about this daily goal...", text: $description, axis: .vertical)
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
                                .disableAutocorrection(true)
                                .onReceive(targetCount.publisher.collect()) {
                                    let filtered = String($0.filter { "0123456789".contains($0) })
                                    if filtered != targetCount {
                                        targetCount = filtered
                                    }
                                }
                            
                            if !targetCount.isEmpty, let target = Int32(targetCount), target <= 0 {
                                Text("Target must be greater than 0")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Visual Type
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                            Text("Progress Display")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            
                            Picker("Visual Type", selection: $visualType) {
                                ForEach(GoalVisualType.allCases, id: \.self) { type in
                                    HStack {
                                        Image(systemName: type.icon)
                                        Text(type.displayName)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        // Daily recurring info
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(UlyssesDesign.Colors.accent)
                                
                                Text("Daily Recurring Goal")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            }
                            
                            Text("This goal will reset every day and track your daily progress.")
                                .font(.caption)
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
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
                        guard let target = Int32(targetCount), target > 0, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            return
                        }
                        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines), target, goalType, nil, visualType)
                        dismiss()
                    })
                    .disabled(saveButtonDisabled)
                    .foregroundColor(saveButtonDisabled ? UlyssesDesign.Colors.tertiary(for: colorScheme) : UlyssesDesign.Colors.accent)
                }
                .padding(UlyssesDesign.Spacing.lg)
            }
            .background(UlyssesDesign.Colors.background(for: colorScheme))
            .navigationBarHidden(true)
        }
        .frame(width: 400, height: 600)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .id(existingGoal?.objectID.description ?? "new")
        .onAppear {
            if let goal = existingGoal {
                title = goal.displayTitle
                description = goal.displayDescription
                targetCount = String(goal.targetCount)
                goalType = goal.typeEnum
                visualType = goal.visualTypeEnum
            }
        }
        .onDisappear {
            // Reset form state when view disappears
            if existingGoal == nil {
                title = ""
                description = ""
                targetCount = ""
                goalType = .words
                visualType = .progressBar
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

// MARK: - Shared Components

struct DailyGoalListRow: View {
    let goal: Goal
    let history: GoalHistory
    let date: Date
    @Environment(\.colorScheme) private var colorScheme

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy-MM-dd"
        return formatter
    }

    var body: some View {
        HStack(spacing: UlyssesDesign.Spacing.sm) {
            // Date
            Text(dateFormatter.string(from: date))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)
            
            // Success/failure icon
            Image(systemName: history.wasCompleted ? "checkmark" : "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(history.wasCompleted ? .green : .red)
                .frame(width: 16)
            
            // Goal progress text
            Text("\(history.completedCount)/\(history.targetCount) \(goal.typeEnum.unit)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))

            Spacer()
        }
        .padding(.horizontal, UlyssesDesign.Spacing.sm)
        .padding(.vertical, UlyssesDesign.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                .fill(UlyssesDesign.Colors.hover.opacity(0.2))
        )
    }
}

// MARK: - Writing Session Components

struct ActiveSessionBanner: View {
    let session: WritingSession?
    let onEndSession: () -> Void
    @ObservedObject var sessionService: SessionManagementService
    @Environment(\.colorScheme) private var colorScheme
    @State private var elapsedTime: String = "0:00"
    @State private var timer: Timer?
    @State private var progressTimer: Timer?

    private var allGoalsCompleted: Bool {
        !sessionService.sessionGoals.isEmpty &&
        sessionService.sessionGoals.allSatisfy { $0.currentCount >= $0.targetCount }
    }

    private var bannerGradient: LinearGradient {
        if allGoalsCompleted {
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [UlyssesDesign.Colors.accent, UlyssesDesign.Colors.accent.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: allGoalsCompleted ? "checkmark.circle.fill" : "timer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(session?.presetName ?? "Writing Session")
                    .font(UlyssesDesign.Typography.sheetMeta)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                if allGoalsCompleted {
                    Text("Goals Complete!")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(elapsedTime)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Session Goals Progress
            if !sessionService.sessionGoals.isEmpty {
                ForEach(sessionService.sessionGoals, id: \.id) { goal in
                    SessionGoalProgressRow(goal: goal)
                }
            }
            
            // End Session Button
            Button(action: onEndSession) {
                HStack {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 12, weight: .medium))
                    Text("End Session")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(UlyssesDesign.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(UlyssesDesign.Spacing.md)
        .background(bannerGradient)
        .cornerRadius(UlyssesDesign.CornerRadius.medium)
        .onAppear {
            updateElapsedTime()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateElapsedTime()
            }

            // Update session progress every 5 seconds
            sessionService.updateSessionProgress()
            progressTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                sessionService.updateSessionProgress()
            }
        }
        .onDisappear {
            timer?.invalidate()
            progressTimer?.invalidate()
        }
    }
    
    private func updateElapsedTime() {
        guard let startTime = session?.startTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
        elapsedTime = String(format: "%d:%02d", minutes, seconds)
    }
}

struct SessionGoalProgressRow: View {
    @ObservedObject var goal: SessionGoal
    @Environment(\.colorScheme) private var colorScheme
    
    private var progress: Double {
        guard goal.targetCount > 0 else { return 0 }
        let calculatedProgress = Double(goal.currentCount) / Double(goal.targetCount)
        guard !calculatedProgress.isNaN && !calculatedProgress.isInfinite else { return 0 }
        return min(max(calculatedProgress, 0), 1) // Clamp between 0 and 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(goal.goalType?.capitalized ?? "Goal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text("\(goal.currentCount)/\(goal.targetCount)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .scaleEffect(x: 1, y: 0.5, anchor: .center)
        }
        .padding(.vertical, 4)
    }
}

struct SessionStartDialog: View {
    @ObservedObject var sessionService: SessionManagementService
    let onStartWithPreset: (SessionGoalPreset) -> Void
    let onStartCustom: (String, [(type: GoalType, target: Int32)]) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCustomSession = false
    @State private var editingPreset: SessionGoalPreset?
    @State private var showingEditDialog = false

    private var presets: [SessionGoalPreset] {
        sessionService.availablePresets
    }

    private var recentPresets: [SessionGoalPreset] {
        sessionService.getRecentPresets()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.lg) {
                    // Recent Presets
                    if !recentPresets.isEmpty {
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                            Text("Recent")
                                .font(UlyssesDesign.Typography.sheetMeta)
                                .fontWeight(.semibold)
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            
                            ForEach(recentPresets, id: \.id) { preset in
                                PresetCard(
                                    preset: preset,
                                    onSelect: {
                                        onStartWithPreset(preset)
                                    },
                                    onEdit: {
                                        editingPreset = preset
                                        showingEditDialog = true
                                    },
                                    onDelete: preset.isBuiltIn ? nil : {
                                        deletePreset(preset)
                                    }
                                )
                            }
                        }
                    }
                    
                    // All Presets
                    VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                        Text("All Presets")
                            .font(UlyssesDesign.Typography.sheetMeta)
                            .fontWeight(.semibold)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))

                        ForEach(presets, id: \.id) { preset in
                            PresetCard(
                                preset: preset,
                                onSelect: {
                                    onStartWithPreset(preset)
                                },
                                onEdit: {
                                    editingPreset = preset
                                    showingEditDialog = true
                                },
                                onDelete: preset.isBuiltIn ? nil : {
                                    deletePreset(preset)
                                }
                            )
                        }
                    }

                    // Custom Session
                    VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                        Text("Custom")
                            .font(UlyssesDesign.Typography.sheetMeta)
                            .fontWeight(.semibold)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))

                        Button(action: { showingCustomSession = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(UlyssesDesign.Colors.accent)

                                Text("Create Custom Session")
                                    .font(UlyssesDesign.Typography.sheetTitle)
                                    .fontWeight(.semibold)
                                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                            }
                            .padding(UlyssesDesign.Spacing.md)
                            .background(UlyssesDesign.Colors.hover.opacity(0.2))
                            .cornerRadius(UlyssesDesign.CornerRadius.medium)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Start Writing Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCustomSession) {
                CustomSessionCreationDialog(onStart: { name, goals in
                    onStartCustom(name, goals)
                    showingCustomSession = false
                    dismiss()
                })
            }
            .sheet(isPresented: $showingEditDialog) {
                if let preset = editingPreset {
                    EditPresetDialog(
                        preset: preset,
                        sessionService: sessionService,
                        onSave: {
                            showingEditDialog = false
                            editingPreset = nil
                        }
                    )
                }
            }
        }
    }

    private func deletePreset(_ preset: SessionGoalPreset) {
        sessionService.deletePreset(preset)
    }
}

struct PresetCard: View {
    let preset: SessionGoalPreset
    let onSelect: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    
    private var goalsDescription: String {
        guard let goals = preset.templateGoals as? Set<SessionGoal> else { return "" }
        return goals.map { goal in
            "\(goal.targetCount) \(goal.goalType ?? "words")"
        }.joined(separator: " • ")
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(preset.name ?? "Untitled")
                        .font(UlyssesDesign.Typography.sheetTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    Spacer()
                    
                    if preset.isBuiltIn {
                        Text("Built-in")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(UlyssesDesign.Colors.accent.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                }
                
                Text(goalsDescription)
                    .font(.system(size: 13))
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
            }
            .padding(UlyssesDesign.Spacing.md)
            .background(UlyssesDesign.Colors.hover.opacity(0.2))
            .cornerRadius(UlyssesDesign.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if preset.isBuiltIn {
                Button {
                    onEdit?()
                } label: {
                    Label("Duplicate and Edit", systemImage: "doc.on.doc")
                }
            } else {
                Button {
                    onEdit?()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

struct CustomSessionCreationDialog: View {
    let onStart: (String, [(type: GoalType, target: Int32)]) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var sessionName = ""
    @State private var wordGoalEnabled = true
    @State private var wordGoalTarget = "500"
    @State private var timeGoalEnabled = false
    @State private var timeGoalTarget = "30"
    @State private var characterGoalEnabled = false
    @State private var characterGoalTarget = "2000"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Session Name")) {
                    TextField("My Writing Session", text: $sessionName)
                        .autocapitalization(.words)
                }

                Section(header: Text("Session Goals")) {
                    // Words Goal
                    Toggle(isOn: $wordGoalEnabled) {
                        HStack {
                            Image(systemName: "textformat")
                                .foregroundColor(UlyssesDesign.Colors.accent)
                            Text("Words")
                        }
                    }

                    if wordGoalEnabled {
                        HStack {
                            Text("Target")
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            TextField("500", text: $wordGoalTarget)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    // Time Goal
                    Toggle(isOn: $timeGoalEnabled) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(UlyssesDesign.Colors.accent)
                            Text("Time (minutes)")
                        }
                    }

                    if timeGoalEnabled {
                        HStack {
                            Text("Target")
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            TextField("30", text: $timeGoalTarget)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    // Characters Goal
                    Toggle(isOn: $characterGoalEnabled) {
                        HStack {
                            Image(systemName: "character")
                                .foregroundColor(UlyssesDesign.Colors.accent)
                            Text("Characters")
                        }
                    }

                    if characterGoalEnabled {
                        HStack {
                            Text("Target")
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            TextField("2000", text: $characterGoalTarget)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section {
                    Button(action: startSession) {
                        HStack {
                            Spacer()
                            Text("Start Session")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!hasValidGoal)
                }
            }
            .navigationTitle("Custom Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var hasValidGoal: Bool {
        !sessionName.trimmingCharacters(in: .whitespaces).isEmpty &&
        ((wordGoalEnabled && Int32(wordGoalTarget) ?? 0 > 0) ||
         (timeGoalEnabled && Int32(timeGoalTarget) ?? 0 > 0) ||
         (characterGoalEnabled && Int32(characterGoalTarget) ?? 0 > 0))
    }

    private func startSession() {
        var goals: [(type: GoalType, target: Int32)] = []

        if wordGoalEnabled, let target = Int32(wordGoalTarget), target > 0 {
            goals.append((.words, target))
        }

        if timeGoalEnabled, let target = Int32(timeGoalTarget), target > 0 {
            goals.append((.time, target))
        }

        if characterGoalEnabled, let target = Int32(characterGoalTarget), target > 0 {
            goals.append((.characters, target))
        }

        guard !goals.isEmpty else { return }
        let name = sessionName.trimmingCharacters(in: .whitespaces)
        onStart(name, goals)
    }
}

struct EditPresetDialog: View {
    let preset: SessionGoalPreset
    @ObservedObject var sessionService: SessionManagementService
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var presetName = ""
    @State private var wordGoalEnabled = false
    @State private var wordGoalTarget = "500"
    @State private var timeGoalEnabled = false
    @State private var timeGoalTarget = "30"
    @State private var characterGoalEnabled = false
    @State private var characterGoalTarget = "2000"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Preset Name")) {
                    TextField("My Writing Preset", text: $presetName)
                        .autocapitalization(.words)
                }

                Section(header: Text("Goals")) {
                    // Words Goal
                    Toggle(isOn: $wordGoalEnabled) {
                        HStack {
                            Image(systemName: "textformat")
                                .foregroundColor(UlyssesDesign.Colors.accent)
                            Text("Words")
                        }
                    }

                    if wordGoalEnabled {
                        HStack {
                            Text("Target")
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            TextField("500", text: $wordGoalTarget)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    // Time Goal
                    Toggle(isOn: $timeGoalEnabled) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(UlyssesDesign.Colors.accent)
                            Text("Time (minutes)")
                        }
                    }

                    if timeGoalEnabled {
                        HStack {
                            Text("Target")
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            TextField("30", text: $timeGoalTarget)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    // Characters Goal
                    Toggle(isOn: $characterGoalEnabled) {
                        HStack {
                            Image(systemName: "character")
                                .foregroundColor(UlyssesDesign.Colors.accent)
                            Text("Characters")
                        }
                    }

                    if characterGoalEnabled {
                        HStack {
                            Text("Target")
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                            TextField("2000", text: $characterGoalTarget)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section {
                    Button(action: savePreset) {
                        HStack {
                            Spacer()
                            Text(preset.isBuiltIn ? "Duplicate and Save" : "Save Changes")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!hasValidGoal)
                }
            }
            .navigationTitle(preset.isBuiltIn ? "Duplicate Preset" : "Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPresetData()
            }
        }
    }

    private var hasValidGoal: Bool {
        !presetName.trimmingCharacters(in: .whitespaces).isEmpty &&
        ((wordGoalEnabled && Int32(wordGoalTarget) ?? 0 > 0) ||
         (timeGoalEnabled && Int32(timeGoalTarget) ?? 0 > 0) ||
         (characterGoalEnabled && Int32(characterGoalTarget) ?? 0 > 0))
    }

    private func loadPresetData() {
        presetName = preset.name ?? ""

        if let goals = preset.templateGoals as? Set<SessionGoal> {
            for goal in goals {
                guard let goalType = GoalType(rawValue: goal.goalType ?? "") else { continue }

                switch goalType {
                case .words:
                    wordGoalEnabled = true
                    wordGoalTarget = String(goal.targetCount)
                case .time:
                    timeGoalEnabled = true
                    timeGoalTarget = String(goal.targetCount)
                case .characters:
                    characterGoalEnabled = true
                    characterGoalTarget = String(goal.targetCount)
                }
            }
        }
    }

    private func savePreset() {
        var goals: [(type: GoalType, target: Int32)] = []

        if wordGoalEnabled, let target = Int32(wordGoalTarget), target > 0 {
            goals.append((.words, target))
        }

        if timeGoalEnabled, let target = Int32(timeGoalTarget), target > 0 {
            goals.append((.time, target))
        }

        if characterGoalEnabled, let target = Int32(characterGoalTarget), target > 0 {
            goals.append((.characters, target))
        }

        guard !goals.isEmpty else { return }
        let name = presetName.trimmingCharacters(in: .whitespaces)

        if preset.isBuiltIn {
            // Duplicate the built-in preset
            _ = sessionService.duplicatePreset(preset, name: name)
        } else {
            // Update the existing preset
            sessionService.updatePreset(preset, name: name, goals: goals)
        }

        onSave()
        dismiss()
    }
}
