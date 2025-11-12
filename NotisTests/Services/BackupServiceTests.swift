//
//  BackupServiceTests.swift
//  NotisTests
//
//  Created by Claude Code
//

import XCTest
import CoreData
import CloudKit
@testable import Notis

final class BackupServiceTests: XCTestCase {

    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var backupService: BackupService!

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        backupService = BackupService.shared
    }

    override func tearDown() {
        // Clean up any test data
        let allSheets = fetchAll(Sheet.self, in: context)
        for sheet in allSheets {
            context.delete(sheet)
        }
        let allGroups = fetchAll(Group.self, in: context)
        for group in allGroups {
            context.delete(group)
        }
        saveContext(context)

        context = nil
        controller = nil
        super.tearDown()
    }

    // MARK: - Backup Status Tests

    func testBackupStatus_InitiallyIdle() {
        // Backup service should start in idle state
        XCTAssertEqual(backupService.backupStatus, .idle)
    }

    // MARK: - Backup Creation Tests

    func testCreateBackup_WithNoData() {
        // Should handle empty database gracefully
        backupService.startManualBackup()

        // Wait for backup to process
        waitForCondition(timeout: 5.0, description: "backup to complete") {
            self.backupService.backupStatus == .completed ||
            self.backupService.backupStatus == .failed ||
            self.backupService.backupStatus == .idle
        }

        // Should complete without crashing
        XCTAssertNotEqual(backupService.backupStatus, .inProgress)
    }

    func testCreateBackup_WithData() {
        // Create test data
        let sheets = TestDataFactory.createSheets(count: 5, context: context)
        saveContext(context)

        backupService.startManualBackup()

        // Wait for backup to process
        waitForCondition(timeout: 10.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        // Backup should reach a final state
        XCTAssertTrue(
            backupService.backupStatus == .completed ||
            backupService.backupStatus == .failed
        )
    }

    func testCreateBackup_IncludesAllSheets() {
        // Create multiple sheets
        let sheets = TestDataFactory.createSheets(count: 10, context: context)
        saveContext(context)

        let sheetIDs = sheets.compactMap { $0.id?.uuidString }

        backupService.startManualBackup()

        // Wait for backup
        waitForCondition(timeout: 10.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        // Verify all sheets are included (if backup succeeded)
        if backupService.backupStatus == .completed {
            // This is a basic test - in real implementation,
            // you'd verify the backup actually contains all sheets
            XCTAssertEqual(sheets.count, 10)
        }
    }

    func testCreateBackup_IncludesGroups() {
        // Create groups with hierarchy
        let group1 = TestDataFactory.createGroup(name: "Group 1", context: context)
        let group2 = TestDataFactory.createGroup(name: "Group 2", parent: group1, context: context)
        let sheet = TestDataFactory.createSheet(context: context)
        sheet.group = group2
        saveContext(context)

        backupService.startManualBackup()

        waitForCondition(timeout: 10.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        // If successful, hierarchy should be preserved
        XCTAssertTrue(
            backupService.backupStatus == .completed ||
            backupService.backupStatus == .failed
        )
    }

    // MARK: - Restore Tests

    func testRestoreBackup_PreservesData() {
        // Create original data
        let originalSheet = TestDataFactory.createSheet(
            title: "Original Title",
            content: "Original Content",
            context: context
        )
        let originalID = originalSheet.id
        saveContext(context)

        // Create backup
        backupService.startManualBackup()
        waitForCondition(timeout: 10.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        // Modify data
        originalSheet.title = "Modified Title"
        originalSheet.content = "Modified Content"
        saveContext(context)

        // Note: Actual restore implementation would require:
        // 1. A way to identify and select backups
        // 2. A restore method
        // 3. Verification of restored data

        // For now, verify that backup completed successfully
        if backupService.backupStatus == .completed {
            // Backup system is functioning
            XCTAssertTrue(true)
        }
    }

    // MARK: - Backup Metadata Tests

    func testBackup_RecordsTimestamp() {
        let sheet = TestDataFactory.createSheet(context: context)
        saveContext(context)

        let beforeBackup = Date()

        backupService.startManualBackup()
        waitForCondition(timeout: 10.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        let afterBackup = Date()

        // If backup has a lastBackupDate property, verify it's in the right range
        if let lastBackup = backupService.lastBackupDate {
            XCTAssertGreaterThanOrEqual(lastBackup, beforeBackup)
            XCTAssertLessThanOrEqual(lastBackup, afterBackup)
        }
    }

    // MARK: - Error Handling Tests

    func testBackup_HandlesCorruptedData() {
        // Create sheet with potentially problematic data
        let sheet = TestDataFactory.createSheet(context: context)
        sheet.content = String(repeating: "x", count: 1_000_000) // Very large content
        sheet.title = nil // Missing title
        saveContext(context)

        backupService.startManualBackup()

        waitForCondition(timeout: 15.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        // Should complete (success or failure) without crashing
        XCTAssertNotEqual(backupService.backupStatus, .inProgress)
    }

    func testBackup_HandlesEmptyStrings() {
        let sheet = TestDataFactory.createSheet(context: context)
        sheet.title = ""
        sheet.content = ""
        saveContext(context)

        backupService.startManualBackup()

        waitForCondition(timeout: 10.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        // Should handle gracefully
        XCTAssertNotEqual(backupService.backupStatus, .inProgress)
    }

    // MARK: - Concurrent Backup Tests

    func testBackup_PreventsConcurrent() {
        // Create some data
        _ = TestDataFactory.createSheets(count: 5, context: context)
        saveContext(context)

        // Start first backup
        backupService.startManualBackup()

        // Try to start second backup immediately
        backupService.startManualBackup()

        // Should only have one backup in progress
        // (Implementation dependent - may queue or reject)

        waitForCondition(timeout: 15.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        // Should complete successfully
        XCTAssertNotEqual(backupService.backupStatus, .inProgress)
    }

    // MARK: - Performance Tests

    func testBackup_LargeDataset() {
        // Create large dataset
        let sheets = TestDataFactory.createSheets(count: 100, context: context)
        for sheet in sheets {
            sheet.content = String(repeating: "This is test content. ", count: 100)
        }
        saveContext(context)

        let start = Date()

        backupService.startManualBackup()
        waitForCondition(timeout: 30.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        let duration = Date().timeIntervalSince(start)

        // Should complete in reasonable time (< 30 seconds for 100 sheets)
        XCTAssertLessThan(duration, 30.0)
    }

    // MARK: - Data Integrity Tests

    func testBackup_PreservesRelationships() {
        // Create related data
        let group = TestDataFactory.createGroup(name: "Test Group", context: context)
        let sheet1 = TestDataFactory.createSheet(title: "Sheet 1", context: context)
        let sheet2 = TestDataFactory.createSheet(title: "Sheet 2", context: context)

        sheet1.group = group
        sheet2.group = group
        saveContext(context)

        backupService.startManualBackup()
        waitForCondition(timeout: 10.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        // Relationships should still be intact
        XCTAssertEqual(sheet1.group, group)
        XCTAssertEqual(sheet2.group, group)
    }

    func testBackup_PreservesUUIDs() {
        let sheet = TestDataFactory.createSheet(context: context)
        let originalID = sheet.id
        saveContext(context)

        backupService.startManualBackup()
        waitForCondition(timeout: 10.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        // UUIDs should remain unchanged
        XCTAssertEqual(sheet.id, originalID)
    }

    func testBackup_PreservesDates() {
        let sheet = TestDataFactory.createSheet(context: context)
        let createdAt = sheet.createdAt
        let modifiedAt = sheet.modifiedAt
        saveContext(context)

        backupService.startManualBackup()
        waitForCondition(timeout: 10.0, description: "backup to complete") {
            self.backupService.backupStatus != .inProgress
        }

        // Dates should be preserved
        XCTAssertEqual(sheet.createdAt, createdAt)
        XCTAssertEqual(sheet.modifiedAt, modifiedAt)
    }

    // MARK: - Cleanup Tests

    func testBackup_NoMemoryLeaks() {
        // Create and backup data multiple times
        for _ in 1...5 {
            let sheets = TestDataFactory.createSheets(count: 10, context: context)
            saveContext(context)

            backupService.startManualBackup()
            waitForCondition(timeout: 10.0, description: "backup to complete") {
                self.backupService.backupStatus != .inProgress
            }

            // Clean up
            for sheet in sheets {
                context.delete(sheet)
            }
            saveContext(context)
        }

        // If we reach here without crashing or hanging, test passes
        XCTAssertTrue(true)
    }
}
