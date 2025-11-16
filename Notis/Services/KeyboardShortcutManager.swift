//
//  KeyboardShortcutManager.swift
//  Notis
//
//  Created by Claude on 11/16/25.
//

import SwiftUI
import Combine

// MARK: - Shortcut Action

enum ShortcutAction: String, CaseIterable, Codable {
    // Navigation
    case commandPalette = "command_palette"
    case newSheet = "new_sheet"
    case settings = "settings"
    case toggleLibrary = "toggle_library"
    case toggleSheetList = "toggle_sheet_list"
    case toggleOutline = "toggle_outline"
    case toggleDashboard = "toggle_dashboard"
    case nextSheet = "next_sheet"
    case previousSheet = "previous_sheet"
    case navigateBack = "navigate_back"
    case navigateForward = "navigate_forward"

    // Editor
    case toggleFocusMode = "toggle_focus_mode"
    case toggleTypewriterMode = "toggle_typewriter_mode"
    case toggleFullScreen = "toggle_full_screen"
    case findReplace = "find_replace"
    case toggleFavorite = "toggle_favorite"

    // View Modes
    case allPanes = "all_panes"
    case sheetsOnly = "sheets_only"
    case editorOnly = "editor_only"

    // Secondary Editor
    case closeSecondaryEditor = "close_secondary_editor"
    case openInSecondaryEditor = "open_secondary_editor"

    // Templates & Tags
    case showTemplates = "show_templates"
    case tagSheet = "tag_sheet"
    case filterByTags = "filter_by_tags"

    // Help
    case showKeyboardShortcuts = "show_keyboard_shortcuts"

    var displayName: String {
        switch self {
        case .commandPalette: return "Command Palette"
        case .newSheet: return "New Sheet"
        case .settings: return "Settings"
        case .toggleLibrary: return "Toggle Library"
        case .toggleSheetList: return "Toggle Sheet List"
        case .toggleOutline: return "Toggle Outline"
        case .toggleDashboard: return "Toggle Dashboard"
        case .nextSheet: return "Next Sheet"
        case .previousSheet: return "Previous Sheet"
        case .navigateBack: return "Navigate Back"
        case .navigateForward: return "Navigate Forward"
        case .toggleFocusMode: return "Toggle Focus Mode"
        case .toggleTypewriterMode: return "Toggle Typewriter Mode"
        case .toggleFullScreen: return "Toggle Full Screen"
        case .findReplace: return "Find & Replace"
        case .toggleFavorite: return "Toggle Favorite"
        case .allPanes: return "All Panes"
        case .sheetsOnly: return "Sheets & Editor"
        case .editorOnly: return "Editor Only"
        case .closeSecondaryEditor: return "Close Secondary Editor"
        case .openInSecondaryEditor: return "Open in Secondary Editor"
        case .showTemplates: return "Show Templates"
        case .tagSheet: return "Tag Sheet"
        case .filterByTags: return "Filter by Tags"
        case .showKeyboardShortcuts: return "Show Keyboard Shortcuts"
        }
    }

    var category: ShortcutCategory {
        switch self {
        case .commandPalette, .newSheet, .settings, .toggleLibrary, .toggleSheetList,
             .toggleOutline, .toggleDashboard, .nextSheet, .previousSheet,
             .navigateBack, .navigateForward:
            return .navigation
        case .toggleFocusMode, .toggleTypewriterMode, .toggleFullScreen,
             .findReplace, .toggleFavorite:
            return .editor
        case .allPanes, .sheetsOnly, .editorOnly:
            return .viewModes
        case .closeSecondaryEditor, .openInSecondaryEditor:
            return .secondaryEditor
        case .showTemplates, .tagSheet, .filterByTags:
            return .templatesAndTags
        case .showKeyboardShortcuts:
            return .help
        }
    }
}

enum ShortcutCategory: String, CaseIterable {
    case navigation = "Navigation"
    case editor = "Editor"
    case viewModes = "View Modes"
    case secondaryEditor = "Secondary Editor"
    case templatesAndTags = "Templates & Tags"
    case help = "Help"
}

// MARK: - Keyboard Shortcut

struct KeyboardShortcut: Codable, Equatable, Hashable {
    let key: String
    let modifiers: EventModifiers

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }

        let keyDisplay: String
        switch key {
        case "leftArrow": keyDisplay = "←"
        case "rightArrow": keyDisplay = "→"
        case "upArrow": keyDisplay = "↑"
        case "downArrow": keyDisplay = "↓"
        case ",": keyDisplay = ","
        case "/": keyDisplay = "/"
        default: keyDisplay = key.uppercased()
        }
        parts.append(keyDisplay)

        return parts.joined()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(modifiers)
    }
}

