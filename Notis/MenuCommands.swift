//
//  MenuCommands.swift
//  Notis
//
//  Created by Mike on 11/18/25.
//

import SwiftUI

#if os(macOS)
import AppKit

// MARK: - App Commands

struct NotisCommands: Commands {
    var body: some Commands {
        // Replace default New Window command
        CommandGroup(replacing: .newItem) {
            FileMenuCommands()
        }

        // Replace default pasteboard commands
        CommandGroup(replacing: .pasteboard) {
            EditMenuCommands()
        }

        // Add Markup menu after Edit
        CommandMenu("Markup") {
            MarkupMenuCommands()
        }

        // Replace default View commands
        CommandGroup(replacing: .sidebar) {
            ViewMenuCommands()
        }

        // Add Go menu
        CommandMenu("Go") {
            GoMenuCommands()
        }

        // Add Window menu items
        CommandGroup(after: .windowSize) {
            WindowMenuCommands()
        }

        // Settings in app menu
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

// MARK: - File Menu Commands

struct FileMenuCommands: View {
    var body: some View {
        Button("New Sheet") {
            NotificationCenter.default.post(name: .menuNewSheet, object: nil)
        }
        .keyboardShortcut("n", modifiers: .command)

        Button("New Group") {
            NotificationCenter.default.post(name: .menuNewGroup, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("New Project") {
            NotificationCenter.default.post(name: .menuNewProject, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .option])

        Divider()

        Button("Toggle Favorite") {
            NotificationCenter.default.post(name: .menuToggleFavorite, object: nil)
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])
    }
}

// MARK: - Edit Menu Commands

struct EditMenuCommands: View {
    var body: some View {
        Button("Copy") {
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
        }
        .keyboardShortcut("c", modifiers: .command)

        Button("Paste") {
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
        }
        .keyboardShortcut("v", modifiers: .command)

        Button("Cut") {
            NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
        }
        .keyboardShortcut("x", modifiers: .command)

        Divider()

        Button("Select All") {
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
        .keyboardShortcut("a", modifiers: .command)

        Divider()

        Button("Move to Trash") {
            NotificationCenter.default.post(name: .menuMoveToTrash, object: nil)
        }
        .keyboardShortcut(.delete, modifiers: .command)
    }
}

// MARK: - Markup Menu Commands

struct MarkupMenuCommands: View {
    var body: some View {
        Button("Bold") {
            NotificationCenter.default.post(name: .menuBold, object: nil)
        }
        .keyboardShortcut("b", modifiers: .command)

        Button("Italic") {
            NotificationCenter.default.post(name: .menuItalic, object: nil)
        }
        .keyboardShortcut("i", modifiers: .command)

        Button("Highlight") {
            NotificationCenter.default.post(name: .menuHighlight, object: nil)
        }
        .keyboardShortcut("h", modifiers: [.command, .shift])

        Button("Strikethrough") {
            NotificationCenter.default.post(name: .menuStrikethrough, object: nil)
        }
        .keyboardShortcut("u", modifiers: [.command, .shift])

        Divider()

        Button("Heading 1") {
            NotificationCenter.default.post(name: .menuHeading, object: 1)
        }
        .keyboardShortcut("1", modifiers: [.command, .option])

        Button("Heading 2") {
            NotificationCenter.default.post(name: .menuHeading, object: 2)
        }
        .keyboardShortcut("2", modifiers: [.command, .option])

        Button("Heading 3") {
            NotificationCenter.default.post(name: .menuHeading, object: 3)
        }
        .keyboardShortcut("3", modifiers: [.command, .option])
    }
}

// MARK: - View Menu Commands

struct ViewMenuCommands: View {
    var body: some View {
        Button("Toggle Library") {
            NotificationCenter.default.post(name: .menuToggleLibrary, object: nil)
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])

        Button("Toggle Second Editor") {
            NotificationCenter.default.post(name: .menuToggleSecondEditor, object: nil)
        }
        .keyboardShortcut("\\", modifiers: .command)

        Divider()

        Button("Toggle Progress") {
            NotificationCenter.default.post(name: .menuToggleProgress, object: nil)
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])

        Button("Toggle Tags") {
            NotificationCenter.default.post(name: .menuToggleTags, object: nil)
        }
        .keyboardShortcut("t", modifiers: [.command, .option])

        Button("Toggle Line Numbers") {
            NotificationCenter.default.post(name: .menuToggleLineNumbers, object: nil)
        }
        .keyboardShortcut("l", modifiers: [.command, .option])

        Divider()

        Menu("Theme") {
            Button("Light") {
                NotificationCenter.default.post(name: .menuTheme, object: "light")
            }
            Button("Dark") {
                NotificationCenter.default.post(name: .menuTheme, object: "dark")
            }
            Button("System") {
                NotificationCenter.default.post(name: .menuTheme, object: "system")
            }
        }

        Divider()

        Button("Toggle Focus Mode") {
            NotificationCenter.default.post(name: .menuToggleFocusMode, object: nil)
        }
        .keyboardShortcut("f", modifiers: [.command, .control])

        Button("Toggle Typewriter Mode") {
            NotificationCenter.default.post(name: .menuToggleTypewriterMode, object: nil)
        }
        .keyboardShortcut("y", modifiers: .command)
    }
}

// MARK: - Go Menu Commands

struct GoMenuCommands: View {
    var body: some View {
        Button("All Sheets") {
            NotificationCenter.default.post(name: .menuGoAll, object: nil)
        }
        .keyboardShortcut("a", modifiers: [.command, .option])

        Button("Last 7 Days") {
            NotificationCenter.default.post(name: .menuGoRecent, object: nil)
        }
        .keyboardShortcut("7", modifiers: [.command, .option])

        Divider()

        Button("Previous Sheet") {
            NotificationCenter.default.post(name: .menuPreviousSheet, object: nil)
        }
        .keyboardShortcut(.leftArrow, modifiers: .command)

        Button("Next Sheet") {
            NotificationCenter.default.post(name: .menuNextSheet, object: nil)
        }
        .keyboardShortcut(.rightArrow, modifiers: .command)

        Divider()

        Button("Library") {
            NotificationCenter.default.post(name: .menuGoLibrary, object: nil)
        }
        .keyboardShortcut("l", modifiers: [.command, .option])

        Button("Sheet List") {
            NotificationCenter.default.post(name: .menuGoSheetList, object: nil)
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])

        Button("Editor") {
            NotificationCenter.default.post(name: .menuGoEditor, object: nil)
        }
        .keyboardShortcut("e", modifiers: [.command, .option])

        Button("Dashboard") {
            NotificationCenter.default.post(name: .menuGoDashboard, object: nil)
        }
        .keyboardShortcut("d", modifiers: [.command, .shift])
    }
}

// MARK: - Window Menu Commands

struct WindowMenuCommands: View {
    var body: some View {
        Divider()

        Button("New Tab") {
            NotificationCenter.default.post(name: .menuNewTab, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command, .option, .shift])

        Divider()

        Button("Export...") {
            NotificationCenter.default.post(name: .menuExport, object: nil)
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])

