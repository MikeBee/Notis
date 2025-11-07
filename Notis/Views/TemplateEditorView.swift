//
//  TemplateEditorView.swift
//  Notis
//
//  Created by Claude on 11/4/25.
//

import SwiftUI
import CoreData

struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var templateService = TemplateService.shared
    
    let template: Template?
    let onSave: (Template) -> Void
    
    @State private var name = ""
    @State private var titleTemplate = ""
    @State private var content = ""
    @State private var category = "General"
    @State private var targetGroupName = ""
    @State private var usesDateInTitle = false
    @State private var keyboardShortcut = ""
    @State private var showingPreview = false
    @State private var showingFolderPicker = false
    
    private var isEditing: Bool {
        template != nil
    }
    
    private var canSave: Bool {
        !name.isEmpty && !titleTemplate.isEmpty
    }
    
    private var availableCategories: [String] {
        let existing = templateService.getTemplateCategories()
        let standard = ["General", "Journal", "Work", "Review", "Notes", "Meeting"]
        return Array(Set(existing + standard)).sorted()
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let template = template, template.isBuiltIn {
                    builtInWarningSection
                }
                
                basicInfoSection
                titleSection
                contentSection
                organizationSection
                shortcutSection
                previewSection
            }
            .navigationTitle(isEditing ? "Edit Template" : "New Template")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            loadTemplateData()
        }
        .sheet(isPresented: $showingPreview) {
            TemplatePreviewView(
                name: name,
                titleTemplate: titleTemplate,
                content: content,
                usesDateInTitle: usesDateInTitle
            )
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerView(
                selectedFolderName: targetGroupName.isEmpty ? nil : targetGroupName
            ) { selectedFolder in
                targetGroupName = selectedFolder ?? ""
            }
        }
    }
    
    private var builtInWarningSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Editing Built-in Template")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("You're editing a built-in template. Your changes will modify the original template for future use.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    private var basicInfoSection: some View {
        Section("Template Details") {
            TextField("Template Name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("Category")
                Spacer()
                Menu(category) {
                    ForEach(availableCategories, id: \.self) { cat in
                        Button(cat) {
                            category = cat
                        }
                    }
                    
                    Divider()
                    
                    Button("Custom...") {
                        // For now, just use General - could add custom category input
                        category = "General"
                    }
                }
            }
        }
    }
    
    private var titleSection: some View {
        Section("Title Generation") {
            TextField("Title Template", text: $titleTemplate)
                .textFieldStyle(.roundedBorder)
            
            Toggle("Include Date in Title", isOn: $usesDateInTitle)
            
            if usesDateInTitle {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title Preview:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(generatePreviewTitle())
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Available Placeholders:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• {date} - Short date (YY-MM-DD)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var contentSection: some View {
        Section("Template Content") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Content")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Preview") {
                        showingPreview = true
                    }
                    .font(.caption)
                }
                
                TextEditor(text: $content)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(Color(.systemGray4))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Placeholders:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• {date} - Short date (YY-MM-DD)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("• {fulldate} - Full date (Monday, January 1, 2024)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("• {time} - Current time")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var organizationSection: some View {
        Section("Organization") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Target Folder")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button("Choose Folder") {
                        showingFolderPicker = true
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                
                HStack {
                    Image(systemName: targetGroupName.isEmpty ? "folder.badge.minus" : "folder")
                        .foregroundColor(targetGroupName.isEmpty ? .secondary : .accentColor)
                        .font(.system(size: 16))
                    
                    Text(targetGroupName.isEmpty ? "None (use selected folder)" : targetGroupName)
                        .font(.subheadline)
                        .foregroundColor(targetGroupName.isEmpty ? .secondary : .primary)
                    
                    Spacer()
                    
                    if !targetGroupName.isEmpty {
                        Button("Clear") {
                            targetGroupName = ""
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .onTapGesture {
                    showingFolderPicker = true
                }
                
                Text("If specified, sheets created from this template will be automatically placed in this folder. If not specified, sheets will use your currently selected folder.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var shortcutSection: some View {
        Section("Keyboard Shortcut") {
            HStack {
                TextField("Key (e.g., 'J' for ⌘J)", text: $keyboardShortcut)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: keyboardShortcut) { _, newValue in
                        // Keep only the last character and make it uppercase
                        keyboardShortcut = String(newValue.suffix(1)).uppercased()
                    }
                
                if !keyboardShortcut.isEmpty {
                    Text("⌘\(keyboardShortcut)")
                        .font(.system(size: 14, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }
            
            Text("Assign a single letter for quick access via Command+[Key]")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var previewSection: some View {
        Section {
            Button("Preview Template") {
                showingPreview = true
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func loadTemplateData() {
        guard let template = template else { return }
        
        name = template.name ?? ""
        titleTemplate = template.titleTemplate ?? ""
        content = template.content ?? ""
        category = template.category ?? "General"
        targetGroupName = template.targetGroupName ?? ""
        usesDateInTitle = template.usesDateInTitle
        keyboardShortcut = template.keyboardShortcut ?? ""
    }
    
    private func generatePreviewTitle() -> String {
        var preview = titleTemplate
        
        if usesDateInTitle {
            let formatter = DateFormatter()
            formatter.dateFormat = "yy-MM-dd"
            let dateString = formatter.string(from: Date())
            
            if preview.contains("{date}") {
                preview = preview.replacingOccurrences(of: "{date}", with: dateString)
            } else {
                preview = "\(dateString) \(preview)"
            }
        }
        
        return preview.isEmpty ? "Untitled" : preview
    }
    
    private func saveTemplate() {
        if let template = template {
            // Update existing template
            template.name = name
            template.titleTemplate = titleTemplate
            template.content = content
            template.category = category
            template.targetGroupName = targetGroupName.isEmpty ? nil : targetGroupName
            template.usesDateInTitle = usesDateInTitle
            template.keyboardShortcut = keyboardShortcut.isEmpty ? nil : keyboardShortcut
            
            templateService.updateTemplate(template)
            onSave(template)
        } else {
            // Create new template
            let newTemplate = templateService.createTemplate(
                name: name,
                titleTemplate: titleTemplate,
                content: content,
                category: category,
                targetGroupName: targetGroupName.isEmpty ? nil : targetGroupName,
                usesDateInTitle: usesDateInTitle,
                keyboardShortcut: keyboardShortcut.isEmpty ? nil : keyboardShortcut
            )
            onSave(newTemplate)
        }
        
        dismiss()
    }
}

struct TemplatePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    
    let name: String
    let titleTemplate: String
    let content: String
    let usesDateInTitle: Bool
    
    private var previewTitle: String {
        var preview = titleTemplate
        
        if usesDateInTitle {
            let formatter = DateFormatter()
            formatter.dateFormat = "yy-MM-dd"
            let dateString = formatter.string(from: Date())
            
            if preview.contains("{date}") {
                preview = preview.replacingOccurrences(of: "{date}", with: dateString)
            } else {
                preview = "\(dateString) \(preview)"
            }
        }
        
        return preview.isEmpty ? "Untitled" : preview
    }
    
    private var previewContent: String {
        var processedContent = content
        
        // Replace placeholders with actual values
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        let fullDate = formatter.string(from: Date())
        
        formatter.dateFormat = "yy-MM-dd"
        let shortDate = formatter.string(from: Date())
        
        processedContent = processedContent.replacingOccurrences(of: "{date}", with: shortDate)
        processedContent = processedContent.replacingOccurrences(of: "{fulldate}", with: fullDate)
        processedContent = processedContent.replacingOccurrences(of: "{time}", with: DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))
        
        return processedContent
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(previewTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        MarkdownReadOnlyView(
                            text: previewContent,
                            fontSize: 16,
                            fontFamily: "system"
                        )
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Template Preview")
            .navigationBarTitleDisplayMode(.large)
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
    TemplateEditorView(template: nil) { template in
        print("Saved template: \(template.displayName)")
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}