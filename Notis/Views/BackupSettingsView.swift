//
//  BackupSettingsView.swift
//  Notis
//
//  Created by Claude on 11/5/25.
//

import SwiftUI

struct BackupSettingsView: View {
    @StateObject private var backupService = BackupService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingBackupList = false
    @State private var availableBackups: [BackupInfo] = []
    @State private var isLoadingBackups = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Backup Status Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Backup Status")
                    .font(.headline)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic Backups")
                            .font(.subheadline)
                            .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                        
                        Text(backupService.isBackupEnabled ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundColor(backupService.isBackupEnabled ? .green : .red)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $backupService.isBackupEnabled)
                }
                .padding()
                .background(UlyssesDesign.Colors.hover.opacity(0.3))
                .cornerRadius(8)
                
                if let lastBackup = backupService.lastBackupDate {
                    Text("Last backup: \(lastBackup.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
            }
            
            // Backup Schedule Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Backup Schedule")
                    .font(.headline)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                let backupInfo = backupService.getBackupInfo()
                
                BackupScheduleRow(
                    title: "Daily Backups",
                    description: "Keep 7 daily backups",
                    lastBackup: backupInfo.lastDaily,
                    icon: "clock"
                )
                
                BackupScheduleRow(
                    title: "Weekly Backups",
                    description: "Keep 4 weekly backups",
                    lastBackup: backupInfo.lastWeekly,
                    icon: "calendar"
                )
                
                BackupScheduleRow(
                    title: "Monthly Backups",
                    description: "Keep 12 monthly backups",
                    lastBackup: backupInfo.lastMonthly,
                    icon: "calendar.badge.clock"
                )
            }
            
            // Current Backup Status
            if backupService.isBackingUp {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text(backupService.backupStatus.description)
                        .font(.caption)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                .padding()
                .background(UlyssesDesign.Colors.accent.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Actions Section
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await backupService.performManualBackup()
                    }
                }) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up")
                        Text("Create Backup Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(backupService.isBackingUp || !backupService.isBackupEnabled)
                
                Button(action: {
                    loadAvailableBackups()
                    showingBackupList = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("View Backup History")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingBackups)
            }
            
            // Information Section
            VStack(alignment: .leading, spacing: 8) {
                Text("About Backups")
                    .font(.headline)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Backups are stored securely in your iCloud account")
                    Text("• Daily backups run automatically every 24 hours")
                    Text("• Weekly backups run every 7 days")
                    Text("• Monthly backups run every 30 days")
                    Text("• Old backups are automatically cleaned up")
                    Text("• All your notes, sheets, groups, and settings are included")
                }
                .font(.caption)
                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
            }
            .padding()
            .background(UlyssesDesign.Colors.hover.opacity(0.2))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Backup & Restore")
        .sheet(isPresented: $showingBackupList) {
            BackupListView(backups: availableBackups, isLoading: isLoadingBackups)
        }
    }
    
    private func loadAvailableBackups() {
        isLoadingBackups = true
        Task {
            do {
                let backups = try await backupService.getAvailableBackups()
                await MainActor.run {
                    self.availableBackups = backups
                    self.isLoadingBackups = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingBackups = false
                }
                print("Failed to load backups: \(error)")
            }
        }
    }
}

struct BackupScheduleRow: View {
    let title: String
    let description: String
    let lastBackup: Date?
    let icon: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(UlyssesDesign.Colors.accent)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                
                if let lastBackup = lastBackup {
                    Text("Last: \(lastBackup.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                } else {
                    Text("Never")
                        .font(.caption)
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                }
            }
            
            Spacer()
            
            if let lastBackup = lastBackup {
                let timeAgo = Date().timeIntervalSince(lastBackup)
                let daysAgo = Int(timeAgo / (24 * 60 * 60))
                
                if daysAgo == 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if daysAgo <= 7 {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            } else {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
            }
        }
        .padding()
        .background(UlyssesDesign.Colors.hover.opacity(0.3))
        .cornerRadius(8)
    }
}

struct BackupListView: View {
    let backups: [BackupInfo]
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var backupService = BackupService.shared
    @State private var availableBackups: [BackupInfo] = []
    @State private var isLoadingBackups = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoadingBackups {
                    VStack {
                        ProgressView()
                        Text("Loading backups...")
                            .font(.caption)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    }
                } else if availableBackups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "icloud.slash")
                            .font(.system(size: 48))
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                        
                        Text("No Backups Found")
                            .font(.headline)
                            .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                        
                        VStack(spacing: 8) {
                            if backupService.lastBackupDate != nil {
                                Text("Backups have been created but may not be visible yet due to iCloud sync.")
                                    .font(.subheadline)
                                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                                    .multilineTextAlignment(.center)
                                
                                Text("Try refreshing in a few minutes or create another backup.")
                                    .font(.caption)
                                    .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Enable automatic backups and create a backup to see your backup history here.")
                                    .font(.subheadline)
                                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding()
                } else {
                    List(availableBackups) { backup in
                        BackupRow(backup: backup)
                    }
                }
            }
            .navigationTitle("Backup History")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Initialize with passed data, then load fresh
                availableBackups = backups
                loadBackups()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Refresh") {
                        loadBackups()
                    }
                    .disabled(isLoadingBackups)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func loadBackups() {
        isLoadingBackups = true
        Task {
            do {
                let backups = try await backupService.getAvailableBackups()
                await MainActor.run {
                    self.availableBackups = backups
                    self.isLoadingBackups = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingBackups = false
                }
                print("Failed to load backups: \(error)")
            }
        }
    }
}

struct BackupRow: View {
    let backup: BackupInfo
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(backup.type.rawValue.capitalized + " Backup")
                        .font(.headline)
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    
                    Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if backup.isManual {
                        Text("Manual")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(UlyssesDesign.Colors.accent.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text("v\(backup.version)")
                        .font(.caption)
                        .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                }
            }
            
            if let deviceId = backup.deviceIdentifier {
                Text("Device: \(deviceId.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BackupSettingsView()
}