//
//  TagService.swift
//  Notis
//
//  Created by Claude on 11/7/25.
//

import Foundation
import CoreData
import SwiftUI
import Combine

class TagService: ObservableObject {
    static let shared = TagService()
    
    @Published var selectedTags: Set<Tag> = []
    @Published var tagSearchText: String = ""
    @Published var isTagMode: Bool = false
    
    // Sort settings with persistence
    @Published var currentSortOrder: TagSortOrder = .alphabetical {
        didSet {
            UserDefaults.standard.set(currentSortOrder.rawValue, forKey: "tagSortOrder")
        }
    }
    
    @Published var sortAscending: Bool = true {
        didSet {
            UserDefaults.standard.set(sortAscending, forKey: "tagSortAscending")
        }
    }
    
    private let viewContext = PersistenceController.shared.container.viewContext
    
    private init() {
        // Load saved sort settings
        let savedSortOrder = UserDefaults.standard.string(forKey: "tagSortOrder")
        self.currentSortOrder = TagSortOrder(rawValue: savedSortOrder ?? "") ?? .alphabetical
        self.sortAscending = UserDefaults.standard.object(forKey: "tagSortAscending") as? Bool ?? true
        
        // Recalculate tag usage counts on startup to ensure accuracy
        DispatchQueue.main.async {
            self.recalculateAllTagUsageCounts()
        }
    }
    
    // MARK: - Tag Management
    
