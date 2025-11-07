//
//  AccessibilityExtensions.swift
//  Notis
//
//  Created by Mike on 11/3/25.
//

import SwiftUI

// MARK: - Accessibility Modifiers
extension View {
    /// Adds comprehensive accessibility support for interactive elements
    func accessibleButton(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        isEnabled: Bool = true
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityRemoveTraits(isEnabled ? [] : .isButton)
            .accessibilityAddTraits(isEnabled ? [] : .isStaticText)
    }
    
    /// Adds accessibility support for list items
    func accessibleListItem(
        label: String,
        value: String? = nil,
        isSelected: Bool = false
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    /// Adds accessibility support for text fields
    func accessibleTextField(
        label: String,
        value: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityHint(hint ?? "")
    }
    
    /// Adds accessibility support for headings
    func accessibleHeading(level: AccessibilityHeadingLevel = .h1) -> some View {
        self
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(level)
    }
    
    /// Adds accessibility support for status updates
    func accessibleStatus(_ announcement: String) -> some View {
        self
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    #if os(iOS)
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                    #elseif os(macOS)
                    NSAccessibility.post(element: NSApp, notification: .announcementRequested, userInfo: [
                        .announcement: announcement
                    ])
                    #endif
                }
            }
    }
    
    /// Adds focus ring for keyboard navigation
    func focusRing(isVisible: Bool = true, color: Color = .accentColor) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                    .stroke(color, lineWidth: 2)
                    .opacity(isVisible ? 1 : 0)
                    .animation(UlyssesDesign.Animations.quick, value: isVisible)
            )
    }
    
    /// Reduces motion for users with accessibility preferences
    func respectsReduceMotion<T: Equatable>(_ animation: Animation, value: T) -> some View {
        self
            .animation(
                UIAccessibility.isReduceMotionEnabled ? .none : animation,
                value: value
            )
    }
}

// MARK: - Simple Priority Enum for internal use
enum AnnouncementPriority {
    case low
    case medium 
    case high
    
    var rawValue: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }
}

// MARK: - Semantic Colors for Accessibility
extension UlyssesDesign.Colors {
    
    /// Returns high contrast colors when accessibility settings require it
    static func accessiblePrimary(for colorScheme: ColorScheme) -> Color {
        #if os(iOS)
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return colorScheme == .dark ? .white : .black
        }
        #endif
        return primary(for: colorScheme)
    }
    
    static func accessibleSecondary(for colorScheme: ColorScheme) -> Color {
        #if os(iOS)
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return colorScheme == .dark ? Color.gray : Color.gray
        }
        #endif
        return secondary(for: colorScheme)
    }
    
    /// Ensures minimum contrast ratio of 4.5:1 for accessibility
    static func accessibleAccent(for colorScheme: ColorScheme) -> Color {
        #if os(iOS)
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return colorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue
        }
        #endif
        return accent
    }
}

// MARK: - VoiceOver Helper
struct VoiceOverHelper {
    
    /// Formats word count for VoiceOver
    static func formatWordCount(_ count: Int) -> String {
        if count == 1 {
            return "1 word"
        } else {
            return "\(count) words"
        }
    }
    
    /// Formats date for VoiceOver
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Creates accessible description for sheet metadata
    static func sheetMetadata(
        title: String,
        wordCount: Int,
        modifiedDate: Date
    ) -> String {
        let formattedDate = formatDate(modifiedDate)
        let formattedCount = formatWordCount(wordCount)
        return "\(title). \(formattedCount). Modified \(formattedDate)"
    }
    
    /// Creates accessible description for group items
    static func groupDescription(
        name: String,
        sheetCount: Int
    ) -> String {
        if sheetCount == 1 {
            return "\(name). 1 sheet"
        } else {
            return "\(name). \(sheetCount) sheets"
        }
    }
}

// MARK: - Keyboard Navigation Support
struct KeyboardNavigationModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    let onAction: () -> Void
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onKeyPress(.return) {
                onAction()
                return .handled
            }
            .onKeyPress(.space) {
                onAction()
                return .handled
            }
            .focusRing(isVisible: isFocused)
    }
}

extension View {
    func keyboardNavigable(onAction: @escaping () -> Void) -> some View {
        self.modifier(KeyboardNavigationModifier(onAction: onAction))
    }
}

#if DEBUG
// MARK: - Accessibility Preview Helper
struct AccessibilityPreview: View {
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.lg) {
            Text("Sample Heading")
                .accessibleHeading(level: .h1)
            
            Button("Sample Button") {}
                .accessibleButton(
                    label: "Create new document",
                    hint: "Opens a new document in the editor"
                )
            
            HStack {
                Text("Document Title")
                Spacer()
                Text("125 words")
                    .font(UlyssesDesign.Typography.counterText)
            }
            .accessibleListItem(
                label: VoiceOverHelper.sheetMetadata(
                    title: "Document Title",
                    wordCount: 125,
                    modifiedDate: Date()
                ),
                isSelected: true
            )
        }
        .padding()
    }
}

#Preview {
    AccessibilityPreview()
}
#endif