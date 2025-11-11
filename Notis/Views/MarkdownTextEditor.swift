//
//  MarkdownTextEditor.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI

struct MarkdownHighlightedText: View {
    @EnvironmentObject var appState: AppState
    
    let text: String
    let fontSize: CGFloat
    let isCurrentParagraph: Bool
    let lineSpacing: CGFloat
    let paragraphSpacing: CGFloat
    let fontFamily: String
    
    init(text: String, fontSize: CGFloat, isCurrentParagraph: Bool, lineSpacing: CGFloat = 1.4, paragraphSpacing: CGFloat = 8, fontFamily: String = "system") {
        self.text = text
        self.fontSize = fontSize
        self.isCurrentParagraph = isCurrentParagraph
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.fontFamily = fontFamily
    }
    
    private func getFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch fontFamily {
        case "serif":
            return .custom("Times New Roman", size: size).weight(weight)
        case "monospace":
            return .custom("Menlo", size: size).weight(weight)
        case "times":
            return .custom("Times", size: size).weight(weight)
        case "helvetica":
            return .custom("Helvetica", size: size).weight(weight)
        case "courier":
            return .custom("Courier", size: size).weight(weight)
        case "avenir":
            return .custom("Avenir", size: size).weight(weight)
        case "georgia":
            return .custom("Georgia", size: size).weight(weight)
        default:
            return .system(size: size, weight: weight, design: .default)
        }
    }
    
    private func getFontForAttributedString(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        switch fontFamily {
        case "serif":
            return UIFont(name: "Times New Roman", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        case "monospace":
            return UIFont(name: "Menlo", size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        case "times":
            return UIFont(name: "Times", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        case "helvetica":
            return UIFont(name: "Helvetica", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        case "courier":
            return UIFont(name: "Courier", size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        case "avenir":
            return UIFont(name: "Avenir", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        case "georgia":
            return UIFont(name: "Georgia", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        default:
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
    }
    
    var body: some View {
        Text(attributedText)
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, text.isEmpty ? 0 : paragraphSpacing)
    }
    
    private var baseColor: Color {
        Color.primary
    }
    
    private func createHeaderAttributedString(text: String, headerLevel: Int, baseFontSize: CGFloat) -> AttributedString {
        let headerPrefixes = ["# ", "## ", "### "]
        guard headerLevel <= headerPrefixes.count else {
            var attributed = AttributedString(text)
            attributed.font = UIFont.boldSystemFont(ofSize: baseFontSize)
            return attributed
        }
        
        let prefix = headerPrefixes[headerLevel - 1]
        let headerText = String(text.dropFirst(prefix.count))
        
        // Create attributed string with both prefix and content
        var fullAttributed = AttributedString()
        
        // Add the header level indicators (H1, H2, H3) with light gray styling (if enabled)
        if appState.showMarkdownHeaderSymbols {
            let headerLabels = ["H1 ", "H2 ", "H3 "]
            let headerLabel = headerLabels[min(headerLevel - 1, headerLabels.count - 1)]
            
            var prefixAttributed = AttributedString(headerLabel)
            prefixAttributed.font = UIFont.systemFont(ofSize: baseFontSize * 0.7, weight: .medium)
            prefixAttributed.foregroundColor = Color.gray.opacity(0.6)
            fullAttributed.append(prefixAttributed)
        }
        
        // Add the header text with bold, large styling
        var contentAttributed = AttributedString(headerText)
        let fontMultiplier: CGFloat = headerLevel == 1 ? 1.5 : (headerLevel == 2 ? 1.3 : 1.1)
        contentAttributed.font = UIFont.boldSystemFont(ofSize: baseFontSize * fontMultiplier)
        contentAttributed.foregroundColor = Color.primary
        
        fullAttributed.append(contentAttributed)
        
        // Apply paragraph style for outdenting if header symbols are shown
        if appState.showMarkdownHeaderSymbols {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 30 // Regular text indented to align with body
            paragraphStyle.firstLineHeadIndent = 0 // First line (with H1/H2/H3) starts at margin
            fullAttributed.paragraphStyle = paragraphStyle
        }
        
        return fullAttributed
    }
    
    private func createBulletListAttributedString(text: String, baseFontSize: CGFloat) -> AttributedString {
        let bulletText = String(text.dropFirst(2)) // Remove "- "
        
        // Create attributed string with bullet and content
        var fullAttributed = AttributedString()
        
        // Add the bullet point with smaller, gray styling
        var bulletAttributed = AttributedString("• ")
        bulletAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
        bulletAttributed.foregroundColor = Color.secondary
        
        // Add the list item text with normal styling
        var contentAttributed = AttributedString(bulletText)
        contentAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
        contentAttributed.foregroundColor = Color.primary
        
        // Combine them
        fullAttributed.append(bulletAttributed)
        fullAttributed.append(contentAttributed)
        
        return fullAttributed
    }
    
    private func checkForAnnotations(in text: String, baseFontSize: CGFloat) -> (hasAnnotations: Bool, attributedString: AttributedString) {
        // Check if text contains annotation patterns {text}
        let pattern = #"\{([^}]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (false, AttributedString(text))
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        if matches.isEmpty {
            return (false, AttributedString(text))
        }

        var fullAttributed = AttributedString()
        var lastLocation = 0

        for match in matches {
            let fullRange = match.range
            let textRange = match.range(at: 1) // Capture group - text inside braces

            // Add text before the annotation
            if fullRange.location > lastLocation {
                let beforeRange = NSRange(location: lastLocation, length: fullRange.location - lastLocation)
                let beforeText = nsText.substring(with: beforeRange)
                var beforeAttributed = AttributedString(beforeText)
                beforeAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
                beforeAttributed.foregroundColor = Color.primary
                fullAttributed.append(beforeAttributed)
            }

            // Add the annotated text with highlighting
            if textRange.location != NSNotFound {
                let annotatedText = nsText.substring(with: textRange)
                var annotatedAttributed = AttributedString(annotatedText)
                annotatedAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
                annotatedAttributed.foregroundColor = Color.primary
                annotatedAttributed.backgroundColor = Color.yellow.opacity(0.3) // Highlight color
                fullAttributed.append(annotatedAttributed)
            }

            lastLocation = fullRange.location + fullRange.length
        }

        // Add remaining text after last annotation
        if lastLocation < nsText.length {
            let remainingRange = NSRange(location: lastLocation, length: nsText.length - lastLocation)
            let remainingText = nsText.substring(with: remainingRange)
            var remainingAttributed = AttributedString(remainingText)
            remainingAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
            remainingAttributed.foregroundColor = Color.primary
            fullAttributed.append(remainingAttributed)
        }

        return (true, fullAttributed)
    }

    private func parseInlineMarkdown(_ text: String, baseFontSize: CGFloat) -> AttributedString {
        // Parse inline bold (**text**) and italic (*text*) within a paragraph
        // Pattern matches **bold** or *italic* but not *** (which would be bold+italic marker)
        let pattern = #"(\*\*([^*]+)\*\*|\*([^*]+)\*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            var attributed = AttributedString(text)
            attributed.font = UIFont.systemFont(ofSize: baseFontSize)
            return attributed
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        if matches.isEmpty {
            var attributed = AttributedString(text)
            attributed.font = UIFont.systemFont(ofSize: baseFontSize)
            return attributed
        }

        var fullAttributed = AttributedString()
        var lastLocation = 0

        for match in matches {
            let fullRange = match.range
            let boldTextRange = match.range(at: 2) // Capture group 2 - text inside **
            let italicTextRange = match.range(at: 3) // Capture group 3 - text inside *

            // Add text before the formatted section
            if fullRange.location > lastLocation {
                let beforeRange = NSRange(location: lastLocation, length: fullRange.location - lastLocation)
                let beforeText = nsText.substring(with: beforeRange)
                var beforeAttributed = AttributedString(beforeText)
                beforeAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
                beforeAttributed.foregroundColor = Color.primary
                fullAttributed.append(beforeAttributed)
            }

            // Check if it's bold text (**text**)
            if boldTextRange.location != NSNotFound {
                let boldText = nsText.substring(with: boldTextRange)
                var boldAttributed = AttributedString(boldText)
                boldAttributed.font = UIFont.boldSystemFont(ofSize: baseFontSize)
                boldAttributed.foregroundColor = Color.primary
                fullAttributed.append(boldAttributed)
            }
            // Check if it's italic text (*text*)
            else if italicTextRange.location != NSNotFound {
                let italicText = nsText.substring(with: italicTextRange)
                var italicAttributed = AttributedString(italicText)
                italicAttributed.font = UIFont.italicSystemFont(ofSize: baseFontSize)
                italicAttributed.foregroundColor = Color.primary
                fullAttributed.append(italicAttributed)
            }

            lastLocation = fullRange.location + fullRange.length
        }

        // Add remaining text after last formatted section
        if lastLocation < nsText.length {
            let remainingRange = NSRange(location: lastLocation, length: nsText.length - lastLocation)
            let remainingText = nsText.substring(with: remainingRange)
            var remainingAttributed = AttributedString(remainingText)
            remainingAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
            remainingAttributed.foregroundColor = Color.primary
            fullAttributed.append(remainingAttributed)
        }

        return fullAttributed
    }
    
    private var attributedText: AttributedString {
        let shouldShowFormatting = !isCurrentParagraph

        // Safe font size validation with NaN protection
        let validFontSize = fontSize.isFinite && !fontSize.isNaN && fontSize > 0 ? fontSize : 16
        let safeFontSize = max(12, min(32, validFontSize))

        if shouldShowFormatting {
            // Headers
            if text.hasPrefix("# ") {
                return createHeaderAttributedString(text: text, headerLevel: 1, baseFontSize: safeFontSize)
            } else if text.hasPrefix("## ") {
                return createHeaderAttributedString(text: text, headerLevel: 2, baseFontSize: safeFontSize)
            } else if text.hasPrefix("### ") {
                return createHeaderAttributedString(text: text, headerLevel: 3, baseFontSize: safeFontSize)
            }
            
            // Bullet lists
            if text.hasPrefix("- ") {
                return createBulletListAttributedString(text: text, baseFontSize: safeFontSize)
            }
            
            // Annotations (check for {text} patterns)
            let annotationResult = checkForAnnotations(in: text, baseFontSize: safeFontSize)
            if annotationResult.hasAnnotations {
                return annotationResult.attributedString
            }

            // Check for inline bold/italic formatting
            if text.contains("*") {
                return parseInlineMarkdown(text, baseFontSize: safeFontSize)
            }
        }
        
        // Fallback for plain text
        var attributed = AttributedString(text)
        attributed.font = UIFont.systemFont(ofSize: safeFontSize)
        return attributed
    }
}

struct MarkdownReadOnlyView: View {
    @EnvironmentObject var appState: AppState
    
    let text: String
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let paragraphSpacing: CGFloat
    let fontFamily: String
    let editorMargins: CGFloat
    
    init(text: String, fontSize: CGFloat, lineSpacing: CGFloat = 1.4, paragraphSpacing: CGFloat = 8, fontFamily: String = "system", editorMargins: CGFloat = 40) {
        self.text = text
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.fontFamily = fontFamily
        self.editorMargins = editorMargins
    }
    
    private var safeFontSize: CGFloat {
        guard fontSize.isFinite && !fontSize.isNaN && fontSize > 0 else { return 16 }
        return max(10, min(72, fontSize))
    }
    
    private var safeLineSpacing: CGFloat {
        guard lineSpacing.isFinite && !lineSpacing.isNaN && lineSpacing > 0 else { return 1.4 }
        return max(0.5, min(3.0, lineSpacing))
    }
    
    private var safeParagraphSpacing: CGFloat {
        guard paragraphSpacing.isFinite && !paragraphSpacing.isNaN && paragraphSpacing >= 0 else { return 8 }
        return max(0, min(24, paragraphSpacing))
    }
    
    private var paragraphs: [String] {
        text.components(separatedBy: .newlines)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    MarkdownHighlightedText(
                        text: paragraph.isEmpty ? " " : paragraph,
                        fontSize: safeFontSize,
                        isCurrentParagraph: false,
                        lineSpacing: safeLineSpacing,
                        paragraphSpacing: safeParagraphSpacing,
                        fontFamily: fontFamily
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, editorMargins)
            .padding(.vertical, 8)
        }
    }
}

struct MarkdownTextEditor: View {
    @EnvironmentObject var appState: AppState
    @Binding var text: String
    @Binding var isTypewriterMode: Bool
    @Binding var isFocusMode: Bool
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let paragraphSpacing: CGFloat
    let fontFamily: String
    let editorMargins: CGFloat
    let hideShortcutBar: Bool
    let disableQuickType: Bool
    let onTextChange: (String) -> Void
    
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var currentLineIndex: Int = 0
    @State private var cursorPosition: Int = 0
    @State private var textEditorHeight: CGFloat = 0
    @State private var cursorPositionInLine: Int = 0
    @State private var lastTextLength: Int = 0
    @FocusState private var isTextEditorFocused: Bool
    
    private var safeFontSize: CGFloat {
        guard fontSize.isFinite && !fontSize.isNaN && fontSize > 0 else { return 16 }
        return max(10, min(72, fontSize))
    }
    
    private var safeLineSpacing: CGFloat {
        guard lineSpacing.isFinite && !lineSpacing.isNaN && lineSpacing > 0 else { return 1.4 }
        return max(0.5, min(3.0, lineSpacing))
    }
    
    private var safeParagraphSpacing: CGFloat {
        guard paragraphSpacing.isFinite && !paragraphSpacing.isNaN && paragraphSpacing >= 0 else { return 8 }
        return max(0, min(24, paragraphSpacing))
    }
    
    private func getFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch fontFamily {
        case "serif":
            return .custom("Times New Roman", size: size).weight(weight)
        case "monospace":
            return .custom("Menlo", size: size).weight(weight)
        case "times":
            return .custom("Times", size: size).weight(weight)
        case "helvetica":
            return .custom("Helvetica", size: size).weight(weight)
        case "courier":
            return .custom("Courier", size: size).weight(weight)
        case "avenir":
            return .custom("Avenir", size: size).weight(weight)
        case "georgia":
            return .custom("Georgia", size: size).weight(weight)
        default:
            return .system(size: size, weight: weight, design: .default)
        }
    }
    
    private var paragraphs: [String] {
        text.components(separatedBy: .newlines)
    }
    
    private func getCurrentLineIndex(from position: Int) -> Int {
        guard position >= 0 else { 
            return 0 
        }
        
        let lines = text.components(separatedBy: .newlines)
        guard !lines.isEmpty else { 
            return 0 
        }
        
        var currentLength = 0
        
        for (index, line) in lines.enumerated() {
            // Check if cursor is within this line
            let lineEnd = currentLength + line.count
            
            if position <= lineEnd {
                // Also calculate position within this line
                cursorPositionInLine = position - currentLength
                return index
            }
            currentLength = lineEnd + 1 // +1 for newline character
        }
        
        // If we're past the end, return the last line
        if let lastLine = lines.last {
            cursorPositionInLine = lastLine.count
        } else {
            cursorPositionInLine = 0
        }
        let lastLineIndex = max(0, lines.count - 1)
        return lastLineIndex
    }
    
    private func calculateLineHeight(for paragraph: String) -> CGFloat {
        // Add the compensated paragraph spacing used in TextEditor
        let compensatedParagraphSpacing = safeParagraphSpacing * 0.5
        let totalLineSpacing = safeLineSpacing + compensatedParagraphSpacing
        
        // Calculate final height to match TextEditor exactly
        let lineHeight = safeFontSize * totalLineSpacing
        let paragraphSpacingHeight = paragraph.isEmpty ? 0 : safeParagraphSpacing
        
        return lineHeight + paragraphSpacingHeight
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ZStack {
                    // Custom paragraph spacing background
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            Text(paragraph.isEmpty ? " " : paragraph)
                                .font(getFont(size: safeFontSize))
                                .lineSpacing(safeLineSpacing)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, paragraph.isEmpty ? 0 : safeParagraphSpacing)
                                .opacity(0) // Invisible - just for spacing
                        }
                    }
                    .padding(.horizontal, editorMargins)
                    .padding(.vertical, 8)
                    
                    // Actual TextEditor
                    TextEditor(text: $text)
                        .font(getFont(size: safeFontSize))
                        .lineSpacing(safeLineSpacing + safeParagraphSpacing * 0.5) // Compensate for paragraph spacing
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .foregroundColor(.primary)
                        .focused($isTextEditorFocused)
                        .autocorrectionDisabled(disableQuickType)
                        .padding(.horizontal, editorMargins)
                        .padding(.vertical, 8)
                        .padding(.top, isTypewriterMode ? geometry.size.height * 0.25 : 0)
                        .padding(.bottom, isTypewriterMode ? geometry.size.height * 0.75 : 0)
                        .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification)) { notification in
                            if let textView = notification.object as? UITextView, textView.isFirstResponder {
                                // Reduce jumping by batching cursor updates
                                DispatchQueue.main.async {
                                    updateCursorPosition(textView.selectedRange)
                                }
                            }
                        }
                        .onAppear {
                            // Configure TextEditor for stability
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                configureTextViewForStability()
                            }
                        }
                }
                // Focus Mode Overlay - Only active when not in typewriter mode
                if isFocusMode && !isTypewriterMode {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            // Create a view that exactly matches the spacing structure
                            VStack(alignment: .leading, spacing: 0) {
                                Rectangle()
                                    .fill(index == currentLineIndex ? Color.clear : Color(.systemBackground).opacity(0.75))
                                    .frame(height: safeFontSize * safeLineSpacing)
                                
                                // Add paragraph spacing if not empty
                                if !paragraph.isEmpty {
                                    Rectangle()
                                        .fill(index == currentLineIndex ? Color.clear : Color(.systemBackground).opacity(0.75))
                                        .frame(height: safeParagraphSpacing)
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: currentLineIndex)
                        }
                    }
                    .allowsHitTesting(false)
                    .padding(.horizontal, editorMargins)
                    .padding(.vertical, 8)
                }
                
                // Typewriter Mode Overlay - dims all lines except current line
                if isTypewriterMode {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            // Create a view that exactly matches the spacing structure
                            VStack(alignment: .leading, spacing: 0) {
                                Rectangle()
                                    .fill(index == currentLineIndex ? Color.clear : Color(.systemBackground).opacity(0.85))
                                    .frame(height: safeFontSize * safeLineSpacing * 0.95) // Slightly smaller to prevent bleeding
                                
                                // Add paragraph spacing if not empty, but smaller
                                if !paragraph.isEmpty {
                                    Rectangle()
                                        .fill(index == currentLineIndex ? Color.clear : Color(.systemBackground).opacity(0.85))
                                        .frame(height: safeParagraphSpacing * 0.8) // Reduced to prevent overlap
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: currentLineIndex)
                        }
                    }
                    .allowsHitTesting(false)
                    .padding(.horizontal, editorMargins)
                    .padding(.vertical, 8)
                    .padding(.top, geometry.size.height * 0.25)
                    .padding(.bottom, geometry.size.height * 0.75)
                }
            }
        }
        .frame(minHeight: 200) // Minimum height to prevent jumping
        .clipped() // Prevent content from overflowing
        .toolbar {
            if !hideShortcutBar {
                ToolbarItemGroup(placement: .keyboard) {
                    HStack(spacing: 8) {
                        Button("**Bold**") { insertMarkdown("**", "**") }
                            .font(.caption)
                        Button("*Italic*") { insertMarkdown("*", "*") }
                            .font(.caption)
                        Button("# Header") { insertMarkdown("# ", "") }
                            .font(.caption)
                        Button("Hide") { isTextEditorFocused = false }
                            .font(.caption)
                    }
                }
            }
        }
        .onChange(of: text) { _, newValue in
            onTextChange(newValue)
            // Don't update cursor position here - let the UIKit notifications handle it
            lastTextLength = newValue.count
            // Track writing activity for time-based goals (debounce this)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                WritingSessionService.shared.recordActivity()
            }
        }
        .onChange(of: isTextEditorFocused) { _, focused in
            if focused {
                // Update current line when focus changes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    updateCurrentLine()
                }
            }
        }
        .onTapGesture {
            isTextEditorFocused = true
        }
        .onAppear {
            // Initialize tracking variables
            lastTextLength = text.count
            cursorPosition = text.count
            
            // Initialize cursor position tracking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                updateCurrentLine()
            }
            
        }
        .onDisappear {
            // Note: removeObserver with 'self' may not work correctly in SwiftUI
            // The notification observer will be cleaned up automatically when the closure is deallocated
        }
    }
    
    private func updateCurrentLine() {
        DispatchQueue.main.async {
            // Use the tracked cursor position
            currentLineIndex = getCurrentLineIndex(from: cursorPosition)
        }
    }
    
    private func updateCursorPosition(_ range: NSRange) {
        // Debounce cursor updates to reduce jumping
        let newPosition = range.location
        guard newPosition != cursorPosition else { return }
        
        DispatchQueue.main.async {
            self.cursorPosition = newPosition
            let newLineIndex = self.getCurrentLineIndex(from: newPosition)
            if newLineIndex != self.currentLineIndex {
                withAnimation(.easeInOut(duration: 0.1)) {
                    self.currentLineIndex = newLineIndex
                }
            }
        }
    }
    
    
    private func updateCurrentLineFromPosition(_ position: Int) {
        DispatchQueue.main.async {
            currentLineIndex = getCurrentLineIndex(from: position)
        }
    }
    
    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        // For simple implementation, append to end of text
        // In a more sophisticated version, we'd insert at cursor position
        let currentText = text
        if suffix.isEmpty {
            // For headers and lists, add at beginning of new line
            if currentText.isEmpty || currentText.hasSuffix("\n") {
                text = currentText + prefix
            } else {
                text = currentText + "\n" + prefix
            }
        } else {
            // For bold/italic, wrap the text
            text = currentText + prefix + suffix
        }
    }
    
    private func insertTab() {
        text = text + "\t"
    }
    
    private func configureTextViewForStability() {
        // Find the UITextView and configure it for better stability
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                self.findAndConfigureTextView(in: window)
            }
        }
    }
    
    private func findAndConfigureTextView(in view: UIView) {
        for subview in view.subviews {
            if let textView = subview as? UITextView {
                // Configure for reduced jumping
                textView.isScrollEnabled = true
                textView.showsVerticalScrollIndicator = false
                textView.showsHorizontalScrollIndicator = false
                textView.contentInsetAdjustmentBehavior = .never
                textView.textContainer.widthTracksTextView = true
                textView.textContainer.heightTracksTextView = false
                textView.layoutManager.allowsNonContiguousLayout = false
                return
            } else {
                findAndConfigureTextView(in: subview)
            }
        }
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
        lineSpacing: 1.4,
        paragraphSpacing: 8,
        fontFamily: "system",
        editorMargins: 40,
        hideShortcutBar: false,
        disableQuickType: false,
        onTextChange: { newText in
            print("Text changed: \(newText.count) characters")
        }
    )
    .environmentObject(AppState())
}
