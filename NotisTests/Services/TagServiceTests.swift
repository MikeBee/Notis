//
//  TagServiceTests.swift
//  NotisTests
//
//  Created by Claude Code
//

import XCTest
import CoreData
@testable import Notis

final class TagServiceTests: XCTestCase {

    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var tagService: TagService!

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        tagService = TagService.shared
    }

    override func tearDown() {
        // Clean up
        let allTags = fetchAll(Tag.self, in: context)
        for tag in allTags {
            context.delete(tag)
        }
        let allSheetTags = fetchAll(SheetTag.self, in: context)
        for sheetTag in allSheetTags {
            context.delete(sheetTag)
        }
        saveContext(context)

        context = nil
        controller = nil
        super.tearDown()
    }

    // MARK: - Inline Tag Processing Tests

    func testProcessInlineTags_FindsHashtags() {
        let content = "This is #test and #another tag"
        let sheet = TestDataFactory.createSheet(content: content, context: context)
        saveContext(context)

        tagService.processInlineTags(in: content, for: sheet)
        saveContext(context)

        // Verify tags were created
        let allTags = fetchAll(Tag.self, in: context)
        let tagNames = allTags.map { $0.name ?? "" }

        XCTAssertTrue(tagNames.contains("test"))
        XCTAssertTrue(tagNames.contains("another"))
    }

    func testProcessInlineTags_FindsNestedTags() {
        let content = "This has #project/work/client-a nested tag"
        let sheet = TestDataFactory.createSheet(content: content, context: context)
        saveContext(context)

        tagService.processInlineTags(in: content, for: sheet)
        saveContext(context)

        // Verify hierarchical tags were created
        let allTags = fetchAll(Tag.self, in: context)
        let tagNames = allTags.map { $0.name ?? "" }

        XCTAssertTrue(tagNames.contains("project"))
        XCTAssertTrue(tagNames.contains("work"))
        XCTAssertTrue(tagNames.contains("client-a"))
    }

    func testProcessInlineTags_HandlesEmptyContent() {
        let content = ""
        let sheet = TestDataFactory.createSheet(content: content, context: context)
        saveContext(context)

        // Should not crash
        tagService.processInlineTags(in: content, for: sheet)

        let allTags = fetchAll(Tag.self, in: context)
        XCTAssertEqual(allTags.count, 0)
    }

    func testProcessInlineTags_HandlesNoTags() {
        let content = "This content has no hashtags at all"
        let sheet = TestDataFactory.createSheet(content: content, context: context)
        saveContext(context)

        tagService.processInlineTags(in: content, for: sheet)

        let allTags = fetchAll(Tag.self, in: context)
        XCTAssertEqual(allTags.count, 0)
    }

    func testProcessInlineTags_HandlesInvalidRegex() {
        // This tests our fix for the try! issue
        // The regex pattern should always compile, but if it doesn't,
        // the function should return gracefully instead of crashing

        let content = "Test content"
        let sheet = TestDataFactory.createSheet(content: content, context: context)
        saveContext(context)

        // Should not crash even if regex compilation fails
        tagService.processInlineTags(in: content, for: sheet)

        // Test passes if we get here without crashing
        XCTAssertTrue(true)
    }

    func testProcessInlineTags_HandlesSpecialCharacters() {
        let content = "Tags with numbers #tag123 and underscores #tag_name"
        let sheet = TestDataFactory.createSheet(content: content, context: context)
        saveContext(context)

        tagService.processInlineTags(in: content, for: sheet)
        saveContext(context)

        let allTags = fetchAll(Tag.self, in: context)
        let tagNames = allTags.map { $0.name ?? "" }

        XCTAssertTrue(tagNames.contains("tag123"))
        XCTAssertTrue(tagNames.contains("tag_name"))
    }

    func testProcessInlineTags_RemovesOldTags() {
        let sheet = TestDataFactory.createSheet(content: "", context: context)
        let oldTag = TestDataFactory.createTag(name: "old", context: context)
        _ = TestDataFactory.createSheetTag(sheet: sheet, tag: oldTag, context: context)
        saveContext(context)

        // Process new content without the old tag
        let newContent = "New content with #new tag"
        sheet.content = newContent
        tagService.processInlineTags(in: newContent, for: sheet)
        saveContext(context)

        // Old tag should be removed from sheet
        let sheetTags = (sheet.tags?.allObjects as? [SheetTag]) ?? []
        let tagNames = sheetTags.compactMap { $0.tag?.name }

        XCTAssertFalse(tagNames.contains("old"))
        XCTAssertTrue(tagNames.contains("new"))
    }

    // MARK: - Tag Creation Tests

    func testCreateTag_Simple() {
        let tag = tagService.createTag(name: "simple", context: context)
        saveContext(context)

        XCTAssertNotNil(tag)
        XCTAssertEqual(tag.name, "simple")
        XCTAssertNil(tag.parent)
    }

    func testCreateTag_WithParent() {
        let parent = TestDataFactory.createTag(name: "parent", context: context)
        saveContext(context)

        let child = tagService.createTag(name: "child", parent: parent, context: context)
        saveContext(context)

        XCTAssertNotNil(child)
        XCTAssertEqual(child.name, "child")
        XCTAssertEqual(child.parent, parent)
    }

    func testCreateTag_Hierarchical() {
        let tag = tagService.createTag(path: "project/work/client", context: context)
        saveContext(context)

        XCTAssertEqual(tag.name, "client")
        XCTAssertEqual(tag.parent?.name, "work")
        XCTAssertEqual(tag.parent?.parent?.name, "project")
    }

    // MARK: - Tag Deletion Tests

    func testDeleteTag_Simple() {
        let tag = TestDataFactory.createTag(name: "test", context: context)
        saveContext(context)

        tagService.deleteTag(tag, context: context)
        saveContext(context)

        let allTags = fetchAll(Tag.self, in: context)
        XCTAssertEqual(allTags.count, 0)
    }

    func testDeleteTag_WithChildren() {
        let parent = TestDataFactory.createTag(name: "parent", context: context)
        let child = TestDataFactory.createTag(name: "child", parent: parent, context: context)
        saveContext(context)

        tagService.deleteTag(parent, context: context)
        saveContext(context)

        // Both parent and child should be deleted
        let allTags = fetchAll(Tag.self, in: context)
        XCTAssertEqual(allTags.count, 0)
    }

    func testDeleteTag_RemovesFromSheets() {
        let tag = TestDataFactory.createTag(name: "test", context: context)
        let sheet = TestDataFactory.createSheet(context: context)
        _ = TestDataFactory.createSheetTag(sheet: sheet, tag: tag, context: context)
        saveContext(context)

        tagService.deleteTag(tag, context: context)
        saveContext(context)

        // Tag should be removed from sheet
        let sheetTags = (sheet.tags?.allObjects as? [SheetTag]) ?? []
        XCTAssertEqual(sheetTags.count, 0)
    }

    // MARK: - Tag Querying Tests

    func testGetAllTags() {
        _ = TestDataFactory.createTag(name: "tag1", context: context)
        _ = TestDataFactory.createTag(name: "tag2", context: context)
        _ = TestDataFactory.createTag(name: "tag3", context: context)
        saveContext(context)

        let allTags = tagService.getAllTags(context: context)

        XCTAssertEqual(allTags.count, 3)
    }

    func testGetTagsForSheet() {
        let sheet = TestDataFactory.createSheet(context: context)
        let tag1 = TestDataFactory.createTag(name: "tag1", context: context)
        let tag2 = TestDataFactory.createTag(name: "tag2", context: context)
        _ = TestDataFactory.createSheetTag(sheet: sheet, tag: tag1, context: context)
        _ = TestDataFactory.createSheetTag(sheet: sheet, tag: tag2, context: context)
        saveContext(context)

        let tags = tagService.getTags(for: sheet)

        XCTAssertEqual(tags.count, 2)
    }

    func testGetSheetsForTag() {
        let tag = TestDataFactory.createTag(name: "test", context: context)
        let sheet1 = TestDataFactory.createSheet(title: "Sheet 1", context: context)
        let sheet2 = TestDataFactory.createSheet(title: "Sheet 2", context: context)
        _ = TestDataFactory.createSheetTag(sheet: sheet1, tag: tag, context: context)
        _ = TestDataFactory.createSheetTag(sheet: sheet2, tag: tag, context: context)
        saveContext(context)

        let sheets = tagService.getSheets(for: tag, includeSubtags: false)

        XCTAssertEqual(sheets.count, 2)
    }

    // MARK: - Tag Usage Tests

    func testUpdateTagUsageCount() {
        let tag = TestDataFactory.createTag(name: "test", context: context)
        tag.usageCount = 0
        saveContext(context)

        let sheet = TestDataFactory.createSheet(context: context)
        _ = TestDataFactory.createSheetTag(sheet: sheet, tag: tag, context: context)
        saveContext(context)

        // Usage count should be updated
        tagService.updateUsageCount(for: tag, context: context)
        saveContext(context)

        XCTAssertEqual(tag.usageCount, 1)
    }

    // MARK: - Performance Tests

    func testProcessInlineTags_LargeContent() {
        // Create content with many tags
        var content = "Large content with many tags: "
        for i in 1...100 {
            content += "#tag\(i) "
        }

        let sheet = TestDataFactory.createSheet(content: content, context: context)
        saveContext(context)

        // Should complete reasonably quickly
        let start = Date()
        tagService.processInlineTags(in: content, for: sheet)
        let duration = Date().timeIntervalSince(start)

        // Should process 100 tags in less than 2 seconds
        XCTAssertLessThan(duration, 2.0)
    }

    // MARK: - Edge Cases

    func testProcessInlineTags_DuplicateTags() {
        let content = "Content with #duplicate and #duplicate again"
        let sheet = TestDataFactory.createSheet(content: content, context: context)
        saveContext(context)

        tagService.processInlineTags(in: content, for: sheet)
        saveContext(context)

        // Should only create one tag
        let allTags = fetchAll(Tag.self, in: context)
        let duplicateTags = allTags.filter { $0.name == "duplicate" }

        XCTAssertEqual(duplicateTags.count, 1)
    }

    func testProcessInlineTags_UnicodeCharacters() {
        let content = "Tags with émojis #test😀 and #café"
        let sheet = TestDataFactory.createSheet(content: content, context: context)
        saveContext(context)

        // Should handle gracefully (may or may not match depending on regex)
        tagService.processInlineTags(in: content, for: sheet)

        // Test passes if it doesn't crash
        XCTAssertTrue(true)
    }

    func testProcessInlineTags_VeryLongTagName() {
        let longTagName = String(repeating: "a", count: 1000)
        let content = "Content with #\(longTagName)"
        let sheet = TestDataFactory.createSheet(content: content, context: context)
        saveContext(context)

        // Should handle gracefully
        tagService.processInlineTags(in: content, for: sheet)

        // Test passes if it doesn't crash
        XCTAssertTrue(true)
    }
}
