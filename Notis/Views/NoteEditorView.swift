//
//  NoteEditorView.swift
//  Notis
//
//  Created by Claude on 11/5/25.
//

import SwiftUI
import CoreData

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var notesService = NotesService.shared
    
    let sheet: Sheet
    let existingNote: Note?
    let onSave: (String) -> Void
    let onDelete: (() -> Void)?
    
    @State private var noteContent = ""
    @FocusState private var isContentFocused: Bool
    
    init(sheet: Sheet, existingNote: Note? = nil, onSave: @escaping (String) -> Void, onDelete: (() -> Void)? = nil) {
        self.sheet = sheet
        self.existingNote = existingNote
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Note content editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $noteContent)
                        .font(.system(size: 14))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(minHeight: 250)
                        .focused($isContentFocused)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    if existingNote != nil, let onDelete = onDelete {
                        Button("Delete Note", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save") {
                        saveNote()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle(existingNote != nil ? "Edit Note" : "New Note")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            noteContent = existingNote?.content ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isContentFocused = true
            }
        }
    }
    
    private func saveNote() {
        let trimmedContent = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedContent.isEmpty else { return }
        
        onSave(trimmedContent)
        dismiss()
    }
}

#Preview {
    NoteEditorView(
        sheet: Sheet(),
        existingNote: nil,
        onSave: { _ in },
        onDelete: nil
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}