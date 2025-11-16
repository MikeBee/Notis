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
    case quickOpenSheet = "quick_open_sheet"

    // Editor - Basic
    case toggleFocusMode = "toggle_focus_mode"
    case toggleTypewriterMode = "toggle_typewriter_mode"
    case toggleFullScreen = "toggle_full_screen"
    case findReplace = "find_replace"
    case findNext = "find_next"
    case findPrevious = "find_previous"
    case findInAllSheets = "find_in_all_sheets"
    case toggleFavorite = "toggle_favorite"

    // Text Formatting
    case bold = "bold"
    case italic = "italic"
    case strikethrough = "strikethrough"
    case highlight = "highlight"
    case annotate = "annotate"
    case insertLink = "insert_link"
    case insertCodeBlock = "insert_code_block"
    case insertQuote = "insert_quote"
    case insertBulletList = "insert_bullet_list"
    case insertNumberedList = "insert_numbered_list"

    // Document Management
    case saveNow = "save_now"
    case duplicateSheet = "duplicate_sheet"
    case deleteSheet = "delete_sheet"
    case renameSheet = "rename_sheet"
    case exportToPDF = "export_to_pdf"
    case exportToObsidian = "export_to_obsidian"
    case exportAll = "export_all"
    case newSheetFromTemplate = "new_sheet_from_template"

    // View & Display
    case increaseFontSize = "increase_font_size"
    case decreaseFontSize = "decrease_font_size"
    case resetFontSize = "reset_font_size"
    case toggleWordCounter = "toggle_word_counter"
    case toggleLineNumbers = "toggle_line_numbers"
    case toggleOutlinePane = "toggle_outline_pane"
    case toggleTagsPane = "toggle_tags_pane"

    // View Modes
    case allPanes = "all_panes"
    case sheetsOnly = "sheets_only"
    case editorOnly = "editor_only"

    // Secondary Editor
    case toggleSecondaryEditor = "toggle_secondary_editor"
    case openInSecondaryEditor = "open_secondary_editor"
    case closeSecondaryEditor = "close_secondary_editor"
    case focusSecondaryEditor = "focus_secondary_editor"
    case focusPrimaryEditor = "focus_primary_editor"
    case cloneToSecondaryEditor = "clone_to_secondary_editor"

    // Goals & Writing
    case viewGoals = "view_goals"
    case quickAddGoal = "quick_add_goal"
    case startStopSession = "start_stop_session"
    case viewGoalsHistory = "view_goals_history"
    case viewWritingStatistics = "view_writing_statistics"

    // Organization
    case moveToPreviousGroup = "move_to_previous_group"
    case moveToNextGroup = "move_to_next_group"
    case archiveSheet = "archive_sheet"
    case pinSheet = "pin_sheet"
    case moveToGroup = "move_to_group"

    // Templates & Tags
    case showTemplates = "show_templates"
    case tagSheet = "tag_sheet"
    case filterByTags = "filter_by_tags"

    // System & Utilities
    case showDocumentInfo = "show_document_info"
    case showAllStatistics = "show_all_statistics"
    case toggleInspector = "toggle_inspector"
    case viewBackups = "view_backups"
    case databaseMaintenance = "database_maintenance"
    case refreshSheet = "refresh_sheet"

    // Help
    case showKeyboardShortcuts = "show_keyboard_shortcuts"

    var displayName: String {
        switch self {
        // Navigation
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
        case .quickOpenSheet: return "Quick Open Sheet"

        // Editor - Basic
        case .toggleFocusMode: return "Toggle Focus Mode"
        case .toggleTypewriterMode: return "Toggle Typewriter Mode"
        case .toggleFullScreen: return "Toggle Full Screen"
        case .findReplace: return "Find & Replace"
        case .findNext: return "Find Next"
        case .findPrevious: return "Find Previous"
        case .findInAllSheets: return "Find in All Sheets"
        case .toggleFavorite: return "Toggle Favorite"

        // Text Formatting
        case .bold: return "Bold"
        case .italic: return "Italic"
        case .strikethrough: return "Strikethrough"
        case .highlight: return "Highlight"
        case .annotate: return "Annotate"
        case .insertLink: return "Insert Link"
        case .insertCodeBlock: return "Insert Code Block"
        case .insertQuote: return "Insert Quote"
        case .insertBulletList: return "Insert Bullet List"
        case .insertNumberedList: return "Insert Numbered List"

        // Document Management
        case .saveNow: return "Save Now"
        case .duplicateSheet: return "Duplicate Sheet"
        case .deleteSheet: return "Delete Sheet"
        case .renameSheet: return "Rename Sheet"
        case .exportToPDF: return "Export to PDF"
        case .exportToObsidian: return "Export to Obsidian"
        case .exportAll: return "Export All Sheets"
        case .newSheetFromTemplate: return "New Sheet from Template"

        // View & Display
        case .increaseFontSize: return "Increase Font Size"
        case .decreaseFontSize: return "Decrease Font Size"
        case .resetFontSize: return "Reset Font Size"
        case .toggleWordCounter: return "Toggle Word Counter"
        case .toggleLineNumbers: return "Toggle Line Numbers"
        case .toggleOutlinePane: return "Toggle Outline Pane"
        case .toggleTagsPane: return "Toggle Tags Pane"

        // View Modes
        case .allPanes: return "All Panes"
        case .sheetsOnly: return "Sheets & Editor"
        case .editorOnly: return "Editor Only"

        // Secondary Editor
        case .toggleSecondaryEditor: return "Toggle Secondary Editor"
        case .openInSecondaryEditor: return "Open in Secondary Editor"
        case .closeSecondaryEditor: return "Close Secondary Editor"
        case .focusSecondaryEditor: return "Focus Secondary Editor"
        case .focusPrimaryEditor: return "Focus Primary Editor"
        case .cloneToSecondaryEditor: return "Clone to Secondary Editor"

        // Goals & Writing
        case .viewGoals: return "View Goals"
        case .quickAddGoal: return "Quick Add Goal"
        case .startStopSession: return "Start/Stop Writing Session"
        case .viewGoalsHistory: return "View Goals History"
        case .viewWritingStatistics: return "View Writing Statistics"

        // Organization
        case .moveToPreviousGroup: return "Move to Previous Group"
        case .moveToNextGroup: return "Move to Next Group"
        case .archiveSheet: return "Archive Sheet"
        case .pinSheet: return "Pin/Unpin Sheet"
        case .moveToGroup: return "Move to Group"

        // Templates & Tags
        case .showTemplates: return "Show Templates"
        case .tagSheet: return "Tag Sheet"
        case .filterByTags: return "Filter by Tags"

        // System & Utilities
        case .showDocumentInfo: return "Show Document Info"
        case .showAllStatistics: return "Show All Statistics"
        case .toggleInspector: return "Toggle Inspector"
        case .viewBackups: return "View Backups"
        case .databaseMaintenance: return "Database Maintenance"
        case .refreshSheet: return "Refresh Sheet"

        // Help
        case .showKeyboardShortcuts: return "Show Keyboard Shortcuts"
        }
    }

    var category: ShortcutCategory {
        switch self {
        case .commandPalette, .newSheet, .settings, .toggleLibrary, .toggleSheetList,
             .toggleOutline, .toggleDashboard, .nextSheet, .previousSheet,
             .navigateBack, .navigateForward, .quickOpenSheet:
            return .navigation
        case .toggleFocusMode, .toggleTypewriterMode, .toggleFullScreen,
             .findReplace, .findNext, .findPrevious, .findInAllSheets, .toggleFavorite:
            return .editor
        case .bold, .italic, .strikethrough, .highlight, .annotate, .insertLink,
             .insertCodeBlock, .insertQuote, .insertBulletList, .insertNumberedList:
            return .formatting
        case .saveNow, .duplicateSheet, .deleteSheet, .renameSheet, .exportToPDF,
             .exportToObsidian, .exportAll, .newSheetFromTemplate:
            return .documentManagement
        case .increaseFontSize, .decreaseFontSize, .resetFontSize, .toggleWordCounter,
             .toggleLineNumbers, .toggleOutlinePane, .toggleTagsPane:
            return .viewAndDisplay
        case .allPanes, .sheetsOnly, .editorOnly:
            return .viewModes
        case .toggleSecondaryEditor, .openInSecondaryEditor, .closeSecondaryEditor,
             .focusSecondaryEditor, .focusPrimaryEditor, .cloneToSecondaryEditor:
            return .secondaryEditor
        case .viewGoals, .quickAddGoal, .startStopSession, .viewGoalsHistory,
             .viewWritingStatistics:
            return .goalsAndWriting
        case .moveToPreviousGroup, .moveToNextGroup, .archiveSheet, .pinSheet, .moveToGroup:
            return .organization
        case .showTemplates, .tagSheet, .filterByTags:
            return .templatesAndTags
        case .showDocumentInfo, .showAllStatistics, .toggleInspector, .viewBackups,
             .databaseMaintenance, .refreshSheet:
            return .systemAndUtilities
        case .showKeyboardShortcuts:
            return .help
        }
    }

    var needsConfirmation: Bool {
        switch self {
        case .deleteSheet, .exportToObsidian:
            return true
        default:
            return false
        }
    }
}