        Button("Export to Obsidian") {
            NotificationCenter.default.post(name: .menuExportToObsidian, object: nil)
        }
        .keyboardShortcut("o", modifiers: [.command, .option])

        Divider()

        Button("Statistics") {
            NotificationCenter.default.post(name: .menuStatistics, object: nil)
        }
        .keyboardShortcut("s", modifiers: [.command, .option])

        Button("Navigation") {
            NotificationCenter.default.post(name: .menuNavigation, object: nil)
        }

        Button("Keyboard Shortcuts") {
            NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
        }
        .keyboardShortcut("/", modifiers: .command)
    }
}

#endif

// MARK: - Menu Notification Names

extension Notification.Name {
    // File Menu
    static let menuNewSheet = Notification.Name("menuNewSheet")
    static let menuNewGroup = Notification.Name("menuNewGroup")
    static let menuNewProject = Notification.Name("menuNewProject")
    static let menuToggleFavorite = Notification.Name("menuToggleFavorite")

    // Edit Menu
    static let menuMoveToTrash = Notification.Name("menuMoveToTrash")

    // Markup Menu
    static let menuBold = Notification.Name("menuBold")
    static let menuItalic = Notification.Name("menuItalic")
    static let menuHighlight = Notification.Name("menuHighlight")
    static let menuStrikethrough = Notification.Name("menuStrikethrough")
    static let menuHeading = Notification.Name("menuHeading")

    // View Menu
    static let menuToggleLibrary = Notification.Name("menuToggleLibrary")
    static let menuToggleSecondEditor = Notification.Name("menuToggleSecondEditor")
    static let menuToggleProgress = Notification.Name("menuToggleProgress")
    static let menuToggleTags = Notification.Name("menuToggleTags")
    static let menuToggleLineNumbers = Notification.Name("menuToggleLineNumbers")
    static let menuTheme = Notification.Name("menuTheme")
    static let menuToggleFocusMode = Notification.Name("menuToggleFocusMode")
    static let menuToggleTypewriterMode = Notification.Name("menuToggleTypewriterMode")

    // Go Menu
    static let menuGoAll = Notification.Name("menuGoAll")
    static let menuGoRecent = Notification.Name("menuGoRecent")
    static let menuPreviousSheet = Notification.Name("menuPreviousSheet")
    static let menuNextSheet = Notification.Name("menuNextSheet")
    static let menuGoLibrary = Notification.Name("menuGoLibrary")
    static let menuGoSheetList = Notification.Name("menuGoSheetList")
    static let menuGoEditor = Notification.Name("menuGoEditor")
    static let menuGoDashboard = Notification.Name("menuGoDashboard")

    // Window Menu
    static let menuNewTab = Notification.Name("menuNewTab")
    static let menuExport = Notification.Name("menuExport")
    static let menuExportToObsidian = Notification.Name("menuExportToObsidian")
    static let menuStatistics = Notification.Name("menuStatistics")
    static let menuNavigation = Notification.Name("menuNavigation")

    // Format commands (for editor)
    static let formatBold = Notification.Name("formatBold")
    static let formatItalic = Notification.Name("formatItalic")
    static let formatHighlight = Notification.Name("formatHighlight")
    static let formatStrikethrough = Notification.Name("formatStrikethrough")
    static let formatHeading = Notification.Name("formatHeading")
}
