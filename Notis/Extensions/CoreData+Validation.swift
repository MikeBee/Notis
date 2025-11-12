//
//  CoreData+Validation.swift
//  Notis
//
//  Created by Claude Code
//

import Foundation
import CoreData
import CloudKit
#if os(iOS)
import UIKit
#endif

/// Data validation and protection helpers for Core Data operations
extension NSManagedObjectContext {

    // MARK: - Safe Save with Validation

    /// Safely save the context with validation and error handling
    /// - Returns: Boolean indicating success
    func safeSave(operation: String = "save") -> Bool {
        guard hasChanges else { return true }

        // Validate all changed objects before saving
        for object in insertedObjects.union(updatedObjects) {
            do {
                try object.validateForUpdate()
            } catch {
                Logger.shared.error("Validation failed for \(object.entity.name ?? "unknown")",
                                   error: error,
                                   category: .coreData)
                return false
            }
        }

        // Attempt save
        do {
            try save()
            Logger.shared.debug("Successfully saved context for: \(operation)", category: .coreData)
            return true
        } catch {
            Logger.shared.error("Failed to save context for: \(operation)",
                               error: error,
                               category: .coreData,
                               userMessage: "Could not save changes")
            return false
        }
    }

    /// Perform operation with automatic rollback on failure
    func safePerform<T>(operation: String, block: () throws -> T) -> T? {
        do {
            let result = try block()
            if safeSave(operation: operation) {
                return result
            } else {
                rollback()
                return nil
            }
        } catch {
            Logger.shared.error("Operation '\(operation)' failed",
                               error: error,
                               category: .coreData)
            rollback()
            return nil
        }
    }
}

// MARK: - Entity Validation Extensions

extension Sheet {

    /// Validate sheet before save
    override public func validateForUpdate() throws {
        try super.validateForUpdate()

        // Validate UUID exists
        guard id != nil else {
            throw ValidationError.missingID
        }

        // Validate title is not empty (or set default)
        if title == nil || title?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            title = "Untitled"
        }

        // Validate dates
        guard let created = createdAt, let modified = modifiedAt else {
            throw ValidationError.missingDates
        }

        // Modified date should not be before created date
        if modified < created {
            throw ValidationError.invalidDates
        }

        // Validate word count is non-negative
        if wordCount < 0 {
            wordCount = 0
        }

        // Validate goal count is non-negative
        if goalCount < 0 {
            goalCount = 0
        }
    }
}

extension Group {

    /// Validate group before save
    override public func validateForUpdate() throws {
        try super.validateForUpdate()

        // Validate UUID exists
        guard id != nil else {
            throw ValidationError.missingID
        }

        // Validate name is not empty
        if name == nil || name?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            name = "Untitled Group"
        }

        // Validate no circular parent references
        var currentParent = parent
        var visitedGroups = Set<NSManagedObjectID>()
        visitedGroups.insert(objectID)

        while let parentGroup = currentParent {
            // Check if we've seen this group before (circular reference)
            if visitedGroups.contains(parentGroup.objectID) {
                throw ValidationError.circularReference
            }

            visitedGroups.insert(parentGroup.objectID)
            currentParent = parentGroup.parent
        }

        // Validate dates
        guard createdAt != nil, modifiedAt != nil else {
            throw ValidationError.missingDates
        }
    }
}

extension Template {

    /// Validate template before save
    override public func validateForUpdate() throws {
        try super.validateForUpdate()

        // Validate UUID exists
        guard id != nil else {
            throw ValidationError.missingID
        }

        // Validate name is not empty
        if name == nil || name?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            name = "Untitled Template"
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case missingID
    case missingDates
    case invalidDates
    case circularReference
    case duplicateSortOrder
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .missingID:
            return "Entity is missing required ID"
        case .missingDates:
            return "Entity is missing required dates"
        case .invalidDates:
            return "Modified date cannot be before created date"
        case .circularReference:
            return "Circular reference detected in group hierarchy"
        case .duplicateSortOrder:
            return "Duplicate sort order detected"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}

// MARK: - Data Integrity Helpers

extension NSManagedObjectContext {

    /// Fix duplicate sort orders in groups
    func fixDuplicateSortOrders() -> Int {
        var fixedCount = 0

        // Fix root groups
        let rootRequest: NSFetchRequest<Group> = Group.fetchRequest()
        rootRequest.predicate = NSPredicate(format: "parent == nil")
        rootRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Group.sortOrder, ascending: true),
                                        NSSortDescriptor(keyPath: \Group.createdAt, ascending: true)]

