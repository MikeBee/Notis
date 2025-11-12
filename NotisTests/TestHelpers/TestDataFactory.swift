//
//  TestDataFactory.swift
//  NotisTests
//
//  Created by Claude Code
//

import Foundation
import CoreData
@testable import Notis

/// Factory for creating test data objects
class TestDataFactory {

    // MARK: - Sheet Creation

    static func createSheet(
        title: String = "Test Sheet",
        content: String = "Test content",
        context: NSManagedObjectContext
    ) -> Sheet {
        let sheet = Sheet(context: context)
        sheet.id = UUID()
        sheet.title = title
        sheet.content = content
        sheet.createdAt = Date()
        sheet.modifiedAt = Date()
        sheet.wordCount = Int64(content.split(separator: " ").count)
        sheet.preview = String(content.prefix(100))
        sheet.isInTrash = false
        return sheet
    }

    static func createSheets(
        count: Int,
        titlePrefix: String = "Sheet",
        context: NSManagedObjectContext
    ) -> [Sheet] {
        return (1...count).map { index in
            createSheet(
                title: "\(titlePrefix) \(index)",
                content: "This is test content for sheet \(index)",
                context: context
            )
        }
    }

    // MARK: - Group Creation

    static func createGroup(
        name: String = "Test Group",
        parent: Group? = nil,
        context: NSManagedObjectContext
    ) -> Group {
        let group = Group(context: context)
        group.id = UUID()
        group.name = name
        group.createdAt = Date()
        group.modifiedAt = Date()
        group.sortOrder = 0
        group.parent = parent
        return group
    }

    static func createGroupHierarchy(
        names: [String],
        context: NSManagedObjectContext
    ) -> [Group] {
        var groups: [Group] = []
        var parent: Group? = nil

        for name in names {
            let group = createGroup(name: name, parent: parent, context: context)
            groups.append(group)
            parent = group
        }

        return groups
    }

    // MARK: - Tag Creation

    static func createTag(
        name: String = "test",
        parent: Tag? = nil,
        context: NSManagedObjectContext
    ) -> Tag {
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.createdAt = Date()
        tag.modifiedAt = Date()
        tag.parent = parent
        tag.usageCount = 0
        return tag
    }

    static func createTagPath(
        path: String,
        context: NSManagedObjectContext
    ) -> Tag {
        let components = path.split(separator: "/").map(String.init)
        var parent: Tag? = nil
        var lastTag: Tag!

        for component in components {
            let tag = createTag(name: component, parent: parent, context: context)
            parent = tag
            lastTag = tag
        }

        return lastTag
    }

    // MARK: - SheetTag (association) Creation

    static func createSheetTag(
        sheet: Sheet,
        tag: Tag,
        context: NSManagedObjectContext
    ) -> SheetTag {
        let sheetTag = SheetTag(context: context)
        sheetTag.sheet = sheet
        sheetTag.tag = tag
        sheetTag.createdAt = Date()
        return sheetTag
    }

    // MARK: - Goal Creation

    static func createGoal(
        title: String = "Test Goal",
        targetCount: Int32 = 1000,
        goalType: String = "words",
        sheet: Sheet? = nil,
        context: NSManagedObjectContext
    ) -> Goal {
        let goal = Goal(context: context)
        goal.id = UUID()
        goal.title = title
        goal.targetCount = targetCount
        goal.currentCount = 0
        goal.goalType = goalType
        goal.visualType = "progressBar"
        goal.createdAt = Date()
        goal.modifiedAt = Date()
        goal.isActive = true
        goal.sheet = sheet
        return goal
    }

    // MARK: - Template Creation

    static func createTemplate(
        name: String = "Test Template",
        content: String = "# Template Content",
        context: NSManagedObjectContext
    ) -> Template {
        let template = Template(context: context)
        template.id = UUID()
        template.name = name
        template.content = content
        template.createdAt = Date()
        template.modifiedAt = Date()
        return template
    }
}
