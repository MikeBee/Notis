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
                    Button("Editor Only") {
                        appState.viewMode = .editorOnly
                    }
                    Button("All Panes") {
                        appState.viewMode = .threePane
                    }
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
                // Dashboard button
                Menu {
                    Button("Overview") {
                        showDashboard(.overview)
                    }
                    Button("Progress") {
                        showDashboard(.progress)
                    }
                    Button("Outline") {
                        showDashboard(.outline)
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
                
                // Settings button
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 28, height: 28)
                .background(Color.clear)
                .cornerRadius(UlyssesDesign.CornerRadius.small)
                .onHover { hovering in
                    // Add hover effect if needed
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
    
    private func openSettings() {
        NotificationCenter.default.post(name: .showSettings, object: nil)
        HapticService.shared.buttonTap()
    }
}

enum DashboardType {
    case overview
    case progress 
    case outline
}

#Preview {
    NavigationBar(appState: AppState())
        .frame(width: 800, height: 44)
}