//
//  SessionManagementService.swift
//  Notis
//
//  Created by Claude on 11/13/25.
//

import Foundation
import CoreData
import Combine

class SessionManagementService: ObservableObject {
    static let shared = SessionManagementService()

    // MARK: - Published Properties
    @Published var activeSession: WritingSession?
    @Published var isSessionActive: Bool = false
    @Published var sessionGoals: [SessionGoal] = []
    @Published var availablePresets: [SessionGoalPreset] = []

    private let viewContext = PersistenceController.shared.container.viewContext
    private var sessionStartWordCounts: [UUID: Int32] = [:] // Sheet ID -> word count at session start

    private init() {
        loadPresets()
        createBuiltInPresetsIfNeeded()
    }

    // MARK: - Session Control

    func startSession(withPreset preset: SessionGoalPreset) {
        guard activeSession == nil else { return }

        let session = WritingSession(context: viewContext)
        session.id = UUID()
        session.startTime = Date()
        session.presetName = preset.name

        // Store current word counts as baseline for this session
        storeSessionBaseline()

        // Create session goals from preset
        var goals: [SessionGoal] = []
        if let templateGoals = preset.templateGoals as? Set<SessionGoal> {
            for templateGoal in templateGoals {
                let goal = SessionGoal(context: viewContext)
                goal.id = UUID()
                goal.goalType = templateGoal.goalType
                goal.targetCount = templateGoal.targetCount
                goal.currentCount = 0
                goal.isCompleted = false
                goal.session = session
                goals.append(goal)
            }
        }

        // Update preset's lastUsedAt
        preset.lastUsedAt = Date()

        do {
            try viewContext.save()
            activeSession = session
            sessionGoals = goals
            isSessionActive = true
            objectWillChange.send()
        } catch {
            print("Failed to start session: \(error)")
        }
    }

    func startSessionWithCustomGoals(name: String, goals: [(type: GoalType, target: Int32)]) {
        guard activeSession == nil else { return }

        let session = WritingSession(context: viewContext)
        session.id = UUID()
        session.startTime = Date()
        session.presetName = name

        // Store current word counts as baseline for this session
        storeSessionBaseline()

        // Create session goals
        var sessionGoalsList: [SessionGoal] = []
        for (type, target) in goals {
            let goal = SessionGoal(context: viewContext)
            goal.id = UUID()
            goal.goalType = type.rawValue
            goal.targetCount = target
            goal.currentCount = 0
            goal.isCompleted = false
            goal.session = session
            sessionGoalsList.append(goal)
        }

        do {
            try viewContext.save()
            activeSession = session
            sessionGoals = sessionGoalsList
            isSessionActive = true
            objectWillChange.send()
        } catch {
            print("Failed to start custom session: \(error)")
        }
    }

    func endSession(saveAsPreset: Bool = false, presetName: String? = nil) {
        guard let session = activeSession else { return }

        session.endTime = Date()
        if let start = session.startTime, let end = session.endTime {
            session.duration = Int32(end.timeIntervalSince(start) / 60) // Store as minutes
        }

        // Calculate words written during session
        session.wordsWritten = calculateSessionWordCount()

        // Mark goals as completed if targets met
        for goal in sessionGoals {
            updateSessionGoal(goal)
            if goal.currentCount >= goal.targetCount {
                goal.isCompleted = true
            }
        }

        // Save as preset if requested
        if saveAsPreset, let name = presetName {
            createPresetFromSession(name: name, session: session)
        }

        do {
            try viewContext.save()
            activeSession = nil
            sessionGoals = []
            isSessionActive = false
            sessionStartWordCounts.removeAll()
            objectWillChange.send()
        } catch {
            print("Failed to end session: \(error)")
        }
    }

    func updateSessionProgress() {
        guard isSessionActive else { return }

        for goal in sessionGoals {
            updateSessionGoal(goal)
        }

        objectWillChange.send()
    }

    private func updateSessionGoal(_ goal: SessionGoal) {
        guard let goalType = GoalType(rawValue: goal.goalType ?? "words") else { return }

        switch goalType {
        case .words:
            goal.currentCount = calculateSessionWordCount()
        case .characters:
            goal.currentCount = calculateSessionCharacterCount()
        case .minutes:
            if let session = activeSession, let startTime = session.startTime {
                let elapsed = Date().timeIntervalSince(startTime)
                goal.currentCount = Int32(elapsed / 60)
            }
        }
    }

    // MARK: - Word Count Calculation

