//
//  EditorSettingsView.swift
//  Notis
//
//  Created by Mike on 11/2/25.
//

import SwiftUI

struct EditorSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var fontSize: Double
    @Binding var lineSpacing: Double
    @Binding var paragraphSpacing: Double
    @Binding var fontFamily: String
    @Binding var editorMargins: Double
    @Binding var showWordCounter: Bool
    // hideShortcutBar moved to global app settings
    @Binding var disableQuickType: Bool
    @Binding var theme: AppState.AppTheme
    @Binding var isTypewriterMode: Bool
    @Binding var isFocusMode: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section("Theme") {
                    Picker("Theme", selection: $theme) {
                        ForEach(AppState.AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Typography") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font Family")
                            Spacer()
                            Picker("Font", selection: $fontFamily) {
                                Text("System").tag("system")
                                Text("Serif").tag("serif")
                                Text("Monospace").tag("monospace")
                                Text("Times").tag("times")
                                Text("Helvetica").tag("helvetica")
                                Text("Courier").tag("courier")
                                Text("Avenir").tag("avenir")
                                Text("Georgia").tag("georgia")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(Int(fontSize))pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $fontSize, in: 10...32, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Line Height")
                            Spacer()
                            Text(String(format: "%.1f", lineSpacing))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $lineSpacing, in: 1.0...3.0, step: 0.1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Paragraph Spacing")
                            Spacer()
                            Text("\(Int(paragraphSpacing))pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $paragraphSpacing, in: 0...24, step: 2)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Editor Margins")
                            Spacer()
                            if editorMargins == 0 {
                                Text("No margin")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(Int(editorMargins))pt")
                                    .foregroundColor(.secondary)
                            }
                        }
                        Slider(value: $editorMargins, in: 0...400, step: 5)
                    }
                }
                
                Section("View Options") {
                    Toggle("Show Word Counter", isOn: $showWordCounter)
                    Toggle("Typewriter Mode", isOn: $isTypewriterMode)
                    Toggle("Focus Mode", isOn: $isFocusMode)
                    // Hide Shortcut Bar moved to main app settings
                }
                
                Section("Keyboard") {
                    Toggle("Disable QuickType", isOn: $disableQuickType)
                        .help("Turn off predictive text and autocomplete suggestions")
                }
            }
            .navigationTitle("Editor Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var fontSize: Double = 16
    @Previewable @State var lineSpacing: Double = 1.4
    @Previewable @State var paragraphSpacing: Double = 8
    @Previewable @State var fontFamily: String = "system"
    @Previewable @State var editorMargins: Double = 40
    @Previewable @State var showWordCounter: Bool = true
    // hideShortcutBar removed from preview
    @Previewable @State var disableQuickType: Bool = false
    @Previewable @State var theme: AppState.AppTheme = .system
    @Previewable @State var isTypewriterMode: Bool = false
    @Previewable @State var isFocusMode: Bool = false
    
    return EditorSettingsView(
        fontSize: $fontSize,
        lineSpacing: $lineSpacing,
        paragraphSpacing: $paragraphSpacing,
        fontFamily: $fontFamily,
        editorMargins: $editorMargins,
        showWordCounter: $showWordCounter,
        // hideShortcutBar: removed parameter,
        disableQuickType: $disableQuickType,
        theme: $theme,
        isTypewriterMode: $isTypewriterMode,
        isFocusMode: $isFocusMode
    )
}