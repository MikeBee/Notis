//
//  MarkdownTextEditor.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI

struct MarkdownTextEditor: View {
    @Binding var text: String
    @Binding var isTypewriterMode: Bool
    @Binding var isFocusMode: Bool
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let onTextChange: (String) -> Void
    
    private var safeFontSize: CGFloat {
        guard fontSize.isFinite && fontSize > 0 else { return 16 }
        return max(10, min(72, fontSize))
    }
    
    private var safeLineSpacing: CGFloat {
        guard lineSpacing.isFinite && lineSpacing > 0 else { return 1.4 }
        return max(0.5, min(3.0, lineSpacing))
    }
    
    var body: some View {
        ZStack {
            Color.clear
            
            TextEditor(text: $text)
                .font(.system(size: safeFontSize, design: .default))
                .lineSpacing(safeLineSpacing)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .autocorrectionDisabled(false)
                .onChange(of: text) { _, newValue in
                    onTextChange(newValue)
                }
        }
        .clipped()
    }
}

#Preview {
    @Previewable @State var sampleText = """
# Sample Document

This is a **bold** text and this is *italic* text.

## Second Header

Some regular content here with more text to test the editor.

### Third Level Header

- List item 1
- List item 2
- List item 3
"""
    @Previewable @State var typewriterMode = false
    @Previewable @State var focusMode = false
    
    MarkdownTextEditor(
        text: $sampleText,
        isTypewriterMode: $typewriterMode,
        isFocusMode: $focusMode,
        fontSize: 16,
        lineSpacing: 1.4
    ) { newText in
        print("Text changed: \(newText.count) characters")
    }
}