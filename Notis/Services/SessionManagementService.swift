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
    private var sessionStartCharacterCounts: [UUID: Int32] = [:] // Sheet ID -> character count at session start

    private init() {
        loadPresets()
        createBuiltInPresetsIfNeeded()

        // Observe Core Data context saves to update session goals automatically
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: viewContext
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func contextDidSave(_ notification: Notification) {
        guard isSessionActive, let userInfo = notification.userInfo else { return }

        // Check if any Sheet objects were updated
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            let updatedSheets = updatedObjects.compactMap { $0 as? Sheet }
            if !updatedSheets.isEmpty {
                DispatchQueue.main.async {
                    self.updateSessionGoalsFromSheets()
                }
            }
        }
    }

    private func updateSessionGoalsFromSheets() {
        guard isSessionActive else { return }

        // Update all session goals
        for goal in sessionGoals {
            guard let goalType = GoalType(rawValue: goal.goalType ?? "words") else { continue }

            switch goalType {
            case .words:
                goal.currentCount = calculateSessionWordCount()
            case .characters:
                goal.currentCount = calculateSessionCharacterCount()
            case .time:
                if let session = activeSession, let startTime = session.startTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    goal.currentCount = Int32(elapsed / 60)
                }
            }
        }

        do {
            try viewContext.save()
            // Trigger SwiftUI update by reassigning the array
            sessionGoals = sessionGoals
        } catch {
            print("Failed to update session goals: \(error)")
        }
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
            sessionStartCharacterCounts.removeAll()
            objectWillChange.send()
        } catch {
            print("Failed to end session: \(error)")
        }
    }

    func updateSessionProgress() {
        guard isSessionActive, let session = activeSession else { return }

        // Only update time goals here (word/character goals update automatically via Core Data observer)
        for goal in sessionGoals where goal.goalType == "time" {
            if let startTime = session.startTime {
                let elapsed = Date().timeIntervalSince(startTime)
                goal.currentCount = Int32(elapsed / 60)
            }
        }

        do {
            try viewContext.save()
            // Trigger SwiftUI update
            sessionGoals = sessionGoals
        } catch {
            print("Failed to save session progress: \(error)")
        }
    }

    private func updateSessionGoal(_ goal: SessionGoal) {
        guard let goalType = GoalType(rawValue: goal.goalType ?? "words") else { return }

        switch goalType {
        case .words:
            goal.currentCount = calculateSessionWordCount()
        case .characters:
            goal.currentCount = calculateSessionCharacterCount()
        case .time:
            if let session = activeSession, let startTime = session.startTime {
                let elapsed = Date().timeIntervalSince(startTime)
                goal.currentCount = Int32(elapsed / 60)
            }
        }
    }

    // MARK: - Word Count Calculation

    private func storeSessionBaseline() {
        sessionStartWordCounts.removeAll()
        sessionStartCharacterCounts.removeAll()

        let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        request.predicate = NSPredicate(format: "isInTrash == NO")

        do {
            let sheets = try viewContext.fetch(request)
            for sheet in sheets {
                if let sheetID = sheet.id {
                    sessionStartWordCounts[sheetID] = sheet.wordCount
                    // Calculate characters from content
                    let characters = Int32(sheet.unifiedContent.count)
                    sessionStartCharacterCounts[sheetID] = characters
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
            print("Session word count calculation error: \(error)")
            return 0
        }
    }

    private func calculateSessionCharacterCount() -> Int32 {
        let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        request.predicate = NSPredicate(format: "isInTrash == NO")

        do {
            let sheets = try viewContext.fetch(request)
            var sessionCharacters: Int32 = 0

            for sheet in sheets {
                guard let sheetID = sheet.id else { continue }

                // Calculate current character count from content
                let currentCharacters = Int32(sheet.unifiedContent.count)

                if let baseline = sessionStartCharacterCounts[sheetID] {
                    // Existing sheet - calculate delta from session start
                    let delta = currentCharacters - baseline
                    sessionCharacters += max(0, delta) // Clamp negative to 0
                } else {
                    // New sheet created during session
                    sessionCharacters += currentCharacters
                }
            }

            return sessionCharacters
        } catch {
            print("Session character count calculation error: \(error)")
            return 0
        }
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
        createBuiltInPreset(name: "Quick Sprint", goals: [(.words, 500), (.time, 30)])
        createBuiltInPreset(name: "Deep Work", goals: [(.words, 2000), (.time, 120)])
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

    func updatePreset(_ preset: SessionGoalPreset, name: String, goals: [(type: GoalType, target: Int32)]) {
        guard !preset.isBuiltIn else { return } // Don't update built-in presets

        preset.name = name

        // Remove existing goals
        if let existingGoals = preset.templateGoals as? Set<SessionGoal> {
            for goal in existingGoals {
                viewContext.delete(goal)
            }
        }

        // Add new goals
        for (type, target) in goals {
            let goal = SessionGoal(context: viewContext)
            goal.id = UUID()
            goal.goalType = type.rawValue
            goal.targetCount = target
            goal.currentCount = 0
            goal.isCompleted = false
            preset.addToTemplateGoals(goal)
        }

        do {
            try viewContext.save()
            loadPresets()
        } catch {
            print("Failed to update preset: \(error)")
        }
    }

    func duplicatePreset(_ preset: SessionGoalPreset, name: String) -> SessionGoalPreset? {
        let newPreset = SessionGoalPreset(context: viewContext)
        newPreset.id = UUID()
        newPreset.name = name
        newPreset.createdAt = Date()
        newPreset.isBuiltIn = false

        // Copy goals from original preset
        if let originalGoals = preset.templateGoals as? Set<SessionGoal> {
            for originalGoal in originalGoals {
                let goal = SessionGoal(context: viewContext)
                goal.id = UUID()
                goal.goalType = originalGoal.goalType
                goal.targetCount = originalGoal.targetCount
                goal.currentCount = 0
                goal.isCompleted = false
                newPreset.addToTemplateGoals(goal)
            }
        }

        do {
            try viewContext.save()
            loadPresets()
            return newPreset
        } catch {
            print("Failed to duplicate preset: \(error)")
            return nil
        }
    }

    func getRecentPresets(limit: Int = 3) -> [SessionGoalPreset] {
        return Array(availablePresets.filter { $0.lastUsedAt != nil }.prefix(limit))
    }
}
