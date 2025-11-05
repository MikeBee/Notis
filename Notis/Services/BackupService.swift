//
//  BackupService.swift
//  Notis
//
//  Created by Claude on 11/5/25.
//

import Foundation
import CoreData
import CloudKit
import SwiftUI

class BackupService: ObservableObject {
    static let shared = BackupService()
    
    private let context: NSManagedObjectContext
    private let cloudKitContainer: CKContainer
    @Published var isBackingUp = false
    @Published var lastBackupDate: Date?
    @Published var backupStatus: BackupStatus = .idle
    
    // Backup configuration
    private let dailyBackupKey = "lastDailyBackup"
    private let weeklyBackupKey = "lastWeeklyBackup"
    private let monthlyBackupKey = "lastMonthlyBackup"
    private let backupEnabledKey = "backupEnabled"
    
    // Backup retention policy
    private let maxDailyBackups = 7      // Keep 7 daily backups
    private let maxWeeklyBackups = 4     // Keep 4 weekly backups
    private let maxMonthlyBackups = 12   // Keep 12 monthly backups
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        self.cloudKitContainer = CKContainer.default()
        self.lastBackupDate = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
        
        // Initialize backup enabled state
        let initialBackupState = UserDefaults.standard.bool(forKey: backupEnabledKey)
        
        // Set the initial state without triggering didSet during initialization
        _isBackupEnabled = Published(initialValue: initialBackupState)
        
