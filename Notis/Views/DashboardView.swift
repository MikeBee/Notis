//
//  DashboardView.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI
import CoreData

struct DashboardSidePanel: View {
    @ObservedObject var sheet: Sheet
    let dashboardType: DashboardType
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(dashboardType.title)
                    .font(UlyssesDesign.Typography.sheetTitle)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
                .background(UlyssesDesign.Colors.hover.opacity(0.5))
                .cornerRadius(UlyssesDesign.CornerRadius.small)
            }
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
            .padding(.vertical, UlyssesDesign.Spacing.md)
            .background(
                UlyssesDesign.Colors.libraryBg(for: colorScheme)
                    .overlay(
                        Rectangle()
                            .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme))
                            .frame(height: 0.5)
                            .opacity(0.6),
                        alignment: .bottom
                    )
            )
            
            // Content
            ScrollView {
                VStack(spacing: UlyssesDesign.Spacing.lg) {
                    switch dashboardType {
                    case .overview:
                        OverviewContent(sheet: sheet)
                    case .progress:
                        ProgressContent(sheet: sheet)
                    case .outline:
                        OutlineContent(sheet: sheet)
                    }
                }
                .padding(UlyssesDesign.Spacing.lg)
            }
            .background(UlyssesDesign.Colors.libraryBg(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UlyssesDesign.Colors.libraryBg(for: colorScheme))
        .overlay(
            Rectangle()
                .fill(UlyssesDesign.Colors.dividerColor(for: colorScheme))
                .frame(width: 0.5)
                .opacity(0.6),
            alignment: .leading
        )
    }
}

struct DashboardView: View {
    @ObservedObject var sheet: Sheet
    let dashboardType: DashboardType
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(dashboardType.title)
                    .font(UlyssesDesign.Typography.sheetTitle)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
                .background(UlyssesDesign.Colors.hover.opacity(0.5))
                .cornerRadius(UlyssesDesign.CornerRadius.small)
            }
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
            .padding(.vertical, UlyssesDesign.Spacing.md)
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
            
            // Content
            ScrollView {
                VStack(spacing: UlyssesDesign.Spacing.lg) {
                    switch dashboardType {
                    case .overview:
                        OverviewContent(sheet: sheet)
                    case .progress:
                        ProgressContent(sheet: sheet)
                    case .outline:
                        OutlineContent(sheet: sheet)
                    }
                }
                .padding(UlyssesDesign.Spacing.lg)
            }
            .background(UlyssesDesign.Colors.background(for: colorScheme))
        }
        .frame(width: 320, height: 480)
        .background(UlyssesDesign.Colors.background(for: colorScheme))
        .cornerRadius(UlyssesDesign.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.large)
                .stroke(UlyssesDesign.Colors.dividerColor(for: colorScheme), lineWidth: 0.5)
        )
        .shadow(color: UlyssesDesign.Shadows.medium, radius: 20, x: 0, y: 10)
    }
}

struct OverviewContent: View {
    @ObservedObject var sheet: Sheet
    @Environment(\.colorScheme) private var colorScheme
    
    private var statistics: SheetStatistics {
        SheetStatistics(content: sheet.content ?? "")
    }
    