enum ShortcutCategory: String, CaseIterable {
    case navigation = "Navigation"
    case editor = "Editor"
    case formatting = "Text Formatting"
    case documentManagement = "Document Management"
    case viewAndDisplay = "View & Display"
    case viewModes = "View Modes"
    case secondaryEditor = "Secondary Editor"
    case goalsAndWriting = "Goals & Writing"
    case organization = "Organization"
    case templatesAndTags = "Templates & Tags"
    case systemAndUtilities = "System & Utilities"
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
            .navigateBack: KeyboardShortcut(key: "[", modifiers: .command),
            .navigateForward: KeyboardShortcut(key: "]", modifiers: .command),
            .quickOpenSheet: KeyboardShortcut(key: "o", modifiers: [.command, .shift]),

            // Editor - Basic (FIXED CONFLICTS)
            .toggleFocusMode: KeyboardShortcut(key: "f", modifiers: [.command, .shift]),
            .toggleTypewriterMode: KeyboardShortcut(key: "t", modifiers: [.command, .shift]),
            .toggleFullScreen: KeyboardShortcut(key: "f", modifiers: [.command, .control]),
            .findReplace: KeyboardShortcut(key: "f", modifiers: .command),
            .findNext: KeyboardShortcut(key: "g", modifiers: .command),
            .findPrevious: KeyboardShortcut(key: "g", modifiers: [.command, .shift]),
            .findInAllSheets: KeyboardShortcut(key: "f", modifiers: [.option, .command]),
            .toggleFavorite: KeyboardShortcut(key: "d", modifiers: .command),

