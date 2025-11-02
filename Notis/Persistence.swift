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
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