    private var averageWritingTime: String {
        // Calculate average time based on word count and typical writing speed
        let wordsPerMinute = 40.0 // Average typing speed
        let minutes = Double(sheet.wordCount) / wordsPerMinute
        
        if minutes < 1 {
            return "< 1 min"
        } else if minutes < 60 {
            return "\(Int(minutes)) min"
        } else {
            let hours = Int(minutes / 60)
            let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(remainingMinutes)m"
        }
    }
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.lg) {
            // Title and Creation Info
            VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
                Text(sheet.title ?? "Untitled")
                    .font(UlyssesDesign.Typography.editorTitle)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    .lineLimit(2)
                
                if let createdAt = sheet.createdAt {
                    Text("Created \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(UlyssesDesign.Typography.sheetMeta)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                
                if let modifiedAt = sheet.modifiedAt {
                    Text("Modified \(modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(UlyssesDesign.Typography.sheetMeta)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))
            
            // Main Statistics Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: UlyssesDesign.Spacing.md) {
                OverviewStatCard(
                    title: "Characters",
                    value: "\(statistics.characters)",
                    icon: "textformat.abc"
                )
                
                OverviewStatCard(
                    title: "Words",
                    value: "\(statistics.words)",
                    icon: "text.word.spacing"
                )
                
                OverviewStatCard(
                    title: "Paragraphs",
                    value: "\(statistics.paragraphs)",
                    icon: "text.alignleft"
                )
                
                OverviewStatCard(
                    title: "Lines",
                    value: "\(statistics.lines)",
                    icon: "text.line.first.and.arrowtriangle.forward"
                )
            }
            
            Divider()
                .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))
            
            // Writing Time Estimate
            VStack(spacing: UlyssesDesign.Spacing.sm) {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.accent)
                    
                    Text("Average Writing Time")
                        .font(UlyssesDesign.Typography.groupName)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    Spacer()
                }
                
                HStack {
                    Text(averageWritingTime)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(UlyssesDesign.Colors.accent)
                    
                    Spacer()
                    
                    Text("Est. time to write this content")
                        .font(UlyssesDesign.Typography.sheetMeta)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(UlyssesDesign.Spacing.md)
            .background(UlyssesDesign.Colors.accent.opacity(0.05))
            .cornerRadius(UlyssesDesign.CornerRadius.medium)
        }
    }
}

struct ProgressContent: View {
    @ObservedObject var sheet: Sheet
    @Environment(\.colorScheme) private var colorScheme
    
    private var statistics: SheetStatistics {
        SheetStatistics(content: sheet.content ?? "")
    }
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.lg) {
            // Title
            Text("Text Statistics")
                .font(UlyssesDesign.Typography.editorTitle)
                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Detailed Statistics
            VStack(spacing: UlyssesDesign.Spacing.sm) {
                ProgressStatRow(label: "Characters", value: "\(statistics.characters)")
                ProgressStatRow(label: "Without Spaces", value: "\(statistics.charactersWithoutSpaces)")
                ProgressStatRow(label: "Words", value: "\(statistics.words)")
                ProgressStatRow(label: "Sentences", value: "\(statistics.sentences)")
                ProgressStatRow(label: "Words/Sentence", value: String(format: "%.1f", statistics.wordsPerSentence))
                ProgressStatRow(label: "Paragraphs", value: "\(statistics.paragraphs)")
                ProgressStatRow(label: "Lines", value: "\(statistics.lines)")
                ProgressStatRow(label: "Pages", value: "\(statistics.pages)")
            }
            
            Divider()
                .background(UlyssesDesign.Colors.dividerColor(for: colorScheme))
            
            // Reading Time
            VStack(spacing: UlyssesDesign.Spacing.sm) {
                HStack {
                    Text("Reading Time")
                        .font(UlyssesDesign.Typography.groupName)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    Spacer()
                    
                    Text(statistics.readingTime)
                        .font(UlyssesDesign.Typography.groupName)
                        .foregroundColor(UlyssesDesign.Colors.accent)
                }
                
                Text("Based on 200 words per minute average reading speed")
                    .font(UlyssesDesign.Typography.sheetMeta)
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(UlyssesDesign.Spacing.md)
            .background(UlyssesDesign.Colors.hover.opacity(0.3))
            .cornerRadius(UlyssesDesign.CornerRadius.medium)
        }
    }
}

struct OutlineContent: View {
    @ObservedObject var sheet: Sheet
    @Environment(\.colorScheme) private var colorScheme
    
