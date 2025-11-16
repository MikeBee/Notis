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

    @AppStorage("h1Color") private var h1Color: String = "default"
    @AppStorage("h2Color") private var h2Color: String = "default"
    @AppStorage("h3Color") private var h3Color: String = "default"
    @AppStorage("h1SizeMultiplier") private var h1SizeMultiplier: Double = 1.5
    @AppStorage("h2SizeMultiplier") private var h2SizeMultiplier: Double = 1.3
    @AppStorage("h3SizeMultiplier") private var h3SizeMultiplier: Double = 1.1
    @AppStorage("highlightColor") private var highlightColor: String = "yellow"
    @AppStorage("annotationColor") private var annotationColor: String = "yellow"
    @AppStorage("strikethroughColor") private var strikethroughColor: String = "gray"

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

    private func headingColorFromName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "indigo": return .indigo
        case "cyan": return .cyan
        case "mint": return .mint
        case "brown": return .brown
        case "gray": return .gray
        default: return .primary
        }
    }

    private func getHeaderMultiplier(for level: Int) -> CGFloat {
        switch level {
        case 1: return CGFloat(h1SizeMultiplier)
        case 2: return CGFloat(h2SizeMultiplier)
        case 3: return CGFloat(h3SizeMultiplier)
        default: return 1.0
        }
    }

    private func getHeaderColor(for level: Int) -> Color {
        switch level {
        case 1: return headingColorFromName(h1Color)
        case 2: return headingColorFromName(h2Color)
        case 3: return headingColorFromName(h3Color)
        default: return .primary
        }
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
        
        // Add the header text with bold, large styling and custom color
        var contentAttributed = AttributedString(headerText)
        let fontMultiplier: CGFloat = getHeaderMultiplier(for: headerLevel)
        contentAttributed.font = UIFont.boldSystemFont(ofSize: baseFontSize * fontMultiplier)
        contentAttributed.foregroundColor = getHeaderColor(for: headerLevel)

        fullAttributed.append(contentAttributed)
        
        // Apply paragraph style for outdenting if header symbols are shown
        if appState.showMarkdownHeaderSymbols {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 30 // Regular text indented to align with body
            paragraphStyle.firstLineHeadIndent = 0 // First line (with H1/H2/H3) starts at margin
            // Use nonisolated assignment to avoid Sendable conformance requirement
            fullAttributed.paragraphStyle = paragraphStyle.copy() as? NSParagraphStyle
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
                annotatedAttributed.backgroundColor = headingColorFromName(annotationColor).opacity(0.3)
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
        // Parse inline markdown: {annotation}, ==highlight==, **bold**, *italic*, __bold__, _italic_, ~~strike~~, %%comment%%
        // Pattern matches all supported inline markdown formats
        // Order matters: match longer patterns first to avoid conflicts
        let pattern = #"(\{([^}]+)\}|==([^=]+)==|~~([^~]+)~~|%%([^%]+)%%|\*\*([^*]+)\*\*|__([^_]+)__|\*([^*]+)\*|_([^_]+)_)"#
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

            // Capture groups (reordered for priority):
            // 2: {annotation}
            // 3: ==highlight==
            // 4: ~~strikethrough~~
            // 5: %%comment%%
            // 6: **bold**
            // 7: __bold__
            // 8: *italic*
            // 9: _italic_

            // Add text before the formatted section
            if fullRange.location > lastLocation {
                let beforeRange = NSRange(location: lastLocation, length: fullRange.location - lastLocation)
                let beforeText = nsText.substring(with: beforeRange)
                var beforeAttributed = AttributedString(beforeText)
                beforeAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
                beforeAttributed.foregroundColor = Color.primary
                fullAttributed.append(beforeAttributed)
            }

            // Check which type of formatting it is (order matches pattern priority)
            if match.range(at: 2).location != NSNotFound {
                // {annotation}
                let annotationText = nsText.substring(with: match.range(at: 2))
                var annotationAttributed = AttributedString(annotationText)
                annotationAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
                annotationAttributed.foregroundColor = Color.primary
                annotationAttributed.backgroundColor = headingColorFromName(annotationColor).opacity(0.3)
                fullAttributed.append(annotationAttributed)
            }
            else if match.range(at: 3).location != NSNotFound {
                // ==highlight==
                let highlightText = nsText.substring(with: match.range(at: 3))
                var highlightAttributed = AttributedString(highlightText)
                highlightAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
                highlightAttributed.foregroundColor = Color.primary
                highlightAttributed.backgroundColor = headingColorFromName(highlightColor).opacity(0.3)
                fullAttributed.append(highlightAttributed)
            }
            else if match.range(at: 4).location != NSNotFound {
                // ~~strikethrough~~
                let strikeText = nsText.substring(with: match.range(at: 4))
                var strikeAttributed = AttributedString(strikeText)
                strikeAttributed.font = UIFont.systemFont(ofSize: baseFontSize)
                strikeAttributed.foregroundColor = headingColorFromName(strikethroughColor)
                strikeAttributed.strikethroughStyle = .single
                fullAttributed.append(strikeAttributed)
            }
            else if match.range(at: 5).location != NSNotFound {
                // %%comment%% - skip rendering (comments are hidden)
                // Don't add anything to the attributed string
            }
            else if match.range(at: 6).location != NSNotFound {
                // **bold**
                let boldText = nsText.substring(with: match.range(at: 6))
                var boldAttributed = AttributedString(boldText)
                boldAttributed.font = UIFont.boldSystemFont(ofSize: baseFontSize)
                boldAttributed.foregroundColor = Color.primary
                fullAttributed.append(boldAttributed)
            }
            else if match.range(at: 7).location != NSNotFound {
                // __bold__
                let boldText = nsText.substring(with: match.range(at: 7))
                var boldAttributed = AttributedString(boldText)
                boldAttributed.font = UIFont.boldSystemFont(ofSize: baseFontSize)
                boldAttributed.foregroundColor = Color.primary
                fullAttributed.append(boldAttributed)
            }
            else if match.range(at: 8).location != NSNotFound {
                // *italic*
                let italicText = nsText.substring(with: match.range(at: 8))
                var italicAttributed = AttributedString(italicText)
                italicAttributed.font = UIFont.italicSystemFont(ofSize: baseFontSize)
                italicAttributed.foregroundColor = Color.primary
                fullAttributed.append(italicAttributed)
            }
            else if match.range(at: 9).location != NSNotFound {
                // _italic_
                let italicText = nsText.substring(with: match.range(at: 9))
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

            // Check for inline markdown formatting (annotation, bold, italic, highlight, strikethrough, comments)
            if text.contains("{") || text.contains("*") || text.contains("_") || text.contains("~") || text.contains("=") || text.contains("%") {
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
    @Environment(\.undoManager) private var undoManager
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
    @State private var isHandlingListContinuation = false
    @FocusState private var isTextEditorFocused: Bool
    @AppStorage("showLineNumbers") private var showLineNumbers: Bool = false
    @State private var hasConfiguredTextView = false
    @State private var currentSentenceRange: NSRange = NSRange(location: 0, length: 0)
    
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

    private var lineNumberWidth: CGFloat {
        let lineCount = paragraphs.count
        let digits = String(lineCount).count
        return CGFloat(digits * 10 + 12) // Approximate width per digit + padding
    }

    private var effectiveEditorMargins: CGFloat {
        // Reduce left margin when line numbers are shown
        return showLineNumbers ? max(8, editorMargins - lineNumberWidth) : editorMargins
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

    private struct SentenceInfo: Identifiable {
        let id: Int
        let text: String
        let range: NSRange
    }

    private var sentences: [SentenceInfo] {
        let nsText = text as NSString
        guard nsText.length > 0 else { return [] }

        var result: [SentenceInfo] = []
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text

        var sentenceId = 0
        tagger.enumerateTags(in: NSRange(location: 0, length: nsText.length),
                            unit: .sentence,
                            scheme: .tokenType,
                            options: []) { _, range, _ in
            let sentenceText = nsText.substring(with: range)
            result.append(SentenceInfo(id: sentenceId, text: sentenceText, range: range))
            sentenceId += 1
        }

        return result
    }

    private var attributedStringForFocusMode: AttributedString {
        var result = AttributedString()

        for sentence in sentences {
            var sentenceAttr = AttributedString(sentence.text)

            // Dim non-current sentences with a semi-transparent background overlay
            // Use the tracked currentSentenceRange instead of recalculating
            let isCurrentSentence = (sentence.range.location == currentSentenceRange.location &&
                                    sentence.range.length == currentSentenceRange.length)

            if !isCurrentSentence {
                sentenceAttr.backgroundColor = Color(.systemBackground).opacity(0.75)
            }
            // Make the text itself transparent so we only see the background dimming
            sentenceAttr.foregroundColor = Color.clear

            result.append(sentenceAttr)
        }

        return result
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
            HStack(alignment: .top, spacing: 0) {
                // Line Numbers (if enabled)
                if showLineNumbers {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            Text("\(index + 1)")
                                .font(getFont(size: safeFontSize * 0.85))
                                .lineSpacing(safeLineSpacing)
                                .foregroundColor(.gray.opacity(0.5))
                                .frame(height: safeFontSize * safeLineSpacing + (paragraph.isEmpty ? 0 : safeParagraphSpacing), alignment: .top)
                                .padding(.bottom, paragraph.isEmpty ? 0 : safeParagraphSpacing)
                        }
                    }
                    .frame(width: lineNumberWidth)
                    .padding(.leading, 8)
                    .padding(.vertical, 8)
                    .padding(.top, isTypewriterMode ? geometry.size.height * 0.5 : (isFocusMode ? geometry.size.height * 0.25 : 0))
                    .padding(.bottom, isTypewriterMode ? geometry.size.height * 0.5 : (isFocusMode ? geometry.size.height * 0.75 : 0))
                }

                // Editor Content
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
                        .padding(.horizontal, effectiveEditorMargins)
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
                            .padding(.horizontal, effectiveEditorMargins)
                            .padding(.vertical, 8)
                            .padding(.top, isTypewriterMode ? geometry.size.height * 0.5 : (isFocusMode ? geometry.size.height * 0.25 : 0))
                            .padding(.bottom, isTypewriterMode ? geometry.size.height * 0.5 : (isFocusMode ? geometry.size.height * 0.75 : 0))
                            .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification)) { notification in
                                if let textView = notification.object as? UITextView, textView.isFirstResponder {
                                    let currentText = textView.text ?? ""

                                    if !isHandlingListContinuation {
                                        handleListContinuationFromTextView(textView: textView, currentText: currentText)
                                    }

                                    DispatchQueue.main.async {
                                        updateCursorPosition(textView.selectedRange)
                                    }
                                }
                            }
                            .onAppear {
                                // Configure TextEditor for stability (only once)
                                if !hasConfiguredTextView {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        configureTextViewForStability()
                                    }
                                }
                            }
                    }

                    // Focus Mode Overlay - dims all lines except current line (positioned at upper quarter)
                    // Uses same overlay approach as Typewriter Mode but with upper quarter positioning
                    if isFocusMode && !isTypewriterMode {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                                VStack(alignment: .leading, spacing: 0) {
                                    Rectangle()
                                        .fill(index == currentLineIndex ? Color.clear : Color(.systemBackground).opacity(0.65))
                                        .frame(height: safeFontSize * safeLineSpacing * 0.95) // Slightly smaller to prevent bleeding

                                    // Add paragraph spacing if not empty, but smaller
                                    if !paragraph.isEmpty {
                                        Rectangle()
                                            .fill(index == currentLineIndex ? Color.clear : Color(.systemBackground).opacity(0.65))
                                            .frame(height: safeParagraphSpacing * 0.8) // Reduced to prevent overlap
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: currentLineIndex)
                            }
                        }
                        .allowsHitTesting(false)
                        .padding(.horizontal, effectiveEditorMargins)
                        .padding(.vertical, 8)
                        .padding(.top, geometry.size.height * 0.25)  // Upper quarter positioning
                        .padding(.bottom, geometry.size.height * 0.75)
                    }

                    // OLDER FOCUS MODE ATTEMPTS - PRESERVED FOR REFERENCE
                    // These approaches had alignment issues that varied with font size
                    //
                    // PROBLEM: Rectangle overlay heights don't align properly with actual text rendering.
                    // The alignment varies with font size - works at one size but breaks at others.
                    //
                    // MULTIPLIERS TRIED:
                    // Line height: 0.85, 0.88, 0.95, 1.05 (all had issues at different font sizes)
                    // Paragraph spacing: 0.7, 0.8, 0.9 (same problem)
                    //
                    // APPROACH TRIED: Text-based overlay with AttributedString
                    // - Created transparent text overlay with background colors
                    // - Problem: Text rendering in Text view doesn't align with TextEditor
                    //
                    // POTENTIAL FUTURE APPROACHES:
                    // 1. Use UITextView introspection to get actual line rectangles from layout manager
                    // 2. Use a blur effect instead of solid overlays
                    // 3. Modify TextEditor's attributed string directly (if possible)
                }
            }
        }
        .frame(minHeight: 400) // Minimum height to prevent jumping
        .clipped() // Prevent content from overflowing
        .toolbar {
            if !hideShortcutBar {
                ToolbarItemGroup(placement: .keyboard) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Text styling
                            Button("**Bold**") { insertMarkdown("**", "**") }
                                .font(.caption)
                            Button("*Italic*") { insertMarkdown("*", "*") }
                                .font(.caption)
                            Button("__Bold__") { insertMarkdown("__", "__") }
                                .font(.caption)
                            Button("_Italic_") { insertMarkdown("_", "_") }
                                .font(.caption)
                            Button("~~Strike~~") { insertMarkdown("~~", "~~") }
                                .font(.caption)
                            Button("==Highlight==") { insertMarkdown("==", "==") }
                                .font(.caption)

                            Divider()
                                .frame(height: 20)

                            // Structure
                            Button("# Header") { insertMarkdown("# ", "") }
                                .font(.caption)
                            Button("> Quote") { insertMarkdown("> ", "") }
                                .font(.caption)
                            Button("%%Comment%%") { insertMarkdown("%%", "%%") }
                                .font(.caption)
                            Button("Footnote") { insertFootnote() }
                                .font(.caption)

                            Divider()
                                .frame(height: 20)

                            Button("Hide") { isTextEditorFocused = false }
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                }
            }
        }
        .onChange(of: text) { oldValue, newValue in
            lastTextLength = newValue.count

            // Only call onTextChange if content actually changed (not just cursor movement)
            if oldValue != newValue {
                onTextChange(newValue)

                // Track writing activity for time-based goals (debounce this)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    WritingSessionService.shared.recordActivity()
                }
            }
        }
        .onChange(of: isTextEditorFocused) { _, focused in
            if focused {
                // Update current line when focus changes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    updateCurrentLine()
                    if isFocusMode {
                        updateCurrentSentence()
                    }
                }
            }
        }
        .onChange(of: isFocusMode) { _, enabled in
            if enabled {
                // Update sentence tracking when Focus mode is enabled
                DispatchQueue.main.async {
                    updateCurrentSentence()
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
                // Initialize sentence tracking for Focus mode
                if isFocusMode {
                    updateCurrentSentence()
                }
            }

        }
        .onDisappear {
            // Note: removeObserver with 'self' may not work correctly in SwiftUI
            // The notification observer will be cleaned up automatically when the closure is deallocated
        }
        .background(
            // Hidden button to handle Command+Y for redo
            Button("") {
                performRedo()
            }
            .keyboardShortcut("y", modifiers: .command)
            .hidden()
        )
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

            // Update current sentence for Focus mode
            if self.isFocusMode {
                self.updateCurrentSentence()
            }
        }
    }

    private func updateCurrentSentence() {
        let newSentenceRange = getCurrentSentenceRange(at: cursorPosition)
        if newSentenceRange.location != currentSentenceRange.location ||
           newSentenceRange.length != currentSentenceRange.length {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentSentenceRange = newSentenceRange
            }
        }
    }

    private func getCurrentSentenceRange(at position: Int) -> NSRange {
        let nsText = text as NSString
        guard nsText.length > 0 else { return NSRange(location: 0, length: 0) }

        // Clamp position to valid range
        let safePosition = max(0, min(position, nsText.length - 1))

        // Use NSLinguisticTagger to find sentence boundaries
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text

        var sentenceRange = NSRange(location: 0, length: 0)
        tagger.enumerateTags(in: NSRange(location: 0, length: nsText.length),
                            unit: .sentence,
                            scheme: .tokenType,
                            options: [.omitWhitespace]) { _, range, _ in
            if NSLocationInRange(safePosition, range) {
                sentenceRange = range
                return
            }
        }

        // Fallback: if no sentence found, return the whole text
        if sentenceRange.length == 0 {
            sentenceRange = NSRange(location: 0, length: nsText.length)
        }

        return sentenceRange
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

    private func insertFootnote() {
        // Find the next available footnote number
        let footnotePattern = #"\[\^(\d+)\]"#
        var maxNumber = 0

        if let regex = try? NSRegularExpression(pattern: footnotePattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if match.numberOfRanges > 1,
                   let numberRange = Range(match.range(at: 1), in: text),
                   let number = Int(text[numberRange]) {
                    maxNumber = max(maxNumber, number)
                }
            }
        }

        let nextNumber = maxNumber + 1
        let footnoteRef = "[^\(nextNumber)]"
        let footnoteDef = "\n[^\(nextNumber)]: "

        // Insert reference at current position
        let currentText = text
        text = currentText + footnoteRef

        // Add definition at the end of the document
        if !currentText.hasSuffix("\n") {
            text = text + "\n"
        }
        text = text + footnoteDef
    }

    private func performRedo() {
        // Trigger redo on the undo manager
        if let undoManager = undoManager, undoManager.canRedo {
            undoManager.redo()
        }
    }

    private func handleListContinuationFromTextView(textView: UITextView, currentText: String) {
        guard currentText.count > lastTextLength else { return }
        guard let lastChar = currentText.last, lastChar.isNewline else { return }

        let lines = currentText.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return }

        let previousLineIndex = lines.count - 2
        let previousLine = lines[previousLineIndex]

        // Check for bullet list (- )
        if previousLine.hasPrefix("- ") {
            let contentAfterBullet = previousLine.dropFirst(2)

            if contentAfterBullet.trimmingCharacters(in: .whitespaces).isEmpty {
                // Remove empty bullet point
                isHandlingListContinuation = true

                let newText = currentText.dropLast()
                var allLines = newText.components(separatedBy: .newlines)
                allLines[previousLineIndex] = ""
                let updatedText = allLines.joined(separator: "\n")

                self.text = updatedText

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.isHandlingListContinuation = false
                }
            } else {
                // Continue bullet list
                isHandlingListContinuation = true
                let updatedText = currentText + "- "
                self.text = updatedText

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.isHandlingListContinuation = false
                }
            }
            return
        }

        // Check for numbered list (1. , 2. , etc.)
        let numberedListPattern = #"^(\d+)\.\s"#
        if let regex = try? NSRegularExpression(pattern: numberedListPattern),
           let match = regex.firstMatch(in: previousLine, range: NSRange(previousLine.startIndex..., in: previousLine)),
           let numberRange = Range(match.range(at: 1), in: previousLine) {

            let numberString = String(previousLine[numberRange])
            let contentStart = previousLine.index(previousLine.startIndex, offsetBy: match.range.length)
            let contentAfterNumber = previousLine[contentStart...]

            if contentAfterNumber.trimmingCharacters(in: .whitespaces).isEmpty {
                // Remove empty numbered item
                isHandlingListContinuation = true

                let newText = currentText.dropLast()
                var allLines = newText.components(separatedBy: .newlines)
                allLines[previousLineIndex] = ""
                let updatedText = allLines.joined(separator: "\n")

                self.text = updatedText

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.isHandlingListContinuation = false
                }
            } else if let number = Int(numberString) {
                // Continue numbered list
                let nextNumber = number + 1
                isHandlingListContinuation = true

                let updatedText = currentText + "\(nextNumber). "
                self.text = updatedText

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.isHandlingListContinuation = false
                }
            }
        }
    }

    private func configureTextViewForStability() {
        // Find the UITextView and configure it for better stability (only once)
        guard !hasConfiguredTextView else { return }

        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                self.findAndConfigureTextView(in: window, depth: 0)
            }
        }
    }

    private func findAndConfigureTextView(in view: UIView, depth: Int) {
        // Prevent excessive recursion depth (max 15 levels)
        guard depth < 15 else { return }

        // Early exit if already configured
        guard !hasConfiguredTextView else { return }

        for subview in view.subviews {
            if let textView = subview as? UITextView {
                // Configure for smooth scrolling without jumping
                textView.isScrollEnabled = true
                textView.showsVerticalScrollIndicator = false
                textView.showsHorizontalScrollIndicator = false
                textView.contentInsetAdjustmentBehavior = .never
                textView.textContainer.widthTracksTextView = true
                textView.textContainer.heightTracksTextView = false

                // Add bottom padding to ensure text is visible when typing at bottom
                textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 200, right: 0)

                // Mark as configured to prevent repeated configuration
                hasConfiguredTextView = true

                return
            } else {
                findAndConfigureTextView(in: subview, depth: depth + 1)
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
            Logger.shared.debug("Text changed: \(newText.count) characters", category: .ui)
        }
    )
    .environmentObject(AppState())
}
