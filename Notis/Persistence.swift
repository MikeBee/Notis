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
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
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
                // Log the error instead of crashing in production
                print("Core Data error: \(error), \(error.userInfo)")
                
                // In development, you might want to delete and recreate the store
                #if DEBUG
                if error.code == 134100 { // Migration error
                    print("Migration failed. In development, considering store reset.")
                    // You could implement store reset logic here if needed
                }
                #endif
                
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
