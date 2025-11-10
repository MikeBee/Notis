//
//  TitleTextField.swift
//  Notis
//
//  Created by Claude on 11/2/25.
//

import SwiftUI

struct TitleTextField: View {
    @Binding var text: String
    let font: Font
    let isNewSheet: Bool
    let onReturnOrTab: () -> Void

    @State private var internalText: String = ""

    var body: some View {
        TextField("Untitled", text: $internalText)
            .font(font)
            .textFieldStyle(PlainTextFieldStyle())
            .onSubmit {
                onReturnOrTab()
            }
            .onKeyPress(.tab) {
                onReturnOrTab()
                return .handled
            }
            .onAppear {
                // Initialize internal text from binding
                // For new sheets, start with empty text so typing replaces "Untitled"
                if isNewSheet && text == "Untitled" {
                    internalText = ""
                } else {
                    internalText = text
                }
            }
            .onChange(of: internalText) { _, newValue in
                // Update the binding when internal text changes
                text = newValue.isEmpty && !isNewSheet ? "Untitled" : newValue
            }
            .onChange(of: text) { _, newValue in
                // Update internal text when binding changes from external source
                // This ensures switching sheets updates the title correctly
                if newValue != internalText {
                    if isNewSheet && newValue == "Untitled" {
                        internalText = ""
                    } else {
                        internalText = newValue
                    }
                }
            }
    }
}

#Preview {
    @Previewable @State var sampleText = "Untitled"
    
    VStack {
        TitleTextField(
            text: $sampleText,
            font: .title.weight(.semibold),
            isNewSheet: true,
            onReturnOrTab: {
                print("Return or Tab pressed")
            }
        )
        
        Text("Current text: '\(sampleText)'")
            .foregroundColor(.secondary)
    }
    .padding()
}