            // Text Formatting
            .bold: KeyboardShortcut(key: "b", modifiers: .command),
            .italic: KeyboardShortcut(key: "i", modifiers: .command),
            .strikethrough: KeyboardShortcut(key: "u", modifiers: .command),
            .highlight: KeyboardShortcut(key: "h", modifiers: [.command, .shift]),
            .annotate: KeyboardShortcut(key: "'", modifiers: .command),
            .insertLink: KeyboardShortcut(key: "k", modifiers: [.command, .shift]),
            .insertCodeBlock: KeyboardShortcut(key: "c", modifiers: [.option, .command]),
            .insertQuote: KeyboardShortcut(key: "q", modifiers: [.option, .command]),
            .insertBulletList: KeyboardShortcut(key: "l", modifiers: .command),
            .insertNumberedList: KeyboardShortcut(key: "l", modifiers: [.option, .command]),

            // Document Management
            .saveNow: KeyboardShortcut(key: "s", modifiers: .command),
            .duplicateSheet: KeyboardShortcut(key: "d", modifiers: [.command, .shift]),
            .deleteSheet: KeyboardShortcut(key: "delete", modifiers: .command),
            .renameSheet: KeyboardShortcut(key: "r", modifiers: .command),
            .exportToPDF: KeyboardShortcut(key: "p", modifiers: .command),
            .exportToObsidian: KeyboardShortcut(key: "e", modifiers: .command),
            .exportAll: KeyboardShortcut(key: "e", modifiers: [.command, .shift]),
            .newSheetFromTemplate: KeyboardShortcut(key: "n", modifiers: [.command, .shift]),

