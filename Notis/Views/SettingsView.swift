//
//  SettingsView.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 1.4
    @AppStorage("paragraphSpacing") private var paragraphSpacing: Double = 8
    @AppStorage("fontFamily") private var fontFamily: String = "system"
    @AppStorage("editorMargins") private var editorMargins: Double = 40
    @AppStorage("defaultGoalType") private var defaultGoalType: String = "words"
    @AppStorage("showWordCount") private var showWordCount: Bool = true
    @AppStorage("showCharacterCount") private var showCharacterCount: Bool = true
    @AppStorage("showReadingTime") private var showReadingTime: Bool = true
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback: Bool = true
    @AppStorage("showTagsPane") private var showTagsPane: Bool = true
    
    @State private var showingExportFilePicker = false
    @State private var showingImportFilePicker = false
    @State private var exportFormat: SettingsExportFormat = .json
    @State private var exportData: Data?
    @State private var exportFileName: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @StateObject private var backupService = BackupService.shared
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Appearance") {
                    HStack {
                        Text("Theme")
                        Spacer()
                        Picker("Theme", selection: $appState.theme) {
                            ForEach(AppState.AppTheme.allCases, id: \.self) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                Section("Typography") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font Family")
                            Spacer()
                            Picker("Font", selection: $fontFamily) {
                                Text("System").tag("system")
                                Text("Serif").tag("serif")
                                Text("Monospace").tag("monospace")
                                Text("Times").tag("times")
                                Text("Helvetica").tag("helvetica")
                                Text("Courier").tag("courier")
                                Text("Avenir").tag("avenir")
                                Text("Georgia").tag("georgia")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(Int(fontSize))pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $fontSize, in: 10...32, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Line Height")
                            Spacer()
                            Text(String(format: "%.1f", lineSpacing))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $lineSpacing, in: 1.0...3.0, step: 0.1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Paragraph Spacing")
                            Spacer()
                            Text("\(Int(paragraphSpacing))pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $paragraphSpacing, in: 0...24, step: 2)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Editor Margins")
                            Spacer()
                            if editorMargins == 0 {
                                Text("No margin")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(Int(editorMargins))pt")
                                    .foregroundColor(.secondary)
                            }
                        }
                        Slider(value: $editorMargins, in: 0...400, step: 5)
                    }
                }
                
                Section("Editor Behavior") {
                    Toggle("Typewriter Mode", isOn: $appState.isTypewriterMode)
                    Toggle("Focus Mode", isOn: $appState.isFocusMode)
                    Toggle("Show Markdown Header Symbols", isOn: $appState.showMarkdownHeaderSymbols)
                    Toggle("Hide Shortcut Bar", isOn: $appState.hideShortcutBar)
                    
                    HStack {
                        Text("Default Goal Type")
                        Spacer()
                        Picker("Goal Type", selection: $defaultGoalType) {
                            Text("Words").tag("words")
                            Text("Characters").tag("characters")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                Section("Statistics") {
                    Toggle("Show Word Count", isOn: $showWordCount)
                    Toggle("Show Character Count", isOn: $showCharacterCount)
                    Toggle("Show Reading Time", isOn: $showReadingTime)
                }
                
                Section("Interface") {
                    Toggle("Library Sidebar", isOn: $appState.showLibrary)
                    Toggle("Sheet List", isOn: $appState.showSheetList)
                    Toggle("Tags Pane", isOn: $showTagsPane)
                    Toggle("Sheet Navigation Bar", isOn: $appState.showSheetNavigation)
                    Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                }
                
                Section("Tag Management") {
                    HStack {
                        Text("Default Tag Sort")
                        Spacer()
                        Menu {
                            ForEach(TagSortOrder.allCases, id: \.self) { sortOrder in
                                Button(action: {
                                    TagService.shared.setSortOrder(sortOrder, ascending: true)
                                }) {
                                    HStack {
                                        Image(systemName: sortOrder.systemImage)
                                        Text(sortOrder.rawValue)
                                        if TagService.shared.currentSortOrder == sortOrder {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: TagService.shared.currentSortOrder.systemImage)
                                    .foregroundColor(.secondary)
                                Text(TagService.shared.currentSortOrder.rawValue)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                
                Section("Obsidian Integration") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Vault Path")
                            Spacer()
                        }
                        
                        if ExportService.shared.obsidianVaultPath.isEmpty {
                            Text("No vault selected")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            Text(ExportService.shared.obsidianVaultPath)
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .lineLimit(2)
                        }
                        
                        Button("Change Obsidian Vault Path") {
                            selectObsidianVault()
                        }
                        .foregroundColor(.accentColor)
                    }
                }
                
                Section("Data Management") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Export Format")
                            Spacer()
                            Picker("Export Format", selection: $exportFormat) {
                                Text("JSON").tag(SettingsExportFormat.json)
                                Text("Markdown Files").tag(SettingsExportFormat.markdown)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        Button("Export All Sheets") {
                            exportSheets()
                        }
                        .foregroundColor(.accentColor)
                    }
                    
                    Button("Import from JSON") {
                        showingImportFilePicker = true
                    }
                    .foregroundColor(.accentColor)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatic Backups")
                                .font(.body)
                            
                            if backupService.isBackupEnabled {
                                if let lastBackup = backupService.lastBackupDate {
                                    Text("Last backup: \(lastBackup, formatter: dateFormatter)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No backups yet")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Disabled")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Spacer()
                        
                        if backupService.isBackingUp {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Toggle("", isOn: $backupService.isBackupEnabled)
                        }
                    }
                    
                    NavigationLink(destination: BackupSettingsView()) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up.fill")
                                .foregroundColor(.accentColor)
                            Text("Backup & Restore")
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: DatabaseMaintenanceView(context: viewContext)) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.accentColor)
                            Text("Database Maintenance")
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: DatabaseHealthDashboard(context: viewContext)) {
                        HStack {
                            Image(systemName: "heart.text.square")
                                .foregroundColor(.green)
                            Text("Database Health Monitor")
                            Spacer()
                        }
                    }

                    NavigationLink(destination: StorageDebugView()) {
                        HStack {
                            Image(systemName: "doc.badge.gearshape")
                                .foregroundColor(.purple)
                            Text("File Storage Debug")
                            Spacer()
                        }
                    }

                    NavigationLink(destination: FileBasedStorageTestView()) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.blue)
                            Text("File-Based Storage Test")
                            Spacer()
                        }
                    }
                }
                
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.11")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("Phase 2: File Sync & Monitoring")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .fileExporter(
                isPresented: $showingExportFilePicker,
                document: ExportDocument(data: exportData ?? Data(), filename: exportFileName),
                contentType: exportFormat == .json ? .json : .plainText,
                defaultFilename: exportFileName
            ) { result in
                switch result {
                case .success:
                    alertMessage = "Export completed successfully!"
                    showingAlert = true
                case .failure(let error):
                    alertMessage = "Export failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
            .fileImporter(
                isPresented: $showingImportFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("Import/Export", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func exportSheets() {
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isInTrash == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Sheet.modifiedAt, ascending: false)]
        
        do {
            let sheets = try viewContext.fetch(fetchRequest)
            
            switch exportFormat {
            case .json:
                exportAsJSON(sheets: sheets)
            case .markdown:
                exportAsMarkdownFiles(sheets: sheets)
            }
        } catch {
            alertMessage = "Failed to fetch sheets: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func exportAsJSON(sheets: [Sheet]) {
        let exportData = sheets.map { sheet in
            ExportedSheet(
                id: sheet.id?.uuidString ?? UUID().uuidString,
                title: sheet.title ?? "Untitled",
                content: sheet.content ?? "",
                createdAt: sheet.createdAt ?? Date(),
                modifiedAt: sheet.modifiedAt ?? Date(),
                groupName: sheet.group?.name,
                wordCount: Int(sheet.wordCount),
                goalCount: Int(sheet.goalCount),
                goalType: sheet.goalType,
                isFavorite: sheet.isFavorite
            )
        }
        
        do {
            let jsonData = try JSONEncoder().encode(exportData)
            self.exportData = jsonData
            self.exportFileName = "notis-export-\(DateFormatter.exportFormatter.string(from: Date())).json"
            showingExportFilePicker = true
        } catch {
            alertMessage = "Failed to encode sheets: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func exportAsMarkdownFiles(sheets: [Sheet]) {
        // Export as a single combined markdown file for simplicity
        var combinedMarkdown = "# Notis Export\n\n"
        combinedMarkdown += "Exported on: \(DateFormatter.readableFormatter.string(from: Date()))\n\n"
        combinedMarkdown += "---\n\n"
        
        for (index, sheet) in sheets.enumerated() {
            if index > 0 {
                combinedMarkdown += "\n\n---\n\n"
            }
            
            combinedMarkdown += "# \(sheet.title ?? "Untitled")\n\n"
            
            if let content = sheet.content, !content.isEmpty {
                combinedMarkdown += content
            } else {
                combinedMarkdown += "*No content*"
            }
            
            combinedMarkdown += "\n\n"
            combinedMarkdown += "*Created: \(DateFormatter.readableFormatter.string(from: sheet.createdAt ?? Date()))*  \n"
            combinedMarkdown += "*Modified: \(DateFormatter.readableFormatter.string(from: sheet.modifiedAt ?? Date()))*  \n"
            combinedMarkdown += "*Words: \(sheet.wordCount)*"
            
            if sheet.isFavorite {
                combinedMarkdown += " ⭐"
            }
        }
        
        do {
            let markdownData = combinedMarkdown.data(using: .utf8) ?? Data()
            self.exportData = markdownData
            self.exportFileName = "notis-export-\(DateFormatter.exportFormatter.string(from: Date())).md"
            showingExportFilePicker = true
        } catch {
            alertMessage = "Failed to create markdown export: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let sheets = try JSONDecoder().decode([ExportedSheet].self, from: data)
                
                importSheets(sheets)
            } catch {
                alertMessage = "Failed to import: \(error.localizedDescription)"
                showingAlert = true
            }
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func importSheets(_ exportedSheets: [ExportedSheet]) {
        var importedCount = 0
        
        // Get or create default Inbox group
        let fetchRequest: NSFetchRequest<Group> = Group.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND parent == nil", "Imported")
        
        let targetGroup: Group
        if let existingGroup = try? viewContext.fetch(fetchRequest).first {
            targetGroup = existingGroup
        } else {
            let newGroup = Group(context: viewContext)
            newGroup.id = UUID()
            newGroup.name = "Imported"
            newGroup.createdAt = Date()
            newGroup.modifiedAt = Date()
            newGroup.sortOrder = 0
            targetGroup = newGroup
        }
        
        for exportedSheet in exportedSheets {
            let newSheet = Sheet(context: viewContext)
            newSheet.id = UUID(uuidString: exportedSheet.id) ?? UUID()
            newSheet.title = exportedSheet.title
            newSheet.content = exportedSheet.content
            newSheet.createdAt = exportedSheet.createdAt
            newSheet.modifiedAt = exportedSheet.modifiedAt
            newSheet.group = targetGroup
            newSheet.wordCount = Int32(exportedSheet.wordCount)
            newSheet.goalCount = Int32(exportedSheet.goalCount)
            newSheet.goalType = exportedSheet.goalType
            newSheet.isFavorite = exportedSheet.isFavorite
            newSheet.isInTrash = false
            newSheet.preview = String(exportedSheet.content.prefix(100))
            newSheet.sortOrder = Int32(importedCount)
            
            importedCount += 1
        }
        
        do {
            try viewContext.save()
            alertMessage = "Successfully imported \(importedCount) sheets!"
            showingAlert = true
        } catch {
            alertMessage = "Failed to save imported sheets: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return filename.components(separatedBy: invalidChars).joined(separator: "-")
    }
    
    private func selectObsidianVault() {
        // Trigger the vault selection from ExportService
        ExportService.shared.selectObsidianVaultPath {
            // Vault path has been updated
        }
    }
    
}

enum SettingsExportFormat: CaseIterable {
    case json
    case markdown
}

struct ExportedSheet: Codable {
    let id: String
    let title: String
    let content: String
    let createdAt: Date
    let modifiedAt: Date
    let groupName: String?
    let wordCount: Int
    let goalCount: Int
    let goalType: String?
    let isFavorite: Bool
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }
    
    let data: Data
    let filename: String
    
    init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }
    
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.filename = "export"
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

extension DateFormatter {
    static let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
    
    static let readableFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}


#Preview {
    @Previewable @State var isPresented = true
    
    return SettingsView(appState: AppState(), isPresented: $isPresented)
}