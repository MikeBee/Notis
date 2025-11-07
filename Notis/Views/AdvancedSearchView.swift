//
//  AdvancedSearchView.swift
//  Notis
//
//  Created by Claude on 11/2/25.
//

import SwiftUI
import CoreData

#if canImport(AppKit)
import AppKit
#endif

struct AdvancedSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    
    @State private var searchText = ""
    @State private var selectedGroup: Group?
    @State private var searchInTitles = true
    @State private var searchInContent = true
    @State private var caseSensitive = false
    @State private var wholeWords = false
    @State private var dateFilter: DateFilter = .any
    @State private var sortBy: SortOption = .relevance
    @State private var searchResults: [Sheet] = []
    @State private var isSearching = false
    @State private var showResults = false
    @State private var searchAnimation = false
    
    enum DateFilter: String, CaseIterable {
        case any = "Any time"
        case today = "Today"
        case week = "Past week"
        case month = "Past month"
        case year = "Past year"
        
        var predicate: NSPredicate? {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .any:
                return nil
            case .today:
                let startOfDay = calendar.startOfDay(for: now)
                return NSPredicate(format: "modifiedAt >= %@", startOfDay as NSDate)
            case .week:
                let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
                return NSPredicate(format: "modifiedAt >= %@", weekAgo as NSDate)
            case .month:
                let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                return NSPredicate(format: "modifiedAt >= %@", monthAgo as NSDate)
            case .year:
                let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                return NSPredicate(format: "modifiedAt >= %@", yearAgo as NSDate)
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case relevance = "Relevance"
        case modified = "Modified Date"
        case created = "Created Date"
        case title = "Title"
        case wordCount = "Word Count"
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.name, ascending: true)],
        animation: .default
    )
    private var allGroups: FetchedResults<Group>
    
    private var windowBackgroundColor: Color {
        #if canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    private var controlBackgroundColor: Color {
        #if canImport(AppKit)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Advanced Search")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            .background(windowBackgroundColor)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Search field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search Query")
                            .font(.headline)
                        
                        TextField("Enter search terms...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                performSearch()
                            }
                    }
                    
                    // Search options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Search Options")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Search in titles", isOn: $searchInTitles)
                            Toggle("Search in content", isOn: $searchInContent)
                            Toggle("Case sensitive", isOn: $caseSensitive)
                            Toggle("Whole words only", isOn: $wholeWords)
                        }
                    }
                    
                    // Filters
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filters")
                            .font(.headline)
                        
                        // Group filter
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Group")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Group", selection: $selectedGroup) {
                                Text("All Groups").tag(nil as Group?)
                                ForEach(allGroups, id: \.self) { group in
                                    Text(group.name ?? "Untitled").tag(group as Group?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        // Date filter
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date Modified")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Date Filter", selection: $dateFilter) {
                                ForEach(DateFilter.allCases, id: \.self) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        // Sort options
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sort By")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Sort By", selection: $sortBy) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    
                    // Search button
                    Button(action: performSearch) {
                        HStack {
                            if isSearching {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Searching...")
                            } else {
                                Image(systemName: "magnifyingglass")
                                Text("Search")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(searchText.isEmpty || isSearching)
                    
                    // Results
                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Results (\(searchResults.count))")
                                .font(.headline)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(searchResults, id: \.id) { sheet in
                                    SearchResultRow(sheet: sheet, searchText: searchText, appState: appState) {
                                        dismiss()
                                    }
                                }
                            }
                        }
                    } else if !searchText.isEmpty && !isSearching {
                        Text("No results found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 700)
        .background(windowBackgroundColor)
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let results = searchSheets()
            
            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
    
    private func searchSheets() -> [Sheet] {
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        var predicates: [NSPredicate] = []
        
        // Base predicate - not in trash
        predicates.append(NSPredicate(format: "isInTrash == NO"))
        
        // Group filter
        if let selectedGroup = selectedGroup {
            predicates.append(NSPredicate(format: "group == %@", selectedGroup))
        }
        
        // Date filter
        if let datePredicate = dateFilter.predicate {
            predicates.append(datePredicate)
        }
        
        // Text search
        var textPredicates: [NSPredicate] = []
        
        if searchInTitles {
            let titlePredicate = caseSensitive ?
                NSPredicate(format: "title CONTAINS %@", searchText) :
                NSPredicate(format: "title CONTAINS[c] %@", searchText)
            textPredicates.append(titlePredicate)
        }
        
        if searchInContent {
            let contentPredicate = caseSensitive ?
                NSPredicate(format: "content CONTAINS %@", searchText) :
                NSPredicate(format: "content CONTAINS[c] %@", searchText)
            textPredicates.append(contentPredicate)
        }
        
        if !textPredicates.isEmpty {
            let textCompoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: textPredicates)
            predicates.append(textCompoundPredicate)
        }
        
        // Combine all predicates
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.predicate = compoundPredicate
        
        // Sort descriptors
        switch sortBy {
        case .relevance:
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)]
        case .modified:
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)]
        case .created:
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.createdAt, ascending: false)]
        case .title:
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.title, ascending: true)]
        case .wordCount:
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.wordCount, ascending: false)]
        }
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Search failed: \(error)")
            return []
        }
    }
}

struct SearchResultRow: View {
    let sheet: Sheet
    let searchText: String
    @ObservedObject var appState: AppState
    let onSelect: () -> Void
    
    private var controlBackgroundColor: Color {
        #if canImport(AppKit)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sheet.title ?? "Untitled")
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let groupName = sheet.group?.name {
                        Text(groupName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let modifiedAt = sheet.modifiedAt {
                        Text(modifiedAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(sheet.wordCount) words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let content = sheet.content, !content.isEmpty {
                Text(content.prefix(200))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(controlBackgroundColor)
        .cornerRadius(8)
        .onTapGesture {
            appState.selectedSheet = sheet
            appState.selectedGroup = sheet.group
            appState.selectedEssential = nil
            onSelect()
        }
    }
}

#Preview {
    AdvancedSearchView(appState: AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}