            // View & Display
            .increaseFontSize: KeyboardShortcut(key: "=", modifiers: .command),
            .decreaseFontSize: KeyboardShortcut(key: "-", modifiers: .command),
            .resetFontSize: KeyboardShortcut(key: "0", modifiers: .command),
            .toggleWordCounter: KeyboardShortcut(key: "w", modifiers: [.option, .command]),
            .toggleLineNumbers: KeyboardShortcut(key: "n", modifiers: [.option, .command]),
            .toggleOutlinePane: KeyboardShortcut(key: "\\", modifiers: .command),
            .toggleTagsPane: KeyboardShortcut(key: "\\", modifiers: [.option, .command]),

            // View Modes
            .allPanes: KeyboardShortcut(key: "1", modifiers: .command),
            .sheetsOnly: KeyboardShortcut(key: "2", modifiers: .command),
            .editorOnly: KeyboardShortcut(key: "3", modifiers: .command),

            // Secondary Editor
            .toggleSecondaryEditor: KeyboardShortcut(key: "\\", modifiers: [.command, .shift]),
            .openInSecondaryEditor: KeyboardShortcut(key: "o", modifiers: [.command, .option]),
            .closeSecondaryEditor: KeyboardShortcut(key: "w", modifiers: [.command, .shift]),
            .focusSecondaryEditor: KeyboardShortcut(key: "rightArrow", modifiers: [.command, .option]),
            .focusPrimaryEditor: KeyboardShortcut(key: "leftArrow", modifiers: [.command, .option]),
            .cloneToSecondaryEditor: KeyboardShortcut(key: "c", modifiers: [.command, .shift]),

            // Goals & Writing
            .viewGoals: KeyboardShortcut(key: "g", modifiers: [.command, .shift]),
            .quickAddGoal: KeyboardShortcut(key: "g", modifiers: [.option, .command]),
            .startStopSession: KeyboardShortcut(key: "s", modifiers: [.command, .shift]),
            .viewGoalsHistory: KeyboardShortcut(key: "h", modifiers: [.option, .command]),
            .viewWritingStatistics: KeyboardShortcut(key: "w", modifiers: [.command, .shift]),

            // Organization
            .moveToPreviousGroup: KeyboardShortcut(key: "[", modifiers: [.command, .shift]),
            .moveToNextGroup: KeyboardShortcut(key: "]", modifiers: [.command, .shift]),
            .archiveSheet: KeyboardShortcut(key: "a", modifiers: [.command, .shift]),
            .pinSheet: KeyboardShortcut(key: "p", modifiers: [.command, .shift]),
            .moveToGroup: KeyboardShortcut(key: "m", modifiers: [.command, .shift]),

            // Templates & Tags (FIXED CONFLICT - tagSheet was ⌘T, now ⌘')
            .showTemplates: KeyboardShortcut(key: "t", modifiers: .command),
            .tagSheet: KeyboardShortcut(key: "'", modifiers: [.command, .shift]),
            .filterByTags: KeyboardShortcut(key: "t", modifiers: [.option, .command]),

            // System & Utilities
            .showDocumentInfo: KeyboardShortcut(key: "i", modifiers: .command),
            .showAllStatistics: KeyboardShortcut(key: "i", modifiers: [.command, .shift]),
            .toggleInspector: KeyboardShortcut(key: "i", modifiers: [.command, .option]),
            .viewBackups: KeyboardShortcut(key: "b", modifiers: [.command, .option]),
            .databaseMaintenance: KeyboardShortcut(key: "m", modifiers: [.command, .option]),
            .refreshSheet: KeyboardShortcut(key: "r", modifiers: [.option, .command]),

            // Help
            .showKeyboardShortcuts: KeyboardShortcut(key: "/", modifiers: .command)
        ]
    }

    // MARK: - Public Methods

    func getShortcut(for action: ShortcutAction) -> KeyboardShortcut? {
        return shortcuts[action]
    }

    func checkForConflict(_ shortcut: KeyboardShortcut, excluding action: ShortcutAction? = nil) -> ShortcutAction? {
        return shortcuts.first(where: { key, value in
            key != action && value == shortcut
        })?.key
    }

    func setShortcut(_ shortcut: KeyboardShortcut, for action: ShortcutAction, replacing: Bool = true) -> ShortcutAction? {
        // Check for conflicts
        let conflictingAction = checkForConflict(shortcut, excluding: action)

        if let conflict = conflictingAction, replacing {
            // Remove the conflicting shortcut
            shortcuts[conflict] = nil
        }

        shortcuts[action] = shortcut
        saveShortcuts()

        return conflictingAction
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
