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

    // Editor Settings (Global)
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 1.4
    @AppStorage("paragraphSpacing") private var paragraphSpacing: Double = 8
    @AppStorage("fontFamily") private var fontFamily: String = "system"
    @AppStorage("editorMargins") private var editorMargins: Double = 40
    @AppStorage("disableQuickType") private var disableQuickType: Bool = false
    @AppStorage("showLineNumbers") private var showLineNumbers: Bool = false

    // Heading Customization
    @AppStorage("h1Color") private var h1Color: String = "default"
    @AppStorage("h2Color") private var h2Color: String = "default"
    @AppStorage("h3Color") private var h3Color: String = "default"
    @AppStorage("h1SizeMultiplier") private var h1SizeMultiplier: Double = 1.5
    @AppStorage("h2SizeMultiplier") private var h2SizeMultiplier: Double = 1.3
    @AppStorage("h3SizeMultiplier") private var h3SizeMultiplier: Double = 1.1

    // Markdown Styling
    @AppStorage("highlightColor") private var highlightColor: String = "yellow"
    @AppStorage("annotationColor") private var annotationColor: String = "yellow"
    @AppStorage("strikethroughColor") private var strikethroughColor: String = "gray"

    // Writing Settings
    @AppStorage("defaultGoalType") private var defaultGoalType: String = "words"
    @AppStorage("showWordCount") private var showWordCount: Bool = true
    @AppStorage("showCharacterCount") private var showCharacterCount: Bool = true
    @AppStorage("showReadingTime") private var showReadingTime: Bool = true

    // Interface Settings
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback: Bool = true
    @AppStorage("showTagsPane") private var showTagsPane: Bool = true

    // Export/Import State
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
                // MARK: - Editor
                Section {
                    // Typography
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

                    HStack {
                        Text("Font Size")
                        Slider(value: $fontSize, in: 10...32, step: 1)
                        Text("\(Int(fontSize))pt")
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }

                    HStack {
                        Text("Line Height")
                        Slider(value: $lineSpacing, in: 1.0...3.0, step: 0.1)
                        Text(String(format: "%.1f", lineSpacing))
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }

                    HStack {
                        Text("Paragraph Spacing")
                        Slider(value: $paragraphSpacing, in: 0...24, step: 2)
                        Text("\(Int(paragraphSpacing))pt")
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }

                    HStack {
                        Text("Editor Margins")
                        Slider(value: $editorMargins, in: 0...400, step: 5)
                        Text(editorMargins == 0 ? "None" : "\(Int(editorMargins))pt")
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }

                    // Behavior
                    Toggle("Typewriter Mode", isOn: $appState.isTypewriterMode)
                    Toggle("Focus Mode", isOn: $appState.isFocusMode)
                    Toggle("Show Markdown Header Symbols", isOn: $appState.showMarkdownHeaderSymbols)
                    Toggle("Show Line Numbers", isOn: $showLineNumbers)

                    // Keyboard
                    Toggle("Disable QuickType", isOn: $disableQuickType)
                        .help("Turn off predictive text and autocomplete suggestions")
                    Toggle("Hide Shortcut Bar", isOn: $appState.hideShortcutBar)

                } header: {
                    Label("Editor", systemImage: "pencil.line")
                }

                // MARK: - Markdown Headers
                Section {
                    // H1 - Color + Size in one row
                    HStack {
                        Text("H1")
                            .frame(width: 30, alignment: .leading)
                        Menu {
                            ForEach(headingColorOptions, id: \.name) { option in
                                Button(action: {
                                    h1Color = option.name
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(option.color)
                                            .frame(width: 16, height: 16)
                                        Text(option.name.capitalized)
                                        if h1Color == option.name {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Circle()
                                .fill(colorFromName(h1Color))
                                .frame(width: 20, height: 20)
                        }
                        Slider(value: $h1SizeMultiplier, in: 1.0...3.0, step: 0.1)
                        Text(String(format: "%.1fx", h1SizeMultiplier))
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }

                    // H2 - Color + Size in one row
                    HStack {
                        Text("H2")
                            .frame(width: 30, alignment: .leading)
                        Menu {
                            ForEach(headingColorOptions, id: \.name) { option in
                                Button(action: {
                                    h2Color = option.name
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(option.color)
                                            .frame(width: 16, height: 16)
                                        Text(option.name.capitalized)
                                        if h2Color == option.name {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Circle()
                                .fill(colorFromName(h2Color))
                                .frame(width: 20, height: 20)
                        }
                        Slider(value: $h2SizeMultiplier, in: 1.0...2.5, step: 0.1)
                        Text(String(format: "%.1fx", h2SizeMultiplier))
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }

                    // H3 - Color + Size in one row
                    HStack {
                        Text("H3")
                            .frame(width: 30, alignment: .leading)
                        Menu {
                            ForEach(headingColorOptions, id: \.name) { option in
                                Button(action: {
                                    h3Color = option.name
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(option.color)
                                            .frame(width: 16, height: 16)
                                        Text(option.name.capitalized)
                                        if h3Color == option.name {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Circle()
                                .fill(colorFromName(h3Color))
                                .frame(width: 20, height: 20)
                        }
                        Slider(value: $h3SizeMultiplier, in: 1.0...2.0, step: 0.1)
                        Text(String(format: "%.1fx", h3SizeMultiplier))
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }
                } header: {
                    Label("Markdown Headers", systemImage: "textformat.size")
                }

                // MARK: - Markdown Styling
                Section {
                    HStack {
                        Text("Highlight ==")
                        Spacer()
                        Menu {
                            ForEach(headingColorOptions, id: \.name) { option in
                                Button(action: {
                                    highlightColor = option.name
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(option.color)
                                            .frame(width: 16, height: 16)
                                        Text(option.name.capitalized)
                                        if highlightColor == option.name {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Circle()
                                .fill(colorFromName(highlightColor))
                                .frame(width: 20, height: 20)
                        }
                    }

                    HStack {
                        Text("Annotation {}")
                        Spacer()
                        Menu {
                            ForEach(headingColorOptions, id: \.name) { option in
                                Button(action: {
                                    annotationColor = option.name
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(option.color)
                                            .frame(width: 16, height: 16)
                                        Text(option.name.capitalized)
                                        if annotationColor == option.name {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Circle()
                                .fill(colorFromName(annotationColor))
                                .frame(width: 20, height: 20)
                        }
                    }

                    HStack {
                        Text("Strikethrough")
                        Spacer()
                        Menu {
                            ForEach(headingColorOptions, id: \.name) { option in
                                Button(action: {
                                    strikethroughColor = option.name
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(option.color)
                                            .frame(width: 16, height: 16)
                                        Text(option.name.capitalized)
                                        if strikethroughColor == option.name {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Circle()
                                .fill(colorFromName(strikethroughColor))
                                .frame(width: 20, height: 20)
                        }
                    }
                } header: {
                    Label("Markdown Styling", systemImage: "paintbrush")
                }

                // MARK: - Appearance
                Section {
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

                    Toggle("Library Sidebar", isOn: $appState.showLibrary)
                    Toggle("Sheet List", isOn: $appState.showSheetList)
                    Toggle("Sheet Navigation Bar", isOn: $appState.showSheetNavigation)
                    Toggle("Tags Pane", isOn: $showTagsPane)

                } header: {
                    Label("Appearance", systemImage: "paintbrush.fill")
                }

                // MARK: - Icon Manager
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Global Status Bar Icons")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Toggle("Template Icon", isOn: $appState.showTemplateIcon)
                        Toggle("Dashboard Icon", isOn: $appState.showDashboardIcon)
                        Toggle("Help Icon", isOn: $appState.showHelpIcon)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Editor Icons")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Toggle("Navigation Buttons", isOn: $appState.showNavigationButtons)
                        Toggle("Favorite Icon", isOn: $appState.showFavoriteIcon)
                        Toggle("Outline Toggle", isOn: $appState.showOutlineIcon)
                        Toggle("Read-Only Mode", isOn: $appState.showReadOnlyIcon)
                        Toggle("Full Screen Icon", isOn: $appState.showFullScreenIcon)
                        Toggle("Word Counter", isOn: $appState.showWordCounter)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sheet List Icons")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Toggle("Editor Only Icon", isOn: $appState.showEditorOnlyIcon)
                    }

                    Text("Note: Settings icon, Library pane viewer, and Library pane icons cannot be toggled.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                } header: {
                    Label("Icon Manager", systemImage: "app.badge")
                } footer: {
                    Text("Control which icons appear in the status bar, editor, and sheet list.")
                        .font(.caption)
                }

                // MARK: - Writing
                Section {
                    HStack {
                        Text("Default Goal Type")
                        Spacer()
                        Picker("Goal Type", selection: $defaultGoalType) {
                            Text("Words").tag("words")
                            Text("Characters").tag("characters")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    Toggle("Show Word Count", isOn: $showWordCount)
                    Toggle("Show Character Count", isOn: $showCharacterCount)
                    Toggle("Show Reading Time", isOn: $showReadingTime)

                } header: {
                    Label("Writing & Statistics", systemImage: "chart.bar.fill")
                }

                // MARK: - Tags
                Section {
                    HStack {
                        Text("Default Sort Order")
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
                } header: {
                    Label("Tag Management", systemImage: "tag.fill")
                }

                // MARK: - System
                Section {
                    Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                } header: {
                    Label("System", systemImage: "gearshape.fill")
                }

                // MARK: - Integrations
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Obsidian Vault Path")
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

                        Button("Change Vault Path") {
                            selectObsidianVault()
                        }
                        .foregroundColor(.accentColor)
                    }
                } header: {
                    Label("Obsidian Integration", systemImage: "link.circle.fill")
                }

                // MARK: - Data & Backup
                Section {
                    // Export
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

                    // Import
                    Button("Import from JSON") {
                        showingImportFilePicker = true
                    }
                    .foregroundColor(.accentColor)

                    // Backup
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
                } header: {
                    Label("Data & Backup", systemImage: "externaldrive.fill")
                }

                // MARK: - Browse Tools
                Section {
                    NavigationLink(destination: FolderBrowserView()) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            Text("Browse by Folder")
                            Spacer()
                        }
                    }

                    NavigationLink(destination: TagsBrowserView()) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.orange)
                            Text("Browse by Tag")
                            Spacer()
                        }
                    }

                    NavigationLink(destination: EnhancedSearchView()) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.purple)
                            Text("Full-Text Search")
                            Spacer()
                        }
                    }
                } header: {
                    Label("Browse Tools", systemImage: "doc.text.magnifyingglass")
                }

                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.26")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("Phase 5: Robustness & Polish")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Label("About", systemImage: "info.circle.fill")
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

    // MARK: - Export Functions

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
        // Helper function to build path from root to group
        func buildGroupPath(_ group: Group) -> [String] {
            var path: [String] = []
            var current: Group? = group
            while let g = current {
                path.insert(g.name ?? "Untitled", at: 0)
                current = g.parent
            }
            return path
        }

        // Helper function to build parent path (excludes the group itself)
        func buildParentPath(_ group: Group) -> [String]? {
            guard let parent = group.parent else { return nil }
            return buildGroupPath(parent)
        }

        // Export sheets with group paths
        let exportedSheets = sheets.map { sheet in
            let groupPath = sheet.group.flatMap { buildGroupPath($0) }
            return ExportedSheet(
                id: sheet.id?.uuidString ?? UUID().uuidString,
                title: sheet.title ?? "Untitled",
                content: sheet.unifiedContent,
                createdAt: sheet.createdAt ?? Date(),
                modifiedAt: sheet.modifiedAt ?? Date(),
                groupName: sheet.group?.name,
                groupPath: groupPath,
                wordCount: Int(sheet.wordCount),
                goalCount: Int(sheet.goalCount),
                goalType: sheet.goalType,
                isFavorite: sheet.isFavorite
            )
        }

        // Collect all unique groups from sheets
        let allGroups = Set(sheets.compactMap { $0.group })

        // Also need to include all ancestor groups (parents of parents)
        var groupsToExport = Set<Group>()
        for group in allGroups {
            var current: Group? = group
            while let g = current {
                groupsToExport.insert(g)
                current = g.parent
            }
        }

        // Export groups with metadata
        let exportedGroups = groupsToExport.map { group in
            let groupId = group.id?.uuidString ?? UUID().uuidString
            let icon = UserDefaults.standard.string(forKey: "group_icon_\(groupId)")
            let color = UserDefaults.standard.string(forKey: "group_color_\(groupId)")

            return ExportedGroup(
                id: groupId,
                name: group.name ?? "Untitled",
                sortOrder: Int(group.sortOrder),
                parentPath: buildParentPath(group),
                icon: icon,
                color: color,
                isFavorite: group.isFavorite,
                createdAt: group.createdAt ?? Date(),
                modifiedAt: group.modifiedAt ?? Date()
            )
        }.sorted { $0.sortOrder < $1.sortOrder } // Sort by sortOrder for proper reconstruction

        let fullExportData = ExportData(
            sheets: exportedSheets,
            groups: exportedGroups,
            exportedAt: Date()
        )

        do {
            let jsonData = try JSONEncoder().encode(fullExportData)
            self.exportData = jsonData
            self.exportFileName = "notis-export-\(DateFormatter.exportFormatter.string(from: Date())).json"
            showingExportFilePicker = true
        } catch {
            alertMessage = "Failed to encode sheets: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func exportAsMarkdownFiles(sheets: [Sheet]) {
        var combinedMarkdown = "# Notis Export\n\n"
        combinedMarkdown += "Exported on: \(DateFormatter.readableFormatter.string(from: Date()))\n\n"
        combinedMarkdown += "---\n\n"

        for (index, sheet) in sheets.enumerated() {
            if index > 0 {
                combinedMarkdown += "\n\n---\n\n"
            }

            combinedMarkdown += "# \(sheet.title ?? "Untitled")\n\n"

            let content = sheet.unifiedContent
            if !content.isEmpty {
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

    // MARK: - Import Functions

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let data = try Data(contentsOf: url)

                // Try new format first (ExportData with groups)
                if let fullExport = try? JSONDecoder().decode(ExportData.self, from: data) {
                    importFullData(fullExport)
                } else {
                    // Fall back to old format (just sheets array)
                    let sheets = try JSONDecoder().decode([ExportedSheet].self, from: data)
                    importSheets(sheets, groups: [])
                }
            } catch {
                alertMessage = "Failed to import: \(error.localizedDescription)"
                showingAlert = true
            }
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func importFullData(_ exportData: ExportData) {
        // First, reconstruct all groups with hierarchy
        let groupsByPath = reconstructGroups(exportData.groups)

        // Then import sheets using the reconstructed groups
        importSheets(exportData.sheets, groups: exportData.groups, groupsByPath: groupsByPath)
    }

    private func reconstructGroups(_ exportedGroups: [ExportedGroup]) -> [String: Group] {
        var groupsByPath: [String: Group] = [:]
        var groupsById: [String: Group] = [:]

        // Sort groups by depth (root groups first, then children)
        let sortedGroups = exportedGroups.sorted { (g1, g2) in
            let depth1 = g1.parentPath?.count ?? 0
            let depth2 = g2.parentPath?.count ?? 0
            if depth1 != depth2 {
                return depth1 < depth2
            }
            return g1.sortOrder < g2.sortOrder
        }

        for exportedGroup in sortedGroups {
            // Build the full path for this group
            var fullPath = exportedGroup.parentPath ?? []
            fullPath.append(exportedGroup.name)
            let pathKey = fullPath.joined(separator: "/")

            // Find or create the group
            let group: Group
            if let existingGroup = groupsById[exportedGroup.id] {
                group = existingGroup
            } else {
                // Check if group exists in database by name and parent
                let fetchRequest: NSFetchRequest<Group> = Group.fetchRequest()
                if let parentPath = exportedGroup.parentPath, !parentPath.isEmpty {
                    let parentKey = parentPath.joined(separator: "/")
                    if let parentGroup = groupsByPath[parentKey] {
                        fetchRequest.predicate = NSPredicate(format: "name == %@ AND parent == %@", exportedGroup.name, parentGroup)
                    } else {
                        fetchRequest.predicate = NSPredicate(format: "name == %@", exportedGroup.name)
                    }
                } else {
                    fetchRequest.predicate = NSPredicate(format: "name == %@ AND parent == nil", exportedGroup.name)
                }

                if let existingGroup = try? viewContext.fetch(fetchRequest).first {
                    group = existingGroup
                } else {
                    // Create new group
                    group = Group(context: viewContext)
                    group.id = UUID(uuidString: exportedGroup.id) ?? UUID()
                    group.name = exportedGroup.name
                    group.createdAt = exportedGroup.createdAt
                    group.modifiedAt = exportedGroup.modifiedAt
                }

                group.sortOrder = Int32(exportedGroup.sortOrder)
                group.isFavorite = exportedGroup.isFavorite

                // Set parent relationship
                if let parentPath = exportedGroup.parentPath, !parentPath.isEmpty {
                    let parentKey = parentPath.joined(separator: "/")
                    group.parent = groupsByPath[parentKey]
                } else {
                    group.parent = nil
                }

                groupsById[exportedGroup.id] = group
            }

            groupsByPath[pathKey] = group

            // Restore icon and color from UserDefaults
            if let icon = exportedGroup.icon {
                UserDefaults.standard.set(icon, forKey: "group_icon_\(exportedGroup.id)")
            }
            if let color = exportedGroup.color {
                UserDefaults.standard.set(color, forKey: "group_color_\(exportedGroup.id)")
            }
        }

        return groupsByPath
    }

    private func importSheets(_ exportedSheets: [ExportedSheet], groups: [ExportedGroup], groupsByPath: [String: Group] = [:]) {
        var importedCount = 0
        var groupCounters: [String: Int32] = [:] // Track number of sheets added to each group

        for exportedSheet in exportedSheets {
            // Find the target group using groupPath if available
            let targetGroup: Group?
            let targetGroupKey: String

            if let groupPath = exportedSheet.groupPath, !groupPath.isEmpty {
                let pathKey = groupPath.joined(separator: "/")
                targetGroupKey = pathKey
                targetGroup = groupsByPath[pathKey]
            } else if let groupName = exportedSheet.groupName {
                // Fallback to simple name lookup (for backward compatibility)
                targetGroupKey = groupName
                let fetchRequest: NSFetchRequest<Group> = Group.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@ AND parent == nil", groupName)
                targetGroup = try? viewContext.fetch(fetchRequest).first
            } else {
                targetGroupKey = "Imported"
                targetGroup = nil
            }

            // Create "Imported" group if no group found
            let finalGroup: Group
            if let group = targetGroup {
                finalGroup = group
            } else {
                let fetchRequest: NSFetchRequest<Group> = Group.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@ AND parent == nil", "Imported")

                if let existingGroup = try? viewContext.fetch(fetchRequest).first {
                    finalGroup = existingGroup
                } else {
                    let newGroup = Group(context: viewContext)
                    newGroup.id = UUID()
                    newGroup.name = "Imported"
                    newGroup.createdAt = Date()
                    newGroup.modifiedAt = Date()
                    newGroup.sortOrder = 0
                    finalGroup = newGroup
                }
            }

            // Find max sort order in target group (only once per group)
            if groupCounters[targetGroupKey] == nil {
                let maxSortOrder: Int32
                if let sheets = finalGroup.sheets as? Set<Sheet>, !sheets.isEmpty {
                    maxSortOrder = sheets.map { $0.sortOrder }.max() ?? -1
                } else {
                    maxSortOrder = -1
                }
                groupCounters[targetGroupKey] = maxSortOrder + 1
            }

            // Create new sheet
            let newSheet = Sheet(context: viewContext)
            newSheet.id = UUID(uuidString: exportedSheet.id) ?? UUID()
            newSheet.title = exportedSheet.title
            newSheet.content = exportedSheet.content
            newSheet.createdAt = exportedSheet.createdAt
            newSheet.modifiedAt = exportedSheet.modifiedAt
            newSheet.group = finalGroup
            newSheet.wordCount = Int32(exportedSheet.wordCount)
            newSheet.goalCount = Int32(exportedSheet.goalCount)
            newSheet.goalType = exportedSheet.goalType
            newSheet.isFavorite = exportedSheet.isFavorite
            newSheet.isInTrash = false

            // Generate proper preview (match app's preview generation logic)
            let trimmed = exportedSheet.content.trimmingCharacters(in: .whitespacesAndNewlines)
            newSheet.preview = trimmed.count <= 200 ? trimmed : String(trimmed.prefix(200)) + "..."

            // Set sort order to avoid duplicates (increment counter for this group)
            newSheet.sortOrder = groupCounters[targetGroupKey]!
            groupCounters[targetGroupKey]! += 1

            importedCount += 1
        }

        do {
            try viewContext.save()
            let groupCount = groups.isEmpty ? groupCounters.count : groups.count
            alertMessage = "Successfully imported \(importedCount) sheets into \(groupCount) group(s)!"
            showingAlert = true
        } catch {
            alertMessage = "Failed to save imported sheets: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func selectObsidianVault() {
        ExportService.shared.selectObsidianVaultPath {
            // Vault path has been updated
        }
    }

    // MARK: - Heading Color Helpers

    private var headingColorOptions: [(name: String, color: Color)] {
        [
            ("default", .primary),
            ("blue", .blue),
            ("purple", .purple),
            ("pink", .pink),
            ("red", .red),
            ("orange", .orange),
            ("yellow", .yellow),
            ("green", .green),
            ("teal", .teal),
            ("indigo", .indigo),
            ("cyan", .cyan),
            ("mint", .mint),
            ("brown", .brown),
            ("gray", .gray)
        ]
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "indigo": return .indigo
        case "cyan": return .cyan
        case "mint": return .mint
        case "brown": return .brown
        case "gray": return .gray
        default: return .primary
        }
    }
}

// MARK: - Supporting Types

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
    let groupPath: [String]? // Full path from root to group (e.g., ["Parent", "Child"])
    let wordCount: Int
    let goalCount: Int
    let goalType: String?
    let isFavorite: Bool
}

struct ExportedGroup: Codable {
    let id: String
    let name: String
    let sortOrder: Int
    let parentPath: [String]? // Path to parent group (nil for root groups)
    let icon: String?
    let color: String?
    let isFavorite: Bool
    let createdAt: Date
    let modifiedAt: Date
}

struct ExportData: Codable {
    let sheets: [ExportedSheet]
    let groups: [ExportedGroup]
    let exportedAt: Date
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
