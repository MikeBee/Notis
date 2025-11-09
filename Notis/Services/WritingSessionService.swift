import SwiftUI
import CoreData
import Combine

class WritingSessionService: ObservableObject {
    static let shared = WritingSessionService()

    // MARK: - Published Properties
    @Published var isSessionActive: Bool = false
    @Published var currentSessionDuration: TimeInterval = 0
    @Published var totalTimeToday: TimeInterval = 0

    // MARK: - Private Properties
    private var sessionStartTime: Date?
    private var sessionPauseTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var lastActivityTime: Date = Date()
    private var activityTimer: Timer?
    private var updateTimer: Timer?
    private var currentSheet: Sheet?

    // Auto-pause after 30 seconds of inactivity
    private let inactivityThreshold: TimeInterval = 30

    private init() {
        loadTodaysTime()
        setupTimers()
    }

    deinit {
        stopTimers()
    }

    // MARK: - Session Control

    func startSession(for sheet: Sheet? = nil) {
        guard !isSessionActive else { return }

        currentSheet = sheet
        sessionStartTime = Date()
        sessionPauseTime = nil
        lastActivityTime = Date()
        isSessionActive = true

        startTimers()
    }

    func pauseSession() {
        guard isSessionActive else { return }

        if let startTime = sessionStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            accumulatedTime += elapsed
        }

        sessionPauseTime = Date()
        isSessionActive = false
        stopTimers()

        updateGoalsWithCurrentTime()
    }

    func resumeSession() {
        guard !isSessionActive, sessionPauseTime != nil else { return }

        sessionStartTime = Date()
        sessionPauseTime = nil
        lastActivityTime = Date()
        isSessionActive = true

        startTimers()
    }

    func endSession() {
        guard sessionStartTime != nil else { return }

        if isSessionActive {
            if let startTime = sessionStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                accumulatedTime += elapsed
            }
        }

        updateGoalsWithCurrentTime()
        saveTodaysTime()

        // Reset session
        sessionStartTime = nil
        sessionPauseTime = nil
        isSessionActive = false
        accumulatedTime = 0
        currentSessionDuration = 0
        currentSheet = nil

        stopTimers()
    }

    // MARK: - Activity Tracking

    func recordActivity() {
        lastActivityTime = Date()

        // Auto-resume if paused but session exists
        if !isSessionActive && sessionStartTime != nil {
            resumeSession()
        }
        // Don't auto-start - let the EditorView manage session start/stop
    }

    private func checkInactivity() {
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)

        if timeSinceLastActivity >= inactivityThreshold && isSessionActive {
            pauseSession()
        }
    }

    // MARK: - Timer Management

    private func setupTimers() {
        // Don't start timers automatically
    }

    private func startTimers() {
        // Check for inactivity every 5 seconds
        activityTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkInactivity()
        }

        // Update duration and goals every second
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
            // Update goals every 5 seconds for real-time progress
            if let currentDuration = self?.currentSessionDuration, Int(currentDuration) % 5 == 0 {
                self?.updateGoalsWithCurrentTime()
            }
        }
    }

    private func stopTimers() {
        activityTimer?.invalidate()
        activityTimer = nil
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateDuration() {
        guard isSessionActive, let startTime = sessionStartTime else { return }

        let currentElapsed = Date().timeIntervalSince(startTime)
        currentSessionDuration = accumulatedTime + currentElapsed
    }

    // MARK: - Goal Integration
    
    // Public method to update time goals from external calls
    func updateTimeGoals() {
        updateGoalsWithCurrentTime()
    }

    private func updateGoalsWithCurrentTime(retryCount: Int = 0) {
        guard retryCount < 3 else { 
            print("Max retry attempts reached for time goal update")
            return 
        }
        
        let sessionMinutes = Int32((accumulatedTime + currentSessionDuration) / 60)
        let totalMinutesToday = Int32((totalTimeToday + accumulatedTime + currentSessionDuration) / 60)

        // Update all active time-based goals
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND goalType == %@", "time")

        do {
            let timeGoals = try context.fetch(request)
            var goalUpdated = false

            for goal in timeGoals {
                // All goals are now global (goal.sheet should be nil)
                // If goal has a sheet assigned (legacy), only update if we're writing in that sheet
                if let goalSheet = goal.sheet {
                    guard goalSheet == currentSheet else { continue }
                }

                // Refresh the goal object to get the latest state
                context.refresh(goal, mergeChanges: true)

                let previousCount = goal.currentCount
                // Only update if the value has changed to avoid unnecessary saves
                if previousCount != totalMinutesToday {
                    goal.currentCount = totalMinutesToday
                    goal.modifiedAt = Date()
                    goalUpdated = true
                    
                    // Check if goal is newly completed
                    if !goal.isCompleted && goal.currentCount >= goal.targetCount {
                        goal.isCompleted = true
                        print("⏱️ Time goal completed: \(goal.displayTitle)")
                        NotificationCenter.default.post(name: .goalCompleted, object: goal)
                    }
                }
            }

            if goalUpdated {
                try context.save()
                GoalsService.shared.objectWillChange.send()
            }
        } catch let error as NSError {
            if error.code == NSManagedObjectMergeError {
                // Handle merge conflicts by retrying after a short delay
                print("Core Data merge conflict in time goals, retrying... (attempt \(retryCount + 1))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateGoalsWithCurrentTime(retryCount: retryCount + 1)
                }
            } else {
                print("Failed to update time goals: \(error)")
            }
        }
    }

    // MARK: - Persistence

    private func loadTodaysTime() {
        let key = "totalTimeToday_\(todayKey())"
        let lastUpdateKey = "lastTimeUpdate"
        
        // Check if this is a new day
        let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastUpdate = lastUpdate {
            let lastUpdateDay = Calendar.current.startOfDay(for: lastUpdate)
            
            // If it's a new day, reset the total time
            if lastUpdateDay < today {
                totalTimeToday = 0
                UserDefaults.standard.set(0, forKey: key)
            } else {
                totalTimeToday = UserDefaults.standard.double(forKey: key)
            }
        } else {
            totalTimeToday = UserDefaults.standard.double(forKey: key)
        }
        
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
    }

    private func saveTodaysTime() {
        totalTimeToday += accumulatedTime + currentSessionDuration
        let key = "totalTimeToday_\(todayKey())"
        UserDefaults.standard.set(totalTimeToday, forKey: key)
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Computed Properties

    var totalMinutesToday: Int {
        return Int((totalTimeToday + accumulatedTime + currentSessionDuration) / 60)
    }

    var currentSessionMinutes: Int {
        return Int((accumulatedTime + currentSessionDuration) / 60)
    }

    var formattedSessionTime: String {
        return formatDuration(accumulatedTime + currentSessionDuration)
    }

    var formattedTotalTime: String {
        return formatDuration(totalTimeToday + accumulatedTime + currentSessionDuration)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let writingSessionStarted = Notification.Name("writingSessionStarted")
    static let writingSessionPaused = Notification.Name("writingSessionPaused")
    static let writingSessionEnded = Notification.Name("writingSessionEnded")
}
