//
//  ExportService.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import Foundation
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: (URL?) -> Void
    
    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion(urls.first)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(nil)
    }
}
#endif

class ExportService: ObservableObject {
    
    static let shared = ExportService()
    
    @Published var obsidianVaultPath: String = ""
    
    #if canImport(UIKit)
    private var documentPickerDelegate: DocumentPickerDelegate?
    private var vaultBookmark: Data?
    #endif
    
    let toastManager = ToastManager()
    
    private init() {
        // Load saved Obsidian vault path
        obsidianVaultPath = UserDefaults.standard.string(forKey: "obsidianVaultPath") ?? ""
        
        #if canImport(UIKit)
        // Load saved bookmark
        vaultBookmark = UserDefaults.standard.data(forKey: "obsidianVaultBookmark")
        #endif
    }
    
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
        case .obsidian:
            exportToObsidian(sheet: sheet)
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
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
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
        #else
        // For macOS, use NSSharingService or similar
        print("Share sheet not implemented for this platform")
        #endif
    }
    
    func copyToClipboard(_ content: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = content
        #elseif canImport(AppKit)
        NSPasteboard.general.setString(content, forType: .string)
        #endif
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
        case .obsidian:
            // For groups, export each sheet individually to Obsidian
            for sheet in sortedSheets {
                exportToObsidian(sheet: sheet)
            }
        }
    }
    
    // MARK: - Obsidian Export Functions
    
    func setObsidianVaultPath(_ path: String) {
        obsidianVaultPath = path
        UserDefaults.standard.set(path, forKey: "obsidianVaultPath")
    }
    
    #if canImport(UIKit)
    func setObsidianVaultURL(_ url: URL) {
        obsidianVaultPath = url.path
        UserDefaults.standard.set(url.path, forKey: "obsidianVaultPath")
        
        // Create and save security-scoped bookmark
        do {
            let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            vaultBookmark = bookmark
            UserDefaults.standard.set(bookmark, forKey: "obsidianVaultBookmark")
        } catch {
            print("Failed to create bookmark: \(error)")
        }
    }
    
    func clearObsidianVault() {
        obsidianVaultPath = ""
        vaultBookmark = nil
        UserDefaults.standard.removeObject(forKey: "obsidianVaultPath")
        UserDefaults.standard.removeObject(forKey: "obsidianVaultBookmark")
    }
    #endif
    
    func exportToObsidian(sheet: Sheet) {
        #if canImport(UIKit)
        // On iOS, always check for bookmark first
        guard let bookmark = vaultBookmark else {
            // No bookmark exists, need to select vault
            selectObsidianVaultPath { [weak self] in
                self?.exportToObsidian(sheet: sheet)
            }
            return
        }
        #else
        // On macOS, check for path
        guard !obsidianVaultPath.isEmpty else {
            // Prompt user to select Obsidian vault path
            selectObsidianVaultPath { [weak self] in
                self?.exportToObsidian(sheet: sheet)
            }
            return
        }
        #endif
        
        guard let content = sheet.content, !content.isEmpty else {
            print("No content to export to Obsidian")
            return
        }
        
        let title = sheet.title?.isEmpty == false ? sheet.title! : "Untitled"
        let filename = "\(title).md"
        
        // Create Obsidian note with metadata
        let obsidianContent = createObsidianNote(sheet: sheet)
        
        #if canImport(UIKit)
        // Use bookmark to access the vault directory on iOS
        do {
            var isStale = false
            let vaultURL = try URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // Bookmark is stale, need to re-select vault
                toastManager.show("❌ Vault access expired. Please reselect vault in Settings.")
                return
            }
            
            // Access the security-scoped resource
            guard vaultURL.startAccessingSecurityScopedResource() else {
                toastManager.show("❌ Unable to access vault directory")
                return
            }
            
            defer { vaultURL.stopAccessingSecurityScopedResource() }
            
            let filePath = vaultURL.appendingPathComponent(filename)
            try obsidianContent.write(to: filePath, atomically: true, encoding: .utf8)
            print("✅ Exported to Obsidian: \(filename)")
            toastManager.show("✅ Exported to Obsidian: \(title)")
            
        } catch {
            print("❌ Failed to export to Obsidian: \(error)")
            toastManager.show("❌ Export failed: \(error.localizedDescription)")
        }
        #else
        // macOS - use direct path access
        let filePath = URL(fileURLWithPath: obsidianVaultPath).appendingPathComponent(filename)
        do {
            try obsidianContent.write(to: filePath, atomically: true, encoding: .utf8)
            print("✅ Exported to Obsidian: \(filename)")
            toastManager.show("✅ Exported to Obsidian: \(title)")
        } catch {
            print("❌ Failed to export to Obsidian: \(error)")
            toastManager.show("❌ Export failed: \(error.localizedDescription)")
        }
        #endif
    }
    
    private func createObsidianNote(sheet: Sheet) -> String {
        let title = sheet.title?.isEmpty == false ? sheet.title! : "Untitled"
        let content = sheet.content ?? ""
        let createdAt = sheet.createdAt ?? Date()
        let modifiedAt = sheet.modifiedAt ?? Date()
        let wordCount = sheet.wordCount
        let groupName = sheet.group?.name ?? "Inbox"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var obsidianNote = """
        ---
        title: "\(title)"
        source: "Notis"
        created: "\(dateFormatter.string(from: createdAt))"
        modified: "\(dateFormatter.string(from: modifiedAt))"
        word_count: \(wordCount)
        group: "\(groupName)"
        tags: ["notis-import"]
        ---
        
        # \(title)
        
        \(content)
        """
        
        return obsidianNote
    }
    
    func selectObsidianVaultPath(completion: @escaping () -> Void = {}) {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your Obsidian vault folder"
        panel.prompt = "Select Vault"
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.setObsidianVaultPath(url.path)
                completion()
            }
        }
        #elseif canImport(UIKit)
        // For iOS, use UIDocumentPickerViewController
        DispatchQueue.main.async { [weak self] in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                print("Could not find window scene")
                return
            }
            
            // Find the topmost view controller
            var topViewController = window.rootViewController
            while let presentedViewController = topViewController?.presentedViewController {
                topViewController = presentedViewController
            }
            
            guard let presenter = topViewController else {
                print("Could not find presenter view controller")
                return
            }
            
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            documentPicker.allowsMultipleSelection = false
            documentPicker.shouldShowFileExtensions = false
            
            // Set initial directory to last used path if available
            if let vaultPath = self?.obsidianVaultPath, !vaultPath.isEmpty {
                let lastUsedURL = URL(fileURLWithPath: vaultPath)
                if FileManager.default.fileExists(atPath: lastUsedURL.path) {
                    documentPicker.directoryURL = lastUsedURL.deletingLastPathComponent()
                }
            }
            
            self?.documentPickerDelegate = DocumentPickerDelegate { [weak self] selectedURL in
                defer { self?.documentPickerDelegate = nil }
                if let selectedURL = selectedURL {
                    // Request access to the selected directory
                    _ = selectedURL.startAccessingSecurityScopedResource()
                    self?.setObsidianVaultURL(selectedURL)
                    completion()
                }
            }
            documentPicker.delegate = self?.documentPickerDelegate
            
            presenter.present(documentPicker, animated: true)
        }
        #else
        print("File picker not available on this platform")
        #endif
    }
}