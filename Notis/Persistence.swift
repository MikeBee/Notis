//
//  Persistence.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample groups and sheets for preview
        let projectsGroup = Group(context: viewContext)
        projectsGroup.id = UUID()
        projectsGroup.name = "Projects"
        projectsGroup.createdAt = Date()
        projectsGroup.modifiedAt = Date()
        projectsGroup.sortOrder = 0

        let journalGroup = Group(context: viewContext)
        journalGroup.id = UUID()
        journalGroup.name = "Journal"
        journalGroup.createdAt = Date()
        journalGroup.modifiedAt = Date()
        journalGroup.sortOrder = 1

        // Create a subgroup
        let workSubgroup = Group(context: viewContext)
        workSubgroup.id = UUID()
        workSubgroup.name = "Work"
        workSubgroup.parent = projectsGroup
        workSubgroup.createdAt = Date()
        workSubgroup.modifiedAt = Date()
        workSubgroup.sortOrder = 0

        // Create sample sheets
        let sheet1 = Sheet(context: viewContext)
        sheet1.id = UUID()
        sheet1.title = "Chapter 1"
        sheet1.content = "# Chapter 1\n\nThis is the beginning of my story..."
        sheet1.preview = "This is the beginning of my story..."
        sheet1.group = projectsGroup
        sheet1.createdAt = Date()
        sheet1.modifiedAt = Date()
        sheet1.wordCount = 8
        sheet1.goalCount = 1000
        sheet1.goalType = "words"
        sheet1.sortOrder = 0

        let sheet2 = Sheet(context: viewContext)
        sheet2.id = UUID()
        sheet2.title = "Meeting Notes"
        sheet2.content = "## Meeting Notes\n\n- Discussed project timeline\n- Reviewed deliverables"
        sheet2.preview = "Discussed project timeline"
        sheet2.group = workSubgroup
        sheet2.createdAt = Date()
        sheet2.modifiedAt = Date()
        sheet2.wordCount = 6
        sheet2.goalCount = 500
        sheet2.goalType = "words"
        sheet2.sortOrder = 0

        do {
            try viewContext.save()
        } catch {
            // Note: fatalError is acceptable here as this is preview-only code
            // used exclusively for SwiftUI previews during development.
            // Production code never executes this path.
            let nsError = error as NSError
            print("Preview data creation failed: \(nsError), \(nsError.userInfo)")
            // For previews, we can continue with empty data rather than crashing
            // fatalError removed to allow preview to function even if save fails
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Notis")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Configure for automatic migration
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true

            // CloudKit configuration
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Log comprehensive error information
                print("⚠️ Core Data Initialization Error:")
                print("   Error Code: \(error.code)")
                print("   Description: \(error.localizedDescription)")
                print("   User Info: \(error.userInfo)")
                print("   Store Description: \(storeDescription)")

                // Post notification so the app can show an error message to the user
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CoreDataInitializationFailed"),
                        object: nil,
                        userInfo: ["error": error]
                    )
                }

                #if DEBUG
                // In development, provide additional context
                if error.code == 134100 { // Migration error
                    print("⚠️ Migration failed. Store may be corrupted or incompatible.")
                    print("   Consider implementing store reset logic or manual migration.")
                } else if error.code == 134090 { // Store URL unreachable
                    print("⚠️ Store location is unreachable. Check file permissions.")
                } else if error.code == 134080 { // Store version mismatch
                    print("⚠️ Store version mismatch. Migration may be required.")
                }
                #endif

                // Instead of crashing, we'll continue with a potentially empty/broken store
                // The app should check initializationError and handle accordingly
                print("⚠️ Continuing with potentially degraded Core Data functionality.")
                print("   App should present error to user and offer recovery options.")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
