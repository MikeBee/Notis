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
    }
    
    private func updateGoalsForSheets(_ sheets: [Sheet]) {
        for sheet in sheets {
            let sheetGoals = getGoals(for: sheet)
            for goal in sheetGoals {
                updateCurrentCount(for: goal)
            }
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
        tag: Tag? = nil
    ) -> Goal {
        let context = PersistenceController.shared.container.viewContext
        let goal = Goal(context: context)
        
        goal.id = UUID()
        goal.title = title
        goal.goalDescription = description
        goal.targetCount = targetCount
        goal.currentCount = 0
        goal.goalType = type.rawValue
        goal.deadline = deadline
        goal.isActive = true
        goal.isCompleted = false
        goal.createdAt = Date()
        goal.modifiedAt = Date()
        goal.sheet = sheet
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
    
    func updateGoal(_ goal: Goal, title: String, description: String?, targetCount: Int32, deadline: Date?) {
        let context = PersistenceController.shared.container.viewContext
        
        goal.title = title
        goal.goalDescription = description
        goal.targetCount = targetCount
        goal.deadline = deadline
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
    
    func updateCurrentCount(for goal: Goal) {
        guard let goalType = GoalType(rawValue: goal.goalType ?? "words") else { return }
        
        let context = PersistenceController.shared.container.viewContext
        var newCount: Int32 = 0
        
        switch goalType {
        case .words:
            if let sheet = goal.sheet {
                newCount = sheet.wordCount
            } else if let tag = goal.tag {
                newCount = getWordCountForTag(tag)
            }
        case .characters:
            if let sheet = goal.sheet {
                newCount = Int32(sheet.content?.count ?? 0)
            } else if let tag = goal.tag {
                newCount = getCharacterCountForTag(tag)
            }
        // case .sessions:
            // For sessions, we would need to track writing sessions separately
            // For now, we'll keep the current count as is
           //  break
        case .time:
            // For time tracking, we would need separate session tracking
            // For now, we'll keep the current count as is
            return
       //  case .completion:
          //  if let sheet = goal.sheet {
       //         newCount = (sheet.content?.isEmpty == false) ? 1 : 0
         //   } else if let tag = goal.tag {
           //     newCount = getCompletionCountForTag(tag)
            // }
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
        } catch {
            print("Failed to update goal progress: \(error)")
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
    
    func getActiveGoals() -> [Goal] {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND isCompleted == NO")
        request.sortDescriptors = [
            NSSortDescriptor(key: "deadline", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch active goals: \(error)")
            return []
        }
    }
    
    func getTodaysGoals() -> [Goal] {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND deadline >= %@ AND deadline < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "deadline", ascending: true)]
        
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
    
    // private func getCompletionCountForTag(_ tag: Tag) -> Int32 {
    //    guard let sheetTags = tag.sheetTags as? Set<SheetTag> else { return 0 }
    //    return Int32(sheetTags.filter { !($0.sheet?.content?.isEmpty ?? true) }.count)
    // }
    
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
        if Calendar.current.isDateInToday(deadline) {  // ← Changed this line
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
    
    var displayTitle: String {
        return title ?? "Untitled Goal"
    }
    
    var displayDescription: String {
        return goalDescription ?? ""
    }
}
