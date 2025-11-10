//
//  TemplateService.swift
//  Notis
//
//  Created by Claude on 11/4/25.
//

import Foundation
import CoreData

class TemplateService: ObservableObject {
    static let shared = TemplateService()
    
    private let context: NSManagedObjectContext
    @Published var templates: [Template] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadTemplates()
        createBuiltInTemplatesIfNeeded()
    }
    
    // MARK: - Template Management
    
    func loadTemplates() {
        let request: NSFetchRequest<Template> = Template.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "isBuiltIn", ascending: false), // Built-in first
            NSSortDescriptor(key: "category", ascending: true),
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        
        do {
            templates = try context.fetch(request)
        } catch {
            print("Failed to load templates: \(error)")
        }
    }
    
    func createTemplate(
        name: String,
        titleTemplate: String,
        content: String,
        category: String = "General",
        targetGroupName: String? = nil,
        usesDateInTitle: Bool = false,
        keyboardShortcut: String? = nil
    ) -> Template {
        let template = Template(context: context)
        template.id = UUID()
        template.name = name
        template.titleTemplate = titleTemplate
        template.content = content
        template.category = category
        template.targetGroupName = targetGroupName
        template.usesDateInTitle = usesDateInTitle
        template.keyboardShortcut = keyboardShortcut
        template.isBuiltIn = false
        template.createdAt = Date()
        template.modifiedAt = Date()
        template.sortOrder = Int32(templates.count)
        
        saveContext()
        loadTemplates()
        
        return template
    }
    
    func updateTemplate(_ template: Template) {
        template.modifiedAt = Date()
        saveContext()
        loadTemplates()
    }
    
    func deleteTemplate(_ template: Template) {
        context.delete(template)
        saveContext()
        loadTemplates()
    }
    
    // MARK: - Template Application
    
    func createSheetFromTemplate(_ template: Template, selectedGroup: Group?) -> Sheet {
        let sheet = Sheet(context: context)
        sheet.id = UUID()
        sheet.createdAt = Date()
        sheet.modifiedAt = Date()

        // Generate title from template
        sheet.title = generateTitleFromTemplate(template)

        // Set content from template using unified storage for new markdown system
        sheet.unifiedContent = processTemplateContent(template.content ?? "")
        
        // Set group (target group or selected group or fallback to Inbox)
        if let targetGroupName = template.targetGroupName, !targetGroupName.isEmpty {
            sheet.group = findOrCreateGroup(named: targetGroupName)
        } else if let selectedGroup = selectedGroup {
            sheet.group = selectedGroup
        } else {
            // Fallback to Inbox if no group is specified
            sheet.group = findOrCreateGroup(named: "Inbox")
        }
        
        // Set additional required fields
        sheet.isInTrash = false
        sheet.isFavorite = false
        sheet.goalCount = 0
        sheet.goalType = "words"
        sheet.deletedAt = nil
        
        // Set sort order within the group
        if let group = sheet.group {
            let sheetsInGroup = (group.sheets?.allObjects as? [Sheet])?.filter { !$0.isInTrash } ?? []
            sheet.sortOrder = Int32(sheetsInGroup.count)
        } else {
            sheet.sortOrder = 0
        }
        
        // Calculate initial stats
        updateSheetStats(sheet)
        
        saveContext()
        
        print("📝 Created sheet: '\(sheet.title ?? "Untitled")' in group: '\(sheet.group?.name ?? "None")'")
        
        return sheet
    }
    
    private func generateTitleFromTemplate(_ template: Template) -> String {
        var title = template.titleTemplate ?? template.name ?? "Untitled"
        
        if template.usesDateInTitle {
            let formatter = DateFormatter()
            formatter.dateFormat = "yy-MM-dd"
            let dateString = formatter.string(from: Date())
            
            // Replace date placeholder or append date
            if title.contains("{date}") {
                title = title.replacingOccurrences(of: "{date}", with: dateString)
            } else {
                title = "\(dateString) \(title)"
            }
        }
        
        return title
    }
    
    private func processTemplateContent(_ content: String) -> String {
        var processedContent = content
        
        // Replace date placeholders
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
    
    private func findOrCreateGroup(named name: String) -> Group {
        let request: NSFetchRequest<Group> = Group.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        
        if let existingGroup = try? context.fetch(request).first {
            return existingGroup
        }
        
        // Create new group
        let group = Group(context: context)
        group.id = UUID()
        group.name = name
        group.createdAt = Date()
        group.modifiedAt = Date()
        group.sortOrder = 0
        
        return group
    }
    
    private func updateSheetStats(_ sheet: Sheet) {
        let content = sheet.content ?? ""
        let words = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        sheet.wordCount = Int32(words.count)
        sheet.preview = String(content.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Built-in Templates
    
    private func createBuiltInTemplatesIfNeeded() {
        let request: NSFetchRequest<Template> = Template.fetchRequest()
        request.predicate = NSPredicate(format: "isBuiltIn == YES")
        
        do {
            let builtInTemplates = try context.fetch(request)
            if builtInTemplates.isEmpty {
                createBuiltInTemplates()
            }
        } catch {
            print("Failed to check for built-in templates: \(error)")
        }
    }
    
    private func createBuiltInTemplates() {
        // Daily Journal Template
        let dailyJournal = Template(context: context)
        dailyJournal.id = UUID()
        dailyJournal.name = "Daily Journal"
        dailyJournal.titleTemplate = "{date} Daily Journal"
        dailyJournal.content = """
# {date} Daily Journal

## How am I feeling today?


## What are my priorities for today?
1. 
2. 
3. 

## What am I grateful for?
- 
- 
- 

## Reflection
What went well today?


What could I improve tomorrow?


## Notes

"""
        dailyJournal.category = "Journal"
        dailyJournal.usesDateInTitle = true
        dailyJournal.isBuiltIn = true
        dailyJournal.createdAt = Date()
        dailyJournal.modifiedAt = Date()
        dailyJournal.sortOrder = 0
        
        // Weekly Review Template
        let weeklyReview = Template(context: context)
        weeklyReview.id = UUID()
        weeklyReview.name = "Weekly Review"
        weeklyReview.titleTemplate = "Week of {date} Review"
        weeklyReview.content = """
# Weekly Review - Week of {date}

## Accomplishments This Week
- 
- 
- 

## Challenges Faced
- 
- 

## Lessons Learned


## Goals for Next Week
1. 
2. 
3. 

## Areas for Improvement


## Wins to Celebrate
- 
- 
"""
        weeklyReview.category = "Review"
        weeklyReview.usesDateInTitle = true
        weeklyReview.isBuiltIn = true
        weeklyReview.createdAt = Date()
        weeklyReview.modifiedAt = Date()
        weeklyReview.sortOrder = 1
        
        // Meeting Notes Template
        let meetingNotes = Template(context: context)
        meetingNotes.id = UUID()
        meetingNotes.name = "Meeting Notes"
        meetingNotes.titleTemplate = "Meeting - {date}"
        meetingNotes.content = """
# Meeting Notes - {fulldate}

**Time:** {time}
**Attendees:** 

## Agenda
1. 
2. 
3. 

## Discussion Points


## Decisions Made
- 
- 

## Action Items
- [ ] 
- [ ] 
- [ ] 

## Follow-up
Next meeting: 

"""
        meetingNotes.category = "Work"
        meetingNotes.usesDateInTitle = true
        meetingNotes.isBuiltIn = true
        meetingNotes.createdAt = Date()
        meetingNotes.modifiedAt = Date()
        meetingNotes.sortOrder = 2
        
        saveContext()
        loadTemplates()
    }
    
    // MARK: - Keyboard Shortcuts
    
    func getTemplatesWithShortcuts() -> [Template] {
        return templates.filter { $0.keyboardShortcut != nil && !($0.keyboardShortcut?.isEmpty ?? true) }
    }
    
    func findTemplateByShortcut(_ shortcut: String) -> Template? {
        return templates.first { $0.keyboardShortcut == shortcut }
    }
    
    // MARK: - Categories
    
    func getTemplateCategories() -> [String] {
        let categories = Set(templates.compactMap { $0.category }).sorted()
        return categories.isEmpty ? ["General"] : Array(categories)
    }
    
    func getTemplates(in category: String) -> [Template] {
        return templates.filter { $0.category == category }
    }
    
    // MARK: - Core Data
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Failed to save template context: \(error)")
        }
    }
}

// MARK: - Template Extensions

extension Template {
    var displayName: String {
        return name ?? "Untitled Template"
    }
    
    var categoryDisplayName: String {
        return category ?? "General"
    }
    
    var hasKeyboardShortcut: Bool {
        return !(keyboardShortcut?.isEmpty ?? true)
    }
    
    var formattedShortcut: String {
        guard let shortcut = keyboardShortcut, !shortcut.isEmpty else { return "" }
        return "⌘\(shortcut.uppercased())"
    }
}