        // Start background backup monitoring
        startBackupMonitoring()
    }
    
    // MARK: - Backup Status
    
    enum BackupStatus {
        case idle
        case preparingBackup
        case uploadingToiCloud
        case cleaningOldBackups
        case completed
        case failed(Error)
        
        var description: String {
            switch self {
            case .idle:
                return "Ready"
            case .preparingBackup:
                return "Preparing backup..."
            case .uploadingToiCloud:
                return "Uploading to iCloud..."
            case .cleaningOldBackups:
                return "Cleaning old backups..."
            case .completed:
                return "Backup completed"
            case .failed(let error):
                return "Backup failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Backup Types
    
    enum BackupType: String, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        
        var recordType: String {
            return "NotisBackup_\(rawValue)"
        }
        
        var interval: TimeInterval {
            switch self {
            case .daily:
                return 24 * 60 * 60 // 24 hours
            case .weekly:
                return 7 * 24 * 60 * 60 // 7 days
            case .monthly:
                return 30 * 24 * 60 * 60 // 30 days
            }
        }
        
        var maxRetention: Int {
            switch self {
            case .daily:
                return 7
            case .weekly:
                return 4
            case .monthly:
                return 12
            }
        }
    }
    
    // MARK: - Backup Data Structure
    
    struct BackupData: Codable {
        let version: String
        let createdAt: Date
        let groups: [GroupBackup]
        let sheets: [SheetBackup]
        let annotations: [AnnotationBackup]
        let notes: [NoteBackup]
        let templates: [TemplateBackup]
        
        struct GroupBackup: Codable {
            let id: UUID
            let name: String
            let parentId: UUID?
            let sortOrder: Int32
            let isFavorite: Bool
            let createdAt: Date
            let modifiedAt: Date
        }
        
        struct SheetBackup: Codable {
            let id: UUID
            let title: String?
            let content: String?
            let preview: String?
            let groupId: UUID?
            let wordCount: Int32
            let goalCount: Int32
            let goalType: String?
            let isFavorite: Bool
            let isInTrash: Bool
            let sortOrder: Int32
            let createdAt: Date
            let modifiedAt: Date
            let deletedAt: Date?
        }
        
        struct AnnotationBackup: Codable {
            let id: UUID
            let annotatedText: String?
            let content: String?
            let position: Int32
            let sheetId: UUID
            let createdAt: Date
            let modifiedAt: Date
        }
        
        struct NoteBackup: Codable {
            let id: UUID
            let content: String?
            let sortOrder: Int32
            let sheetId: UUID
            let createdAt: Date
            let modifiedAt: Date
        }
        
        struct TemplateBackup: Codable {
            let id: UUID
            let name: String?
            let content: String?
            let category: String?
            let titleTemplate: String?
            let targetGroupName: String?
            let keyboardShortcut: String?
            let usesDateInTitle: Bool
            let isBuiltIn: Bool
            let sortOrder: Int32
            let createdAt: Date
            let modifiedAt: Date
        }
    }
    
    // MARK: - Public Interface
    
    @Published var isBackupEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isBackupEnabled, forKey: backupEnabledKey)
            if isBackupEnabled {
                Task {
                    await checkAndPerformBackups()
                }
            }
        }
    }
    
    
    @MainActor
    func performManualBackup() async {
        await performBackup(type: .daily, isManual: true)
    }
    
    func getBackupInfo() -> (lastDaily: Date?, lastWeekly: Date?, lastMonthly: Date?) {
        let lastDaily = UserDefaults.standard.object(forKey: dailyBackupKey) as? Date
        let lastWeekly = UserDefaults.standard.object(forKey: weeklyBackupKey) as? Date
        let lastMonthly = UserDefaults.standard.object(forKey: monthlyBackupKey) as? Date
        return (lastDaily, lastWeekly, lastMonthly)
    }
    
    // MARK: - Backup Monitoring
    
    private func startBackupMonitoring() {
        // Check for backups every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.checkAndPerformBackups()
            }
        }
        
        // Perform initial check
        Task {
            await checkAndPerformBackups()
        }
    }
    
    @MainActor
    func checkAndPerformBackups() async {
        guard isBackupEnabled else { return }
        
        let now = Date()
        
        // Check if we need daily backup
        if needsBackup(type: .daily, currentDate: now) {
            await performBackup(type: .daily)
        }
        
        // Check if we need weekly backup
        if needsBackup(type: .weekly, currentDate: now) {
            await performBackup(type: .weekly)
        }
        
        // Check if we need monthly backup
        if needsBackup(type: .monthly, currentDate: now) {
            await performBackup(type: .monthly)
        }
    }
    
    private func needsBackup(type: BackupType, currentDate: Date) -> Bool {
        let key = keyForBackupType(type)
        guard let lastBackup = UserDefaults.standard.object(forKey: key) as? Date else {
            return true // No backup exists
        }
        
        return currentDate.timeIntervalSince(lastBackup) >= type.interval
    }
    
    private func keyForBackupType(_ type: BackupType) -> String {
        switch type {
        case .daily: return dailyBackupKey
        case .weekly: return weeklyBackupKey
        case .monthly: return monthlyBackupKey
        }
    }
    
    // MARK: - Backup Execution
    
    @MainActor
    private func performBackup(type: BackupType, isManual: Bool = false) async {
        guard !isBackingUp else { return }
        
        isBackingUp = true
        backupStatus = .preparingBackup
        
        var backupSucceeded = false
        
        do {
            // Prepare backup data
            let backupData = try await prepareBackupData()
            
            backupStatus = .uploadingToiCloud
            
            // Upload to iCloud
            try await uploadBackupToiCloud(backupData, type: type, isManual: isManual)
            backupSucceeded = true
            print("✅ BackupService: Successfully uploaded \(type.rawValue) backup to iCloud")
            
            backupStatus = .cleaningOldBackups
            
            // Clean old backups (this might fail on first run due to schema)
            try await cleanOldBackups(type: type)
            
            backupStatus = .completed
            
        } catch {
            backupStatus = .failed(error)
            print("❌ BackupService: Backup failed: \(error)")
        }
        
        // Update last backup dates only if upload succeeded
        if backupSucceeded {
            let now = Date()
            UserDefaults.standard.set(now, forKey: keyForBackupType(type))
            UserDefaults.standard.set(now, forKey: "lastBackupDate")
            lastBackupDate = now
            print("✅ BackupService: Updated last backup date to \(now)")
        }
        
        isBackingUp = false
        
        // Reset status after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.backupStatus = .idle
        }
    }
    
    private func prepareBackupData() async throws -> BackupData {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Fetch all data
                    let groups = try self.fetchGroups()
                    let sheets = try self.fetchSheets()
                    let annotations = try self.fetchAnnotations()
                    let notes = try self.fetchNotes()
                    let templates = try self.fetchTemplates()
                    
                    let backupData = BackupData(
                        version: "1.0",
                        createdAt: Date(),
                        groups: groups,
                        sheets: sheets,
                        annotations: annotations,
                        notes: notes,
                        templates: templates
                    )
                    
                    continuation.resume(returning: backupData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchGroups() throws -> [BackupData.GroupBackup] {
        let request: NSFetchRequest<Group> = Group.fetchRequest()
        let groups = try context.fetch(request)
        
        return groups.map { group in
            BackupData.GroupBackup(
                id: group.id ?? UUID(),
                name: group.name ?? "",
                parentId: group.parent?.id,
                sortOrder: group.sortOrder,
                isFavorite: group.isFavorite,
                createdAt: group.createdAt ?? Date(),
                modifiedAt: group.modifiedAt ?? Date()
            )
        }
    }
    
    private func fetchSheets() throws -> [BackupData.SheetBackup] {
        let request: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        let sheets = try context.fetch(request)
        
        return sheets.map { sheet in
            BackupData.SheetBackup(
                id: sheet.id ?? UUID(),
                title: sheet.title,
                content: sheet.content,
                preview: sheet.preview,
                groupId: sheet.group?.id,
                wordCount: sheet.wordCount,
                goalCount: sheet.goalCount,
                goalType: sheet.goalType,
                isFavorite: sheet.isFavorite,
                isInTrash: sheet.isInTrash,
                sortOrder: sheet.sortOrder,
                createdAt: sheet.createdAt ?? Date(),
                modifiedAt: sheet.modifiedAt ?? Date(),
                deletedAt: sheet.deletedAt
            )
        }
    }
    
    private func fetchAnnotations() throws -> [BackupData.AnnotationBackup] {
        let request: NSFetchRequest<Annotation> = Annotation.fetchRequest()
        let annotations = try context.fetch(request)
        
        return annotations.compactMap { annotation in
            guard let sheetId = annotation.sheet?.id else { return nil }
            return BackupData.AnnotationBackup(
                id: annotation.id ?? UUID(),
                annotatedText: annotation.annotatedText,
                content: annotation.content,
                position: annotation.position,
                sheetId: sheetId,
                createdAt: annotation.createdAt ?? Date(),
                modifiedAt: annotation.modifiedAt ?? Date()
            )
        }
    }
    
    private func fetchNotes() throws -> [BackupData.NoteBackup] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let notes = try context.fetch(request)
        
        return notes.compactMap { note in
            guard let sheetId = note.sheet?.id else { return nil }
            return BackupData.NoteBackup(
                id: note.id ?? UUID(),
                content: note.content,
                sortOrder: note.sortOrder,
                sheetId: sheetId,
                createdAt: note.createdAt ?? Date(),
                modifiedAt: note.modifiedAt ?? Date()
            )
        }
    }
    
    private func fetchTemplates() throws -> [BackupData.TemplateBackup] {
        let request: NSFetchRequest<Template> = Template.fetchRequest()
        let templates = try context.fetch(request)
        
        return templates.map { template in
            BackupData.TemplateBackup(
                id: template.id ?? UUID(),
                name: template.name,
                content: template.content,
                category: template.category,
                titleTemplate: template.titleTemplate,
                targetGroupName: template.targetGroupName,
                keyboardShortcut: template.keyboardShortcut,
                usesDateInTitle: template.usesDateInTitle,
                isBuiltIn: template.isBuiltIn,
                sortOrder: template.sortOrder,
                createdAt: template.createdAt ?? Date(),
                modifiedAt: template.modifiedAt ?? Date()
            )
        }
    }
    
    // MARK: - CloudKit Operations
    
    private func uploadBackupToiCloud(_ backupData: BackupData, type: BackupType, isManual: Bool) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(backupData)
        
        // Create a unique record ID for this backup
        let recordID = CKRecord.ID(recordName: "\(type.rawValue)_\(UUID().uuidString)")
        let record = CKRecord(recordType: type.recordType, recordID: recordID)
        record["backupData"] = jsonData
        record["createdAt"] = backupData.createdAt
        record["version"] = backupData.version
        record["isManual"] = isManual
        #if os(iOS)
        record["deviceIdentifier"] = await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        #else
        record["deviceIdentifier"] = ProcessInfo.processInfo.hostName
        #endif
        
        let database = cloudKitContainer.privateCloudDatabase
        let savedRecord = try await database.save(record)
        print("✅ BackupService: Saved backup record with ID: \(savedRecord.recordID.recordName)")
    }
    
    private func cleanOldBackups(type: BackupType) async throws {
        let database = cloudKitContainer.privateCloudDatabase
        
        do {
            let query = CKQuery(recordType: type.recordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            
            let records = try await database.records(matching: query).matchResults.compactMap { try? $0.1.get() }
            
            // Keep only the most recent backups according to retention policy
            let recordsToDelete = Array(records.dropFirst(type.maxRetention))
            
            if !recordsToDelete.isEmpty {
                let recordIDs = recordsToDelete.map { $0.recordID }
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for recordID in recordIDs {
                        group.addTask {
                            _ = try await database.deleteRecord(withID: recordID)
                        }
                    }
                    
                    for try await _ in group {
                        // Wait for all deletions to complete
                    }
                }
            }
        } catch let error as CKError where error.code == .invalidArguments {
            // CloudKit schema doesn't exist yet or fields aren't queryable
            // This is expected on first run - we'll skip cleanup for now
            print("⚠️ BackupService: CloudKit schema not ready for cleanup, skipping: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Restore Operations
    
    private func ensureCloudKitSchemaExists() async {
        // Try to create a test record to ensure schema exists
        let database = cloudKitContainer.privateCloudDatabase
        
        for type in BackupType.allCases {
            do {
                // Check if we can query for records of this type
                let query = CKQuery(recordType: type.recordType, predicate: NSPredicate(format: "TRUEPREDICATE"))
                query.resultsLimit = 1
                _ = try await database.records(matching: query)
                print("✅ BackupService: Schema exists for \(type.recordType)")
            } catch let error as CKError {
                if error.code == .invalidArguments || error.code == .unknownItem {
                    print("🔧 BackupService: Schema doesn't exist for \(type.recordType), will be created on next backup")
                }
            } catch {
                print("⚠️ BackupService: Unexpected error checking schema for \(type.recordType): \(error)")
            }
        }
    }
    
    func getAvailableBackups() async throws -> [BackupInfo] {
        let database = cloudKitContainer.privateCloudDatabase
        var allBackups: [BackupInfo] = []
        
        // First, ensure CloudKit schema exists
        await ensureCloudKitSchemaExists()
        
        for type in BackupType.allCases {
            do {
                print("🔍 BackupService: Querying \(type.recordType) backups...")
                let query = CKQuery(recordType: type.recordType, predicate: NSPredicate(value: true))
                query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                
                let result = try await database.records(matching: query)
                let records = result.matchResults.compactMap { try? $0.1.get() }
                print("✅ BackupService: Found \(records.count) \(type.recordType) backup records")
                
                let backups = records.map { record in
                    BackupInfo(
                        id: record.recordID.recordName,
                        type: type,
                        createdAt: record["createdAt"] as? Date ?? Date(),
                        version: record["version"] as? String ?? "1.0",
                        isManual: record["isManual"] as? Bool ?? false,
                        deviceIdentifier: record["deviceIdentifier"] as? String
                    )
                }
                
                allBackups.append(contentsOf: backups)
            } catch let error as CKError {
                switch error.code {
                case .invalidArguments:
                    // CloudKit schema doesn't exist yet or fields aren't queryable
                    print("⚠️ BackupService: CloudKit schema not ready for \(type.recordType): \(error.localizedDescription)")
                case .unknownItem:
                    // Record type doesn't exist yet
                    print("⚠️ BackupService: Record type \(type.recordType) doesn't exist yet")
                case .networkFailure, .networkUnavailable:
                    // Network issues - this should be retried
                    print("🌐 BackupService: Network error querying \(type.recordType): \(error.localizedDescription)")
                    throw error
                case .notAuthenticated:
                    // User not signed into iCloud
                    print("🔐 BackupService: Not authenticated with iCloud: \(error.localizedDescription)")
                    throw error
                default:
                    print("❌ BackupService: Unexpected CloudKit error for \(type.recordType): \(error.localizedDescription)")
                    throw error
                }
                continue
            } catch {
                print("❌ BackupService: Unexpected error querying \(type.recordType): \(error.localizedDescription)")
                throw error
            }
        }
        
        let sortedBackups = allBackups.sorted { $0.createdAt > $1.createdAt }
        print("📋 BackupService: Returning \(sortedBackups.count) total backups")
        return sortedBackups
    }
    
    func restoreFromBackup(_ backupInfo: BackupInfo) async throws {
        // Implementation for restore would go here
        // This would involve downloading the backup data and restoring to Core Data
        // For safety, this should probably create a full backup before restoring
        throw NSError(domain: "BackupService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Restore functionality not yet implemented"])
    }
}

// MARK: - Supporting Types

struct BackupInfo: Identifiable {
    let id: String
    let type: BackupService.BackupType
    let createdAt: Date
    let version: String
    let isManual: Bool
    let deviceIdentifier: String?
}