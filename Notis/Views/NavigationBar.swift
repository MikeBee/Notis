//
//  NavigationBar.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI

struct NavigationBar: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showViewModeMenu = false
    @State private var isHelpButtonHovering = false
    @State private var isSettingsButtonHovering = false
    
    var body: some View {
        HStack(spacing: UlyssesDesign.Spacing.md) {
            // Left side controls
            HStack(spacing: UlyssesDesign.Spacing.sm) {
                // Library toggle (sidebar icon)
                Button(action: toggleLibrary) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(
                            appState.showLibrary 
                                ? UlyssesDesign.Colors.accent 
                                : UlyssesDesign.Colors.secondary(for: colorScheme)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 28, height: 28)
                .background(
                    appState.showLibrary 
                        ? UlyssesDesign.Colors.accent.opacity(0.1)
                        : Color.clear
                )
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                
                // View mode selector (down arrow)
                Menu {
                    Button("Library Only") {
                        appState.viewMode = .libraryOnly
                    }
                    Button("Sheets Only") {
                        appState.viewMode = .sheetsOnly
                    }
                    .keyboardShortcut("2", modifiers: .command)
                    Button("Editor Only") {
                        appState.viewMode = .editorOnly
                    }
                    .keyboardShortcut("3", modifiers: .command)
                    Button("All Panes") {
                        appState.viewMode = .threePane
                    }
                    .keyboardShortcut("1", modifiers: .command)
                } label: {
                    HStack(spacing: 4) {
                        Text(appState.viewMode.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    }
                    .padding(.horizontal, UlyssesDesign.Spacing.sm)
                    .padding(.vertical, UlyssesDesign.Spacing.xs)
                    .background(UlyssesDesign.Colors.hover.opacity(0.5))
                    .cornerRadius(UlyssesDesign.CornerRadius.small)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
            
            Spacer()
            
            // Center - App title or current context
            Text("Notis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
            
            Spacer()
            
            // Right side controls
            HStack(spacing: UlyssesDesign.Spacing.sm) {
                // Template button
                Button(action: showTemplates) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 28, height: 28)
                .background(Color.clear)
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                .help("Templates")
                
                // Dashboard button
                Menu {
                    Button("Overview") {
                        showDashboard(.overview)
                    }
                    Button("Progress") {
                        showDashboard(.progress)
                    }
                    Button("Goals") {
                        showDashboard(.goals)
                    }
                    Button("Outline") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appState.showOutlinePane.toggle()
                        }
                    }
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 28, height: 28)
                .background(Color.clear)
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                .menuStyle(BorderlessButtonMenuStyle())
                
                // Help button
                Button(action: showHelp) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        .scaleEffect(isHelpButtonHovering ? 1.1 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 28, height: 28)
                .background(UlyssesDesign.Colors.hover.opacity(isHelpButtonHovering ? 1 : 0))
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                .scaleEffect(isHelpButtonHovering ? 1.05 : 1.0)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        isHelpButtonHovering = hovering
                    }
                }
                
                // Settings button
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        .scaleEffect(isSettingsButtonHovering ? 1.1 : 1.0)
                        .rotationEffect(.degrees(isSettingsButtonHovering ? 45 : 0))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 28, height: 28)
                .background(UlyssesDesign.Colors.hover.opacity(isSettingsButtonHovering ? 1 : 0))
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                .scaleEffect(isSettingsButtonHovering ? 1.05 : 1.0)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        isSettingsButtonHovering = hovering
                    }
                }
            }
        }
        .padding(.horizontal, UlyssesDesign.Spacing.lg)
        .padding(.vertical, UlyssesDesign.Spacing.sm)
        .background(
            UlyssesDesign.Colors.background(for: colorScheme)
                .overlay(
                    Rectangle()
                        .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme))
                        .frame(height: 0.5)
                        .opacity(0.6),
                    alignment: .bottom
                )
        )
    }
    
    private func toggleLibrary() {
        withAnimation(.easeInOut(duration: 0.25)) {
            appState.showLibrary.toggle()
            
            // If we're hiding the library and currently in library-only mode,
            // switch to a sensible view mode
            if !appState.showLibrary && appState.viewMode == .libraryOnly {
                appState.viewMode = appState.showSheetList ? .sheetsOnly : .editorOnly
            }
        }
        
        HapticService.shared.buttonTap()
    }
    
    private func showDashboard(_ type: DashboardType) {
        NotificationCenter.default.post(name: .showDashboard, object: type)
        HapticService.shared.buttonTap()
    }
    
    private func showHelp() {
        NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
        HapticService.shared.buttonTap()
    }
    
    private func openSettings() {
        NotificationCenter.default.post(name: .showSettings, object: nil)
        HapticService.shared.buttonTap()
    }
    
    private func showTemplates() {
        NotificationCenter.default.post(name: .showTemplates, object: nil)
        HapticService.shared.buttonTap()
    }
}

enum DashboardType {
    case overview
    case progress 
    case outline
    case goals
}

#Preview {
    NavigationBar(appState: AppState())
        .frame(width: 800, height: 44)
}