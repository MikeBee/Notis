//
//  KeyboardShortcutsSettingsView.swift
//  Notis
//
//  Created by Claude on 11/16/25.
//

import SwiftUI

struct KeyboardShortcutsSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var shortcutManager = KeyboardShortcutManager.shared
    @State private var editingAction: ShortcutAction?
    @State private var searchText = ""
    @State private var showingConflictAlert = false
    @State private var conflictMessage = ""

    private var filteredActions: [ShortcutAction] {
        if searchText.isEmpty {
            return ShortcutAction.allCases
        }
        return ShortcutAction.allCases.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 12) {
                HStack {
                    Text("Keyboard Shortcuts")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Button("Reset All") {
                        shortcutManager.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                }

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search shortcuts...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()

            Divider()

            // Shortcuts list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(ShortcutCategory.allCases, id: \.self) { category in
                        let categoryActions = filteredActions.filter { $0.category == category }

                        if !categoryActions.isEmpty {
                            Section {
                                ForEach(categoryActions, id: \.self) { action in
                                    ShortcutRow(
                                        action: action,
                                        shortcut: shortcutManager.getShortcut(for: action),
                                        isEditing: editingAction == action,
                                        onEdit: { editingAction = action },
                                        onReset: { shortcutManager.resetAction(action) },
                                        onRemove: { shortcutManager.removeShortcut(for: action) }
                                    )
                                    .background(Color(.systemBackground))
                                }
                            } header: {
                                HStack {
                                    Text(category.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                        .font(.system(size: 12, weight: .semibold))
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground))
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Click on a shortcut to edit it. Press keys to assign a new shortcut.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
        .alert("Shortcut Conflict", isPresented: $showingConflictAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(conflictMessage)
        }
    }
}

struct ShortcutRow: View {
    let action: ShortcutAction
    let shortcut: KeyboardShortcut?
    let isEditing: Bool
    let onEdit: () -> Void
    let onReset: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack {
            // Action name
            Text(action.displayName)
                .font(.body)

            Spacer()

            // Shortcut display or editor
            if let shortcut = shortcut {
                HStack(spacing: 8) {
                    Text(shortcut.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isEditing ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                        .onTapGesture {
                            onEdit()
                        }

                    Menu {
                        Button("Edit") { onEdit() }
                        Button("Reset to Default") { onReset() }
                        Button("Remove", role: .destructive) { onRemove() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            } else {
                Button("Assign Shortcut") {
                    onEdit()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }
}

// MARK: - Shortcut Recorder View

struct ShortcutRecorderView: View {
    @Binding var isPresented: Bool
    let action: ShortcutAction
    @StateObject private var shortcutManager = KeyboardShortcutManager.shared
    @State private var recordedKeys: Set<String> = []
    @State private var recordedModifiers: EventModifiers = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Record Shortcut for \(action.displayName)")
                .font(.headline)

            Text("Press the key combination you want to use")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                if !recordedModifiers.isEmpty || !recordedKeys.isEmpty {
                    Text(getDisplayString())
                        .font(.system(.title, design: .monospaced))
                        .padding()
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(8)
                } else {
                    Text("Waiting for input...")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 80)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                if !recordedKeys.isEmpty {
                    Button("Save") {
                        if let key = recordedKeys.first {
                            let shortcut = KeyboardShortcut(key: key, modifiers: recordedModifiers)
                            shortcutManager.setShortcut(shortcut, for: action)
                        }
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 250)
    }

    private func getDisplayString() -> String {
        var parts: [String] = []
        if recordedModifiers.contains(.command) { parts.append("⌘") }
        if recordedModifiers.contains(.control) { parts.append("⌃") }
        if recordedModifiers.contains(.option) { parts.append("⌥") }
        if recordedModifiers.contains(.shift) { parts.append("⇧") }

        if let key = recordedKeys.first {
            parts.append(key.uppercased())
        }

        return parts.joined()
    }
}

#Preview {
    KeyboardShortcutsSettingsView()
}
