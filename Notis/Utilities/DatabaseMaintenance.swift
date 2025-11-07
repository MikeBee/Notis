//
//  DatabaseMaintenance.swift
//  Notis
//
//  Created by Claude on 11/3/25.
//

import CoreData
import Foundation
import CloudKit

// MARK: - Data Models for Maintenance Results

struct MaintenanceIssue {
    let id = UUID()
    let type: IssueType
    let severity: Severity
    let description: String
    let affectedEntity: String?
    let affectedID: UUID?
    let canAutoFix: Bool
    let detected: Date = Date()
    let affectedEntityTitle: String?
    let affectedEntityCreatedAt: Date?
    let affectedEntityModifiedAt: Date?
    
    enum IssueType: String, CaseIterable {
        case orphanedRecord = "Orphaned Record"
        case missingID = "Missing ID"
        case invalidRelationship = "Invalid Relationship"
        case invalidDate = "Invalid Date"
        case duplicate = "Duplicate Record"
        case inconsistentData = "Inconsistent Data"
        case syncConflict = "Sync Conflict"
        case corruptedData = "Corrupted Data"
        case tagIssue = "Tag Data Issue"
    }
    
    enum Severity: String, CaseIterable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case info = "Info"
        
        var color: String {
            switch self {
            case .critical: return "red"
            case .high: return "orange"
            case .medium: return "yellow"
            case .low: return "blue"
            case .info: return "gray"
            }
        }
    }
    
    // Standard initializer for general issues
    init(type: IssueType, severity: Severity, description: String,
         affectedEntity: String?, affectedID: UUID?, canAutoFix: Bool) {
        self.type = type
        self.severity = severity
        self.description = description
        self.affectedEntity = affectedEntity
        self.affectedID = affectedID
        self.canAutoFix = canAutoFix
        self.affectedEntityTitle = nil
        self.affectedEntityCreatedAt = nil
        self.affectedEntityModifiedAt = nil
    }
    
    // Convenience initializer for issues with Core Data entities
    init(type: IssueType, severity: Severity, description: String, 
         affectedEntity: String?, affectedID: UUID?, canAutoFix: Bool,
         sheet: Sheet? = nil, group: Group? = nil, tag: Tag? = nil) {
        self.type = type
        self.severity = severity
        self.description = description
        self.affectedEntity = affectedEntity
        self.affectedID = affectedID
        self.canAutoFix = canAutoFix
        
        if let sheet = sheet {
            self.affectedEntityTitle = sheet.title
            self.affectedEntityCreatedAt = sheet.createdAt
            self.affectedEntityModifiedAt = sheet.modifiedAt
        } else if let group = group {
            self.affectedEntityTitle = group.name
            self.affectedEntityCreatedAt = group.createdAt
            self.affectedEntityModifiedAt = group.modifiedAt
        } else if let tag = tag {
            self.affectedEntityTitle = tag.displayName
            self.affectedEntityCreatedAt = tag.createdAt
            self.affectedEntityModifiedAt = tag.modifiedAt
        } else {
            self.affectedEntityTitle = nil
            self.affectedEntityCreatedAt = nil
            self.affectedEntityModifiedAt = nil
        }
    }
}

struct MaintenanceReport {
    let id = UUID()
    let timestamp = Date()
    let issues: [MaintenanceIssue]
    let fixedIssues: [MaintenanceIssue]
    let duration: TimeInterval
    let totalEntitiesScanned: Int
    
    var criticalIssues: [MaintenanceIssue] {
        issues.filter { $0.severity == .critical }
    }
    
    var autoFixableIssues: [MaintenanceIssue] {
        issues.filter { $0.canAutoFix }
    }
    
    var isHealthy: Bool {
        criticalIssues.isEmpty && issues.count < 5
    }
}

// MARK: - Main Database Maintenance Class

@MainActor
class DatabaseMaintenance: ObservableObject {
    private let context: NSManagedObjectContext
    @Published var isRunning = false
    @Published var currentOperation = ""
    @Published var progress = 0.0
    @Published var lastReport: MaintenanceReport?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Public Interface
    
    func runFullMaintenance(autoFix: Bool = false) async -> MaintenanceReport {
        let startTime = Date()
        isRunning = true
        currentOperation = "Starting maintenance scan..."
        progress = 0.0
        
        var allIssues: [MaintenanceIssue] = []
        var fixedIssues: [MaintenanceIssue] = []
        var totalScanned = 0
        
        // Stage 1: Data Integrity Validation
        currentOperation = "Validating data integrity..."
        progress = 0.1
        let integrityIssues = await validateDataIntegrity()
        allIssues.append(contentsOf: integrityIssues)
        totalScanned += await getTotalEntityCount()
        
        // Stage 2: Duplicate Detection
        currentOperation = "Detecting duplicates..."
        progress = 0.3
        let duplicateIssues = await detectDuplicates()
        allIssues.append(contentsOf: duplicateIssues)
        
        // Stage 3: Data Consistency Checks
        currentOperation = "Checking data consistency..."
        progress = 0.5
        let consistencyIssues = await validateDataConsistency()
        allIssues.append(contentsOf: consistencyIssues)
        
        // Stage 4: CloudKit Sync Health
        currentOperation = "Checking CloudKit sync health..."
        progress = 0.7
        let syncIssues = await validateCloudKitSync()
        allIssues.append(contentsOf: syncIssues)
        
        // Stage 5: Migration & Repair Validation
        currentOperation = "Checking migration and repair needs..."
        progress = 0.75
        let migrationIssues = await validateMigrationAndRepair()
        allIssues.append(contentsOf: migrationIssues)
        
        // Auto-fix if requested
        if autoFix {
            currentOperation = "Auto-fixing issues..."
            progress = 0.8
            fixedIssues = await autoFixIssues(allIssues)
            allIssues.removeAll { issue in
                fixedIssues.contains { $0.id == issue.id }
            }
        }
        
        progress = 1.0
        currentOperation = "Maintenance complete"
        
        let report = MaintenanceReport(
            issues: allIssues,
            fixedIssues: fixedIssues,
            duration: Date().timeIntervalSince(startTime),
            totalEntitiesScanned: totalScanned
        )
        
        lastReport = report
        isRunning = false
        
        return report
    }
    
    func quickHealthCheck() async -> MaintenanceReport {
        let startTime = Date()
        currentOperation = "Quick health check..."
        progress = 0.0
        
        var issues: [MaintenanceIssue] = []
        
        // Quick checks only - most critical issues
        issues.append(contentsOf: await findOrphanedRecords())
        issues.append(contentsOf: await findMissingIDs())
        
        let report = MaintenanceReport(
            issues: issues,
            fixedIssues: [],
            duration: Date().timeIntervalSince(startTime),
            totalEntitiesScanned: await getTotalEntityCount()
        )
        
        progress = 1.0
        currentOperation = "Health check complete"
        lastReport = report
        
        return report
    }
    
    func fixSingleIssue(_ issue: MaintenanceIssue) async -> Bool {
        return await attemptAutoFix(issue)
    }
}

// MARK: - Stage 1: Data Integrity Validators

extension DatabaseMaintenance {
    
    private func validateDataIntegrity() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        issues.append(contentsOf: await findOrphanedRecords())
        issues.append(contentsOf: await findMissingIDs())
        issues.append(contentsOf: await validateRelationships())
        issues.append(contentsOf: await validateDates())
        issues.append(contentsOf: await validateCoreDataIntegrity())
        
