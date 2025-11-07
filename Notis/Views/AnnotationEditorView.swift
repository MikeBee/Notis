//
//  AnnotationEditorView.swift
//  Notis
//
//  Created by Claude on 11/4/25.
//

import SwiftUI
import CoreData

struct AnnotationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var annotationService = AnnotationService.shared
    
    let annotatedText: String
    let sheet: Sheet
    let position: Int
    let existingAnnotation: Annotation?
    let onSave: (Annotation) -> Void
    let onDelete: (() -> Void)?
    
    @State private var annotationContent = ""
    @FocusState private var isTextFieldFocused: Bool
    
    init(annotatedText: String, sheet: Sheet, position: Int, existingAnnotation: Annotation? = nil, onSave: @escaping (Annotation) -> Void, onDelete: (() -> Void)? = nil) {
        self.annotatedText = annotatedText
        self.sheet = sheet
        self.position = position
        self.existingAnnotation = existingAnnotation
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Annotated text display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Annotated Text:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(annotatedText)
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                        )
                }
                
                // Annotation content editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Annotation:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $annotationContent)
                        .font(.system(size: 14))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(minHeight: 100)
                        .focused($isTextFieldFocused)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    if existingAnnotation != nil, let onDelete = onDelete {
                        Button("Remove Annotation", role: .destructive) {
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
                        saveAnnotation()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(annotationContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Annotation")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            annotationContent = existingAnnotation?.content ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func saveAnnotation() {
        let trimmedContent = annotationContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        if let existing = existingAnnotation {
            annotationService.updateAnnotation(existing, content: trimmedContent)
            onSave(existing)
        } else {
            let newAnnotation = annotationService.createAnnotation(
                for: annotatedText,
                content: trimmedContent,
                in: sheet,
                at: position
            )
            onSave(newAnnotation)
        }
        
        dismiss()
    }
}

#Preview {
    AnnotationEditorView(
        annotatedText: "Sample annotated text",
        sheet: Sheet(),
        position: 0,
        existingAnnotation: nil,
        onSave: { _ in },
        onDelete: nil
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}