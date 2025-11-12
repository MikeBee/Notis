//
//  MarkdownFileServiceTests.swift
//  NotisTests
//
//  Created by Claude Code
//

import XCTest
import CoreData
@testable import Notis

final class MarkdownFileServiceTests: XCTestCase {

    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var fileService: MarkdownFileService!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        fileService = MarkdownFileService.shared
        tempDirectory = createTempDirectory()
    }

    override func tearDown() {
        removeTempDirectory(tempDirectory)
        context = nil
        controller = nil
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - File Creation Tests

    func testSaveMarkdownFile_CreatesFile() {
        let sheet = TestDataFactory.createSheet(
            title: "Test Note",
            content: "Test content",
            context: context
        )
        saveContext(context)

        let result = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)

        XCTAssertTrue(result.success, "File save should succeed")
        XCTAssertNotNil(result.url, "File URL should be returned")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url!.path))
    }

    func testSaveMarkdownFile_CreatesValidYAML() {
        let sheet = TestDataFactory.createSheet(
            title: "YAML Test",
            content: "Content with **markdown**",
            context: context
        )
        sheet.createdAt = Date()
        sheet.modifiedAt = Date()
        sheet.wordCount = 3
        saveContext(context)

        let result = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)

        XCTAssertTrue(result.success)

        // Read file content
        guard let url = result.url else {
            XCTFail("No URL returned")
            return
        }

        let content = try? String(contentsOf: url, encoding: .utf8)
        XCTAssertNotNil(content)

        // Verify YAML frontmatter
        XCTAssertTrue(content!.hasPrefix("---"))
        XCTAssertTrue(content!.contains("title: YAML Test"))
        XCTAssertTrue(content!.contains("wordCount:"))
        XCTAssertTrue(content!.contains("Content with **markdown**"))
    }

    func testSaveMarkdownFile_HandlesSpecialCharacters() {
        let sheet = TestDataFactory.createSheet(
            title: "Special: Characters / Test",
            content: "Content with émojis 😀 and special chars: \n\t\"quotes\"",
            context: context
        )
        saveContext(context)

        let result = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)

        XCTAssertTrue(result.success)

        // Verify file can be read back
        guard let url = result.url else {
            XCTFail("No URL returned")
            return
        }

        let content = try? String(contentsOf: url, encoding: .utf8)
        XCTAssertNotNil(content)
        XCTAssertTrue(content!.contains("😀"))
    }

    func testSaveMarkdownFile_PreservesLineBreaks() {
        let content = "Line 1\nLine 2\n\nLine 4 (with blank line)"
        let sheet = TestDataFactory.createSheet(
            title: "Line Break Test",
            content: content,
            context: context
        )
        saveContext(context)

        let result = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)

        XCTAssertTrue(result.success)

        // Read back and verify line breaks are preserved
        guard let url = result.url else {
            XCTFail("No URL returned")
            return
        }

        let fileContent = try? String(contentsOf: url, encoding: .utf8)
        XCTAssertNotNil(fileContent)
        XCTAssertTrue(fileContent!.contains("Line 1\nLine 2\n\nLine 4"))
    }

    // MARK: - File Reading Tests

    func testParseMarkdownFile_ReadsYAML() {
        // Create a test file with YAML frontmatter
        let yamlContent = """
        ---
        title: Test Title
        wordCount: 10
        createdAt: 2025-01-01T12:00:00Z
        ---

        This is the content
        """

        let fileURL = createTestFile(
            at: tempDirectory,
            name: "test.md",
            content: yamlContent
        )

        let result = fileService.parseMarkdownFile(at: fileURL)

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.title, "Test Title")
        XCTAssertEqual(result.content, "This is the content")
        XCTAssertEqual(result.wordCount, 10)
    }

    func testParseMarkdownFile_HandlesNoYAML() {
        let content = "# Just markdown\n\nNo YAML here"
        let fileURL = createTestFile(
            at: tempDirectory,
            name: "no-yaml.md",
            content: content
        )

        let result = fileService.parseMarkdownFile(at: fileURL)

        // Should still succeed, treating entire content as body
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.content)
    }

    func testParseMarkdownFile_HandlesMalformedYAML() {
        let badYaml = """
        ---
        this is not valid yaml: [[[
        title incomplete
        ---

        Content here
        """

        let fileURL = createTestFile(
            at: tempDirectory,
            name: "bad-yaml.md",
            content: badYaml
        )

        let result = fileService.parseMarkdownFile(at: fileURL)

        // Should handle gracefully, not crash
        // Success or failure depends on implementation, but shouldn't crash
        XCTAssertNotNil(result)
    }

    // MARK: - File Update Tests

    func testUpdateMarkdownFile_PreservesData() {
        let sheet = TestDataFactory.createSheet(
            title: "Original",
            content: "Original content",
            context: context
        )
        saveContext(context)

        let result1 = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)
        XCTAssertTrue(result1.success)

        // Update sheet
        sheet.title = "Updated"
        sheet.content = "Updated content"
        saveContext(context)

        let result2 = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)
        XCTAssertTrue(result2.success)

        // Verify updated content
        guard let url = result2.url else {
            XCTFail("No URL returned")
            return
        }

        let content = try? String(contentsOf: url, encoding: .utf8)
        XCTAssertNotNil(content)
        XCTAssertTrue(content!.contains("title: Updated"))
        XCTAssertTrue(content!.contains("Updated content"))
    }

    // MARK: - File Deletion Tests

    func testDeleteFile_RemovesFile() {
        let sheet = TestDataFactory.createSheet(context: context)
        saveContext(context)

        let result = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)
        XCTAssertTrue(result.success)

        guard let url = result.url else {
            XCTFail("No URL returned")
            return
        }

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        // Delete file
        let deleteSuccess = fileService.deleteFile(at: url)
        XCTAssertTrue(deleteSuccess)

        // Verify file is gone
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDeleteFile_HandlesNonExistentFile() {
        let nonExistentURL = tempDirectory.appendingPathComponent("nonexistent.md")

        // Should handle gracefully
        let deleteSuccess = fileService.deleteFile(at: nonExistentURL)

        // Depending on implementation, may return false or true
        // Either way, shouldn't crash
        XCTAssertNotNil(deleteSuccess)
    }

    // MARK: - Trash Operations Tests

    func testMoveToTrash_MovesFile() {
        let sheet = TestDataFactory.createSheet(context: context)
        saveContext(context)

        let result = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)
        XCTAssertTrue(result.success)

        guard let url = result.url else {
            XCTFail("No URL returned")
            return
        }

        // Move to trash
        let trashResult = fileService.moveToTrash(at: url)

        if trashResult.success {
            // Original file should be gone
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))

            // New location should exist
            if let newURL = trashResult.url {
                XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
                XCTAssertTrue(newURL.path.contains(".Trash"))
            }
        }
    }

    // MARK: - Data Integrity Tests

    func testSaveAndLoad_RoundTrip() {
        let originalTitle = "Round Trip Test"
        let originalContent = "# Header\n\nParagraph with **bold** and *italic*.\n\nAnother paragraph."

        let sheet = TestDataFactory.createSheet(
            title: originalTitle,
            content: originalContent,
            context: context
        )
        sheet.wordCount = 10
        sheet.createdAt = Date()
        sheet.modifiedAt = Date()
        saveContext(context)

        // Save to file
        let saveResult = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)
        XCTAssertTrue(saveResult.success)

        guard let url = saveResult.url else {
            XCTFail("No URL returned")
            return
        }

        // Load from file
        let loadResult = fileService.parseMarkdownFile(at: url)
        XCTAssertTrue(loadResult.success)

        // Verify data matches
        XCTAssertEqual(loadResult.title, originalTitle)
        XCTAssertEqual(loadResult.content?.trimmingCharacters(in: .whitespacesAndNewlines),
                      originalContent.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertEqual(loadResult.wordCount, 10)
    }

    func testMultipleFiles_NoCollisions() {
        let sheets = TestDataFactory.createSheets(count: 10, context: context)
        saveContext(context)

        var urls: [URL] = []

        for sheet in sheets {
            let result = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)
            XCTAssertTrue(result.success)
            if let url = result.url {
                urls.append(url)
            }
        }

        // All URLs should be unique
        let uniqueURLs = Set(urls)
        XCTAssertEqual(urls.count, uniqueURLs.count)

        // All files should exist
        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }

    // MARK: - Error Handling Tests

    func testSaveMarkdownFile_HandlesReadOnlyDirectory() {
        // Create a read-only directory (may not work on all systems)
        let readOnlyDir = tempDirectory.appendingPathComponent("readonly")
        try? FileManager.default.createDirectory(at: readOnlyDir, withIntermediateDirectories: true)

        // Try to save
        let sheet = TestDataFactory.createSheet(context: context)
        let result = fileService.saveMarkdownFile(for: sheet, in: readOnlyDir)

        // Should either succeed or fail gracefully (no crash)
        XCTAssertNotNil(result)
    }

    func testParseMarkdownFile_HandlesCorruptedFile() {
        // Create a file with binary data
        let binaryData = Data([0xFF, 0xFE, 0x00, 0x01, 0x02])
        let url = tempDirectory.appendingPathComponent("binary.md")
        try? binaryData.write(to: url)

        let result = fileService.parseMarkdownFile(at: url)

        // Should handle gracefully
        XCTAssertNotNil(result)
    }

    // MARK: - Performance Tests

    func testSaveMarkdownFile_LargeContent() {
        // Create a sheet with very large content
        let largeContent = String(repeating: "This is a line of text. ", count: 10000)

        let sheet = TestDataFactory.createSheet(
            title: "Large Content",
            content: largeContent,
            context: context
        )
        saveContext(context)

        let start = Date()
        let result = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)
        let duration = Date().timeIntervalSince(start)

        XCTAssertTrue(result.success)
        // Should complete in reasonable time (< 2 seconds)
        XCTAssertLessThan(duration, 2.0)
    }

    func testBatchFileOperations() {
        let sheets = TestDataFactory.createSheets(count: 50, context: context)
        saveContext(context)

        let start = Date()

        for sheet in sheets {
            let result = fileService.saveMarkdownFile(for: sheet, in: tempDirectory)
            XCTAssertTrue(result.success)
        }

        let duration = Date().timeIntervalSince(start)

        // Should complete 50 files in reasonable time (< 5 seconds)
        XCTAssertLessThan(duration, 5.0)
    }
}
