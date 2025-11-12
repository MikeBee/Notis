//
//  DatabaseMaintenanceView.swift
//  Notis
//
//  Created by Claude on 11/3/25.
//

import SwiftUI
import CoreData

struct DatabaseMaintenanceView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var maintenance: DatabaseMaintenance
    @State private var showingReport = false
    @State private var autoFixEnabled = false
    
    init(context: NSManagedObjectContext) {
        _maintenance = StateObject(wrappedValue: DatabaseMaintenance(context: context))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                
                if maintenance.isRunning {
                    runningSection
                } else {
                    actionSection
                }
                
                if let report = maintenance.lastReport {
                    lastReportSection(report)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Database Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingReport) {
            if let report = maintenance.lastReport {
                MaintenanceReportView(report: report, context: viewContext)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Database Health & Maintenance")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Keep your data clean and optimized")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var runningSection: some View {
        VStack(spacing: 16) {
            ProgressView(value: maintenance.progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text(maintenance.currentOperation)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("\(Int(maintenance.progress * 100))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            // Auto-fix toggle
            HStack {
                Toggle("Auto-fix detected issues", isOn: $autoFixEnabled)
                    .font(.subheadline)
                
                Button(action: {
                    // Show help about auto-fix
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            VStack(spacing: 12) {
                // Quick Health Check
                Button(action: {
                    Task {
                        _ = await maintenance.quickHealthCheck()
                        showingReport = true
                    }
                }) {
                    HStack {
                        Image(systemName: "heart.text.square")
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("Quick Health Check")
                                .font(.headline)
                            Text("Fast scan for critical issues")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Full Maintenance
                Button(action: {
                    Task {
                        _ = await maintenance.runFullMaintenance(autoFix: autoFixEnabled)
                        showingReport = true
                    }
                }) {
                    HStack {
                        Image(systemName: "gear.badge.checkmark")
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("Full Maintenance Scan")
                                .font(.headline)
                            Text("Complete database analysis and repair")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func lastReportSection(_ report: MaintenanceReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last Scan Results")
                    .font(.headline)
                
                Spacer()
                
                Button("View Details") {
                    showingReport = true
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            HStack(spacing: 16) {
                // Health Status
                HStack(spacing: 8) {
                    Image(systemName: report.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(report.isHealthy ? .green : .orange)
                    
                    Text(report.isHealthy ? "Healthy" : "Issues Found")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // Issue count
                if !report.issues.isEmpty {
                    Text("\(report.issues.count) issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Critical issues summary
            if !report.criticalIssues.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text("\(report.criticalIssues.count) critical issues require attention")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Scan info
            HStack {
                Text("Scanned \(report.totalEntitiesScanned) entities")
                Spacer()
                Text(formatDuration(report.duration))
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.1fs", duration)
        } else {
            return String(format: "%.0fs", duration)
        }
    }
}

struct MaintenanceReportView: View {
    let report: MaintenanceReport
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedSeverity: MaintenanceIssue.Severity?
    @State private var fixedIssues: Set<UUID> = []
    @StateObject private var maintenance: DatabaseMaintenance
    
    init(report: MaintenanceReport, context: NSManagedObjectContext) {
        self.report = report
        _maintenance = StateObject(wrappedValue: DatabaseMaintenance(context: context))
    }
    
    private var filteredIssues: [MaintenanceIssue] {
        let issues = report.issues.filter { !fixedIssues.contains($0.id) }
        if let severity = selectedSeverity {
            return issues.filter { $0.severity == severity }
        }
        return issues
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                reportHeader
                
                // Filters
                if !report.issues.isEmpty {
                    filterSection
                }
                
                // Issues list
                if filteredIssues.isEmpty {
                    emptyStateView
                } else {
                    issuesList
                }
            }
            .navigationTitle("Maintenance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var reportHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Database Health")
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Image(systemName: report.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(report.isHealthy ? .green : .orange)
                        
                        Text(report.isHealthy ? "Healthy" : "Issues Detected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(report.issues.count)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("issues found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !report.fixedIssues.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(report.fixedIssues.count) issues were automatically fixed")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                }
            }
            
            HStack {
                Text("Scanned \(report.totalEntitiesScanned) entities")
                Spacer()
                Text("Duration: \(formatDuration(report.duration))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button("All (\(report.issues.count))") {
                    selectedSeverity = nil
                }
                .buttonStyle(FilterButtonStyle(isSelected: selectedSeverity == nil))
                
                ForEach(MaintenanceIssue.Severity.allCases, id: \.self) { severity in
                    let count = report.issues.filter { $0.severity == severity }.count
                    if count > 0 {
                        Button("\(severity.rawValue) (\(count))") {
                            selectedSeverity = severity
                        }
                        .buttonStyle(FilterButtonStyle(isSelected: selectedSeverity == severity))
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("No Issues Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your database is in excellent condition!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var issuesList: some View {
        List(filteredIssues, id: \.id) { issue in
            IssueRowView(issue: issue) { issueToFix in
                Task {
                    let success = await maintenance.fixSingleIssue(issueToFix)
                    if success {
                        fixedIssues.insert(issueToFix.id)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.1fs", duration)
        } else {
            return String(format: "%.0fs", duration)
        }
    }
}

struct IssueRowView: View {
    let issue: MaintenanceIssue
    let onFix: ((MaintenanceIssue) -> Void)?
    
    init(issue: MaintenanceIssue, onFix: ((MaintenanceIssue) -> Void)? = nil) {
        self.issue = issue
        self.onFix = onFix
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Severity indicator
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.type.rawValue)
                        .font(.headline)
                    
                    if let entityTitle = issue.affectedEntityTitle {
                        Text(entityTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if let entity = issue.affectedEntity {
                        Text(entity)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(issue.severity.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(severityColor)
                    
                    if issue.canAutoFix {
                        Text("Auto-fixable")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Text(issue.description)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            // Entity dates if available
            if let createdAt = issue.affectedEntityCreatedAt,
               let modifiedAt = issue.affectedEntityModifiedAt {
                HStack {
                    Text("Created: \(formatDate(createdAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Modified: \(formatDate(modifiedAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Fix button
            if issue.canAutoFix, let onFix = onFix {
                HStack {
                    Spacer()
                    Button(action: {
                        onFix(issue)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.caption)
                            Text("Fix Issue")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var severityIcon: String {
        switch issue.severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.circle"
        case .low: return "info.circle"
        case .info: return "info.circle"
        }
    }
    
    private var severityColor: Color {
        switch issue.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct FilterButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    DatabaseMaintenanceView(context: PersistenceController.preview.container.viewContext)
}