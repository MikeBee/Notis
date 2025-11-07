//
//  AnnotationService.swift
//  Notis
//
//  Created by Claude on 11/4/25.
//

import Foundation
import CoreData
import SwiftUI

class AnnotationService: ObservableObject {
    static let shared = AnnotationService()
    
    private let context: NSManagedObjectContext
    @Published var annotations: [Annotation] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    // MARK: - Annotation Parsing
    
    struct AnnotatedRange {
        let range: NSRange
        let text: String
        let annotation: Annotation?
    }
    
    func parseAnnotations(in text: String, for sheet: Sheet) -> [AnnotatedRange] {
        var annotatedRanges: [AnnotatedRange] = []
        let nsText = text as NSString
        
        // Regex to find {text} patterns
        let pattern = #"\{([^}]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return annotatedRanges
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        for match in matches {
            let fullRange = match.range
            let textRange = match.range(at: 1) // Capture group - text inside braces
            
            if textRange.location != NSNotFound {
                let annotatedText = nsText.substring(with: textRange)
                let existingAnnotation = findAnnotation(for: annotatedText, in: sheet, at: fullRange.location)
                
                annotatedRanges.append(AnnotatedRange(
                    range: fullRange,
                    text: annotatedText,
                    annotation: existingAnnotation
                ))
            }
        }
        
        return annotatedRanges
    }
    
    // MARK: - Annotation Management
    
    func createAnnotation(for text: String, content: String, in sheet: Sheet, at position: Int) -> Annotation {
        let annotation = Annotation(context: context)
        annotation.id = UUID()
        annotation.annotatedText = text
        annotation.content = content
        annotation.position = Int32(position)
        annotation.sheet = sheet
        annotation.createdAt = Date()
        annotation.modifiedAt = Date()
        
        saveContext()
        return annotation
    }
    
    func updateAnnotation(_ annotation: Annotation, content: String) {
        annotation.content = content
        annotation.modifiedAt = Date()
        saveContext()
    }
    
    func deleteAnnotation(_ annotation: Annotation) {
        context.delete(annotation)
        saveContext()
    }
    
    func findAnnotation(for text: String, in sheet: Sheet, at position: Int) -> Annotation? {
        let request: NSFetchRequest<Annotation> = Annotation.fetchRequest()
        request.predicate = NSPredicate(format: "sheet == %@ AND annotatedText == %@ AND position == %d", 
                                       sheet, text, position)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    func getAnnotations(for sheet: Sheet) -> [Annotation] {
        let request: NSFetchRequest<Annotation> = Annotation.fetchRequest()
        request.predicate = NSPredicate(format: "sheet == %@", sheet)
        request.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true)]
        
        return (try? context.fetch(request)) ?? []
    }
    
    // MARK: - Text Processing
    
    func processAnnotatedText(_ text: String, for sheet: Sheet) -> String {
        // Process text to create/update annotations
        let annotatedRanges = parseAnnotations(in: text, for: sheet)
        
        // Update positions for existing annotations
        for range in annotatedRanges {
            if let annotation = range.annotation {
                annotation.position = Int32(range.range.location)
                annotation.modifiedAt = Date()
            }
        }
        
        saveContext()
        return text
    }
    
    func removeAnnotationBraces(from text: String, at range: NSRange) -> String {
        let nsText = text as NSString
        let beforeRange = NSRange(location: 0, length: range.location)
        let afterRange = NSRange(location: range.location + range.length, 
                                length: nsText.length - (range.location + range.length))
        
        let before = nsText.substring(with: beforeRange)
        let annotatedContent = nsText.substring(with: NSRange(location: range.location + 1, 
                                                             length: range.length - 2)) // Remove { }
        let after = nsText.substring(with: afterRange)
        
        return before + annotatedContent + after
    }
    
    // MARK: - Utility
    
    func getAnnotationAtPosition(_ position: Int, in text: String, for sheet: Sheet) -> (Annotation, NSRange)? {
        let annotatedRanges = parseAnnotations(in: text, for: sheet)
        
        for range in annotatedRanges {
            if range.range.contains(position), let annotation = range.annotation {
                return (annotation, range.range)
            }
        }
        
        return nil
    }
    
    // MARK: - Core Data
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Failed to save annotation context: \(error)")
        }
    }
}

// MARK: - Extensions

extension Annotation {
    var displayText: String {
        return annotatedText ?? "Annotation"
    }
    
    var displayContent: String {
        return content ?? ""
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modifiedAt ?? createdAt ?? Date())
    }
}

extension NSRange {
    func contains(_ position: Int) -> Bool {
        return position >= location && position < location + length
    }
}