        if let rootGroups = try? fetch(rootRequest) {
            var sortOrderMap: [Int32: [Group]] = [:]

            // Find duplicates
            for group in rootGroups {
                sortOrderMap[group.sortOrder, default: []].append(group)
            }

            // Fix groups with duplicate sort orders
            for groups in sortOrderMap.values where groups.count > 1 {
                Logger.shared.warning("Found \(groups.count) root groups with duplicate sort order", category: .coreData)
                // Reassign sort orders based on creation date
                for (index, group) in groups.enumerated() {
                    let newSortOrder = (sortOrderMap.keys.max() ?? 0) + Int32(index) + 1
                    group.sortOrder = newSortOrder
                    fixedCount += 1
                }
            }
        }

        // Fix subgroups for each parent
        let allGroupsRequest: NSFetchRequest<Group> = Group.fetchRequest()
        if let allGroups = try? fetch(allGroupsRequest) {
            let groupsWithChildren = allGroups.filter { ($0.subgroups?.count ?? 0) > 0 }

            for parentGroup in groupsWithChildren {
                guard let subgroups = parentGroup.subgroups?.allObjects as? [Group] else { continue }

                let sortedSubgroups = subgroups.sorted { g1, g2 in
                    if g1.sortOrder == g2.sortOrder {
                        return (g1.createdAt ?? Date()) < (g2.createdAt ?? Date())
                    }
                    return g1.sortOrder < g2.sortOrder
                }

                var sortOrderMap: [Int32: [Group]] = [:]
                for group in sortedSubgroups {
                    sortOrderMap[group.sortOrder, default: []].append(group)
                }

                for groups in sortOrderMap.values where groups.count > 1 {
                    Logger.shared.warning("Found \(groups.count) subgroups with duplicate sort order in parent '\(parentGroup.name ?? "Untitled")'", category: .coreData)
                    for (index, group) in groups.enumerated() {
                        let newSortOrder = (sortOrderMap.keys.max() ?? 0) + Int32(index) + 1
                        group.sortOrder = newSortOrder
                        fixedCount += 1
                    }
                }
            }
        }

        if fixedCount > 0 {
            Logger.shared.info("Fixed \(fixedCount) duplicate sort orders", category: .coreData)
            _ = safeSave(operation: "fix duplicate sort orders")
        }

        return fixedCount
    }

    /// Ensure unique sort order for a group within its parent or root level
    func ensureUniqueSortOrder(for group: Group) {
        let siblings: [Group]

        if let parent = group.parent {
            siblings = (parent.subgroups?.allObjects as? [Group]) ?? []
        } else {
            // Root level groups
            let request: NSFetchRequest<Group> = Group.fetchRequest()
            request.predicate = NSPredicate(format: "parent == nil AND self != %@", group)
            siblings = (try? fetch(request)) ?? []
        }

        let usedSortOrders = Set(siblings.map { $0.sortOrder })

        // If current sort order is already in use, find next available
        if usedSortOrders.contains(group.sortOrder) {
            var newSortOrder = group.sortOrder
            while usedSortOrders.contains(newSortOrder) {
                newSortOrder += 1
            }
            group.sortOrder = newSortOrder
            Logger.shared.debug("Adjusted sort order to \(newSortOrder) to avoid duplicate", category: .coreData)
        }
    }
}

// MARK: - Safety Backup Before Destructive Operations

extension BackupService {

    /// Create a safety backup before performing a destructive operation
    /// - Parameter operation: Description of the destructive operation
    /// - Returns: Boolean indicating if backup succeeded
    @MainActor
    func createSafetyBackup(for operation: String) async -> Bool {
        Logger.shared.info("Creating safety backup before: \(operation)", category: .backup)

        guard !isBackingUp else {
            Logger.shared.warning("Backup already in progress, skipping safety backup", category: .backup)
            return false
        }

        do {
            // Create backup data
            let backupData = try await prepareBackupData()

            // Upload as a manual daily backup with special naming
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(backupData)

            let recordID = CKRecord.ID(recordName: "safety_\(Date().timeIntervalSince1970)_\(UUID().uuidString)")
            let record = CKRecord(recordType: "NotisBackup_daily", recordID: recordID)

            record["backupData"] = jsonData
            record["createdAt"] = backupData.createdAt
            record["version"] = backupData.version
            record["isManual"] = true
            record["isSafetyBackup"] = true
            record["operation"] = operation
            #if os(iOS)
            record["deviceIdentifier"] = await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            #else
            record["deviceIdentifier"] = ProcessInfo.processInfo.hostName
            #endif

            let database = cloudKitContainer.privateCloudDatabase
            _ = try await database.save(record)

            Logger.shared.info("Safety backup created successfully for: \(operation)", category: .backup)
            return true
        } catch {
            Logger.shared.error("Failed to create safety backup",
                               error: error,
                               category: .backup)
            return false
        }
    }
}
