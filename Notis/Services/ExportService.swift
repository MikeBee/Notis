//
//  ExportService.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import Foundation
import UIKit
import UniformTypeIdentifiers

class ExportService: ObservableObject {
    
    static let shared = ExportService()
    
    private init() {}
    
    enum ExportError: LocalizedError {
        case invalidContent
        case exportFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidContent:
                return "Invalid content to export"
            case .exportFailed:
                return "Export operation failed"
            }
        }
    }
    
    func exportSheet(_ sheet: Sheet, format: ExportFormat) {
        guard let content = sheet.content, !content.isEmpty else {
            print("No content to export")
            return
        }
        
        let title = sheet.title?.isEmpty == false ? sheet.title! : "Untitled"
        
        switch format {
        case .markdown:
            exportAsMarkdown(content: content, title: title)
        case .plainText:
            exportAsPlainText(content: content, title: title)
        }
    }
    
    private func exportAsMarkdown(content: String, title: String) {
        let filename = "\(title).md"
        let documentContent = content
        
        presentDocumentPicker(content: documentContent, filename: filename, contentType: UTType(filenameExtension: "md") ?? UTType.data)
    }
    
    private func exportAsPlainText(content: String, title: String) {
        let filename = "\(title).txt"
        
        // Convert markdown to plain text
        let plainTextContent = convertMarkdownToPlainText(content)
        
        presentDocumentPicker(content: plainTextContent, filename: filename, contentType: .plainText)
    }
    
    private func convertMarkdownToPlainText(_ markdown: String) -> String {
        var plainText = markdown
        
        // Remove headers
        plainText = plainText.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
        
        // Remove bold formatting
        plainText = plainText.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
        
        // Remove italic formatting
        plainText = plainText.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
        
        // Remove links but keep the text
        plainText = plainText.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        
        // Remove inline code
        plainText = plainText.replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
        
        // Remove list markers
        plainText = plainText.replacingOccurrences(of: #"^[\s]*[-*+]\s+"#, with: "", options: .regularExpression)
        plainText = plainText.replacingOccurrences(of: #"^[\s]*\d+\.\s+"#, with: "", options: .regularExpression)
        
        return plainText
    }
    
    private func presentDocumentPicker(content: String, filename: String, contentType: UTType) {
        guard let data = content.data(using: .utf8) else {
            print("Failed to convert content to data")
            return
        }
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: tempURL)
            
            // Present share sheet
            DispatchQueue.main.async {
                self.presentShareSheet(for: tempURL)
            }
        } catch {
            print("Failed to write temporary file: \(error)")
        }
    }
    
    private func presentShareSheet(for url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("Could not find root view controller")
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                      y: rootViewController.view.bounds.midY,
                                      width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true)
    }
    
    func copyToClipboard(_ content: String) {
        UIPasteboard.general.string = content
    }
    
    func exportGroup(_ group: Group, format: ExportFormat) {
        guard let sheets = group.sheets?.allObjects as? [Sheet],
              !sheets.isEmpty else {
            print("No sheets to export in group")
            return
        }
        
        let sortedSheets = sheets.sorted { ($0.sortOrder) < ($1.sortOrder) }
        var combinedContent = ""
        
        for (index, sheet) in sortedSheets.enumerated() {
            if index > 0 {
                combinedContent += "\n\n---\n\n"
            }
            
            if let title = sheet.title, !title.isEmpty {
                combinedContent += "# \(title)\n\n"
            }
            
            if let content = sheet.content {
                combinedContent += content
            }
        }
        
        let groupName = group.name?.isEmpty == false ? group.name! : "Untitled Group"
        
        switch format {
        case .markdown:
            exportAsMarkdown(content: combinedContent, title: groupName)
        case .plainText:
            exportAsPlainText(content: combinedContent, title: groupName)
        }
    }
}