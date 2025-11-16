//
//  KeyboardShortcutsHelp.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI

struct KeyboardKey: View {
    let key: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if key == "⌘" || key == "⇧" || key == "⌥" || key == "⌃" {
            Text(key)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        } else if isMarkdownSyntax {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(markdownBackground)
        } else {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(keyBackground)
        }
    }
    
    private var isMarkdownSyntax: Bool {
        key.contains("#") || key.contains("*") || key.contains("-") || key.contains("1.")
    }
    
    private var markdownBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(colorScheme == .dark ? Color.blue.opacity(0.4) : Color.blue.opacity(0.3), lineWidth: 0.5)
            )
    }
    
    private var keyBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 0.5)
            )
    }
}

struct KeyboardShortcutsHelp: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var shortcutManager = KeyboardShortcutManager.shared
    @State private var searchText = ""

    private struct DisplayShortcut {
        let action: ShortcutAction
        let keys: String
        let description: String
        let needsConfirmation: Bool
    }

    private struct ShortcutRow: View {
        let shortcut: DisplayShortcut

        var body: some View {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    // Display shortcuts as individual keys
                    ForEach(shortcut.keys.map(String.init), id: \.self) { key in
                        KeyboardKey(key: key)
                    }
                }
                .frame(width: 110, alignment: .leading)

                HStack(spacing: 4) {
                    Text(shortcut.description)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)

                    if shortcut.needsConfirmation {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 1)
            .padding(.horizontal, 2)
        }
    }

    private var filteredCategories: [ShortcutCategory] {
        if searchText.isEmpty {
            return ShortcutCategory.allCases
        }
        return ShortcutCategory.allCases.filter { category in
            getShortcuts(for: category).contains { shortcut in
                shortcut.description.localizedCaseInsensitiveContains(searchText) ||
                shortcut.keys.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func getShortcuts(for category: ShortcutCategory) -> [DisplayShortcut] {
        let actions = ShortcutAction.allCases.filter { $0.category == category }
        return actions.compactMap { action in
            guard let shortcut = shortcutManager.getShortcut(for: action) else { return nil }
            return DisplayShortcut(
                action: action,
                keys: shortcut.displayString,
                description: action.displayName,
                needsConfirmation: action.needsConfirmation
            )
        }.filter { shortcut in
            if searchText.isEmpty { return true }
            return shortcut.description.localizedCaseInsensitiveContains(searchText) ||
                   shortcut.keys.localizedCaseInsensitiveContains(searchText)
        }
    }

    private let markdownShortcuts: [(String, String)] = [
        ("# Text", "Large Header"),
        ("## Text", "Medium Header"),
        ("### Text", "Small Header"),
        ("**text**", "Bold Text"),
        ("*text*", "Italic Text"),
        ("~~text~~", "Strikethrough"),
        ("==text==", "Highlight"),
        ("::text::", "Annotation"),
        ("- Item", "Bullet List"),
        ("1. Item", "Numbered List"),
        ("> Quote", "Block Quote"),
        ("`code`", "Inline Code"),
        ("```code```", "Code Block")
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Keyboard Shortcuts")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    TextField("Search shortcuts...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Divider()

                // Shortcuts content
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        // Keyboard shortcuts from manager
                        ForEach(filteredCategories, id: \.self) { category in
                            let shortcuts = getShortcuts(for: category)

                            if !shortcuts.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                        .padding(.bottom, 1)

                                    VStack(spacing: 0) {
                                        ForEach(shortcuts.indices, id: \.self) { index in
                                            ShortcutRow(shortcut: shortcuts[index])
                                        }
                                    }
                                }
                            }
                        }

                        // Markdown syntax (always shown if no search or search matches)
                        if searchText.isEmpty || markdownShortcuts.contains(where: { $0.0.localizedCaseInsensitiveContains(searchText) || $0.1.localizedCaseInsensitiveContains(searchText) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Markdown Syntax")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.bottom, 1)

                                VStack(spacing: 0) {
                                    ForEach(markdownShortcuts.filter { searchText.isEmpty || $0.0.localizedCaseInsensitiveContains(searchText) || $0.1.localizedCaseInsensitiveContains(searchText) }, id: \.0) { shortcut in
                                        HStack(spacing: 8) {
                                            KeyboardKey(key: shortcut.0)
                                                .frame(width: 110, alignment: .leading)

                                            Text(shortcut.1)
                                                .font(.system(size: 13))
                                                .foregroundColor(.primary)

                                            Spacer()
                                        }
                                        .padding(.vertical, 1)
                                        .padding(.horizontal, 2)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .frame(width: 520, height: 560)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    KeyboardShortcutsHelp(isPresented: $isPresented)
}