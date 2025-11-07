//
//  NotesService.swift
//  Notis
//
//  Created by Claude on 11/5/25.
//

import Foundation
import CoreData
import SwiftUI

class NotesService: ObservableObject {
    static let shared = NotesService()
    
    private let context: NSManagedObjectContext
    @Published var notes: [Note] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    // MARK: - Note Management
    
    func createNote(content: String, in sheet: Sheet) -> Note {
        let note = Note(context: context)
        note.id = UUID()
        note.content = content
        note.sheet = sheet
        note.createdAt = Date()
        note.modifiedAt = Date()
        note.sortOrder = Int32(getNotes(for: sheet).count)
        
        saveContext()
        return note
    }
    
    func updateNote(_ note: Note, content: String) {
        note.content = content
        note.modifiedAt = Date()
        saveContext()
    }
    
    func deleteNote(_ note: Note) {
        context.delete(note)
        saveContext()
    }
    
    func getNotes(for sheet: Sheet) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "sheet == %@", sheet)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        
        return (try? context.fetch(request)) ?? []
    }
    
    func reorderNotes(_ notes: [Note]) {
        for (index, note) in notes.enumerated() {
            note.sortOrder = Int32(index)
        }
        saveContext()
    }
    
    // MARK: - Core Data
    
    private func saveContext() {
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            print("Failed to save notes context: \(error)")
        }
    }
}

// MARK: - Extensions

extension Note {
    var displayContent: String {
        return content ?? ""
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modifiedAt ?? createdAt ?? Date())
    }
    
    var preview: String {
        let content = displayContent
        if content.count <= 100 {
            return content
        }
        let index = content.index(content.startIndex, offsetBy: 100)
        return String(content[..<index]) + "..."
    }
    
    var firstLine: String {
        let content = displayContent
        if let firstLineEnd = content.firstIndex(of: "\n") {
            return String(content[..<firstLineEnd])
        }
        return content.count <= 50 ? content : String(content.prefix(50)) + "..."
    }
}