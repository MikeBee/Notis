//
//  Logger.swift
//  Notis
//
//  Created by Claude Code
//

import Foundation
import OSLog

/// Logging levels for the application
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Categories for organizing logs
enum LogCategory: String {
    case coreData = "CoreData"
    case fileSystem = "FileSystem"
    case backup = "Backup"
    case tags = "Tags"
    case sync = "Sync"
    case ui = "UI"
    case network = "Network"
    case goals = "Goals"
    case templates = "Templates"
    case export = "Export"
    case general = "General"
}

/// Structured logging service for Notis
class Logger {

    static let shared = Logger()

    // Minimum log level to display (configurable)
    var minimumLogLevel: LogLevel = {
        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }()

    // Whether to show user-facing toasts for errors
    var showUserToasts: Bool = true

    // OSLog for system-level logging
    private let osLog = OSLog(subsystem: "com.notis.app", category: "Notis")

    private init() {}

    // MARK: - Public Logging Methods

    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: LogCategory = .general, userMessage: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
        if let userMessage = userMessage, showUserToasts {
            showToast(userMessage, type: .warning)
        }
    }

    func error(_ message: String, error: Error? = nil, category: LogCategory = .general, userMessage: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error, category: category, file: file, function: function, line: line)

        if let userMessage = userMessage, showUserToasts {
            showToast(userMessage, type: .error)
        }
    }

    func critical(_ message: String, error: Error? = nil, category: LogCategory = .general, userMessage: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .critical, category: category, file: file, function: function, line: line)

        if let userMessage = userMessage, showUserToasts {
            showToast(userMessage, type: .error)
        }
    }

    // MARK: - Private Methods

    private func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        guard level >= minimumLogLevel else { return }

        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logTimestamp.string(from: Date())

        // Format: [Timestamp] [Level] [Category] [File:Line] Message
        let logMessage = "[\(timestamp)] \(level.emoji) [\(category.rawValue)] [\(fileName):\(line)] \(message)"

        // Print to console
        print(logMessage)

        // Also log to OSLog for system integration
        os_log("%{public}@", log: osLog, type: level.osLogType, logMessage)
    }

    private func showToast(_ message: String, type: ToastType) {
        DispatchQueue.main.async {
            ToastManager.shared.show(message, type: type)
        }
    }
}

// MARK: - Convenience Extensions

extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Toast Type Extension

enum ToastType {
    case success
    case info
    case warning
    case error
}

extension ToastManager {
    func show(_ message: String, type: ToastType) {
        let icon: String
        switch type {
        case .success:
            icon = "checkmark.circle.fill"
        case .info:
            icon = "info.circle.fill"
        case .warning:
            icon = "exclamationmark.triangle.fill"
        case .error:
            icon = "xmark.circle.fill"
        }
        show(message, icon: icon)
    }
}
