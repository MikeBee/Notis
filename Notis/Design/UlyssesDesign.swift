//
//  UlyssesDesign.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI

struct UlyssesDesign {
    
    // MARK: - Colors (Ulysses-style)
    struct Colors {
        // Light Theme
        static let libraryBackground = Color(red: 0.96, green: 0.96, blue: 0.97) // #f5f5f7
        static let sheetListBackground = Color(red: 0.98, green: 0.98, blue: 0.99) // #fafafb
        static let editorBackground = Color.white
        
        static let libraryBackgroundDark = Color(red: 0.11, green: 0.11, blue: 0.12) // #1c1c1e
        static let sheetListBackgroundDark = Color(red: 0.14, green: 0.14, blue: 0.15) // #242426
        static let editorBackgroundDark = Color(red: 0.09, green: 0.09, blue: 0.10) // #171719
        
        // Text Colors
        static let primaryText = Color(red: 0.07, green: 0.07, blue: 0.09) // #121214
        static let secondaryText = Color(red: 0.45, green: 0.45, blue: 0.50) // #737380
        static let tertiaryText = Color(red: 0.65, green: 0.65, blue: 0.70) // #a6a6b3
        
        static let primaryTextDark = Color(red: 0.92, green: 0.92, blue: 0.96) // #ebebf5
        static let secondaryTextDark = Color(red: 0.55, green: 0.55, blue: 0.58) // #8c8c94
        static let tertiaryTextDark = Color(red: 0.40, green: 0.40, blue: 0.43) // #66666e
        
        // Accent & Selection
        static let accent = Color(red: 0.29, green: 0.62, blue: 1.0) // #4a9eff
        static let selection = Color(red: 0.29, green: 0.62, blue: 1.0).opacity(0.15)
        static let hover = Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.04)
        
        // Borders & Dividers
        static let divider = Color(red: 0.85, green: 0.85, blue: 0.88) // #d9d9e0
        static let dividerDark = Color(red: 0.25, green: 0.25, blue: 0.28) // #404047
        
        // Goal Progress
        static let goalProgress = Color(red: 0.29, green: 0.62, blue: 1.0) // #4a9eff
        static let goalTrack = Color(red: 0.90, green: 0.90, blue: 0.92) // #e6e6eb
    }
    
    // MARK: - Typography
    struct Typography {
        // Scale (based on 1.125 type scale)
        private static let baseSize: CGFloat = 16
        
        // Library
        static let libraryTitle = Font.system(size: 13, weight: .semibold, design: .default)
        static let groupName = Font.system(size: 13, weight: .medium, design: .default)
        static let groupCount = Font.system(size: 11, weight: .regular, design: .monospaced)
        
        // Sheet List
        static let sheetTitle = Font.system(size: 15, weight: .semibold, design: .default)
        static let sheetPreview = Font.system(size: 13, weight: .regular, design: .default)
        static let sheetMeta = Font.system(size: 11, weight: .regular, design: .default)
        
        // Editor
        static let editorTitle = Font.system(size: 24, weight: .semibold, design: .serif)
        static let editorBody = Font.system(size: 17, weight: .regular, design: .serif)
        static let editorH1 = Font.system(size: 32, weight: .bold, design: .serif)
        static let editorH2 = Font.system(size: 28, weight: .bold, design: .serif)
        static let editorH3 = Font.system(size: 24, weight: .semibold, design: .serif)
        static let editorH4 = Font.system(size: 20, weight: .semibold, design: .serif)
        static let editorH5 = Font.system(size: 18, weight: .medium, design: .serif)
        static let editorH6 = Font.system(size: 16, weight: .medium, design: .serif)
        
        // UI Elements
        static let buttonLabel = Font.system(size: 14, weight: .medium, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let footnote = Font.system(size: 10, weight: .regular, design: .default)
        static let code = Font.system(size: 14, weight: .regular, design: .monospaced)
        
        // Status and indicators
        static let statusLabel = Font.system(size: 11, weight: .semibold, design: .default)
        static let counterText = Font.system(size: 11, weight: .medium, design: .monospaced)
        
        // Line height multipliers for better readability
        static let tightLineHeight: CGFloat = 1.2
        static let normalLineHeight: CGFloat = 1.4
        static let relaxedLineHeight: CGFloat = 1.6
        static let looseLineHeight: CGFloat = 1.8
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        
        // Pane Widths
        static let libraryWidth: CGFloat = 280
        static let sheetListWidth: CGFloat = 360
        static let editorMaxWidth: CGFloat = 650
        static let editorMargin: CGFloat = 60
        static let dashboardWidth: CGFloat = 320
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let subtle = Color.black.opacity(0.05)
        static let medium = Color.black.opacity(0.10)
        static let strong = Color.black.opacity(0.15)
    }
    
    // MARK: - Animations
    struct Animations {
        // Timing curves
        static let quick = Animation.easeInOut(duration: 0.15)
        static let standard = Animation.easeInOut(duration: 0.25)
        static let smooth = Animation.easeInOut(duration: 0.35)
        static let gentle = Animation.easeInOut(duration: 0.5)
        
        // Spring animations
        static let springy = Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
        static let elastic = Animation.spring(response: 0.5, dampingFraction: 0.5)
        
        // Specialized animations
        static let buttonPress = Animation.spring(response: 0.2, dampingFraction: 0.8)
        static let modalPresent = Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let slideTransition = Animation.easeInOut(duration: 0.3)
    }
    
    // MARK: - Effects
    struct Effects {
        // Blur effects
        static let subtle = 2.0
        static let medium = 8.0
        static let strong = 16.0
        
        // Opacity levels
        static let faint = 0.3
        static let visible = 0.6
        static let prominent = 0.8
    }
}

// MARK: - Theme-aware Colors
extension UlyssesDesign.Colors {
    
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? editorBackgroundDark : editorBackground
    }
    
    static func libraryBg(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? libraryBackgroundDark : libraryBackground
    }
    
    static func sheetListBg(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? sheetListBackgroundDark : sheetListBackground
    }
    
    static func primary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? primaryTextDark : primaryText
    }
    
    static func secondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? secondaryTextDark : secondaryText
    }
    
    static func tertiary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? tertiaryTextDark : tertiaryText
    }
    
    static func dividerColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? dividerDark : divider
    }
    
    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? sheetListBackgroundDark : sheetListBackground
    }
    
    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? dividerDark : divider
    }
}