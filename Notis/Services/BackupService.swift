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
    internal let cloudKitContainer: CKContainer
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
        case downloadingBackup
        case restoringData
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
            case .downloadingBackup:
                return "Downloading backup..."
            case .restoringData:
                return "Restoring data..."
            case .completed:
                return "Operation completed"
            case .failed(let error):
                return "Operation failed: \(error.localizedDescription)"
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
            let fileURL: String?
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
            
            backupStatus = .cleaningOldBackups
            
            // Clean old backups (this might fail on first run due to schema)
            try await cleanOldBackups(type: type)
            
            backupStatus = .completed
            
        } catch {
            backupStatus = .failed(error)
        }
        
        // Update last backup dates only if upload succeeded
        if backupSucceeded {
            let now = Date()
            UserDefaults.standard.set(now, forKey: keyForBackupType(type))
            UserDefaults.standard.set(now, forKey: "lastBackupDate")
            lastBackupDate = now
        }
        
        isBackingUp = false
        
        // Reset status after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.backupStatus = .idle
        }
    }
    
    internal func prepareBackupData() async throws -> BackupData {
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
                content: sheet.unifiedContent,  // Use new unified content accessor
                preview: sheet.preview,
                fileURL: sheet.fileURL,  // Include fileURL for reference
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
        
        // Store the record ID so we can fetch it directly later
        let recordIDsKey = "backup_record_ids_\(type.rawValue)"
        var existingRecordIDs = UserDefaults.standard.stringArray(forKey: recordIDsKey) ?? []
        existingRecordIDs.append(savedRecord.recordID.recordName)
        // Keep only the last 20 record IDs to avoid bloat
        if existingRecordIDs.count > 20 {
            existingRecordIDs = Array(existingRecordIDs.suffix(20))
        }
        UserDefaults.standard.set(existingRecordIDs, forKey: recordIDsKey)
    }
    
    private func cleanOldBackups(type: BackupType) async throws {
        let database = cloudKitContainer.privateCloudDatabase
        
        do {
            let query = CKQuery(recordType: type.recordType, predicate: NSPredicate(format: "TRUEPREDICATE"))
            
            let records = try await database.records(matching: query).matchResults.compactMap { try? $0.1.get() }
            
            // Sort records manually by creation date
            let sortedRecords = records.sorted { record1, record2 in
                let date1 = record1["createdAt"] as? Date ?? Date.distantPast
                let date2 = record2["createdAt"] as? Date ?? Date.distantPast
                return date1 > date2 // newest first
            }
            
            // Keep only the most recent backups according to retention policy
            let recordsToDelete = Array(sortedRecords.dropFirst(type.maxRetention))
            
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
                _ = try await database.records(matching: query)
            } catch let error as CKError {
                if error.code == .invalidArguments || error.code == .unknownItem {
                }
            } catch {
            }
        }
    }
    
    func getAvailableBackups() async throws -> [BackupInfo] {
        
        let database = cloudKitContainer.privateCloudDatabase
        var allBackups: [BackupInfo] = []
        
        // Check iCloud account status first
        do {
            _ = try await cloudKitContainer.accountStatus()
        } catch {
            // Continue with backup discovery even if account status check fails
        }
        
        // Try to fetch records using stored record IDs first
        for type in BackupType.allCases {
            let recordIDsKey = "backup_record_ids_\(type.rawValue)"
            if let storedRecordIDs = UserDefaults.standard.stringArray(forKey: recordIDsKey), !storedRecordIDs.isEmpty {
                
                // Try to fetch each stored record directly
                for recordIDString in storedRecordIDs {
                    do {
                        let recordID = CKRecord.ID(recordName: recordIDString)
                        let record = try await database.record(for: recordID)
                        
                        let backup = BackupInfo(
                            id: record.recordID.recordName,
                            type: type,
                            createdAt: record["createdAt"] as? Date ?? Date(),
                            version: record["version"] as? String ?? "1.0",
                            isManual: record["isManual"] as? Bool ?? false,
                            deviceIdentifier: record["deviceIdentifier"] as? String
                        )
                        allBackups.append(backup)
                    } catch {
                        // Continue to next record if this one fails
                    }
                }
            } else {
                // No stored record IDs for this type
            }
        }
        
        if !allBackups.isEmpty {
            let sortedBackups = allBackups.sorted { $0.createdAt > $1.createdAt }
            return sortedBackups
        }
        
        // Instead of querying with predicates that require queryable fields,
        // let's try to fetch records directly if we know the pattern
        for type in BackupType.allCases {
            do {
                
                // Try the query approach first, but with better error handling
                do {
                    // Use a simpler predicate that doesn't rely on indexes
                    let query = CKQuery(recordType: type.recordType, predicate: NSPredicate(value: true))
                    let (matchResults, queryCursor) = try await database.records(matching: query)
                    
                    var allRecords = matchResults.compactMap { try? $0.1.get() }
                    
                    // If there's a cursor, fetch more results
                    var cursor = queryCursor
                    while let currentCursor = cursor {
                        let (moreResults, nextCursor) = try await database.records(continuingMatchFrom: currentCursor)
                        allRecords.append(contentsOf: moreResults.compactMap { try? $0.1.get() })
                        cursor = nextCursor
                    }
                    
                    
                    // Sort records manually since CloudKit sorting might not work yet
                    let sortedRecords = allRecords.sorted { record1, record2 in
                        let date1 = record1["createdAt"] as? Date ?? Date.distantPast
                        let date2 = record2["createdAt"] as? Date ?? Date.distantPast
                        return date1 > date2
                    }
                    
                    let backups = sortedRecords.map { record in
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
                    
                } catch let ckError as CKError where ckError.code == .invalidArguments {
                    // Query failed - this shouldn't happen after 24+ hours but let's try a workaround
                    
                    // Try fetching all records from the private database (last resort)
                    // Use the new iOS 15+ approach to fetch all records of a type
                    let allRecordsQuery = CKQuery(recordType: type.recordType, predicate: NSPredicate(value: true))
                    let operation = CKQueryOperation(query: allRecordsQuery)
                    operation.database = database
                    operation.resultsLimit = CKQueryOperation.maximumResults
                    
                    var foundRecords: [CKRecord] = []
                    operation.recordMatchedBlock = { recordID, result in
                        switch result {
                        case .success(let record):
                            foundRecords.append(record)
                        case .failure(_):
                            // Skip failed records
                            break
                        }
                    }
                    
                    let operationResult = await withCheckedContinuation { continuation in
                        operation.queryResultBlock = { result in
                            continuation.resume(returning: result)
                        }
                        database.add(operation)
                    }
                    
                    switch operationResult {
                    case .success:
                        let backups = foundRecords.map { record in
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
                    case .failure(_):
                        // Query failed, continue to next type
                        break
                    }
                    
                    continue
                }
                
            } catch let error as CKError {
                switch error.code {
                case .unknownItem:
                    // Record type doesn't exist yet
                    break
                case .networkFailure, .networkUnavailable:
                    // Network issues - this should be retried
                    throw error
                case .notAuthenticated:
                    // User not signed into iCloud
                    throw error
                default:
                    // Don't throw - continue with other types
                    break
                }
                continue
            } catch {
                continue
            }
        }
        
        let sortedBackups = allBackups.sorted { $0.createdAt > $1.createdAt }
        
        
        return sortedBackups
    }
    
    @MainActor
    func restoreFromBackup(_ backupInfo: BackupInfo) async throws {
        guard !isBackingUp else {
            throw NSError(domain: "BackupService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot restore while backup is in progress"])
        }
        
        isBackingUp = true
        backupStatus = .preparingBackup
        
        do {
            // Step 1: Create a safety backup before restore
            let safetyBackupData = try await prepareBackupData()
            try await uploadBackupToiCloud(safetyBackupData, type: .daily, isManual: true)
            
            // Step 2: Download and parse the backup data
            backupStatus = .downloadingBackup
            let backupData = try await downloadBackupData(backupInfo)
            
            // Step 3: Restore the data
            backupStatus = .restoringData
            try await restoreData(backupData)
            
            backupStatus = .completed
            
        } catch {
            backupStatus = .failed(error)
            throw error
        }
        
        isBackingUp = false
        
        // Reset status after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.backupStatus = .idle
        }
    }
    
    private func downloadBackupData(_ backupInfo: BackupInfo) async throws -> BackupData {
        let database = cloudKitContainer.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: backupInfo.id)
        
        let record = try await database.record(for: recordID)
        
        guard let backupDataRaw = record["backupData"] as? Data else {
            throw NSError(domain: "BackupService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Backup data not found in record"])
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(BackupData.self, from: backupDataRaw)
    }
    
    private func restoreData(_ backupData: BackupData) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Clear existing data
                    try self.clearAllData()
                    
                    // Create lookup dictionaries for relationships
                    var groupLookup: [UUID: Group] = [:]
                    var sheetLookup: [UUID: Sheet] = [:]
                    
                    // Step 1: Restore groups (in dependency order)
                    // First, create all groups without parent relationships
                    for groupBackup in backupData.groups {
                        let group = Group(context: self.context)
                        group.id = groupBackup.id
                        group.name = groupBackup.name
                        group.sortOrder = groupBackup.sortOrder
                        group.isFavorite = groupBackup.isFavorite
                        group.createdAt = groupBackup.createdAt
                        group.modifiedAt = groupBackup.modifiedAt
                        groupLookup[groupBackup.id] = group
                    }
                    
                    // Second, establish parent-child relationships
                    for groupBackup in backupData.groups {
                        if let parentId = groupBackup.parentId,
                           let group = groupLookup[groupBackup.id],
                           let parent = groupLookup[parentId] {
                            group.parent = parent
                        }
                    }
                    
                    // Step 2: Restore templates
                    for templateBackup in backupData.templates {
                        let template = Template(context: self.context)
                        template.id = templateBackup.id
                        template.name = templateBackup.name
                        template.content = templateBackup.content
                        template.category = templateBackup.category
                        template.titleTemplate = templateBackup.titleTemplate
                        template.targetGroupName = templateBackup.targetGroupName
                        template.keyboardShortcut = templateBackup.keyboardShortcut
                        template.usesDateInTitle = templateBackup.usesDateInTitle
                        template.isBuiltIn = templateBackup.isBuiltIn
                        template.sortOrder = templateBackup.sortOrder
                        template.createdAt = templateBackup.createdAt
                        template.modifiedAt = templateBackup.modifiedAt
                    }
                    
                    // Step 3: Create group folders in filesystem
                    let fileService = MarkdownFileService.shared
                    for groupBackup in backupData.groups {
                        if let group = groupLookup[groupBackup.id] {
                            let folderPath = group.folderPath()
                            _ = fileService.createFolder(path: folderPath)
                        }
                    }

                    // Step 4: Restore sheets with markdown files
                    for sheetBackup in backupData.sheets {
                        let sheet = Sheet(context: self.context)
                        sheet.id = sheetBackup.id
                        sheet.title = sheetBackup.title ?? "Untitled"
                        sheet.preview = sheetBackup.preview
                        sheet.wordCount = sheetBackup.wordCount
                        sheet.goalCount = sheetBackup.goalCount
                        sheet.goalType = sheetBackup.goalType
                        sheet.isFavorite = sheetBackup.isFavorite
                        sheet.isInTrash = sheetBackup.isInTrash
                        sheet.sortOrder = sheetBackup.sortOrder
                        sheet.createdAt = sheetBackup.createdAt
                        sheet.modifiedAt = sheetBackup.modifiedAt
                        sheet.deletedAt = sheetBackup.deletedAt

                        // Link to group if specified
                        if let groupId = sheetBackup.groupId,
                           let group = groupLookup[groupId] {
                            sheet.group = group
                        }

                        // Create markdown file with content
                        let content = sheetBackup.content ?? ""
                        let folderPath = sheet.group?.folderPath()

                        // Build metadata
                        let metadata = NoteMetadata(
                            uuid: sheet.id?.uuidString ?? UUID().uuidString,
                            title: sheet.title ?? "Untitled",
                            tags: [],
                            created: sheet.createdAt ?? Date(),
                            modified: sheet.modifiedAt ?? Date(),
                            progress: 0.0,
                            status: sheet.isFavorite ? "favorite" : "draft"
                        )

                        // Create the markdown file (in trash if needed)
                        if sheetBackup.isInTrash {
                            // For trashed sheets, create file in trash directory
                            let trashFilename = "\(metadata.title).md"
                            let trashURL = fileService.getTrashDirectory().appendingPathComponent(trashFilename)
                            let markdown = YAMLFrontmatterService.shared.serialize(metadata: metadata, content: content)
                            if let markdownData = markdown.data(using: .utf8) {
                                try? markdownData.write(to: trashURL)
                                sheet.fileURL = trashURL.path
                                if let relativePath = fileService.relativePath(for: trashURL) {
                                    var trashMetadata = metadata
                                    trashMetadata.path = relativePath
                                    _ = NotesIndexService.shared.upsertNote(trashMetadata)
                                }
                            }
                        } else {
                            // For normal sheets, create in Notes directory
                            let result = fileService.createFile(
                                title: sheet.title ?? "Untitled",
                                content: content,
                                folderPath: folderPath?.isEmpty == false ? folderPath : nil,
                                tags: [],
                                metadata: metadata
                            )

                            if result.success, let fileURL = result.url, let finalMetadata = result.metadata {
                                sheet.fileURL = fileURL.path
                                _ = NotesIndexService.shared.upsertNote(finalMetadata)
                            }
                        }

                        sheetLookup[sheetBackup.id] = sheet
                    }
                    
                    // Step 5: Restore annotations
                    for annotationBackup in backupData.annotations {
                        guard let sheet = sheetLookup[annotationBackup.sheetId] else {
                            continue
                        }
                        
                        let annotation = Annotation(context: self.context)
                        annotation.id = annotationBackup.id
                        annotation.annotatedText = annotationBackup.annotatedText
                        annotation.content = annotationBackup.content
                        annotation.position = annotationBackup.position
                        annotation.createdAt = annotationBackup.createdAt
                        annotation.modifiedAt = annotationBackup.modifiedAt
                        annotation.sheet = sheet
                    }
                    
                    // Step 6: Restore notes
                    for noteBackup in backupData.notes {
                        guard let sheet = sheetLookup[noteBackup.sheetId] else {
                            continue
                        }
                        
                        let note = Note(context: self.context)
                        note.id = noteBackup.id
                        note.content = noteBackup.content
                        note.sortOrder = noteBackup.sortOrder
                        note.createdAt = noteBackup.createdAt
                        note.modifiedAt = noteBackup.modifiedAt
                        note.sheet = sheet
                    }
                    
                    // Save all changes
                    try self.context.save()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func clearAllData() throws {
        // Clear all entities in dependency order
        let entityNames = ["Note", "Annotation", "Sheet", "Group", "Template"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs], into: [context])
            }
        }
        
        try context.save()
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