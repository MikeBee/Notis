//
//  EnhancedContextMenu.swift
//  Notis
//
//  Created by Mike on 11/3/25.
//

import SwiftUI

struct ContextMenuItem {
    let id = UUID()
    let title: String
    let icon: String
    let shortcut: String?
    let isDestructive: Bool
    let isEnabled: Bool
    let isDivider: Bool
    let action: () -> Void
    
    init(
        title: String = "",
        icon: String = "",
        shortcut: String? = nil,
        isDestructive: Bool = false,
        isEnabled: Bool = true,
        isDivider: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.icon = icon
        self.shortcut = shortcut
        self.isDestructive = isDestructive
        self.isEnabled = isEnabled
        self.isDivider = isDivider
        self.action = action
    }
    
    static func divider() -> ContextMenuItem {
        ContextMenuItem(isDivider: true)
    }
}

struct EnhancedContextMenuButton: View {
    let item: ContextMenuItem
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: item.action) {
            HStack(spacing: UlyssesDesign.Spacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 16)
                
                Text(item.title)
                    .font(UlyssesDesign.Typography.buttonLabel)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                }
            }
            .padding(.horizontal, UlyssesDesign.Spacing.md)
            .padding(.vertical, UlyssesDesign.Spacing.sm)
            .background(backgroundColor)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!item.isEnabled)
        .onHover { hovering in
            withAnimation(UlyssesDesign.Animations.quick) {
                isHovering = hovering && item.isEnabled
            }
        }
    }
    
    private var textColor: Color {
        if !item.isEnabled {
            return UlyssesDesign.Colors.tertiary(for: colorScheme)
        } else if item.isDestructive {
            return .red
        } else {
            return UlyssesDesign.Colors.primary(for: colorScheme)
        }
    }
    
    private var iconColor: Color {
        if !item.isEnabled {
            return UlyssesDesign.Colors.tertiary(for: colorScheme)
        } else if item.isDestructive {
            return .red
        } else {
            return UlyssesDesign.Colors.accent
        }
    }
    
    private var backgroundColor: Color {
        if isHovering && item.isEnabled {
            return item.isDestructive 
                ? Color.red.opacity(0.1)
                : UlyssesDesign.Colors.accent.opacity(0.1)
        }
        return Color.clear
    }
}

extension View {
    func enhancedContextMenu(items: [ContextMenuItem]) -> some View {
        self.contextMenu {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if item.isDivider {
                        Divider()
                    } else {
                        EnhancedContextMenuButton(item: item)
                    }
                }
            }
        }
    }
}

#Preview {
    Text("Right-click me")
        .padding()
        .enhancedContextMenu(items: [
            ContextMenuItem(title: "Open", icon: "doc.text", shortcut: "↩") {},
            ContextMenuItem(title: "Duplicate", icon: "doc.on.doc", shortcut: "⌘D") {},
            .divider(),
            ContextMenuItem(title: "Delete", icon: "trash", isDestructive: true) {}
        ])
}