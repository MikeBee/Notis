import SwiftUI
import CoreData
import Foundation

class GoalsService: ObservableObject {
    static let shared = GoalsService()
    @Published var goals: [Goal] = []
    
    private init() {
        // Observe Core Data context saves to update goals automatically
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: PersistenceController.shared.container.viewContext
        )
        
        // Check for daily resets on startup
        DispatchQueue.main.async {
            self.checkAndResetDailyGoals()
            WritingSessionService.shared.updateTimeGoals()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func contextDidSave(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        // Check if any Sheet objects were updated
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            let updatedSheets = updatedObjects.compactMap { $0 as? Sheet }
            if !updatedSheets.isEmpty {
                DispatchQueue.main.async {
                    self.updateGoalsForSheets(updatedSheets)
                }
            }
        }
        
        // Also check for newly inserted sheets
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            let insertedSheets = insertedObjects.compactMap { $0 as? Sheet }
            if !insertedSheets.isEmpty {
                DispatchQueue.main.async {
                    self.updateGoalsForSheets(insertedSheets)
                }
            }
        }
    }
    
    private func updateGoalsForSheets(_ sheets: [Sheet]) {
        // Since all goals are now global, update all active goals when any sheet changes
        let allGoals = getAllGoals()
        
        for goal in allGoals {
            updateCurrentCount(for: goal)
        }
    }
    
    // MARK: - Goal Management
    
    func createGoal(
        title: String,
        description: String? = nil,
        targetCount: Int32,
        type: GoalType,
        deadline: Date? = nil,
        sheet: Sheet? = nil,
        tag: Tag? = nil,
        visualType: GoalVisualType = .progressBar
    ) -> Goal {
        let context = PersistenceController.shared.container.viewContext
        let goal = Goal(context: context)

        goal.id = UUID()
        goal.title = title
        goal.goalDescription = description
        goal.targetCount = targetCount
        goal.currentCount = 0
        goal.goalType = type.rawValue
        goal.deadline = nil // All goals are now daily recurring (no deadlines)
        goal.isActive = true
        goal.isCompleted = false
        goal.createdAt = Date()
        goal.modifiedAt = Date()
        goal.lastResetDate = Date()
        goal.visualType = visualType.rawValue
        goal.sheet = nil // Goals are now global, not tied to specific sheets
        goal.tag = tag

        do {
            try context.save()
            updateCurrentCount(for: goal)
            objectWillChange.send()
        } catch {
            print("Failed to create goal: \(error)")
        }

        return goal
    }
    
    func updateGoal(_ goal: Goal, title: String, description: String?, targetCount: Int32, type: GoalType? = nil, deadline: Date?) {
        let context = PersistenceController.shared.container.viewContext
        
        goal.title = title
        goal.goalDescription = description
        goal.targetCount = targetCount
        if let type = type {
            goal.goalType = type.rawValue
        }
        goal.deadline = nil // All goals are daily recurring
        goal.modifiedAt = Date()
        
        do {
            try context.save()
            updateCurrentCount(for: goal)
            objectWillChange.send()
        } catch {
            print("Failed to update goal: \(error)")
        }
    }
    
    func deleteGoal(_ goal: Goal) {
        let context = PersistenceController.shared.container.viewContext
        context.delete(goal)
        
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            print("Failed to delete goal: \(error)")
        }
    }
    
    func toggleGoalCompletion(_ goal: Goal) {
        let context = PersistenceController.shared.container.viewContext
        
        goal.isCompleted.toggle()
        goal.modifiedAt = Date()
        
        if goal.isCompleted {
            goal.currentCount = goal.targetCount
        }
        
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            print("Failed to toggle goal completion: \(error)")
        }
    }
    
    func pauseResumeGoal(_ goal: Goal) {
        let context = PersistenceController.shared.container.viewContext
        
        goal.isActive.toggle()
        goal.modifiedAt = Date()
        
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            print("Failed to pause/resume goal: \(error)")
        }
    }
    
    // MARK: - Goal Progress Tracking
    
    func updateCurrentCount(for goal: Goal, retryCount: Int = 0) {
        guard let goalType = GoalType(rawValue: goal.goalType ?? "words") else { return }
        guard retryCount < 3 else { 
            print("Max retry attempts reached for goal update")
            return 
        }
        
        let context = PersistenceController.shared.container.viewContext
        
        // Refresh the goal object to get the latest state
        context.refresh(goal, mergeChanges: true)
        
        var newCount: Int32 = 0
        
        switch goalType {
        case .words:
            if let tag = goal.tag {
                newCount = getWordCountForTag(tag)
            } else {
                // Global goal - count across all sheets
                newCount = getTotalWordCount()
            }
        case .characters:
            if let tag = goal.tag {
                newCount = getCharacterCountForTag(tag)
            } else {
                // Global goal - count across all sheets
                newCount = getTotalCharacterCount()
            }
        case .time:
            // Writing time is tracked separately via WritingSessionService
            WritingSessionService.shared.updateTimeGoals()
            return
        }
        
        let previousCount = goal.currentCount
        goal.currentCount = newCount
        goal.modifiedAt = Date()
        
        // Check if goal is newly completed
        if !goal.isCompleted && newCount >= goal.targetCount {
            goal.isCompleted = true
            NotificationCenter.default.post(name: .goalCompleted, object: goal)
        } else if goal.isCompleted && newCount < goal.targetCount {
            goal.isCompleted = false
        }
        
        do {
            try context.save()
            if newCount != previousCount {
                objectWillChange.send()
            }
        } catch let error as NSError {
            if error.code == NSManagedObjectMergeError {
                // Handle merge conflicts by retrying with fresh data
                print("Core Data merge conflict detected, retrying goal update... (attempt \(retryCount + 1))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateCurrentCount(for: goal, retryCount: retryCount + 1)
                }
            } else {
                print("Failed to update goal progress: \(error)")
            }
        }
    }
    
    // MARK: - Goal Queries
    
    func getGoals(for sheet: Sheet) -> [Goal] {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "sheet == %@", sheet)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch goals for sheet: \(error)")
            return []
        }
    }
    
    func getGoals(for tag: Tag) -> [Goal] {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "tag == %@", tag)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch goals for tag: \(error)")
            return []
        }
    }
    
    func getAllGoals() -> [Goal] {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch all goals: \(error)")
            return []
        }
    }
    
    func getTodaysGoals() -> [Goal] {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        // Get all active goals (which are now all daily recurring goals)
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch today's goals: \(error)")
            return []
        }
    }
    
    // MARK: - Utility Functions
    
    private func getWordCountForTag(_ tag: Tag) -> Int32 {
        guard let sheetTags = tag.sheetTags as? Set<SheetTag> else { return 0 }
        return sheetTags.compactMap { $0.sheet?.wordCount }.reduce(0, +)
    }
    
    private func getCharacterCountForTag(_ tag: Tag) -> Int32 {
        guard let sheetTags = tag.sheetTags as? Set<SheetTag> else { return 0 }
        return sheetTags.compactMap { Int32($0.sheet?.content?.count ?? 0) }.reduce(0, +)
    }
    
    private func getTotalWordCount() -> Int32 {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        request.predicate = NSPredicate(format: "isInTrash == NO")
        
        do {
            let sheets = try context.fetch(request)
            return sheets.reduce(0) { $0 + $1.wordCount }
        } catch {
            print("Failed to fetch sheets for total word count: \(error)")
            return 0
        }
    }
    
    private func getTotalCharacterCount() -> Int32 {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        request.predicate = NSPredicate(format: "isInTrash == NO")
        
        do {
            let sheets = try context.fetch(request)
            return sheets.reduce(0) { $0 + Int32($1.content?.count ?? 0) }
        } catch {
            print("Failed to fetch sheets for total character count: \(error)")
            return 0
        }
    }

    func updateAllGoals() {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let goals = try context.fetch(request)
            for goal in goals {
                updateCurrentCount(for: goal)
            }
        } catch {
            print("Failed to update all goals: \(error)")
        }
    }

    // MARK: - Daily Reset Logic

    func checkAndResetDailyGoals() {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")

        do {
            let goals = try context.fetch(request)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            for goal in goals {
                // All goals are now daily recurring goals (no deadlines)

                // Check if goal needs to be reset
                if let lastReset = goal.lastResetDate {
                    let lastResetDay = calendar.startOfDay(for: lastReset)

                    // If last reset was before today, save history and reset
                    if lastResetDay < today {
                        saveGoalHistory(for: goal, date: lastResetDay)
                        resetGoal(goal)
                    }
                } else {
                    // No last reset date, initialize it
                    goal.lastResetDate = Date()
                }
            }

            try context.save()
            objectWillChange.send()
        } catch {
            print("Failed to check and reset daily goals: \(error)")
        }
    }

    private func resetGoal(_ goal: Goal) {
        goal.currentCount = 0
        goal.isCompleted = false
        goal.lastResetDate = Date()
        goal.modifiedAt = Date()
    }

    // MARK: - History Tracking

    func saveGoalHistory(for goal: Goal, date: Date? = nil) {
        let context = PersistenceController.shared.container.viewContext
        let history = GoalHistory(context: context)

        history.id = UUID()
        history.date = date ?? Date()
        history.completedCount = goal.currentCount
        history.targetCount = goal.targetCount
        history.wasCompleted = goal.isCompleted
        history.goal = goal

        do {
            try context.save()
        } catch {
            print("Failed to save goal history: \(error)")
        }
    }

    func getGoalHistory(for goal: Goal, limit: Int = 30) -> [GoalHistory] {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<GoalHistory> = GoalHistory.fetchRequest()
        request.predicate = NSPredicate(format: "goal == %@", goal)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = limit

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch goal history: \(error)")
            return []
        }
    }

    func getAllGoalHistoryForDate(_ date: Date) -> [(goal: Goal, history: GoalHistory)] {
        let context = PersistenceController.shared.container.viewContext
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<GoalHistory> = GoalHistory.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(key: "goal.title", ascending: true),
            NSSortDescriptor(key: "date", ascending: false)
        ]

        do {
            let histories = try context.fetch(request)
            return histories.compactMap { history in
                guard let goal = history.goal else { return nil }
                return (goal: goal, history: history)
            }
        } catch {
            print("Failed to fetch goal history for date: \(error)")
            return []
        }
    }
    
    func getAllGoalHistoryRecent(limit: Int = 30) -> [(goal: Goal, history: GoalHistory, date: Date)] {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<GoalHistory> = GoalHistory.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: false),
            NSSortDescriptor(key: "goal.title", ascending: true)
        ]
        request.fetchLimit = limit

        do {
            let histories = try context.fetch(request)
            return histories.compactMap { history in
                guard let goal = history.goal, let date = history.date else { return nil }
                return (goal: goal, history: history, date: date)
            }
        } catch {
            print("Failed to fetch recent goal history: \(error)")
            return []
        }
    }
}

