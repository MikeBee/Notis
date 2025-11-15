//
//  FindReplaceView.swift
//  Notis
//
//  Created by Claude on 11/2/25.
//  Enhanced with robust search & replace functionality
//

import SwiftUI
import CoreData

#if canImport(AppKit)
import AppKit
#endif

struct FindReplaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    @Binding var text: String
    let currentSheet: Sheet?

    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var caseSensitive = false
    @State private var wholeWords = false
    @State private var useRegex = false
    @State private var wrapAround = true
    @State private var searchScope: SearchScope = .currentNote

    @State private var currentMatch = 0
    @State private var totalMatches = 0
    @State private var searchResults: [NSRange] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var recentSearches: [String] = []
    @State private var showHistory = false

    @FocusState private var searchFieldFocused: Bool

    enum SearchScope: String, CaseIterable {
        case currentNote = "Current Note"
        case allNotes = "All Notes"

        var icon: String {
            switch self {
            case .currentNote: return "doc.text"
            case .allNotes: return "doc.on.doc"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Find & Replace")
                    .font(UlyssesDesign.Typography.editorH4)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, UlyssesDesign.Spacing.xl)
            .padding(.top, UlyssesDesign.Spacing.lg)
            .padding(.bottom, UlyssesDesign.Spacing.md)

            Divider()
                .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))

            ScrollView {
                VStack(spacing: UlyssesDesign.Spacing.lg) {
                    // Search Field
                    VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.xs) {
                        HStack {
                            Label("Find", systemImage: "magnifyingglass")
                                .font(UlyssesDesign.Typography.caption)
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))

                            Spacer()

                            if !recentSearches.isEmpty {
                                Button(action: { showHistory.toggle() }) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 12))
                                        .foregroundColor(UlyssesDesign.Colors.accent)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Recent Searches")
                            }
                        }

                        HStack(spacing: UlyssesDesign.Spacing.sm) {
                            SearchTextField(
                                text: $searchText,
                                placeholder: "Search text...",
                                colorScheme: colorScheme,
                                onSubmit: {
                                    performSearch()
                                    findNext()
                                }
                            )
                            .focused($searchFieldFocused)
                            .onChange(of: searchText) { _, _ in
                                performSearch()
                            }

                            // Navigation buttons
                            HStack(spacing: 4) {
                                Button(action: findPrevious) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(searchResults.isEmpty ? UlyssesDesign.Colors.tertiary(for: colorScheme) : UlyssesDesign.Colors.primary(for: colorScheme))
                                        .frame(width: 28, height: 28)
                                        .background(
                                            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                                                .fill(UlyssesDesign.Colors.surface(for: colorScheme))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(searchResults.isEmpty)
                                .keyboardShortcut("g", modifiers: [.command, .shift])
                                .help("Find Previous (⇧⌘G)")

                                Button(action: findNext) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(searchResults.isEmpty ? UlyssesDesign.Colors.tertiary(for: colorScheme) : UlyssesDesign.Colors.primary(for: colorScheme))
                                        .frame(width: 28, height: 28)
                                        .background(
                                            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                                                .fill(UlyssesDesign.Colors.surface(for: colorScheme))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(searchResults.isEmpty)
                                .keyboardShortcut("g", modifiers: .command)
                                .help("Find Next (⌘G)")
                            }
                        }

                        // Recent searches dropdown
                        if showHistory && !recentSearches.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(recentSearches.prefix(5), id: \.self) { recent in
                                    Button(action: {
                                        searchText = recent
                                        showHistory = false
                                        performSearch()
                                    }) {
                                        HStack {
                                            Image(systemName: "clock")
                                                .font(.system(size: 10))
                                                .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                                            Text(recent)
                                                .font(UlyssesDesign.Typography.caption)
                                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                                            Spacer()
                                        }
                                        .padding(.horizontal, UlyssesDesign.Spacing.sm)
                                        .padding(.vertical, UlyssesDesign.Spacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                                                .fill(UlyssesDesign.Colors.surface(for: colorScheme))
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(UlyssesDesign.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.medium)
                                    .fill(UlyssesDesign.Colors.background(for: colorScheme))
                                    .shadow(color: UlyssesDesign.Shadows.medium, radius: 8)
                            )
                        }

                        // Match counter
                        if !searchResults.isEmpty {
                            HStack {
                                Text("\(currentMatch + 1) of \(totalMatches)")
                                    .font(UlyssesDesign.Typography.caption)
                                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                                    .padding(.leading, UlyssesDesign.Spacing.xs)
                                Spacer()
                            }
                        } else if !searchText.isEmpty {
                            HStack {
                                Text("No matches found")
                                    .font(UlyssesDesign.Typography.caption)
                                    .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                                    .padding(.leading, UlyssesDesign.Spacing.xs)
                                Spacer()
                            }
                        }
                    }

                    // Replace Field
                    VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.xs) {
                        Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                            .font(UlyssesDesign.Typography.caption)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))

                        HStack(spacing: UlyssesDesign.Spacing.sm) {
                            SearchTextField(
                                text: $replaceText,
                                placeholder: "Replace with...",
                                colorScheme: colorScheme,
                                onSubmit: replaceCurrentMatch
                            )

                            // Replace buttons
                            HStack(spacing: 4) {
                                Button(action: replaceCurrentMatch) {
                                    Text("Replace")
                                        .font(UlyssesDesign.Typography.buttonLabel)
                                        .foregroundColor(searchResults.isEmpty ? UlyssesDesign.Colors.tertiary(for: colorScheme) : .white)
                                        .padding(.horizontal, UlyssesDesign.Spacing.md)
                                        .padding(.vertical, UlyssesDesign.Spacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                                                .fill(searchResults.isEmpty ? UlyssesDesign.Colors.surface(for: colorScheme) : UlyssesDesign.Colors.accent)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(searchResults.isEmpty)
                                .keyboardShortcut(.return, modifiers: .command)
                                .help("Replace (⌘↩)")

                                Button(action: replaceAllMatches) {
                                    Text("All")
                                        .font(UlyssesDesign.Typography.buttonLabel)
                                        .foregroundColor(searchResults.isEmpty ? UlyssesDesign.Colors.tertiary(for: colorScheme) : UlyssesDesign.Colors.accent)
                                        .padding(.horizontal, UlyssesDesign.Spacing.md)
                                        .padding(.vertical, UlyssesDesign.Spacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                                                .stroke(searchResults.isEmpty ? UlyssesDesign.Colors.border(for: colorScheme) : UlyssesDesign.Colors.accent, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(searchResults.isEmpty)
                                .keyboardShortcut(.return, modifiers: [.command, .option])
                                .help("Replace All (⌘⌥↩)")
                            }
                        }
                    }

                    Divider()
                        .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))

                    // Search Options
                    VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.md) {
                        Text("Options")
                            .font(UlyssesDesign.Typography.caption)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))

                        VStack(spacing: UlyssesDesign.Spacing.sm) {
                            OptionToggle(
                                isOn: $caseSensitive,
                                icon: "textformat",
                                label: "Case Sensitive",
                                colorScheme: colorScheme
                            )
                            .onChange(of: caseSensitive) { _, _ in
                                performSearch()
                            }

                            OptionToggle(
                                isOn: $wholeWords,
                                icon: "text.word.spacing",
                                label: "Whole Words",
                                colorScheme: colorScheme
                            )
                            .onChange(of: wholeWords) { _, _ in
                                performSearch()
                            }

                            OptionToggle(
                                isOn: $useRegex,
                                icon: "asterisk.circle",
                                label: "Regular Expression",
                                colorScheme: colorScheme
                            )
                            .onChange(of: useRegex) { _, _ in
                                performSearch()
                            }

                            OptionToggle(
                                isOn: $wrapAround,
                                icon: "arrow.circlepath",
                                label: "Wrap Around",
                                colorScheme: colorScheme
                            )
                        }
                    }

                    // Search Scope (only if we have access to other notes)
                    if currentSheet != nil {
                        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.md) {
                            Text("Search In")
                                .font(UlyssesDesign.Typography.caption)
                                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))

                            HStack(spacing: UlyssesDesign.Spacing.sm) {
                                ForEach(SearchScope.allCases, id: \.self) { scope in
                                    Button(action: {
                                        searchScope = scope
                                        if scope == .allNotes {
                                            // Future: implement multi-note search
                                            errorMessage = "Multi-note search coming soon!"
                                            showingError = true
                                        }
                                    }) {
                                        HStack(spacing: UlyssesDesign.Spacing.xs) {
                                            Image(systemName: scope.icon)
                                                .font(.system(size: 12))
                                            Text(scope.rawValue)
                                                .font(UlyssesDesign.Typography.caption)
                                        }
                                        .foregroundColor(searchScope == scope ? .white : UlyssesDesign.Colors.primary(for: colorScheme))
                                        .padding(.horizontal, UlyssesDesign.Spacing.md)
                                        .padding(.vertical, UlyssesDesign.Spacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                                                .fill(searchScope == scope ? UlyssesDesign.Colors.accent : UlyssesDesign.Colors.surface(for: colorScheme))
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }

                    // Error message
                    if showingError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(UlyssesDesign.Typography.caption)
                                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                            Spacer()
                            Button("Dismiss") {
                                showingError = false
                            }
                            .buttonStyle(PlainButtonStyle())
                            .font(UlyssesDesign.Typography.caption)
                        }
                        .padding(UlyssesDesign.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.medium)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                }
                .padding(UlyssesDesign.Spacing.xl)
            }
        }
        .frame(width: 500, height: 550)
        .background(UlyssesDesign.Colors.background(for: colorScheme))
        .cornerRadius(UlyssesDesign.CornerRadius.large)
        .shadow(color: UlyssesDesign.Shadows.strong, radius: 20)
        .onAppear {
            searchFieldFocused = true
            loadRecentSearches()
        }
    }

    // MARK: - Search Functions

    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            totalMatches = 0
            currentMatch = 0
            return
        }

        // Save to recent searches
        saveRecentSearch(searchText)

        searchResults = []
        let nsText = text as NSString

        if useRegex {
            // Regular expression search
            do {
                var options: NSRegularExpression.Options = []
                if !caseSensitive {
                    options.insert(.caseInsensitive)
                }

                let regex = try NSRegularExpression(pattern: searchText, options: options)
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
                searchResults = matches.map { $0.range }
            } catch {
                errorMessage = "Invalid regular expression: \(error.localizedDescription)"
                showingError = true
                return
            }
        } else {
            // Standard text search
            var searchRange = NSRange(location: 0, length: nsText.length)
            var options: NSString.CompareOptions = []

            if !caseSensitive {
                options.insert(.caseInsensitive)
            }

            while searchRange.location < nsText.length {
                let foundRange = nsText.range(of: searchText, options: options, range: searchRange)
                if foundRange.location == NSNotFound {
                    break
                }

                // Check whole word matching if enabled
                if wholeWords {
                    if isWholeWord(range: foundRange, in: text) {
                        searchResults.append(foundRange)
                    }
                } else {
                    searchResults.append(foundRange)
                }

                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = nsText.length - searchRange.location
            }
        }

        totalMatches = searchResults.count
        currentMatch = totalMatches > 0 ? 0 : 0
    }

    private func isWholeWord(range: NSRange, in text: String) -> Bool {
        let nsText = text as NSString

        // Check character before match
        if range.location > 0 {
            let charBefore = nsText.substring(with: NSRange(location: range.location - 1, length: 1))
            if charBefore.rangeOfCharacter(from: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))) != nil {
                return false
            }
        }

        // Check character after match
        let endLocation = range.location + range.length
        if endLocation < nsText.length {
            let charAfter = nsText.substring(with: NSRange(location: endLocation, length: 1))
            if charAfter.rangeOfCharacter(from: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))) != nil {
                return false
            }
        }

        return true
    }

    private func findNext() {
        guard !searchResults.isEmpty else { return }

        if wrapAround {
            currentMatch = (currentMatch + 1) % searchResults.count
        } else {
            if currentMatch < searchResults.count - 1 {
                currentMatch += 1
            }
        }
    }

    private func findPrevious() {
        guard !searchResults.isEmpty else { return }

        if wrapAround {
            currentMatch = currentMatch > 0 ? currentMatch - 1 : searchResults.count - 1
        } else {
            if currentMatch > 0 {
                currentMatch -= 1
            }
        }
    }

    private func replaceCurrentMatch() {
        guard !searchResults.isEmpty, currentMatch < searchResults.count else { return }

        let range = searchResults[currentMatch]
        let nsText = text as NSString
        text = nsText.replacingCharacters(in: range, with: replaceText)

        // Update search results after replacement
        performSearch()

        // Move to next match if available
        if !searchResults.isEmpty && currentMatch < searchResults.count {
            // Stay at same index (which is now the next match)
        } else if !searchResults.isEmpty {
            currentMatch = 0
        }
    }

    private func replaceAllMatches() {
        guard !searchResults.isEmpty else { return }

        // Show confirmation for large replacements
        if searchResults.count > 50 {
            errorMessage = "This will replace \(searchResults.count) matches. Please use Replace button for large operations."
            showingError = true
            return
        }

        // Replace from last to first to maintain ranges
        let sortedResults = searchResults.sorted { $0.location > $1.location }
        var newText = text
        var replacementCount = 0

        for range in sortedResults {
            newText = (newText as NSString).replacingCharacters(in: range, with: replaceText)
            replacementCount += 1
        }

        text = newText

        // Show success message
        errorMessage = "Replaced \(replacementCount) occurrence\(replacementCount == 1 ? "" : "s")"
        showingError = true

        performSearch()
    }

    // MARK: - Recent Searches

    private func loadRecentSearches() {
        if let searches = UserDefaults.standard.stringArray(forKey: "recentSearches") {
            recentSearches = searches
        }
    }

    private func saveRecentSearch(_ search: String) {
        guard !search.isEmpty else { return }

        // Remove if already exists
        recentSearches.removeAll { $0 == search }

        // Add to front
        recentSearches.insert(search, at: 0)

        // Keep only last 10
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }

        UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
    }
}

