//
//  StorageDebugView.swift
//  Notis
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import CoreData

/// Debug view to display file storage statistics
/// Add this to Settings or as a toolbar item for testing
struct StorageDebugView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var stats: (total: Int, fileStorage: Int, coreData: Int, hybrid: Int) = (0, 0, 0, 0)
    @State private var baseDirectory: String = ""
    @State private var integrity: (valid: Int, missing: Int) = (0, 0)
    @State private var isMigrating: Bool = false
    @State private var migrationResult: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("File Storage Debug")
                .font(.title2)
                .fontWeight(.bold)

            Divider()

            // Storage Statistics
            VStack(alignment: .leading, spacing: 12) {
                Text("Storage Statistics")
                    .font(.headline)

                HStack {
                    Text("Total Sheets:")
                    Spacer()
                    Text("\(stats.total)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("File Storage:")
                    Spacer()
                    Text("\(stats.fileStorage)")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Core Data:")
                    Spacer()
                    Text("\(stats.coreData)")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Hybrid (Both):")
                    Spacer()
                    Text("\(stats.hybrid)")
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // File Integrity
            VStack(alignment: .leading, spacing: 12) {
                Text("File Integrity")
                    .font(.headline)

                HStack {
                    Text("Valid Files:")
                    Spacer()
                    Text("\(integrity.valid)")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Missing Files:")
                    Spacer()
                    Text("\(integrity.missing)")
                        .foregroundColor(integrity.missing > 0 ? .red : .secondary)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Directory Path
            VStack(alignment: .leading, spacing: 8) {
                Text("Storage Directory")
                    .font(.headline)

                Text(baseDirectory)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(5)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // File Listing
            VStack(alignment: .leading, spacing: 8) {
                Text("Files in Directory")
                    .font(.headline)

                if let files = listFiles() {
                    if files.isEmpty {
                        Text("No files found")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(files.prefix(10), id: \.self) { file in
                                    Text(file)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if files.count > 10 {
                                    Text("... and \(files.count - 10) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                } else {
                    Text("Directory doesn't exist")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Migration Result
            if let result = migrationResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Migration Result")
                        .font(.headline)

                    Text(result)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Actions
            VStack(spacing: 12) {
                Button(action: refreshStats) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Statistics")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                if integrity.missing > 0 {
                    Button(action: migrateFiles) {
                        HStack {
                            if isMigrating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "folder.badge.gearshape")
                                Text("Migrate Old Files to New Structure")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isMigrating)
                }

                Button(action: printDetailedStats) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Print to Console")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            refreshStats()
        }
    }

    private func listFiles() -> [String]? {
        let sheetsDir = FileStorageService.shared.getSheetsDirectory()
        let fileManager = FileManager.default

        // Check if directory exists
        guard fileManager.fileExists(atPath: sheetsDir.path) else {
            return nil
        }

        // List files
        do {
            let contents = try fileManager.contentsOfDirectory(at: sheetsDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            return contents.map { $0.lastPathComponent }.sorted()
        } catch {
            print("❌ Failed to list files: \(error)")
            return []
        }
    }

    private func refreshStats() {
        stats = FileStorageService.shared.getStorageStats(context: viewContext)
        baseDirectory = FileStorageService.shared.getSheetsDirectory().path
        integrity = FileStorageService.shared.verifyFileIntegrity(context: viewContext)
    }

    private func migrateFiles() {
        isMigrating = true
        migrationResult = nil

        // Run migration in background
        DispatchQueue.global(qos: .userInitiated).async {
            let result = FileStorageService.shared.migrateToNewFileStructure(context: viewContext)

            // Update UI on main thread
            DispatchQueue.main.async {
                isMigrating = false
                migrationResult = """
                Migrated: \(result.success)
                Failed: \(result.failed)
                Skipped: \(result.skipped)
                """

                // Refresh stats
                refreshStats()
            }
        }
    }

    private func printDetailedStats() {
        print("\n" + "=".repeating(60))
        print("FILE STORAGE DETAILED STATISTICS")
        print("=".repeating(60))

        FileStorageService.shared.printStorageStats(context: viewContext)

        print("\n📁 Storage Directory:")
        print(baseDirectory)

        print("\n🔍 File Integrity Check:")
        let (valid, missing) = FileStorageService.shared.verifyFileIntegrity(context: viewContext)
        print("✓ Valid: \(valid)")
        print("✗ Missing: \(missing)")

        // List individual sheets
        let fetchRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
        if let sheets = try? viewContext.fetch(fetchRequest) {
            print("\n📊 Individual Sheet Details:")
            for (index, sheet) in sheets.prefix(10).enumerated() {
                let title = sheet.title ?? "Untitled"
                let storageType = sheet.storageType
                let hasContent = !sheet.hybridContent.isEmpty
                print("\(index + 1). \(title)")
                print("   Storage: \(storageType)")
                print("   Has Content: \(hasContent)")
                if let fileURL = sheet.fileURL {
                    print("   File: \(fileURL)")
                }
            }

            if sheets.count > 10 {
                print("   ... and \(sheets.count - 10) more sheets")
            }
        }

        print("=".repeating(60) + "\n")
    }
}

extension String {
    func repeating(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

#Preview {
    StorageDebugView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