    func createTag(name: String, parent: Tag? = nil, color: String? = nil) -> Tag? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return nil }
        
        // Check if tag already exists
        if let existingTag = findTag(byName: normalizedName, parent: parent) {
            return existingTag
        }
        
        let tag = Tag(context: viewContext)
        tag.id = UUID()
        tag.name = normalizedName
        tag.parent = parent
        tag.color = color
        tag.createdAt = Date()
        tag.modifiedAt = Date()
        tag.lastUsedAt = Date()
        tag.usageCount = 0
        tag.isPinned = false
        tag.sortOrder = Int32(getChildCount(for: parent))
        
        // Generate path for hierarchical organization
        tag.path = generatePath(for: tag)
        
        do {
            try viewContext.save()
            return tag
        } catch {
            print("Failed to create tag: \(error)")
            return nil
        }
    }
    
    func createTagFromPath(_ path: String, color: String? = nil) -> Tag? {
        let components = path.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !components.isEmpty else { return nil }
        
        var currentParent: Tag?
        var currentTag: Tag?
        
        for component in components {
            if let existing = findTag(byName: component, parent: currentParent) {
                currentTag = existing
                currentParent = existing
            } else {
                currentTag = createTag(name: component, parent: currentParent, color: color)
                currentParent = currentTag
            }
        }
        
        return currentTag
    }
    
    func deleteTag(_ tag: Tag) {
        // Move child tags to parent or root level
        if let children = tag.children?.allObjects as? [Tag] {
            for child in children {
                child.parent = tag.parent
                child.path = generatePath(for: child)
            }
        }

        viewContext.delete(tag)

        do {
            try viewContext.save()
        } catch {
            print("Failed to delete tag: \(error)")
        }
    }

    func deleteTags(_ tags: [Tag]) {
        for tag in tags {
            // Move child tags to parent or root level
            if let children = tag.children?.allObjects as? [Tag] {
                for child in children {
                    child.parent = tag.parent
                    child.path = generatePath(for: child)
                }
            }

            viewContext.delete(tag)
        }

        do {
            try viewContext.save()
            print("✓ Deleted \(tags.count) tag(s)")
        } catch {
            print("Failed to delete tags: \(error)")
        }
    }

    func getUnusedTags() -> [Tag] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.path, ascending: true)]

        do {
            let allTags = try viewContext.fetch(fetchRequest)
            // Filter tags with no sheet associations
            let unusedTags = allTags.filter { tag in
                let sheetCount = tag.sheetTags?.count ?? 0
                return sheetCount == 0
            }
            return unusedTags
        } catch {
            print("Failed to fetch unused tags: \(error)")
            return []
        }
    }

    func renameTag(_ tag: Tag, newName: String) {
        let normalizedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }
        
        tag.name = normalizedName
        tag.modifiedAt = Date()
        tag.path = generatePath(for: tag)
        
        // Update paths for all children
        updateChildrenPaths(for: tag)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to rename tag: \(error)")
        }
    }
    
    func moveTag(_ tag: Tag, toParent newParent: Tag?) {
        // Prevent circular references
        if let newParent = newParent, isAncestor(tag, of: newParent) {
            return
        }
        
        tag.parent = newParent
        tag.path = generatePath(for: tag)
        tag.modifiedAt = Date()
        tag.sortOrder = Int32(getChildCount(for: newParent))
        
        // Update paths for all children
        updateChildrenPaths(for: tag)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to move tag: \(error)")
        }
    }
    
    // MARK: - Sheet-Tag Association
    
    func addTag(_ tag: Tag, to sheet: Sheet) {
        // Check if association already exists
        if let existingTags = sheet.tags?.allObjects as? [SheetTag],
           existingTags.contains(where: { $0.tag == tag }) {
            // Tag already exists, don't increment usage again
            return
        }
        
        let sheetTag = SheetTag(context: viewContext)
        sheetTag.id = UUID()
        sheetTag.sheet = sheet
        sheetTag.tag = tag
        sheetTag.createdAt = Date()
        
        // Update tag usage statistics only when actually adding new association
        updateTagUsage(tag)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to add tag to sheet: \(error)")
        }
    }
    
    func removeTag(_ tag: Tag, from sheet: Sheet) {
        guard let sheetTags = sheet.tags?.allObjects as? [SheetTag] else { return }
        
        if let sheetTag = sheetTags.first(where: { $0.tag == tag }) {
            viewContext.delete(sheetTag)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to remove tag from sheet: \(error)")
            }
        }
    }
    
    func getSheetTags(for sheet: Sheet) -> [Tag] {
        guard let sheetTags = sheet.tags?.allObjects as? [SheetTag] else { return [] }
        return sheetTags.compactMap { $0.tag }.sorted { $0.path ?? "" < $1.path ?? "" }
    }
    
    func getSheets(for tag: Tag, includeSubtags: Bool = false) -> [Sheet] {
        var tagsToSearch = [tag]
        
        if includeSubtags {
            tagsToSearch.append(contentsOf: getAllDescendants(of: tag))
        }
        
        var sheets: Set<Sheet> = []
        
        for searchTag in tagsToSearch {
            if let sheetTags = searchTag.sheetTags?.allObjects as? [SheetTag] {
                for sheetTag in sheetTags {
                    if let sheet = sheetTag.sheet, !sheet.isInTrash {
                        sheets.insert(sheet)
                    }
                }
            }
        }
        
        return Array(sheets).sorted { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }
    }
    
    // MARK: - Tag Search and Filtering
    
    func searchTags(query: String) -> [Tag] {
        guard !query.isEmpty else { return getAllTags() }
        
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        let searchPredicate = NSPredicate(format: "name CONTAINS[cd] %@ OR path CONTAINS[cd] %@", query, query)
        fetchRequest.predicate = searchPredicate
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Tag.path, ascending: true)
        ]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to search tags: \(error)")
            return []
        }
    }
    
    func getFilteredSheets(tags: Set<Tag>, operation: TagFilterOperation = .and) -> [Sheet] {
        guard !tags.isEmpty else { return [] }
        
        let tagArray = Array(tags)
        var resultSheets: Set<Sheet> = []
        
        switch operation {
        case .and:
            // Sheets must have ALL selected tags
            if let firstTag = tagArray.first {
                resultSheets = Set(getSheets(for: firstTag))
                
                for tag in tagArray.dropFirst() {
                    let tagSheets = Set(getSheets(for: tag))
                    resultSheets = resultSheets.intersection(tagSheets)
                }
            }
            
        case .or:
            // Sheets must have ANY of the selected tags
            for tag in tagArray {
                let tagSheets = Set(getSheets(for: tag))
                resultSheets = resultSheets.union(tagSheets)
            }
            
        case .not:
            // Get all sheets then remove those with selected tags
            let allSheets = Set(getAllSheets())
            for tag in tagArray {
                let tagSheets = Set(getSheets(for: tag))
                resultSheets = allSheets.subtracting(tagSheets)
            }
        }
        
        return Array(resultSheets).sorted { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }
    }
    
    // MARK: - Tag Hierarchy
    
    func getRootTags() -> [Tag] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "parent == nil")
        fetchRequest.sortDescriptors = getSortDescriptors()
        
        do {
            let tags = try viewContext.fetch(fetchRequest)
            return sortTags(tags)
        } catch {
            print("Failed to fetch root tags: \(error)")
            return []
        }
    }
    
    func getChildTags(for parent: Tag) -> [Tag] {
        guard let children = parent.children?.allObjects as? [Tag] else { return [] }
        return sortTags(children)
    }
    
    func getAllTags() -> [Tag] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.path, ascending: true)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch all tags: \(error)")
            return []
        }
    }
    
    func getTagCount(for tag: Tag, includeSubtags: Bool = false) -> Int {
        return getSheets(for: tag, includeSubtags: includeSubtags).count
    }
    
    // MARK: - Inline Tag Processing
    
    func processInlineTags(in content: String, for sheet: Sheet) {
        let tagPattern = #"#([a-zA-Z0-9_/-]+)"#
        let regex = try! NSRegularExpression(pattern: tagPattern, options: [])
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        
        var foundTags: Set<String> = []
        
        regex.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
            if let match = match,
               let range = Range(match.range(at: 1), in: content) {
                let tagPath = String(content[range])
                foundTags.insert(tagPath)
            }
        }
        
        // Remove existing tag associations
        if let existingSheetTags = sheet.tags?.allObjects as? [SheetTag] {
            for sheetTag in existingSheetTags {
                viewContext.delete(sheetTag)
            }
        }
        
        // Add new tag associations
        for tagPath in foundTags {
            if let tag = createTagFromPath(tagPath) {
                addTag(tag, to: sheet)
            }
        }
    }
    
    func suggestRelatedTags(for sheet: Sheet, limit: Int = 10) -> [Tag] {
        let currentTags = Set(getSheetTags(for: sheet))
        var suggestions: [Tag: Int] = [:]
        
        // Find tags that frequently co-occur with current tags
        for tag in currentTags {
            let relatedSheets = getSheets(for: tag)
            for relatedSheet in relatedSheets {
                let relatedTags = Set(getSheetTags(for: relatedSheet))
                for relatedTag in relatedTags {
                    if !currentTags.contains(relatedTag) {
                        suggestions[relatedTag, default: 0] += 1
                    }
                }
            }
        }
        
        return suggestions
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    // MARK: - Tag Pinning and Sorting
    
    // Debug function to print current sort configuration
    func debugSortOrder() {
        print("🏷️ Current Sort: \(currentSortOrder.rawValue), Ascending: \(sortAscending)")
        let allTags = getAllTags()
        let sorted = sortTags(allTags)
        print("📋 Tags in order:")
        for (index, tag) in sorted.enumerated() {
            let pinnedStatus = tag.isPinned ? "📌" : "  "
            print("  \(index + 1). \(pinnedStatus)\(tag.displayName) (usage: \(tag.usageCount))")
        }
    }
    
    // Debug function to simulate usage for testing frequency sort
    #if DEBUG
    func simulateTagUsage() {
        let allTags = getAllTags()
        guard !allTags.isEmpty else {
            print("⚠️ No tags found to simulate usage")
            return
        }
        
        // Give some tags different usage counts for testing
        let testUsages = [5, 12, 3, 8, 1, 15, 2]
        for (index, tag) in allTags.prefix(testUsages.count).enumerated() {
            tag.usageCount = Int32(testUsages[index])
            tag.lastUsedAt = Date().addingTimeInterval(TimeInterval(-index * 3600)) // Different times
        }
        
        do {
            try viewContext.save()
            print("🧪 Simulated usage for \(testUsages.count) tags")
            debugSortOrder()
        } catch {
            print("Failed to save simulated usage: \(error)")
        }
    }
    
    func recalculateTagUsageCounts() {
        let allTags = getAllTags()
        print("🔄 Recalculating usage counts for \(allTags.count) tags")
        
        for tag in allTags {
            // Count actual sheet associations
            let actualUsageCount = tag.sheetTags?.count ?? 0
            tag.usageCount = Int32(actualUsageCount)
            print("📊 \(tag.displayName): \(actualUsageCount) actual associations")
        }
        
        do {
            try viewContext.save()
            print("✅ Usage counts recalculated")
            debugSortOrder()
        } catch {
            print("Failed to save recalculated usage: \(error)")
        }
    }
    #endif
    
    func toggleTagPin(_ tag: Tag) {
        tag.isPinned.toggle()
        tag.modifiedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to toggle tag pin: \(error)")
        }
    }
    
    func setSortOrder(_ sortOrder: TagSortOrder, ascending: Bool? = nil) {
        if let ascending = ascending {
            // Explicit direction provided
            currentSortOrder = sortOrder
            sortAscending = ascending
        } else {
            // Toggle direction if same sort order, otherwise use default ascending
            if currentSortOrder == sortOrder {
                sortAscending.toggle()
            } else {
                currentSortOrder = sortOrder
                // Set sensible defaults for different sort orders
                switch sortOrder {
                case .frequency, .recent, .creationDate:
                    sortAscending = false // Most used/recent first
                default:
                    sortAscending = true // Alphabetical/manual ascending by default
                }
            }
        }
        objectWillChange.send()
        
        // Debug output
        #if DEBUG
        debugSortOrder()
        #endif
    }
    
    func recalculateAllTagUsageCounts() {
        let allTags = getAllTags()
        for tag in allTags {
            let actualUsageCount = tag.sheetTags?.count ?? 0
            tag.usageCount = Int32(actualUsageCount)
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to recalculate tag usage counts: \(error)")
        }
    }
    
    private func updateTagUsage(_ tag: Tag) {
        // Calculate actual usage count based on sheet associations
        let actualUsageCount = tag.sheetTags?.count ?? 0
        tag.usageCount = Int32(actualUsageCount)
        tag.lastUsedAt = Date()
        tag.modifiedAt = Date()
        
        // Save the usage update immediately
        do {
            try viewContext.save()
        } catch {
            print("Failed to save tag usage update: \(error)")
        }
    }
    
    private func getSortDescriptors() -> [NSSortDescriptor] {
        switch currentSortOrder {
        case .alphabetical:
            // Use localizedCaseInsensitiveCompare for proper case-insensitive sorting
            return [NSSortDescriptor(key: "name", ascending: sortAscending, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        case .frequency:
            return [NSSortDescriptor(keyPath: \Tag.usageCount, ascending: !sortAscending)]
        case .recent:
            return [NSSortDescriptor(keyPath: \Tag.lastUsedAt, ascending: !sortAscending)]
        case .manual:
            return [NSSortDescriptor(keyPath: \Tag.sortOrder, ascending: sortAscending)]
        case .color:
            return [NSSortDescriptor(keyPath: \Tag.color, ascending: sortAscending)]
        case .creationDate:
            return [NSSortDescriptor(keyPath: \Tag.createdAt, ascending: !sortAscending)]
        }
    }
    
    func sortTags(_ tags: [Tag]) -> [Tag] {
        // First separate pinned and unpinned tags
        let pinnedTags = tags.filter { $0.isPinned }
        let unpinnedTags = tags.filter { !$0.isPinned }
        
        // Sort each group according to the selected sort order
        let sortedPinned = pinnedTags.sorted(by: getSortComparator())
        let sortedUnpinned = unpinnedTags.sorted(by: getSortComparator())
        
        // Return pinned tags first, then unpinned
        return sortedPinned + sortedUnpinned
    }
    
    private func getSortComparator() -> (Tag, Tag) -> Bool {
        switch currentSortOrder {
        case .alphabetical:
            return { tag1, tag2 in
                let name1 = (tag1.name ?? "").lowercased()
                let name2 = (tag2.name ?? "").lowercased()
                return self.sortAscending ? name1 < name2 : name1 > name2
            }
        case .frequency:
            return { tag1, tag2 in
                self.sortAscending ? tag1.usageCount < tag2.usageCount : tag1.usageCount > tag2.usageCount
            }
        case .recent:
            return { tag1, tag2 in
                let date1 = tag1.lastUsedAt ?? Date.distantPast
                let date2 = tag2.lastUsedAt ?? Date.distantPast
                return self.sortAscending ? date1 < date2 : date1 > date2
            }
        case .manual:
            return { tag1, tag2 in
                self.sortAscending ? tag1.sortOrder < tag2.sortOrder : tag1.sortOrder > tag2.sortOrder
            }
        case .color:
            return { tag1, tag2 in
                let color1 = tag1.color ?? ""
                let color2 = tag2.color ?? ""
                return self.sortAscending ? color1 < color2 : color1 > color2
            }
        case .creationDate:
            return { tag1, tag2 in
                let date1 = tag1.createdAt ?? Date.distantPast
                let date2 = tag2.createdAt ?? Date.distantPast
                return self.sortAscending ? date1 < date2 : date1 > date2
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func findTag(byName name: String, parent: Tag?) -> Tag? {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        
        if let parent = parent {
            fetchRequest.predicate = NSPredicate(format: "name == %@ AND parent == %@", name, parent)
        } else {
            fetchRequest.predicate = NSPredicate(format: "name == %@ AND parent == nil", name)
        }
        
        do {
            return try viewContext.fetch(fetchRequest).first
        } catch {
            return nil
        }
    }
    
    private func generatePath(for tag: Tag) -> String {
        var components: [String] = []
        var currentTag: Tag? = tag
        
        while let tag = currentTag {
            if let name = tag.name {
                components.insert(name, at: 0)
            }
            currentTag = tag.parent
        }
        
        return components.joined(separator: "/")
    }
    
    private func updateChildrenPaths(for tag: Tag) {
        if let children = tag.children?.allObjects as? [Tag] {
            for child in children {
                child.path = generatePath(for: child)
                updateChildrenPaths(for: child)
            }
        }
    }
    
    private func getChildCount(for parent: Tag?) -> Int {
        if let parent = parent {
            return parent.children?.count ?? 0
        } else {
            return getRootTags().count
        }
    }
    
    private func isAncestor(_ ancestor: Tag, of descendant: Tag) -> Bool {
        var current = descendant.parent
        while let parent = current {
            if parent == ancestor {
                return true
            }
            current = parent.parent
        }
        return false
    }
    
    private func getAllDescendants(of tag: Tag) -> [Tag] {
        var descendants: [Tag] = []
        
        if let children = tag.children?.allObjects as? [Tag] {
            for child in children {
                descendants.append(child)
                descendants.append(contentsOf: getAllDescendants(of: child))
            }
        }
        
        return descendants
    }
    
    private func getAllSheets() -> [Sheet] {
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isInTrash == NO")
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch all sheets: \(error)")
            return []
        }
    }
}

// MARK: - Supporting Types

enum TagFilterOperation {
    case and
    case or
    case not
}

enum TagViewMode {
    case tree
    case flat
    case search
}

enum TagSortOrder: String, CaseIterable {
    case alphabetical = "Alphabetical"
    case frequency = "Frequency"
    case recent = "Recently Used"
    case manual = "Manual"
    case color = "Color"
    case creationDate = "Creation Date"
    
    var systemImage: String {
        switch self {
        case .alphabetical: return "textformat.abc"
        case .frequency: return "chart.bar.fill"
        case .recent: return "clock.fill"
        case .manual: return "hand.draw.fill"
        case .color: return "paintpalette.fill"
        case .creationDate: return "calendar"
        }
    }
}

// MARK: - Tag Extensions

extension Tag {
    var displayName: String {
        return name ?? "Untitled Tag"
    }
    
    var fullPath: String {
        return path ?? displayName
    }
    
    var hasChildren: Bool {
        return (children?.count ?? 0) > 0
    }
    
    var tagColor: Color {
        if let colorString = color {
            switch colorString {
            case "red": return .red
            case "orange": return .orange
            case "yellow": return .yellow
            case "green": return .green
            case "blue": return .blue
            case "purple": return .purple
            case "pink": return .pink
            case "gray": return .gray
            default: return .accentColor
            }
        }
        return .accentColor
    }
}

extension Sheet {
    var tagsList: [Tag] {
        return TagService.shared.getSheetTags(for: self)
    }
    
    var tagsText: String {
        return tagsList.map { "#\($0.fullPath)" }.joined(separator: " ")
    }
}