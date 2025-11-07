//
//  TemplateSelectionView.swift
//  Notis
//
//  Created by Claude on 11/4/25.
//

import SwiftUI
import CoreData

struct TemplateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var templateService = TemplateService.shared
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingTemplateEditor = false
    @State private var editingTemplate: Template?
    
    let selectedGroup: Group?
    let onTemplateSelected: (Template) -> Void
    
    private var categories: [String] {
        ["All"] + templateService.getTemplateCategories()
    }
    
    private var filteredTemplates: [Template] {
        var templates = templateService.templates
        
        // Filter by category
        if selectedCategory != "All" {
            templates = templates.filter { $0.category == selectedCategory }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            templates = templates.filter { template in
                template.displayName.localizedCaseInsensitiveContains(searchText) ||
                template.categoryDisplayName.localizedCaseInsensitiveContains(searchText) ||
                (template.content?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return templates
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with search and categories
                headerSection
                
                // Template list
                templateList
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingTemplate = nil
                        showingTemplateEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search templates...")
        .sheet(isPresented: $showingTemplateEditor) {
            TemplateEditorView(template: editingTemplate) { updatedTemplate in
                templateService.loadTemplates()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Category selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        CategoryPill(
                            title: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Stats
            if !filteredTemplates.isEmpty {
                HStack {
                    Text("\(filteredTemplates.count) template\(filteredTemplates.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if selectedGroup != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.caption)
                            Text("Will create in: \(selectedGroup?.name ?? "Inbox")")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var templateList: some View {
        List {
            if filteredTemplates.isEmpty {
                emptyState
            } else {
                ForEach(filteredTemplates, id: \.id) { template in
                    TemplateRow(template: template) {
                        onTemplateSelected(template)
                        dismiss()
                    } onEdit: { template in
                        editingTemplate = template
                        showingTemplateEditor = true
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Templates Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your search or create a new template")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create Template") {
                editingTemplate = nil
                showingTemplateEditor = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TemplateRow: View {
    let template: Template
    let onSelect: () -> Void
    let onEdit: (Template) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Template icon
            VStack {
                Image(systemName: templateIcon)
                    .font(.title2)
                    .foregroundColor(template.isBuiltIn ? .blue : .accentColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(template.isBuiltIn ? Color.blue.opacity(0.1) : Color.accentColor.opacity(0.1))
                    )
                
                Spacer()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(template.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if template.hasKeyboardShortcut {
                        Text(template.formattedShortcut)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                            .foregroundColor(.secondary)
                    }
                    
                    if template.isBuiltIn {
                        Text("Built-in")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                
                HStack {
                    Text(template.categoryDisplayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .foregroundColor(.secondary)
                        .cornerRadius(8)
                    
                    if let targetGroup = template.targetGroupName, !targetGroup.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "folder")
                                .font(.caption2)
                            Text(targetGroup)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if let content = template.content, !content.isEmpty {
                    Text(contentPreview(content))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Actions - Always show edit button
            VStack {
                Button {
                    onEdit(template)
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isHovering ? 1.0 : 0.7)
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color(.systemGray6) : Color.clear)
        )
    }
    
    private var templateIcon: String {
        switch template.categoryDisplayName.lowercased() {
        case "journal": return "book"
        case "work": return "briefcase"
        case "review": return "checkmark.circle"
        case "meeting": return "person.2"
        case "notes": return "note.text"
        default: return "doc.text"
        }
    }
    
    private func contentPreview(_ content: String) -> String {
        let cleanContent = content
            .replacingOccurrences(of: "{date}", with: "DATE")
            .replacingOccurrences(of: "{fulldate}", with: "DATE")
            .replacingOccurrences(of: "{time}", with: "TIME")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return String(cleanContent.prefix(100)) + (cleanContent.count > 100 ? "..." : "")
    }
}

#Preview {
    TemplateSelectionView(selectedGroup: nil) { template in
        print("Selected template: \(template.displayName)")
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}