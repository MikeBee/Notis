//
//  DatabaseHealthMonitor.swift
//  Notis
//
//  Created by Claude on 11/3/25.
//

import CoreData
import Foundation
import Combine
import SwiftUI

// MARK: - Real-time Health Monitoring

@MainActor
class DatabaseHealthMonitor: ObservableObject {
    private let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    private var healthCheckTimer: Timer?
    
    @Published var healthStatus: HealthStatus = .unknown
    @Published var metrics: HealthMetrics = HealthMetrics()
    @Published var recentIssues: [MaintenanceIssue] = []
    @Published var isMonitoring = false
    
    enum HealthStatus: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case critical = "Critical"
        case unknown = "Unknown"
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .yellow
            case .poor: return .orange
            case .critical: return .red
            case .unknown: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .excellent: return "checkmark.circle.fill"
            case .good: return "checkmark.circle"
            case .fair: return "exclamationmark.triangle"
            case .poor: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.circle.fill"
            case .unknown: return "questionmark.circle"
            }
        }
    }
    
    struct HealthMetrics {
        var totalSheets: Int = 0
        var totalGroups: Int = 0
        var totalWordCount: Int = 0
        var totalCharacterCount: Int = 0
        var orphanedRecords: Int = 0
        var duplicateRecords: Int = 0
        var inconsistentRecords: Int = 0
        var lastBackupDate: Date?
        var databaseSize: Int64 = 0
        var queryPerformance: TimeInterval = 0
        var syncStatus: String = "Unknown"
        var criticalIssueCount: Int = 0
        var mediumIssueCount: Int = 0
        var lowIssueCount: Int = 0
        
        var healthScore: Double {
            // Calculate health score out of 100
            var score: Double = 100
            
            // Deduct points for issues
            score -= Double(criticalIssueCount * 20) // 20 points per critical issue
            score -= Double(mediumIssueCount * 5)    // 5 points per medium issue
            score -= Double(lowIssueCount * 1)       // 1 point per low issue
            
            // Deduct points for performance issues
            if queryPerformance > 1.0 && queryPerformance.isFinite {
                score -= 10 // Poor performance
            }
            
            // Deduct points for large database without backup
            if databaseSize > 100_000_000 && lastBackupDate == nil { // 100MB
                score -= 15
            }
            
            let finalScore = max(0, min(100, score))
            return finalScore.isFinite ? finalScore : 0
        }
        
        var healthStatus: HealthStatus {
            let score = healthScore
            switch score {
            case 90...100: return .excellent
            case 75..<90: return .good
            case 60..<75: return .fair
            case 30..<60: return .poor
            case 0..<30: return .critical
            default: return .unknown
            }
        }
    }
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        setupNotificationObservers()
    }
    
    deinit {
        // Stop monitoring synchronously to avoid retain cycle
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    func startMonitoring(interval: TimeInterval = 300) { // Default 5 minutes
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Initial health check
        Task {
            await performHealthCheck()
        }
        
        // Schedule periodic health checks
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                await self.performHealthCheck()
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    func performHealthCheck() async {
        let startTime = Date()
        
        // Update basic metrics
        await updateBasicMetrics()
        
        // Perform quick issue scan
        let maintenance = DatabaseMaintenance(context: viewContext)
        let quickReport = await maintenance.quickHealthCheck()
        
        // Update health status based on issues
        updateHealthStatus(from: quickReport)
        
        // Update performance metric
        let performance = Date().timeIntervalSince(startTime)
        metrics.queryPerformance = performance.isFinite ? performance : 0
        healthStatus = metrics.healthStatus
        
        // Keep only recent issues (last 10)
        recentIssues = Array(quickReport.issues.prefix(10))
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        // Listen for Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    // Update metrics when data changes
                    if self?.isMonitoring == true {
                        await self?.updateBasicMetrics()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateBasicMetrics() async {
        do {
            // Count entities
            let sheetRequest: NSFetchRequest<Sheet> = Sheet.fetchRequest()
            sheetRequest.predicate = NSPredicate(format: "isInTrash == NO")
            let sheets = try viewContext.fetch(sheetRequest)
            
            let groupRequest: NSFetchRequest<Group> = Group.fetchRequest()
            let groups = try viewContext.fetch(groupRequest)
            
            // Calculate totals
            let totalWords = sheets.reduce(0) { $0 + Int($1.wordCount) }
            let totalChars = sheets.reduce(0) { total, sheet in
                total + (sheet.content?.count ?? 0)
            }
            
            // Check database file size
            let databaseSize = getDatabaseFileSize()
            
            // Update metrics
            metrics.totalSheets = sheets.count
            metrics.totalGroups = groups.count
            metrics.totalWordCount = totalWords
            metrics.totalCharacterCount = totalChars
            metrics.databaseSize = databaseSize
            
        } catch {
            print("Failed to update basic metrics: \(error)")
        }
    }
    
    private func updateHealthStatus(from report: MaintenanceReport) {
        let critical = report.issues.filter { $0.severity == .critical }.count
        let medium = report.issues.filter { $0.severity == .medium }.count
        let low = report.issues.filter { $0.severity == .low }.count
        
        metrics.criticalIssueCount = critical
        metrics.mediumIssueCount = medium
        metrics.lowIssueCount = low
        
        // Count specific issue types
        metrics.orphanedRecords = report.issues.filter { $0.type == .orphanedRecord }.count
        metrics.duplicateRecords = report.issues.filter { $0.type == .duplicate }.count
        metrics.inconsistentRecords = report.issues.filter { $0.type == .inconsistentData }.count
    }
    
    private func getDatabaseFileSize() -> Int64 {
        guard let storeCoordinator = viewContext.persistentStoreCoordinator,
              let store = storeCoordinator.persistentStores.first,
              let storeURL = store.url else {
            return 0
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: - Health Dashboard View

struct DatabaseHealthDashboard: View {
    let context: NSManagedObjectContext
    @State private var healthMonitor: DatabaseHealthMonitor?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    var body: some View {
        if let healthMonitor = healthMonitor {
            DatabaseHealthDashboardContent(healthMonitor: healthMonitor, context: context)
        } else {
            ProgressView("Loading...")
                .onAppear {
                    healthMonitor = DatabaseHealthMonitor(context: context)
                }
        }
    }
}

struct DatabaseHealthDashboardContent: View {
    @ObservedObject var healthMonitor: DatabaseHealthMonitor
    let context: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingMaintenanceView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Health Status Overview
                    healthStatusCard
                    
                    // Metrics Grid
                    metricsGrid
                    
                    // Recent Issues
                    if !healthMonitor.recentIssues.isEmpty {
                        recentIssuesSection
                    }
                    
                    // Actions
                    actionsSection
                }
                .padding(24)
            }
            .navigationTitle("Database Health")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(healthMonitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                        if healthMonitor.isMonitoring {
                            healthMonitor.stopMonitoring()
                        } else {
                            healthMonitor.startMonitoring()
                        }
                    }
                    .foregroundColor(healthMonitor.isMonitoring ? .red : .accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await healthMonitor.performHealthCheck()
                }
            }
            .onDisappear {
                healthMonitor.stopMonitoring()
            }
        }
        .sheet(isPresented: $showingMaintenanceView) {
            DatabaseMaintenanceView(context: context)
        }
    }
    
    private var healthStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: healthMonitor.healthStatus.icon)
                    .font(.system(size: 48))
                    .foregroundColor(healthMonitor.healthStatus.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Database Health")
                        .font(.headline)
                    
                    Text(healthMonitor.healthStatus.rawValue)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(healthMonitor.healthStatus.color)
                    
                    Text("Score: \(Int(healthMonitor.metrics.healthScore))/100")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Health Score Progress Bar
            let progressValue = healthMonitor.metrics.healthScore.isFinite ? healthMonitor.metrics.healthScore : 0
            ProgressView(value: progressValue, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: healthMonitor.healthStatus.color))
                .frame(height: 8)
            
            if healthMonitor.isMonitoring {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Real-time monitoring active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "Total Sheets",
                value: "\(healthMonitor.metrics.totalSheets)",
                icon: "doc.text",
                color: .blue
            )
            
            MetricCard(
                title: "Total Groups",
                value: "\(healthMonitor.metrics.totalGroups)",
                icon: "folder",
                color: .orange
            )
            
            MetricCard(
                title: "Word Count",
                value: formatNumber(healthMonitor.metrics.totalWordCount),
                icon: "textformat",
                color: .green
            )
            
            MetricCard(
                title: "Database Size",
                value: formatFileSize(healthMonitor.metrics.databaseSize),
                icon: "internaldrive",
                color: .purple
            )
            
            MetricCard(
                title: "Critical Issues",
                value: "\(healthMonitor.metrics.criticalIssueCount)",
                icon: "exclamationmark.triangle.fill",
                color: healthMonitor.metrics.criticalIssueCount > 0 ? .red : .gray
            )
            
            MetricCard(
                title: "Query Performance",
                value: "\(String(format: "%.2f", healthMonitor.metrics.queryPerformance))s",
                icon: "speedometer",
                color: healthMonitor.metrics.queryPerformance > 1.0 ? .red : .green
            )
        }
    }
    
    private var recentIssuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Issues")
                    .font(.headline)
                
                Spacer()
                
                Text("\(healthMonitor.recentIssues.count) found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(healthMonitor.recentIssues.prefix(5), id: \.id) { issue in
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(severityColor(issue.severity))
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.type.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text(issue.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Text(issue.severity.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(severityColor(issue.severity).opacity(0.2))
                            .foregroundColor(severityColor(issue.severity))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                    
                    if issue.id != healthMonitor.recentIssues.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingMaintenanceView = true
            }) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Run Full Maintenance")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button(action: {
                Task {
                    await healthMonitor.performHealthCheck()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Health Check")
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }
    
    private func severityColor(_ severity: MaintenanceIssue.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

#Preview {
    DatabaseHealthDashboard(context: PersistenceController.preview.container.viewContext)
}