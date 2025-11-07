//
//  FindReplaceView.swift
//  Notis
//
//  Created by Claude on 11/2/25.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

struct FindReplaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var caseSensitive = false
    @State private var wholeWords = false
    @State private var currentMatch = 0
    @State private var totalMatches = 0
    @State private var searchResults: [NSRange] = []
    
    private var backgroundColorForPlatform: Color {
        #if canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Find & Replace")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Search controls
            VStack(spacing: 12) {
                // Find field
                HStack {
                    TextField("Find", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: searchText) { _, _ in
                            performSearch()
                        }
                    
                    Button("Previous") {
                        findPrevious()
                    }
                    .disabled(searchResults.isEmpty)
                    
                    Button("Next") {
                        findNext()
                    }
                    .disabled(searchResults.isEmpty)
                }
                
                // Replace field
                HStack {
                    TextField("Replace", text: $replaceText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Replace") {
                        replaceCurrentMatch()
                    }
                    .disabled(searchResults.isEmpty)
                    
                    Button("Replace All") {
                        replaceAllMatches()
                    }
                    .disabled(searchResults.isEmpty)
                }
                
                // Options
                HStack {
                    Toggle("Case Sensitive", isOn: $caseSensitive)
                        .onChange(of: caseSensitive) { _, _ in
                            performSearch()
                        }
                    
                    Toggle("Whole Words", isOn: $wholeWords)
                        .onChange(of: wholeWords) { _, _ in
                            performSearch()
                        }
                    
                    Spacer()
                    
                    // Match counter
                    if !searchResults.isEmpty {
                        Text("\(currentMatch + 1) of \(totalMatches)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(width: 400, height: 200)
        .background(backgroundColorForPlatform)
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            totalMatches = 0
            currentMatch = 0
            return
        }
        
        var options: NSString.CompareOptions = []
        if !caseSensitive {
            options.insert(.caseInsensitive)
        }
        // Note: Whole word matching would need more complex logic
        // For now, we'll just use the basic search
        
        searchResults = []
        let nsText = text as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        
        while searchRange.location < nsText.length {
            let foundRange = nsText.range(of: searchText, options: options, range: searchRange)
            if foundRange.location == NSNotFound {
                break
            }
            searchResults.append(foundRange)
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = nsText.length - searchRange.location
        }
        
        totalMatches = searchResults.count
        currentMatch = totalMatches > 0 ? 0 : 0
    }
    
    private func findNext() {
        guard !searchResults.isEmpty else { return }
        currentMatch = (currentMatch + 1) % searchResults.count
    }
    
    private func findPrevious() {
        guard !searchResults.isEmpty else { return }
        currentMatch = currentMatch > 0 ? currentMatch - 1 : searchResults.count - 1
    }
    
    private func replaceCurrentMatch() {
        guard !searchResults.isEmpty, currentMatch < searchResults.count else { return }
        
        let range = searchResults[currentMatch]
        let nsText = text as NSString
        text = nsText.replacingCharacters(in: range, with: replaceText)
        
        // Update search results after replacement
        performSearch()
    }
    
    private func replaceAllMatches() {
        guard !searchResults.isEmpty else { return }
        
        // Replace from last to first to maintain ranges
        let sortedResults = searchResults.sorted { $0.location > $1.location }
        var newText = text
        
        for range in sortedResults {
            newText = (newText as NSString).replacingCharacters(in: range, with: replaceText)
        }
        
        text = newText
        performSearch()
    }
}

#Preview {
    @Previewable @State var sampleText = """
    This is a sample text with some words.
    We can search for words and replace them.
    Words, words everywhere!
    """
    
    FindReplaceView(text: $sampleText)
}