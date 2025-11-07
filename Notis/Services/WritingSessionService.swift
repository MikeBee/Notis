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

        // Update duration every second
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
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

    private func updateGoalsWithCurrentTime() {
        let totalMinutes = Int32((accumulatedTime + currentSessionDuration) / 60)

        // Update all active time-based goals
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND goalType == %@", "time")

        do {
            let timeGoals = try context.fetch(request)

            for goal in timeGoals {
                // If goal is for a specific sheet, only update if we're writing in that sheet
                if let goalSheet = goal.sheet {
                    guard goalSheet == currentSheet else { continue }
                }

                // Update the goal's current count
                goal.currentCount = totalMinutes
                goal.modifiedAt = Date()

                // Check if goal is completed
                if !goal.isCompleted && goal.currentCount >= goal.targetCount {
                    goal.isCompleted = true
                    NotificationCenter.default.post(name: .goalCompleted, object: goal)
                }
            }

            try context.save()
            GoalsService.shared.objectWillChange.send()
        } catch {
            print("Failed to update time goals: \(error)")
        }
    }

    // MARK: - Persistence

    private func loadTodaysTime() {
        let key = "totalTimeToday_\(todayKey())"
        totalTimeToday = UserDefaults.standard.double(forKey: key)
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