    private func storeSessionBaseline() {
        sessionStartWordCounts.removeAll()

        let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        request.predicate = NSPredicate(format: "isInTrash == NO")

        do {
            let sheets = try viewContext.fetch(request)
            for sheet in sheets {
                if let sheetID = sheet.id {
                    sessionStartWordCounts[sheetID] = sheet.wordCount
                }
            }
        } catch {
            print("Failed to store session baseline: \(error)")
        }
    }

    private func calculateSessionWordCount() -> Int32 {
        let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        request.predicate = NSPredicate(format: "isInTrash == NO")

        do {
            let sheets = try viewContext.fetch(request)
            var sessionWords: Int32 = 0

            for sheet in sheets {
                guard let sheetID = sheet.id else { continue }

                if let baseline = sessionStartWordCounts[sheetID] {
                    // Existing sheet - calculate delta from session start
                    let delta = sheet.wordCount - baseline
                    sessionWords += max(0, delta) // Clamp negative to 0
                } else {
                    // New sheet created during session
                    sessionWords += sheet.wordCount
                }
            }

            return sessionWords
        } catch {
            print("Failed to calculate session word count: \(error)")
            return 0
        }
    }

    private func calculateSessionCharacterCount() -> Int32 {
        // Similar to word count, but based on character count
        // For now, return 0 as character tracking would need baselineCharacterCount
        return 0
    }

    // MARK: - Preset Management

    private func loadPresets() {
        let request: NSFetchRequest<SessionGoalPreset> = SessionGoalPreset.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "lastUsedAt", ascending: false),
            NSSortDescriptor(key: "name", ascending: true)
        ]

        do {
            availablePresets = try viewContext.fetch(request)
        } catch {
            print("Failed to load presets: \(error)")
            availablePresets = []
        }
    }

    private func createBuiltInPresetsIfNeeded() {
        // Check if built-in presets already exist
        let request: NSFetchRequest<SessionGoalPreset> = SessionGoalPreset.fetchRequest()
        request.predicate = NSPredicate(format: "isBuiltIn == YES")

        do {
            let existing = try viewContext.fetch(request)
            if !existing.isEmpty {
                return // Built-in presets already exist
            }
        } catch {
            print("Failed to check for built-in presets: \(error)")
        }

        // Create built-in presets
        createBuiltInPreset(name: "Quick Sprint", goals: [(.words, 500), (.minutes, 30)])
        createBuiltInPreset(name: "Deep Work", goals: [(.words, 2000), (.minutes, 120)])
        createBuiltInPreset(name: "Morning Pages", goals: [(.words, 750)])

        loadPresets() // Reload to include new presets
    }

    private func createBuiltInPreset(name: String, goals: [(GoalType, Int32)]) {
        let preset = SessionGoalPreset(context: viewContext)
        preset.id = UUID()
        preset.name = name
        preset.createdAt = Date()
        preset.isBuiltIn = true

        for (type, target) in goals {
            let goal = SessionGoal(context: viewContext)
            goal.id = UUID()
            goal.goalType = type.rawValue
            goal.targetCount = target
            goal.currentCount = 0
            goal.isCompleted = false
            goal.preset = preset
        }

        do {
            try viewContext.save()
        } catch {
            print("Failed to create built-in preset '\(name)': \(error)")
        }
    }

    func createPresetFromSession(name: String, session: WritingSession) {
        let preset = SessionGoalPreset(context: viewContext)
        preset.id = UUID()
        preset.name = name
        preset.createdAt = Date()
        preset.lastUsedAt = Date()
        preset.isBuiltIn = false

        // Copy session goals to preset template
        if let goals = session.sessionGoals as? Set<SessionGoal> {
            for sessionGoal in goals {
                let templateGoal = SessionGoal(context: viewContext)
                templateGoal.id = UUID()
                templateGoal.goalType = sessionGoal.goalType
                templateGoal.targetCount = sessionGoal.targetCount
                templateGoal.currentCount = 0
                templateGoal.isCompleted = false
                templateGoal.preset = preset
            }
        }

        do {
            try viewContext.save()
            loadPresets()
        } catch {
            print("Failed to create preset from session: \(error)")
        }
    }

    func deletePreset(_ preset: SessionGoalPreset) {
        guard !preset.isBuiltIn else { return } // Don't delete built-in presets

        viewContext.delete(preset)
        do {
            try viewContext.save()
            loadPresets()
        } catch {
            print("Failed to delete preset: \(error)")
        }
    }

    func getRecentPresets(limit: Int = 3) -> [SessionGoalPreset] {
        return Array(availablePresets.filter { $0.lastUsedAt != nil }.prefix(limit))
    }
}
