//
//  XCTestCase+Extensions.swift
//  NotisTests
//
//  Created by Claude Code
//

import XCTest
import CoreData
@testable import Notis

extension XCTestCase {

    // MARK: - Async Helpers

    /// Wait for a condition to be true with timeout
    func waitForCondition(
        timeout: TimeInterval = 2.0,
        description: String = "condition",
        condition: () -> Bool
    ) {
        let start = Date()
        while !condition() {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("Timeout waiting for \(description)")
                break
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    /// Wait for async operation to complete
    func waitForAsync(timeout: TimeInterval = 2.0, work: @escaping () -> Void) {
        let expectation = self.expectation(description: "async work")
        DispatchQueue.global().async {
            work()
            expectation.fulfill()
        }
        waitForExpectations(timeout: timeout)
    }

    // MARK: - Core Data Helpers

    /// Create an in-memory persistence controller for testing
    func createTestPersistenceController() -> PersistenceController {
        return PersistenceController(inMemory: true)
    }

    /// Save context and fail test if save fails
    func saveContext(_ context: NSManagedObjectContext, file: StaticString = #file, line: UInt = #line) {
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save context: \(error)", file: file, line: line)
        }
    }

    /// Fetch all objects of a given type
    func fetchAll<T: NSManagedObject>(
        _ type: T.Type,
        in context: NSManagedObjectContext,
        predicate: NSPredicate? = nil
    ) -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        do {
            return try context.fetch(request)
        } catch {
            XCTFail("Failed to fetch \(type): \(error)")
            return []
        }
    }

    /// Count objects of a given type
    func count<T: NSManagedObject>(
        _ type: T.Type,
        in context: NSManagedObjectContext,
        predicate: NSPredicate? = nil
    ) -> Int {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        do {
            return try context.count(for: request)
        } catch {
            XCTFail("Failed to count \(type): \(error)")
            return 0
        }
    }

    // MARK: - File System Helpers

    /// Create a temporary directory for testing
    func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
        } catch {
            XCTFail("Failed to create temp directory: \(error)")
        }
        return tempDir
    }

    /// Clean up temporary directory
    func removeTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Create a test file with content
    func createTestFile(
        at directory: URL,
        name: String,
        content: String
    ) -> URL {
        let fileURL = directory.appendingPathComponent(name)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
        return fileURL
    }

    // MARK: - Assertion Helpers

    /// Assert that a value is not NaN
    func XCTAssertNotNaN(
        _ value: Double,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(value.isNaN, "Value is NaN: \(message)", file: file, line: line)
        XCTAssertFalse(value.isInfinite, "Value is infinite: \(message)", file: file, line: line)
    }

    /// Assert that a CGFloat is not NaN
    func XCTAssertNotNaN(
        _ value: CGFloat,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(value.isNaN, "Value is NaN: \(message)", file: file, line: line)
        XCTAssertFalse(value.isInfinite, "Value is infinite: \(message)", file: file, line: line)
    }

    /// Assert that two arrays contain the same elements (order independent)
    func XCTAssertEqualUnordered<T: Equatable>(
        _ array1: [T],
        _ array2: [T],
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            Set(array1),
            Set(array2),
            "Arrays contain different elements: \(message)",
            file: file,
            line: line
        )
    }
}