        return issues
    }
    
    private func findOrphanedRecords() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            // Find sheets without groups
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            sheetRequest.predicate = NSPredicate(format: "group == nil AND isInTrash == NO")
            let orphanedSheets = try context.fetch(sheetRequest)
            
            for sheet in orphanedSheets {
                issues.append(MaintenanceIssue(
                    type: .orphanedRecord,
                    severity: .high,
                    description: "Sheet '\(sheet.title ?? "Untitled")' has no group assignment",
                    affectedEntity: "Sheet",
                    affectedID: sheet.id,
                    canAutoFix: true,
                    sheet: sheet
                ))
            }
            
            // Find groups with invalid parent references
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            let allGroups = try context.fetch(groupRequest)
            
            for group in allGroups {
                if let parent = group.parent, parent.isDeleted {
                    issues.append(MaintenanceIssue(
                        type: .orphanedRecord,
                        severity: .medium,
                        description: "Group '\(group.name ?? "Unnamed")' has invalid parent reference",
                        affectedEntity: "Group",
                        affectedID: group.id,
                        canAutoFix: true
                    ))
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to scan for orphaned records: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func findMissingIDs() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            // Check sheets
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            sheetRequest.predicate = NSPredicate(format: "id == nil")
            let sheetsWithoutID = try context.fetch(sheetRequest)
            
            for sheet in sheetsWithoutID {
                issues.append(MaintenanceIssue(
                    type: .missingID,
                    severity: .critical,
                    description: "Sheet '\(sheet.title ?? "Untitled")' missing UUID identifier",
                    affectedEntity: "Sheet",
                    affectedID: nil,
                    canAutoFix: true,
                    sheet: sheet
                ))
            }
            
            // Check groups
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            groupRequest.predicate = NSPredicate(format: "id == nil")
            let groupsWithoutID = try context.fetch(groupRequest)
            
            for group in groupsWithoutID {
                issues.append(MaintenanceIssue(
                    type: .missingID,
                    severity: .critical,
                    description: "Group '\(group.name ?? "Unnamed")' missing UUID identifier",
                    affectedEntity: "Group",
                    affectedID: nil,
                    canAutoFix: true,
                    group: group
                ))
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to scan for missing IDs: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func validateRelationships() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let sheets = try context.fetch(sheetRequest)
            
            for sheet in sheets {
                // Check if sheet's group still exists and is valid
                if let group = sheet.group {
                    if group.isDeleted {
                        issues.append(MaintenanceIssue(
                            type: .invalidRelationship,
                            severity: .high,
                            description: "Sheet '\(sheet.title ?? "Untitled")' references deleted group",
                            affectedEntity: "Sheet",
                            affectedID: sheet.id,
                            canAutoFix: true
                        ))
                    }
                    
                    // Check bidirectional relationship
                    if let groupSheets = group.sheets as? Set<Sheet>, !groupSheets.contains(sheet) {
                        issues.append(MaintenanceIssue(
                            type: .invalidRelationship,
                            severity: .medium,
                            description: "Sheet-Group relationship inconsistency for '\(sheet.title ?? "Untitled")'",
                            affectedEntity: "Sheet",
                            affectedID: sheet.id,
                            canAutoFix: true
                        ))
                    }
                }
            }
            
            // Check group hierarchy
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            let groups = try context.fetch(groupRequest)
            
            for group in groups {
                if let parent = group.parent {
                    if let parentSubgroups = parent.subgroups as? Set<Group>, !parentSubgroups.contains(group) {
                        issues.append(MaintenanceIssue(
                            type: .invalidRelationship,
                            severity: .medium,
                            description: "Group hierarchy inconsistency for '\(group.name ?? "Unnamed")'",
                            affectedEntity: "Group",
                            affectedID: group.id,
                            canAutoFix: true
                        ))
                    }
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to validate relationships: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func validateDates() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        let now = Date()
        let futureThreshold = now.addingTimeInterval(86400) // 24 hours from now
        
        do {
            // Check sheet dates
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let sheets = try context.fetch(sheetRequest)
            
            for sheet in sheets {
                if let createdAt = sheet.createdAt, createdAt > futureThreshold {
                    issues.append(MaintenanceIssue(
                        type: .invalidDate,
                        severity: .medium,
                        description: "Sheet '\(sheet.title ?? "Untitled")' has future creation date",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
                
                if let modifiedAt = sheet.modifiedAt, let createdAt = sheet.createdAt, modifiedAt < createdAt {
                    issues.append(MaintenanceIssue(
                        type: .invalidDate,
                        severity: .low,
                        description: "Sheet '\(sheet.title ?? "Untitled")' modified before creation",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
            }
            
            // Check group dates
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            let groups = try context.fetch(groupRequest)
            
            for group in groups {
                if let createdAt = group.createdAt, createdAt > futureThreshold {
                    issues.append(MaintenanceIssue(
                        type: .invalidDate,
                        severity: .medium,
                        description: "Group '\(group.name ?? "Unnamed")' has future creation date",
                        affectedEntity: "Group",
                        affectedID: group.id,
                        canAutoFix: true
                    ))
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to validate dates: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
}

// MARK: - Helper Methods

extension DatabaseMaintenance {
    
    private func getTotalEntityCount() async -> Int {
        do {
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            let sheetTagRequest: NSFetchRequest<SheetTag> = SheetTag.fetchRequest()
            
            let sheetCount = try context.count(for: sheetRequest)
            let groupCount = try context.count(for: groupRequest)
            let tagCount = try context.count(for: tagRequest)
            let sheetTagCount = try context.count(for: sheetTagRequest)
            
            return sheetCount + groupCount + tagCount + sheetTagCount
        } catch {
            return 0
        }
    }
    
    // Stage 2: Duplicate Detection & Cleanup
    private func detectDuplicates() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        issues.append(contentsOf: await findDuplicateSheets())
        issues.append(contentsOf: await findDuplicateGroups())
        
        return issues
    }
    
    // Stage 3: Data Consistency Validation
    private func validateDataConsistency() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        issues.append(contentsOf: await validateWordCounts())
        issues.append(contentsOf: await validatePreviews())
        issues.append(contentsOf: await validateTrashState())
        issues.append(contentsOf: await validateSortOrders())
        issues.append(contentsOf: await validateGoalSettings())
        issues.append(contentsOf: await validateTagData())
        
        return issues
    }
    
    // Stage 4: CloudKit Sync Health
    private func validateCloudKitSync() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        issues.append(contentsOf: await checkCloudKitAccountStatus())
        issues.append(contentsOf: await detectSyncConflicts())
        issues.append(contentsOf: await findRecordsFailedToSync())
        issues.append(contentsOf: await validateCloudKitRecordIntegrity())
        
        return issues
    }
    
    // Stage 5: Migration & Repair Validation
    private func validateMigrationAndRepair() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        issues.append(contentsOf: await checkDatabaseSchema())
        issues.append(contentsOf: await validateDataIntegrity())
        issues.append(contentsOf: await checkPerformanceIssues())
        issues.append(contentsOf: await validateBackupNeeds())
        
        return issues
    }
    
    private func autoFixIssues(_ issues: [MaintenanceIssue]) async -> [MaintenanceIssue] {
        var fixedIssues: [MaintenanceIssue] = []
        
        for issue in issues where issue.canAutoFix {
            if await attemptAutoFix(issue) {
                fixedIssues.append(issue)
            }
        }
        
        return fixedIssues
    }
    
    private func attemptAutoFix(_ issue: MaintenanceIssue) async -> Bool {
        switch issue.type {
        case .missingID:
            return await fixMissingID(issue)
        case .orphanedRecord:
            return await fixOrphanedRecord(issue)
        case .invalidDate:
            return await fixInvalidDate(issue)
        case .invalidRelationship:
            return await fixInvalidRelationship(issue)
        case .inconsistentData:
            return await fixInconsistentData(issue)
        case .tagIssue:
            return await fixTagIssue(issue)
        case .duplicate:
            return await fixDuplicateTag(issue)
        default:
            return false
        }
    }
    
    private func fixMissingID(_ issue: MaintenanceIssue) async -> Bool {
        do {
            if issue.affectedEntity == "Sheet" {
                let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
                request.predicate = NSPredicate(format: "id == nil")
                request.fetchLimit = 1
                
                if let sheet = try context.fetch(request).first {
                    sheet.id = UUID()
                    try context.save()
                    return true
                }
            } else if issue.affectedEntity == "Group" {
                let request: NSFetchRequest<Group> = Group.fetchRequest()
                request.predicate = NSPredicate(format: "id == nil")
                request.fetchLimit = 1
                
                if let group = try context.fetch(request).first {
                    group.id = UUID()
                    try context.save()
                    return true
                }
            } else if issue.affectedEntity == "Tag" {
                let request: NSFetchRequest<Tag> = Tag.fetchRequest()
                request.predicate = NSPredicate(format: "id == nil")
                request.fetchLimit = 1
                
                if let tag = try context.fetch(request).first {
                    tag.id = UUID()
                    try context.save()
                    return true
                }
            } else if issue.affectedEntity == "SheetTag" {
                let request: NSFetchRequest<SheetTag> = SheetTag.fetchRequest()
                request.predicate = NSPredicate(format: "id == nil")
                request.fetchLimit = 1
                
                if let sheetTag = try context.fetch(request).first {
                    sheetTag.id = UUID()
                    try context.save()
                    return true
                }
            }
        } catch {
            print("Failed to fix missing ID: \(error)")
        }
        return false
    }
    
    private func fixOrphanedRecord(_ issue: MaintenanceIssue) async -> Bool {
        do {
            if issue.affectedEntity == "Sheet", let sheetID = issue.affectedID {
                let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
                sheetRequest.predicate = NSPredicate(format: "id == %@", sheetID as CVarArg)
                
                if let sheet = try context.fetch(sheetRequest).first {
                    // Find or create an "Inbox" group for orphaned sheets
                    let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
                    groupRequest.predicate = NSPredicate(format: "name == %@ AND parent == nil", "Inbox")
                    
                    let inboxGroup: Group
                    if let existingInbox = try context.fetch(groupRequest).first {
                        inboxGroup = existingInbox
                    } else {
                        inboxGroup = Group(context: context)
                        inboxGroup.id = UUID()
                        inboxGroup.name = "Inbox"
                        inboxGroup.createdAt = Date()
                        inboxGroup.modifiedAt = Date()
                        inboxGroup.sortOrder = 0
                    }
                    
                    sheet.group = inboxGroup
                    try context.save()
                    return true
                }
            }
        } catch {
            print("Failed to fix orphaned record: \(error)")
        }
        return false
    }
    
    private func fixInvalidDate(_ issue: MaintenanceIssue) async -> Bool {
        do {
            let now = Date()
            
            if issue.affectedEntity == "Sheet", let sheetID = issue.affectedID {
                let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", sheetID as CVarArg)
                
                if let sheet = try context.fetch(request).first {
                    if let createdAt = sheet.createdAt, createdAt > now {
                        sheet.createdAt = now
                    }
                    if let modifiedAt = sheet.modifiedAt, let createdAt = sheet.createdAt, modifiedAt < createdAt {
                        sheet.modifiedAt = createdAt
                    }
                    try context.save()
                    return true
                }
            }
        } catch {
            print("Failed to fix invalid date: \(error)")
        }
        return false
    }
    
    private func fixInvalidRelationship(_ issue: MaintenanceIssue) async -> Bool {
        // Complex relationship fixes would be implemented here
        // For now, return false to avoid potential data corruption
        return false
    }
    
    private func fixInconsistentData(_ issue: MaintenanceIssue) async -> Bool {
        do {
            if issue.description.contains("Duplicate sort orders") {
                return await fixDuplicateSortOrders(issue)
            } else if issue.description.contains("Word count mismatch") {
                return await fixWordCountMismatch(issue)
            } else if issue.description.contains("Preview mismatch") {
                return await fixPreviewMismatch(issue)
            } else if issue.description.contains("trash state") {
                return await fixTrashState(issue)
            }
        } catch {
            print("Failed to fix inconsistent data: \(error)")
        }
        return false
    }
    
    private func fixDuplicateSortOrders(_ issue: MaintenanceIssue) async -> Bool {
        do {
            if let groupID = issue.affectedID {
                let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
                groupRequest.predicate = NSPredicate(format: "id == %@", groupID as CVarArg)
                
                if let group = try context.fetch(groupRequest).first {
                    // Get all sheets in this group
                    if let sheets = group.sheets?.allObjects as? [Sheet] {
                        let nonTrashedSheets = sheets.filter { !$0.isInTrash }
                        
                        // Reassign sort orders sequentially
                        for (index, sheet) in nonTrashedSheets.enumerated() {
                            sheet.sortOrder = Int32(index)
                        }
                        
                        try context.save()
                        return true
                    }
                }
            } else {
                // Fix root level groups
                let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
                groupRequest.predicate = NSPredicate(format: "parent == nil")
                let rootGroups = try context.fetch(groupRequest)
                
                for (index, group) in rootGroups.enumerated() {
                    group.sortOrder = Int32(index)
                }
                
                try context.save()
                return true
            }
        } catch {
            print("Failed to fix duplicate sort orders: \(error)")
        }
        return false
    }
    
    private func fixWordCountMismatch(_ issue: MaintenanceIssue) async -> Bool {
        do {
            if let sheetID = issue.affectedID {
                let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", sheetID as CVarArg)
                
                if let sheet = try context.fetch(request).first {
                    let actualWordCount = calculateWordCount(sheet.content ?? "")
                    sheet.wordCount = Int32(actualWordCount)
                    try context.save()
                    return true
                }
            }
        } catch {
            print("Failed to fix word count: \(error)")
        }
        return false
    }
    
    private func fixPreviewMismatch(_ issue: MaintenanceIssue) async -> Bool {
        do {
            if let sheetID = issue.affectedID {
                let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", sheetID as CVarArg)
                
                if let sheet = try context.fetch(request).first {
                    let content = sheet.content ?? ""
                    sheet.preview = String(content.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
                    try context.save()
                    return true
                }
            }
        } catch {
            print("Failed to fix preview: \(error)")
        }
        return false
    }
    
    private func fixTrashState(_ issue: MaintenanceIssue) async -> Bool {
        do {
            if let sheetID = issue.affectedID {
                let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", sheetID as CVarArg)
                
                if let sheet = try context.fetch(request).first {
                    if sheet.isInTrash && sheet.deletedAt == nil {
                        sheet.deletedAt = Date()
                    } else if !sheet.isInTrash && sheet.deletedAt != nil {
                        sheet.deletedAt = nil
                    }
                    try context.save()
                    return true
                }
            }
        } catch {
            print("Failed to fix trash state: \(error)")
        }
        return false
    }
    
    private func fixTagIssue(_ issue: MaintenanceIssue) async -> Bool {
        do {
            if let tagID = issue.affectedID {
                let request: NSFetchRequest<Tag> = Tag.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", tagID as CVarArg)
                
                if let tag = try context.fetch(request).first {
                    if issue.description.contains("usage count mismatch") {
                        // Fix usage count
                        let actualUsageCount = tag.sheetTags?.count ?? 0
                        tag.usageCount = Int32(actualUsageCount)
                        try context.save()
                        return true
                    } else if issue.description.contains("incorrect path") {
                        // Fix tag path
                        tag.path = generateTagPath(for: tag)
                        try context.save()
                        return true
                    }
                }
            }
        } catch {
            print("Failed to fix tag issue: \(error)")
        }
        return false
    }
    
    private func fixDuplicateTag(_ issue: MaintenanceIssue) async -> Bool {
        do {
            if issue.affectedEntity == "Tag", let tagID = issue.affectedID {
                let request: NSFetchRequest<Tag> = Tag.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", tagID as CVarArg)
                
                if let duplicateTag = try context.fetch(request).first {
                    // Rename the duplicate tag by appending a number
                    let baseName = duplicateTag.name ?? "Tag"
                    var counter = 2
                    var newName = "\(baseName) \(counter)"
                    
                    // Find a unique name
                    while await tagNameExists(newName, parent: duplicateTag.parent) {
                        counter += 1
                        newName = "\(baseName) \(counter)"
                    }
                    
                    duplicateTag.name = newName
                    duplicateTag.path = generateTagPath(for: duplicateTag)
                    duplicateTag.modifiedAt = Date()
                    
                    try context.save()
                    return true
                }
            }
        } catch {
            print("Failed to fix duplicate tag: \(error)")
        }
        return false
    }
    
    private func tagNameExists(_ name: String, parent: Tag?) async -> Bool {
        do {
            let request: NSFetchRequest<Tag> = Tag.fetchRequest()
            
            if let parent = parent {
                request.predicate = NSPredicate(format: "name == %@ AND parent == %@", name, parent)
            } else {
                request.predicate = NSPredicate(format: "name == %@ AND parent == nil", name)
            }
            
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }
}

// MARK: - Stage 2: Duplicate Detection & Cleanup

extension DatabaseMaintenance {
    
    private func findDuplicateSheets() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            sheetRequest.predicate = NSPredicate(format: "isInTrash == NO")
            let sheets = try context.fetch(sheetRequest)
            
            // Group sheets by potential duplicate criteria
            let duplicateGroups = Dictionary(grouping: sheets) { sheet in
                DuplicateKey(
                    title: sheet.title?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "",
                    contentHash: sheet.content?.hash ?? 0,
                    groupID: sheet.group?.id
                )
            }.filter { $0.value.count > 1 }
            
            for (key, duplicateSheets) in duplicateGroups {
                // Exact content duplicates (highest severity)
                let exactContentDuplicates = duplicateSheets.filter { 
                    $0.content?.trimmingCharacters(in: .whitespacesAndNewlines) == 
                    duplicateSheets.first?.content?.trimmingCharacters(in: .whitespacesAndNewlines) 
                }
                
                if exactContentDuplicates.count > 1 {
                    for (index, sheet) in exactContentDuplicates.dropFirst().enumerated() {
                        issues.append(MaintenanceIssue(
                            type: .duplicate,
                            severity: .high,
                            description: "Duplicate sheet with identical content: '\(sheet.title ?? "Untitled")' (duplicate \(index + 1) of \(exactContentDuplicates.count))",
                            affectedEntity: "Sheet",
                            affectedID: sheet.id,
                            canAutoFix: true
                        ))
                    }
                    continue
                }
                
                // Similar title duplicates (medium severity)
                let sameTitleDuplicates = duplicateSheets.filter { 
                    $0.title?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key.title
                }
                
                if sameTitleDuplicates.count > 1 {
                    // Check if content is similar (using simple similarity heuristic)
                    for sheet in sameTitleDuplicates.dropFirst() {
                        let similarity = calculateContentSimilarity(
                            sameTitleDuplicates.first?.content ?? "",
                            sheet.content ?? ""
                        )
                        
                        if similarity > 0.8 { // 80% similar
                            issues.append(MaintenanceIssue(
                                type: .duplicate,
                                severity: .medium,
                                description: "Potential duplicate sheet with similar title and content: '\(sheet.title ?? "Untitled")' (\(Int(similarity * 100))% similar)",
                                affectedEntity: "Sheet",
                                affectedID: sheet.id,
                                canAutoFix: false
                            ))
                        } else {
                            issues.append(MaintenanceIssue(
                                type: .duplicate,
                                severity: .low,
                                description: "Sheet with duplicate title: '\(sheet.title ?? "Untitled")'",
                                affectedEntity: "Sheet",
                                affectedID: sheet.id,
                                canAutoFix: false
                            ))
                        }
                    }
                }
            }
            
            // Check for sheets created very close in time with similar content
            let recentDuplicates = findRecentlyCreatedDuplicates(sheets)
            issues.append(contentsOf: recentDuplicates)
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to scan for duplicate sheets: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func findDuplicateGroups() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            let groups = try context.fetch(groupRequest)
            
            // Group by parent and name
            let duplicateGroups = Dictionary(grouping: groups) { group in
                GroupDuplicateKey(
                    name: group.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "",
                    parentID: group.parent?.id
                )
            }.filter { $0.value.count > 1 }
            
            for (key, duplicateGroups) in duplicateGroups {
                for (index, group) in duplicateGroups.dropFirst().enumerated() {
                    let parentDescription = key.parentID != nil ? " under same parent" : " at root level"
                    issues.append(MaintenanceIssue(
                        type: .duplicate,
                        severity: .medium,
                        description: "Duplicate group name: '\(group.name ?? "Unnamed")'\(parentDescription) (duplicate \(index + 1) of \(duplicateGroups.count))",
                        affectedEntity: "Group",
                        affectedID: group.id,
                        canAutoFix: true
                    ))
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to scan for duplicate groups: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func findRecentlyCreatedDuplicates(_ sheets: [Sheet]) -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        let timeThreshold: TimeInterval = 300 // 5 minutes
        
        // Sort sheets by creation date
        let sortedSheets = sheets.sorted { 
            ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) 
        }
        
        for i in 0..<sortedSheets.count {
            for j in (i+1)..<sortedSheets.count {
                let sheet1 = sortedSheets[i]
                let sheet2 = sortedSheets[j]
                
                guard let date1 = sheet1.createdAt, let date2 = sheet2.createdAt else { continue }
                
                // If sheets are too far apart in time, skip
                if abs(date2.timeIntervalSince(date1)) > timeThreshold { break }
                
                let similarity = calculateContentSimilarity(
                    sheet1.content ?? "",
                    sheet2.content ?? ""
                )
                
                if similarity > 0.9 { // 90% similar and created within 5 minutes
                    issues.append(MaintenanceIssue(
                        type: .duplicate,
                        severity: .high,
                        description: "Potential accidental duplicate: '\(sheet2.title ?? "Untitled")' created \(Int(abs(date2.timeIntervalSince(date1))))s after similar sheet",
                        affectedEntity: "Sheet",
                        affectedID: sheet2.id,
                        canAutoFix: false
                    ))
                }
            }
        }
        
        return issues
    }
    
    private func calculateContentSimilarity(_ content1: String, _ content2: String) -> Double {
        let text1 = content1.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let text2 = content2.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Simple similarity calculation using Jaccard similarity
        let words1 = Set(text1.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let words2 = Set(text2.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        
        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }
}

// MARK: - Helper Structures for Duplicate Detection

private struct DuplicateKey: Hashable {
    let title: String
    let contentHash: Int
    let groupID: UUID?
}

private struct GroupDuplicateKey: Hashable {
    let name: String
    let parentID: UUID?
}

// MARK: - Stage 3: Data Consistency Validation

extension DatabaseMaintenance {
    
    private func validateWordCounts() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let sheets = try context.fetch(sheetRequest)
            
            for sheet in sheets {
                let actualWordCount = calculateWordCount(sheet.content ?? "")
                let storedWordCount = Int(sheet.wordCount)
                
                if actualWordCount != storedWordCount {
                    let difference = abs(actualWordCount - storedWordCount)
                    let severity: MaintenanceIssue.Severity = difference > 10 ? .medium : .low
                    
                    issues.append(MaintenanceIssue(
                        type: .inconsistentData,
                        severity: severity,
                        description: "Word count mismatch for '\(sheet.title ?? "Untitled")': stored \(storedWordCount), actual \(actualWordCount)",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to validate word counts: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func validatePreviews() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let sheets = try context.fetch(sheetRequest)
            
            for sheet in sheets {
                let content = sheet.content ?? ""
                let storedPreview = sheet.preview ?? ""
                let expectedPreview = String(content.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if storedPreview != expectedPreview {
                    issues.append(MaintenanceIssue(
                        type: .inconsistentData,
                        severity: .low,
                        description: "Preview mismatch for '\(sheet.title ?? "Untitled")': preview doesn't match content",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
                
                // Check for empty content but non-empty preview
                if content.isEmpty && !storedPreview.isEmpty {
                    issues.append(MaintenanceIssue(
                        type: .inconsistentData,
                        severity: .medium,
                        description: "Invalid preview for empty sheet '\(sheet.title ?? "Untitled")'",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to validate previews: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func validateTrashState() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let sheets = try context.fetch(sheetRequest)
            
            for sheet in sheets {
                // Check if trash state matches deleted date
                if sheet.isInTrash && sheet.deletedAt == nil {
                    issues.append(MaintenanceIssue(
                        type: .inconsistentData,
                        severity: .medium,
                        description: "Sheet '\(sheet.title ?? "Untitled")' marked as trashed but has no deletion date",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
                
                if !sheet.isInTrash && sheet.deletedAt != nil {
                    issues.append(MaintenanceIssue(
                        type: .inconsistentData,
                        severity: .medium,
                        description: "Sheet '\(sheet.title ?? "Untitled")' has deletion date but not marked as trashed",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
                
                // Check for very old trashed items
                if sheet.isInTrash, let deletedAt = sheet.deletedAt {
                    let daysSinceDeleted = Date().timeIntervalSince(deletedAt) / 86400
                    if daysSinceDeleted > 30 { // Older than 30 days
                        issues.append(MaintenanceIssue(
                            type: .inconsistentData,
                            severity: .info,
                            description: "Sheet '\(sheet.title ?? "Untitled")' has been in trash for \(Int(daysSinceDeleted)) days",
                            affectedEntity: "Sheet",
                            affectedID: sheet.id,
                            canAutoFix: false
                        ))
                    }
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to validate trash state: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func validateSortOrders() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            // Validate sheet sort orders within groups
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            let groups = try context.fetch(groupRequest)
            
            for group in groups {
                if let sheets = group.sheets?.allObjects as? [Sheet] {
                    let nonTrashedSheets = sheets.filter { !$0.isInTrash }
                    let sortOrders = nonTrashedSheets.map { Int($0.sortOrder) }.sorted()
                    
                    // Check for duplicate sort orders
                    let uniqueSortOrders = Set(sortOrders)
                    if sortOrders.count != uniqueSortOrders.count {
                        issues.append(MaintenanceIssue(
                            type: .inconsistentData,
                            severity: .low,
                            description: "Duplicate sort orders in group '\(group.name ?? "Unnamed")'",
                            affectedEntity: "Group",
                            affectedID: group.id,
                            canAutoFix: true
                        ))
                    }
                    
                    // Check for large gaps in sort orders
                    if sortOrders.count > 1 {
                        for i in 1..<sortOrders.count {
                            let gap = sortOrders[i] - sortOrders[i-1]
                            if gap > 100 { // Arbitrary threshold for "large gap"
                                issues.append(MaintenanceIssue(
                                    type: .inconsistentData,
                                    severity: .info,
                                    description: "Large gap in sort orders in group '\(group.name ?? "Unnamed")' (gap: \(gap))",
                                    affectedEntity: "Group",
                                    affectedID: group.id,
                                    canAutoFix: true
                                ))
                                break
                            }
                        }
                    }
                }
            }
            
            // Validate group sort orders at each level
            let rootGroups = groups.filter { $0.parent == nil }
            validateGroupSortOrders(rootGroups, parentName: "root level", issues: &issues)
            
            for group in groups {
                if let subgroups = group.subgroups?.allObjects as? [Group] {
                    validateGroupSortOrders(subgroups, parentName: group.name ?? "Unnamed", issues: &issues)
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to validate sort orders: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func validateGroupSortOrders(_ groups: [Group], parentName: String, issues: inout [MaintenanceIssue]) {
        let sortOrders = groups.map { Int($0.sortOrder) }.sorted()
        let uniqueSortOrders = Set(sortOrders)
        
        if sortOrders.count != uniqueSortOrders.count {
            issues.append(MaintenanceIssue(
                type: .inconsistentData,
                severity: .low,
                description: "Duplicate sort orders in groups under '\(parentName)'",
                affectedEntity: "Group",
                affectedID: nil,
                canAutoFix: true
            ))
        }
    }
    
    private func validateGoalSettings() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let sheets = try context.fetch(sheetRequest)
            
            for sheet in sheets {
                // Check for invalid goal counts
                if sheet.goalCount < 0 {
                    issues.append(MaintenanceIssue(
                        type: .inconsistentData,
                        severity: .medium,
                        description: "Sheet '\(sheet.title ?? "Untitled")' has negative goal count: \(sheet.goalCount)",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
                
                // Check for unrealistic goal counts
                if sheet.goalCount > 100000 { // 100k words/characters seems excessive
                    issues.append(MaintenanceIssue(
                        type: .inconsistentData,
                        severity: .low,
                        description: "Sheet '\(sheet.title ?? "Untitled")' has unusually high goal count: \(sheet.goalCount)",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: false
                    ))
                }
                
                // Check for invalid goal types
                let validGoalTypes = ["words", "characters"]
                if let goalType = sheet.goalType, !validGoalTypes.contains(goalType) {
                    issues.append(MaintenanceIssue(
                        type: .inconsistentData,
                        severity: .medium,
                        description: "Sheet '\(sheet.title ?? "Untitled")' has invalid goal type: '\(goalType)'",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
                
                // Check goal progress consistency
                if sheet.goalCount > 0 {
                    let currentCount = sheet.goalType == "words" ? Int(sheet.wordCount) : (sheet.content?.count ?? 0)
                    if currentCount > sheet.goalCount * 3 { // More than 3x the goal seems suspicious
                        issues.append(MaintenanceIssue(
                            type: .inconsistentData,
                            severity: .info,
                            description: "Sheet '\(sheet.title ?? "Untitled")' significantly exceeds goal (\(currentCount)/\(sheet.goalCount))",
                            affectedEntity: "Sheet",
                            affectedID: sheet.id,
                            canAutoFix: false
                        ))
                    }
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to validate goal settings: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func validateTagData() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            // Check tags
            let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            let tags = try context.fetch(tagRequest)
            
            for tag in tags {
                // Check for missing IDs
                if tag.id == nil {
                    issues.append(MaintenanceIssue(
                        type: .missingID,
                        severity: .critical,
                        description: "Tag '\(tag.displayName)' missing UUID identifier",
                        affectedEntity: "Tag",
                        affectedID: nil,
                        canAutoFix: true,
                        tag: tag
                    ))
                }
                
                // Check for invalid usage counts
                let actualUsageCount = tag.sheetTags?.count ?? 0
                let storedUsageCount = Int(tag.usageCount)
                
                if storedUsageCount != actualUsageCount {
                    issues.append(MaintenanceIssue(
                        type: .tagIssue,
                        severity: storedUsageCount > actualUsageCount ? .medium : .low,
                        description: "Tag '\(tag.displayName)' usage count mismatch: stored \(storedUsageCount), actual \(actualUsageCount)",
                        affectedEntity: "Tag",
                        affectedID: tag.id,
                        canAutoFix: true,
                        tag: tag
                    ))
                }
                
                // Check for orphaned tags with no associations
                if actualUsageCount == 0 && tag.usageCount > 0 {
                    issues.append(MaintenanceIssue(
                        type: .orphanedRecord,
                        severity: .low,
                        description: "Tag '\(tag.displayName)' has usage count but no sheet associations",
                        affectedEntity: "Tag",
                        affectedID: tag.id,
                        canAutoFix: true,
                        tag: tag
                    ))
                }
                
                // Check for invalid parent references
                if let parent = tag.parent, parent.isDeleted {
                    issues.append(MaintenanceIssue(
                        type: .invalidRelationship,
                        severity: .medium,
                        description: "Tag '\(tag.displayName)' has invalid parent reference",
                        affectedEntity: "Tag",
                        affectedID: tag.id,
                        canAutoFix: true,
                        tag: tag
                    ))
                }
                
                // Check for circular tag hierarchies
                if await hasCircularTagHierarchy(tag) {
                    issues.append(MaintenanceIssue(
                        type: .invalidRelationship,
                        severity: .high,
                        description: "Tag '\(tag.displayName)' is part of a circular hierarchy",
                        affectedEntity: "Tag",
                        affectedID: tag.id,
                        canAutoFix: true,
                        tag: tag
                    ))
                }
                
                // Check for invalid path data
                let expectedPath = generateTagPath(for: tag)
                if tag.path != expectedPath {
                    issues.append(MaintenanceIssue(
                        type: .tagIssue,
                        severity: .low,
                        description: "Tag '\(tag.displayName)' has incorrect path: '\(tag.path ?? "nil")' should be '\(expectedPath)'",
                        affectedEntity: "Tag",
                        affectedID: tag.id,
                        canAutoFix: true,
                        tag: tag
                    ))
                }
            }
            
            // Check SheetTag relationships
            let sheetTagRequest: NSFetchRequest<SheetTag> = SheetTag.fetchRequest()
            let sheetTags = try context.fetch(sheetTagRequest)
            
            for sheetTag in sheetTags {
                // Check for missing IDs
                if sheetTag.id == nil {
                    issues.append(MaintenanceIssue(
                        type: .missingID,
                        severity: .critical,
                        description: "SheetTag association missing UUID identifier",
                        affectedEntity: "SheetTag",
                        affectedID: nil,
                        canAutoFix: true
                    ))
                }
                
                // Check for orphaned SheetTag records
                if sheetTag.sheet == nil || sheetTag.tag == nil {
                    issues.append(MaintenanceIssue(
                        type: .orphanedRecord,
                        severity: .high,
                        description: "Orphaned SheetTag association (sheet: \(sheetTag.sheet != nil), tag: \(sheetTag.tag != nil))",
                        affectedEntity: "SheetTag",
                        affectedID: sheetTag.id,
                        canAutoFix: true
                    ))
                }
                
                // Check for references to deleted entities
                if let sheet = sheetTag.sheet, sheet.isDeleted {
                    issues.append(MaintenanceIssue(
                        type: .invalidRelationship,
                        severity: .high,
                        description: "SheetTag references deleted sheet",
                        affectedEntity: "SheetTag",
                        affectedID: sheetTag.id,
                        canAutoFix: true
                    ))
                }
                
                if let tag = sheetTag.tag, tag.isDeleted {
                    issues.append(MaintenanceIssue(
                        type: .invalidRelationship,
                        severity: .high,
                        description: "SheetTag references deleted tag",
                        affectedEntity: "SheetTag",
                        affectedID: sheetTag.id,
                        canAutoFix: true
                    ))
                }
            }
            
            // Check for duplicate tag names at the same hierarchy level
            let tagsByParent = Dictionary(grouping: tags) { $0.parent?.id }
            
            for (parentID, siblingTags) in tagsByParent {
                let nameGroups = Dictionary(grouping: siblingTags) { $0.name?.lowercased() ?? "" }
                
                for (name, duplicateTags) in nameGroups where duplicateTags.count > 1 && !name.isEmpty {
                    let parentDescription = parentID != nil ? " under same parent" : " at root level"
                    
                    for (index, tag) in duplicateTags.dropFirst().enumerated() {
                        issues.append(MaintenanceIssue(
                            type: .duplicate,
                            severity: .medium,
                            description: "Duplicate tag name '\(name)'\(parentDescription) (duplicate \(index + 1) of \(duplicateTags.count))",
                            affectedEntity: "Tag",
                            affectedID: tag.id,
                            canAutoFix: true,
                            tag: tag
                        ))
                    }
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to validate tag data: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func hasCircularTagHierarchy(_ tag: Tag) async -> Bool {
        var visited: Set<UUID> = []
        var current = tag.parent
        
        while let currentTag = current {
            guard let id = currentTag.id else { return false }
            
            if visited.contains(id) {
                return true // Circular reference found
            }
            
            visited.insert(id)
            current = currentTag.parent
        }
        
        return false
    }
    
    private func generateTagPath(for tag: Tag) -> String {
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
    
    private func calculateWordCount(_ content: String) -> Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
}

// MARK: - Stage 4: CloudKit Sync Health Tools

extension DatabaseMaintenance {
    
    private func checkCloudKitAccountStatus() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        let container = CKContainer.default()
        
        do {
            let accountStatus = try await container.accountStatus()
            
            switch accountStatus {
            case .available:
                // Account is available and ready for sync
                break
            case .noAccount:
                issues.append(MaintenanceIssue(
                    type: .syncConflict,
                    severity: .high,
                    description: "No iCloud account configured - CloudKit sync is disabled",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            case .restricted:
                issues.append(MaintenanceIssue(
                    type: .syncConflict,
                    severity: .high,
                    description: "iCloud account is restricted - CloudKit sync may not work properly",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            case .couldNotDetermine:
                issues.append(MaintenanceIssue(
                    type: .syncConflict,
                    severity: .medium,
                    description: "Could not determine iCloud account status - check network connection",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            case .temporarilyUnavailable:
                issues.append(MaintenanceIssue(
                    type: .syncConflict,
                    severity: .medium,
                    description: "iCloud services temporarily unavailable - sync may be delayed",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            @unknown default:
                issues.append(MaintenanceIssue(
                    type: .syncConflict,
                    severity: .medium,
                    description: "Unknown iCloud account status",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .syncConflict,
                severity: .high,
                description: "Failed to check CloudKit account status: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func detectSyncConflicts() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            // Check for records with conflicting modification dates
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let sheets = try context.fetch(sheetRequest)
            
            for sheet in sheets {
                // Look for records that haven't been modified locally but have very recent modification dates
                // This could indicate sync conflicts or issues
                if let modifiedAt = sheet.modifiedAt {
                    let timeSinceModification = Date().timeIntervalSince(modifiedAt)
                    
                    // If modified very recently (within last 10 seconds) but we're in a maintenance scan,
                    // it might indicate rapid sync updates
                    if timeSinceModification < 10 && timeSinceModification > 0 {
                        issues.append(MaintenanceIssue(
                            type: .syncConflict,
                            severity: .info,
                            description: "Sheet '\(sheet.title ?? "Untitled")' was recently modified (\(Int(timeSinceModification))s ago) - possible sync activity",
                            affectedEntity: "Sheet",
                            affectedID: sheet.id,
                            canAutoFix: false
                        ))
                    }
                }
            }
            
            // Check for groups with similar issues
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            let groups = try context.fetch(groupRequest)
            
            for group in groups {
                if let modifiedAt = group.modifiedAt {
                    let timeSinceModification = Date().timeIntervalSince(modifiedAt)
                    
                    if timeSinceModification < 10 && timeSinceModification > 0 {
                        issues.append(MaintenanceIssue(
                            type: .syncConflict,
                            severity: .info,
                            description: "Group '\(group.name ?? "Unnamed")' was recently modified (\(Int(timeSinceModification))s ago) - possible sync activity",
                            affectedEntity: "Group",
                            affectedID: group.id,
                            canAutoFix: false
                        ))
                    }
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to detect sync conflicts: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func findRecordsFailedToSync() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        // Check for records that might have failed to sync by looking at the Core Data context
        // Note: This is a simplified check - in a real implementation, you'd want to track
        // sync status more explicitly
        
        do {
            // Look for records that have been modified but might not have synced
            let cutoffDate = Date().addingTimeInterval(-86400) // 24 hours ago
            
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            sheetRequest.predicate = NSPredicate(format: "modifiedAt > %@", cutoffDate as NSDate)
            let recentlyModifiedSheets = try context.fetch(sheetRequest)
            
            // In a real implementation, you'd check if these records have corresponding CloudKit records
            // For now, we'll flag records that have been modified very frequently as potentially problematic
            let sheetCounts = Dictionary(grouping: recentlyModifiedSheets) { sheet in
                sheet.id?.uuidString ?? "unknown"
            }
            
            for (sheetID, sheets) in sheetCounts {
                if sheets.count > 1 {
                    // This shouldn't happen with proper UUIDs, but could indicate sync issues
                    issues.append(MaintenanceIssue(
                        type: .syncConflict,
                        severity: .high,
                        description: "Multiple records found with same ID - potential sync conflict",
                        affectedEntity: "Sheet",
                        affectedID: UUID(uuidString: sheetID),
                        canAutoFix: false
                    ))
                }
            }
            
            // Check for very old records that might have sync issues
            let oldRecordRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            oldRecordRequest.predicate = NSPredicate(format: "createdAt < %@", Date().addingTimeInterval(-2592000) as NSDate) // 30 days
            let oldSheets = try context.fetch(oldRecordRequest)
            
            for sheet in oldSheets {
                if sheet.modifiedAt == nil {
                    issues.append(MaintenanceIssue(
                        type: .syncConflict,
                        severity: .low,
                        description: "Old sheet '\(sheet.title ?? "Untitled")' has no modification date - may have sync issues",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to check for sync failures: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func validateCloudKitRecordIntegrity() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        // Check Core Data CloudKit integration health
        if let persistentContainer = context.persistentStoreCoordinator?.persistentStores.first {
            let storeType = persistentContainer.type
            
            if storeType != NSSQLiteStoreType {
                issues.append(MaintenanceIssue(
                    type: .syncConflict,
                    severity: .medium,
                    description: "Persistent store is not SQLite type - CloudKit sync may not work properly",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            }
            
            // Check if CloudKit is properly configured
            if persistentContainer.options?[NSPersistentHistoryTrackingKey] as? Bool != true {
                issues.append(MaintenanceIssue(
                    type: .syncConflict,
                    severity: .medium,
                    description: "Persistent history tracking is not enabled - required for CloudKit sync",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            }
        }
        
        // Check for records that might have CloudKit-specific issues
        do {
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let sheets = try context.fetch(sheetRequest)
            
            for sheet in sheets {
                // Check for records with null UUIDs (CloudKit requires unique identifiers)
                if sheet.id == nil {
                    issues.append(MaintenanceIssue(
                        type: .syncConflict,
                        severity: .high,
                        description: "Sheet '\(sheet.title ?? "Untitled")' missing UUID - required for CloudKit sync",
                        affectedEntity: "Sheet",
                        affectedID: nil,
                        canAutoFix: true
                    ))
                }
                
                // Check for very large content that might exceed CloudKit limits
                if let content = sheet.content, content.count > 1048576 { // 1MB limit for CloudKit
                    issues.append(MaintenanceIssue(
                        type: .syncConflict,
                        severity: .high,
                        description: "Sheet '\(sheet.title ?? "Untitled")' content too large for CloudKit sync (\(content.count) bytes)",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: false
                    ))
                }
                
                // Check for invalid characters that might cause CloudKit issues
                if let title = sheet.title, title.contains("\0") {
                    issues.append(MaintenanceIssue(
                        type: .syncConflict,
                        severity: .medium,
                        description: "Sheet title contains null character - may cause CloudKit sync issues",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: true
                    ))
                }
            }
            
            // Check groups for similar issues
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            let groups = try context.fetch(groupRequest)
            
            for group in groups {
                if group.id == nil {
                    issues.append(MaintenanceIssue(
                        type: .syncConflict,
                        severity: .high,
                        description: "Group '\(group.name ?? "Unnamed")' missing UUID - required for CloudKit sync",
                        affectedEntity: "Group",
                        affectedID: nil,
                        canAutoFix: true
                    ))
                }
                
                if let name = group.name, name.contains("\0") {
                    issues.append(MaintenanceIssue(
                        type: .syncConflict,
                        severity: .medium,
                        description: "Group name contains null character - may cause CloudKit sync issues",
                        affectedEntity: "Group",
                        affectedID: group.id,
                        canAutoFix: true
                    ))
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to validate CloudKit record integrity: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
}

// MARK: - Stage 5: Migration & Repair Utilities

extension DatabaseMaintenance {
    
    private func checkDatabaseSchema() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        guard let persistentStoreCoordinator = context.persistentStoreCoordinator else {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "No persistent store coordinator found",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
            return issues
        }
        
        // Check if Core Data model needs migration
        for store in persistentStoreCoordinator.persistentStores {
            do {
                if let storeURL = store.url {
                    // Check if the store is compatible with the current model
                    let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: store.type, at: storeURL, options: nil)
                    
                    let model = persistentStoreCoordinator.managedObjectModel
                    let isCompatible = model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
                    
                    if !isCompatible {
                        issues.append(MaintenanceIssue(
                            type: .corruptedData,
                            severity: .high,
                            description: "Database schema migration required - current model is incompatible with store",
                            affectedEntity: nil,
                            affectedID: nil,
                            canAutoFix: false
                        ))
                    }
                    
                    // Check store file integrity
                    let fileManager = FileManager.default
                    if !fileManager.fileExists(atPath: storeURL.path) {
                        issues.append(MaintenanceIssue(
                            type: .corruptedData,
                            severity: .critical,
                            description: "Database file missing at \(storeURL.path)",
                            affectedEntity: nil,
                            affectedID: nil,
                            canAutoFix: false
                        ))
                    } else {
                        // Check file size and modification date
                        let attributes = try fileManager.attributesOfItem(atPath: storeURL.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        
                        if fileSize == 0 {
                            issues.append(MaintenanceIssue(
                                type: .corruptedData,
                                severity: .critical,
                                description: "Database file is empty",
                                affectedEntity: nil,
                                affectedID: nil,
                                canAutoFix: false
                            ))
                        } else if fileSize > 1073741824 { // 1GB
                            issues.append(MaintenanceIssue(
                                type: .corruptedData,
                                severity: .medium,
                                description: "Database file is very large (\(fileSize / 1024 / 1024)MB) - consider cleanup",
                                affectedEntity: nil,
                                affectedID: nil,
                                canAutoFix: false
                            ))
                        }
                    }
                }
            } catch {
                issues.append(MaintenanceIssue(
                    type: .corruptedData,
                    severity: .high,
                    description: "Failed to check database schema: \(error.localizedDescription)",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            }
        }
        
        return issues
    }
    
    private func validateCoreDataIntegrity() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            // Check for any Core Data validation errors
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let sheets = try context.fetch(sheetRequest)
            
            for sheet in sheets {
                do {
                    try context.obtainPermanentIDs(for: [sheet])
                    if sheet.isDeleted {
                        issues.append(MaintenanceIssue(
                            type: .corruptedData,
                            severity: .high,
                            description: "Sheet '\(sheet.title ?? "Untitled")' is marked as deleted but still in context",
                            affectedEntity: "Sheet",
                            affectedID: sheet.id,
                            canAutoFix: false
                        ))
                    }
                } catch {
                    issues.append(MaintenanceIssue(
                        type: .corruptedData,
                        severity: .high,
                        description: "Failed to obtain permanent ID for sheet '\(sheet.title ?? "Untitled")': \(error.localizedDescription)",
                        affectedEntity: "Sheet",
                        affectedID: sheet.id,
                        canAutoFix: false
                    ))
                }
            }
            
            // Check groups
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            let groups = try context.fetch(groupRequest)
            
            for group in groups {
                do {
                    try context.obtainPermanentIDs(for: [group])
                    if group.isDeleted {
                        issues.append(MaintenanceIssue(
                            type: .corruptedData,
                            severity: .high,
                            description: "Group '\(group.name ?? "Unnamed")' is marked as deleted but still in context",
                            affectedEntity: "Group",
                            affectedID: group.id,
                            canAutoFix: false
                        ))
                    }
                } catch {
                    issues.append(MaintenanceIssue(
                        type: .corruptedData,
                        severity: .high,
                        description: "Failed to obtain permanent ID for group '\(group.name ?? "Unnamed")': \(error.localizedDescription)",
                        affectedEntity: "Group",
                        affectedID: group.id,
                        canAutoFix: false
                    ))
                }
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .critical,
                description: "Failed to validate Core Data integrity: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func checkPerformanceIssues() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            // Check for performance issues
            let startTime = Date()
            
            // Test basic fetch performance
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            sheetRequest.fetchLimit = 100
            _ = try context.fetch(sheetRequest)
            
            let fetchTime = Date().timeIntervalSince(startTime)
            
            if fetchTime > 1.0 { // If basic fetch takes more than 1 second
                issues.append(MaintenanceIssue(
                    type: .inconsistentData,
                    severity: .medium,
                    description: "Database queries are slow (\(String(format: "%.2f", fetchTime))s for 100 records) - consider optimization",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            }
            
            // Check for too many records in memory
            let totalSheets = try context.count(for: NSFetchRequest<Sheet>(entityName: "Sheet"))
            let totalGroups = try context.count(for: NSFetchRequest<Group>(entityName: "Group"))
            
            if totalSheets > 10000 {
                issues.append(MaintenanceIssue(
                    type: .inconsistentData,
                    severity: .medium,
                    description: "Very large number of sheets (\(totalSheets)) may impact performance",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            }
            
            if totalGroups > 1000 {
                issues.append(MaintenanceIssue(
                    type: .inconsistentData,
                    severity: .low,
                    description: "Large number of groups (\(totalGroups)) may impact organization",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            }
            
            // Check for sheets with very large content
            let allSheetsRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            let allSheets = try context.fetch(allSheetsRequest)
            
            let largeSheets = allSheets.filter { sheet in
                let contentLength = sheet.content?.count ?? 0
                return contentLength > 100000 // 100KB = 100,000 characters
            }
            
            if !largeSheets.isEmpty {
                let sheetTitles = largeSheets.map { sheet in
                    let title = sheet.title ?? "Untitled"
                    let actualSize = sheet.content?.count ?? 0
                    let sizeKB = actualSize / 1024
                    return "\(title) (\(sizeKB)KB, \(actualSize) chars)"
                }.joined(separator: ", ")
                
                issues.append(MaintenanceIssue(
                    type: .inconsistentData,
                    severity: .info,
                    description: "\(largeSheets.count) sheet(s) have very large content (>100KB) which may impact performance: \(sheetTitles)",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .medium,
                description: "Failed to check performance: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
    
    private func validateBackupNeeds() async -> [MaintenanceIssue] {
        var issues: [MaintenanceIssue] = []
        
        do {
            // Check when data was last modified to determine backup urgency
            let recentSheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            recentSheetRequest.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
            recentSheetRequest.fetchLimit = 1
            
            if let mostRecentSheet = try context.fetch(recentSheetRequest).first,
               let lastModified = mostRecentSheet.modifiedAt {
                
                let daysSinceLastModification = Date().timeIntervalSince(lastModified) / 86400
                
                if daysSinceLastModification > 30 {
                    issues.append(MaintenanceIssue(
                        type: .inconsistentData,
                        severity: .info,
                        description: "No sheets modified in \(Int(daysSinceLastModification)) days - consider creating a backup",
                        affectedEntity: nil,
                        affectedID: nil,
                        canAutoFix: false
                    ))
                } else if daysSinceLastModification < 1 {
                    // Recent activity - backup recommended
                    issues.append(MaintenanceIssue(
                        type: .inconsistentData,
                        severity: .info,
                        description: "Recent writing activity detected - consider creating a backup to preserve your work",
                        affectedEntity: nil,
                        affectedID: nil,
                        canAutoFix: false
                    ))
                }
            }
            
            // Check total content value to assess backup importance
            let allSheetsRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            allSheetsRequest.predicate = NSPredicate(format: "isInTrash == NO")
            let allSheets = try context.fetch(allSheetsRequest)
            
            let totalWordCount = allSheets.reduce(0) { $0 + Int($1.wordCount) }
            let totalCharacters = allSheets.reduce(0) { total, sheet in
                total + (sheet.content?.count ?? 0)
            }
            
            if totalWordCount > 50000 { // Significant amount of content
                issues.append(MaintenanceIssue(
                    type: .inconsistentData,
                    severity: .info,
                    description: "Large content library (\(totalWordCount) words, \(totalCharacters) characters) - regular backups recommended",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            }
            
            // Check for sheets marked as favorites (high value content)
            let favoriteRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            favoriteRequest.predicate = NSPredicate(format: "isFavorite == YES AND isInTrash == NO")
            let favoriteCount = try context.count(for: favoriteRequest)
            
            if favoriteCount > 0 {
                issues.append(MaintenanceIssue(
                    type: .inconsistentData,
                    severity: .info,
                    description: "\(favoriteCount) favorite sheet(s) detected - ensure these important documents are backed up",
                    affectedEntity: nil,
                    affectedID: nil,
                    canAutoFix: false
                ))
            }
            
        } catch {
            issues.append(MaintenanceIssue(
                type: .corruptedData,
                severity: .low,
                description: "Failed to assess backup needs: \(error.localizedDescription)",
                affectedEntity: nil,
                affectedID: nil,
                canAutoFix: false
            ))
        }
        
        return issues
    }
}