    private var headers: [HeaderItem] {
        HeaderExtractor.extractHeaders(from: sheet.content ?? "")
    }
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.lg) {
            // Title
            Text("Document Outline")
                .font(UlyssesDesign.Typography.editorTitle)
                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if headers.isEmpty {
                VStack(spacing: UlyssesDesign.Spacing.md) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    
                    Text("No Headers Found")
                        .font(UlyssesDesign.Typography.sheetTitle)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    
                    Text("Add headers using # markdown syntax to see your document outline")
                        .font(UlyssesDesign.Typography.sheetMeta)
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: UlyssesDesign.Spacing.xs) {
                    ForEach(headers, id: \.id) { header in
                        OutlineHeaderRow(header: header)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct OverviewStatCard: View {
    let title: String
    let value: String
    let icon: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(UlyssesDesign.Colors.accent)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Text(title)
                    .font(UlyssesDesign.Typography.sheetMeta)
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(UlyssesDesign.Spacing.md)
        .background(UlyssesDesign.Colors.hover.opacity(0.3))
        .cornerRadius(UlyssesDesign.CornerRadius.medium)
    }
}

struct ProgressStatRow: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            Text(label)
                .font(UlyssesDesign.Typography.groupName)
                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
            
            Spacer()
            
            Text(value)
                .font(UlyssesDesign.Typography.groupName)
                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

struct OutlineHeaderRow: View {
    let header: HeaderItem
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            // Indentation based on header level
            HStack(spacing: 0) {
                ForEach(0..<(header.level - 1), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16)
                }
                
                Circle()
                    .fill(UlyssesDesign.Colors.accent)
                    .frame(width: 6, height: 6)
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8)
            }
            
            Text(header.text)
                .font(.system(size: 14 - CGFloat(header.level - 1), weight: header.level <= 2 ? .semibold : .medium))
                .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Data Models and Utilities

struct SheetStatistics {
    let content: String
    
    var characters: Int {
        content.count
    }
    
    var charactersWithoutSpaces: Int {
        content.replacingOccurrences(of: " ", with: "").count
    }
    
    var words: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    var sentences: Int {
        content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
    
    var wordsPerSentence: Double {
        guard sentences > 0 else { return 0 }
        return Double(words) / Double(sentences)
    }
    
    var paragraphs: Int {
        content.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
    
    var lines: Int {
        guard !content.isEmpty else { return 0 }
        return content.components(separatedBy: .newlines).count
    }
    
    var pages: Int {
        // Estimate pages based on ~250 words per page
        max(1, Int(ceil(Double(words) / 250.0)))
    }
    
    var readingTime: String {
        let wordsPerMinute = 200.0
        let minutes = Double(words) / wordsPerMinute
        
        if minutes < 1 {
            return "< 1 min"
        } else if minutes < 60 {
            return "\(Int(minutes)) min"
        } else {
            let hours = Int(minutes / 60)
            let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

struct HeaderItem {
    let id = UUID()
    let level: Int
    let text: String
    let range: NSRange
}

struct HeaderExtractor {
    static func extractHeaders(from text: String) -> [HeaderItem] {
        let pattern = #"^(#{1,6})\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return []
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        return matches.compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            
            let hashRange = match.range(at: 1)
            let textRange = match.range(at: 2)
            
            let level = (text as NSString).substring(with: hashRange).count
            let headerText = (text as NSString).substring(with: textRange)
            
            return HeaderItem(level: level, text: headerText, range: match.range)
        }
    }
}

extension DashboardType {
    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .progress:
            return "Progress"
        case .outline:
            return "Outline"
        }
    }
}

#Preview {
    let sampleSheet = Sheet()
    sampleSheet.title = "Sample Document"
    sampleSheet.content = """
# Main Header

This is a sample document with some content.

## Secondary Header

More content here with **bold** text and *italic* text.

### Third Level

Some more paragraphs to test the statistics.

Another paragraph here.
"""
    sampleSheet.wordCount = 25
    sampleSheet.createdAt = Date()
    sampleSheet.modifiedAt = Date()
    
    return DashboardSidePanel(
        sheet: sampleSheet,
        dashboardType: .overview,
        isPresented: .constant(true)
    )
    .frame(width: 320, height: 500)
}