// MARK: - Keyboard Shortcut Manager

@MainActor
class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()

    @Published private(set) var shortcuts: [ShortcutAction: KeyboardShortcut] = [:]

    private let userDefaultsKey = "customKeyboardShortcuts"

    init() {
        loadShortcuts()
    }

    // MARK: - Default Shortcuts

    private func defaultShortcuts() -> [ShortcutAction: KeyboardShortcut] {
        return [
            // Navigation
            .commandPalette: KeyboardShortcut(key: "k", modifiers: .command),
            .newSheet: KeyboardShortcut(key: "n", modifiers: .command),
            .settings: KeyboardShortcut(key: ",", modifiers: .command),
            .toggleLibrary: KeyboardShortcut(key: "l", modifiers: [.command, .shift]),
            .toggleSheetList: KeyboardShortcut(key: "r", modifiers: [.command, .shift]),
            .toggleOutline: KeyboardShortcut(key: "o", modifiers: .command),
            .toggleDashboard: KeyboardShortcut(key: "d", modifiers: [.command, .shift]),
            .nextSheet: KeyboardShortcut(key: "rightArrow", modifiers: .command),
            .previousSheet: KeyboardShortcut(key: "leftArrow", modifiers: .command),
            .navigateBack: KeyboardShortcut(key: "leftArrow", modifiers: .command),
            .navigateForward: KeyboardShortcut(key: "rightArrow", modifiers: .command),

            // Editor
            .toggleFocusMode: KeyboardShortcut(key: "f", modifiers: .command),
            .toggleTypewriterMode: KeyboardShortcut(key: "t", modifiers: .command),
            .toggleFullScreen: KeyboardShortcut(key: "f", modifiers: [.command, .control]),
            .findReplace: KeyboardShortcut(key: "f", modifiers: .command),
            .toggleFavorite: KeyboardShortcut(key: "d", modifiers: .command),

            // View Modes
            .allPanes: KeyboardShortcut(key: "1", modifiers: .command),
            .sheetsOnly: KeyboardShortcut(key: "2", modifiers: .command),
            .editorOnly: KeyboardShortcut(key: "3", modifiers: .command),

            // Secondary Editor
            .closeSecondaryEditor: KeyboardShortcut(key: "w", modifiers: [.command, .shift]),
            .openInSecondaryEditor: KeyboardShortcut(key: "o", modifiers: [.command, .shift]),

            // Templates & Tags
            .showTemplates: KeyboardShortcut(key: "t", modifiers: [.command, .shift]),
            .tagSheet: KeyboardShortcut(key: "t", modifiers: .command),
            .filterByTags: KeyboardShortcut(key: "f", modifiers: [.command, .shift]),

            // Help
            .showKeyboardShortcuts: KeyboardShortcut(key: "/", modifiers: .command)
        ]
    }

    // MARK: - Public Methods

    func getShortcut(for action: ShortcutAction) -> KeyboardShortcut? {
        return shortcuts[action]
    }

    func setShortcut(_ shortcut: KeyboardShortcut, for action: ShortcutAction) {
        // Check for conflicts
        if let conflictingAction = shortcuts.first(where: { $0.key != action && $0.value == shortcut })?.key {
            // Remove the conflicting shortcut
            shortcuts[conflictingAction] = nil
        }

        shortcuts[action] = shortcut
        saveShortcuts()
    }

    func removeShortcut(for action: ShortcutAction) {
        shortcuts[action] = nil
        saveShortcuts()
    }

    func resetToDefaults() {
        shortcuts = defaultShortcuts()
        saveShortcuts()
    }

    func resetAction(_ action: ShortcutAction) {
        shortcuts[action] = defaultShortcuts()[action]
        saveShortcuts()
    }

    // MARK: - Persistence

    private func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ShortcutAction: KeyboardShortcut].self, from: data) {
            shortcuts = decoded
        } else {
            shortcuts = defaultShortcuts()
        }
    }

    private func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
}

// MARK: - EventModifiers Codable Extension

extension EventModifiers: Codable {
    enum CodingKeys: String, CodingKey {
        case rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        self.init(rawValue: rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .rawValue)
    }
}

// MARK: - EventModifiers Hashable Extension

extension EventModifiers: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