// MARK: - Goal Types

enum GoalType: String, CaseIterable {
    case words = "words"
    case characters = "characters"
    case time = "time"

    var displayName: String {
        switch self {
        case .words:
            return "Words"
        case .characters:
            return "Characters"
        case .time:
            return "Writing Time"
        }
    }

    var icon: String {
        switch self {
        case .words:
            return "text.word.spacing"
        case .characters:
            return "textformat.abc"
        case .time:
            return "clock"
        }
    }

    var unit: String {
        switch self {
        case .words:
            return "words"
        case .characters:
            return "chars"
        case .time:
            return "minutes"
        }
    }
}

enum GoalVisualType: String, CaseIterable {
    case progressBar = "progressBar"
    case pieChart = "pieChart"

    var displayName: String {
        switch self {
        case .progressBar:
            return "Progress Bar"
        case .pieChart:
            return "Pie Chart"
        }
    }

    var icon: String {
        switch self {
        case .progressBar:
            return "chart.bar.fill"
        case .pieChart:
            return "chart.pie.fill"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let goalCompleted = Notification.Name("goalCompleted")
    static let goalUpdated = Notification.Name("goalUpdated")
}

// MARK: - Goal Extensions

extension Goal {
    var progressPercentage: Double {
        guard targetCount > 0 else { return 0 }
        return min(1.0, Double(currentCount) / Double(targetCount))
    }
    
    var isOverdue: Bool {
        guard let deadline = deadline else { return false }
        return Date() > deadline && !isCompleted
    }
    
    var formattedDeadline: String {
        guard let deadline = deadline else { return "No deadline" }

        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(deadline) {
            return "Today"
        } else if Calendar.current.isDate(deadline, inSameDayAs: Date().addingTimeInterval(86400)) {
            return "Tomorrow"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: deadline)
        }
    }
    
    var typeEnum: GoalType {
        return GoalType(rawValue: goalType ?? "words") ?? .words
    }

    var visualTypeEnum: GoalVisualType {
        return GoalVisualType(rawValue: visualType ?? "progressBar") ?? .progressBar
    }

    var isDailyGoal: Bool {
        return deadline == nil
    }

    var displayTitle: String {
        return title ?? "Untitled Goal"
    }

    var displayDescription: String {
        return goalDescription ?? ""
    }
}