// MARK: - Supporting Views

struct SearchTextField: View {
    @Binding var text: String
    let placeholder: String
    let colorScheme: ColorScheme
    let onSubmit: () -> Void

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .font(UlyssesDesign.Typography.editorBody)
            .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
            .padding(UlyssesDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                    .fill(UlyssesDesign.Colors.surface(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                            .stroke(UlyssesDesign.Colors.border(for: colorScheme), lineWidth: 0.5)
                    )
            )
            .onSubmit(onSubmit)
    }
}

struct OptionToggle: View {
    @Binding var isOn: Bool
    let icon: String
    let label: String
    let colorScheme: ColorScheme

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: UlyssesDesign.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isOn ? UlyssesDesign.Colors.accent : UlyssesDesign.Colors.secondary(for: colorScheme))
                    .frame(width: 20)

                Text(label)
                    .font(UlyssesDesign.Typography.buttonLabel)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: UlyssesDesign.Colors.accent))
            }
            .padding(UlyssesDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                    .fill(isOn ? UlyssesDesign.Colors.accent.opacity(0.1) : UlyssesDesign.Colors.surface(for: colorScheme))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sampleText = """
    This is a sample text with some words.
    We can search for words and replace them.
    Words, words everywhere!

    Regular expressions like \\d+ can match numbers: 123, 456, 789.
    Whole word matching ensures 'word' doesn't match 'words'.

    Case sensitive search differentiates Word from word.
    """

    FindReplaceView(text: $sampleText, currentSheet: nil)
}
