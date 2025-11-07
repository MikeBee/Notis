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
    
    private struct ShortcutGroup {
        let title: String
        let shortcuts: [KeyboardShortcut]
    }
    
    private struct KeyboardShortcut {
        let keys: String
        let description: String
    }
    
    private struct ShortcutRow: View {
        let shortcut: KeyboardShortcut
        
        var body: some View {
            HStack {
                HStack(spacing: 2) {
                    if isMarkdownShortcut {
                        // Display markdown syntax as a single key
                        KeyboardKey(key: shortcut.keys)
                    } else {
                        // Display regular shortcuts as individual keys
                        ForEach(shortcut.keys.map(String.init), id: \.self) { key in
                            KeyboardKey(key: key)
                        }
                    }
                }
                .frame(width: 120, alignment: .leading)
                
                Text(shortcut.description)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
        
        private var isMarkdownShortcut: Bool {
            shortcut.keys.contains("#") || shortcut.keys.contains("*") || 
            shortcut.keys.contains("-") || shortcut.keys.contains("1.")
        }
    }
    
    private let shortcutGroups: [ShortcutGroup] = [
        ShortcutGroup(title: "General", shortcuts: [
            KeyboardShortcut(keys: "⌘K", description: "Command Palette"),
            KeyboardShortcut(keys: "⌘,", description: "Settings"),
            KeyboardShortcut(keys: "⌘/", description: "Show Keyboard Shortcuts")
        ]),
        ShortcutGroup(title: "Documents", shortcuts: [
            KeyboardShortcut(keys: "⌘N", description: "New Sheet"),
            KeyboardShortcut(keys: "⌘S", description: "Save (Auto-saved)"),
            KeyboardShortcut(keys: "⌘←", description: "Previous Sheet"),
            KeyboardShortcut(keys: "⌘→", description: "Next Sheet")
        ]),
        ShortcutGroup(title: "View", shortcuts: [
            KeyboardShortcut(keys: "⌘1", description: "Show All Panes"),
            KeyboardShortcut(keys: "⌘2", description: "Show Sheets & Editor"),
            KeyboardShortcut(keys: "⌘3", description: "Show Editor Only"),
            KeyboardShortcut(keys: "⌘⇧L", description: "Toggle Library Panel"),
            KeyboardShortcut(keys: "⌘⇧R", description: "Toggle Sheet List"),
            KeyboardShortcut(keys: "⌘O", description: "Toggle Outline Panel"),
            KeyboardShortcut(keys: "⌘⇧D", description: "Toggle Dashboard")
        ]),
        ShortcutGroup(title: "Editor", shortcuts: [
            KeyboardShortcut(keys: "⌘F", description: "Toggle Focus Mode"),
            KeyboardShortcut(keys: "⌘T", description: "Toggle Typewriter Mode"),
            KeyboardShortcut(keys: "⌘D", description: "Toggle Favorite")
        ]),
        ShortcutGroup(title: "Folder Management", shortcuts: [
            KeyboardShortcut(keys: "⌘↑", description: "Move Folder Up"),
            KeyboardShortcut(keys: "⌘↓", description: "Move Folder Down"),
            KeyboardShortcut(keys: "⌘]", description: "Indent Folder"),
            KeyboardShortcut(keys: "⌘[", description: "Outdent Folder")
        ]),
        ShortcutGroup(title: "Markdown Formatting", shortcuts: [
            KeyboardShortcut(keys: "# Text", description: "Large Header"),
            KeyboardShortcut(keys: "## Text", description: "Medium Header"),
            KeyboardShortcut(keys: "### Text", description: "Small Header"),
            KeyboardShortcut(keys: "**text**", description: "Bold Text"),
            KeyboardShortcut(keys: "*text*", description: "Italic Text"),
            KeyboardShortcut(keys: "- Item", description: "Bullet List"),
            KeyboardShortcut(keys: "1. Item", description: "Numbered List")
        ])
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
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                Divider()
                
                // Shortcuts content
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(shortcutGroups.indices, id: \.self) { groupIndex in
                            let group = shortcutGroups[groupIndex]
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text(group.title)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 8) {
                                    ForEach(group.shortcuts.indices, id: \.self) { shortcutIndex in
                                        ShortcutRow(shortcut: group.shortcuts[shortcutIndex])
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
            .frame(width: 450, height: 500)
            .background(
                RoundedRectangle(cornerRadius: 12)
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