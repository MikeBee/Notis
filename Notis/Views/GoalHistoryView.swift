//
//  GoalHistoryView.swift
//  Notis
//
//  Created by Claude on 11/7/25.
//
 
import SwiftUI
import CoreData

enum HistoryViewMode: String, CaseIterable {
    case singleDay = "single"
    case multiDay = "multi"
    
    var displayName: String {
        switch self {
        case .singleDay:
            return "Single Day"
        case .multiDay:
            return "Recent"
        }
    }
}
 
struct GoalHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var goalsService = GoalsService.shared
    @State private var recentHistory: [(goal: Goal, history: GoalHistory, date: Date)] = []
    @State private var selectedDate: Date = Date()
    @State private var historyData: [(goal: Goal, history: GoalHistory)] = []
    @State private var viewMode: HistoryViewMode = .singleDay
 
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    private var groupedByDate: [DateGroup] {
        let calendar = Calendar.current
        var groups: [Date: [(goal: Goal, history: GoalHistory, date: Date)]] = [:]

        for item in recentHistory {
            let startOfDay = calendar.startOfDay(for: item.date)
            if groups[startOfDay] == nil {
                groups[startOfDay] = []
            }
            groups[startOfDay]?.append(item)
        }

        return groups
            .map { DateGroup(date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    private struct DateGroup {
        let date: Date
        let items: [(goal: Goal, history: GoalHistory, date: Date)]
    }
 
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // View mode selector
                Picker("View Mode", selection: $viewMode) {
                    ForEach(HistoryViewMode.allCases, id: \.self) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(UlyssesDesign.Colors.hover.opacity(0.3))
                
                // Date picker (only shown for single day mode)
                if viewMode == .singleDay {
                HStack {
                    Button(action: previousDay) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                    }
                    .buttonStyle(PlainButtonStyle())
 
                    Spacer()
 
                    Text(dateFormatter.string(from: selectedDate))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
 
                    Spacer()
 
                    Button(action: nextDay) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(canGoToNextDay ? UlyssesDesign.Colors.primary(for: colorScheme) : UlyssesDesign.Colors.tertiary(for: colorScheme))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canGoToNextDay)
                }
                .padding()
                .background(UlyssesDesign.Colors.hover.opacity(0.3))
                }
 
                // History content
                if (viewMode == .singleDay && historyData.isEmpty) || (viewMode == .multiDay && recentHistory.isEmpty) {
                    VStack(spacing: UlyssesDesign.Spacing.md) {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
 
                        Text("No Goals History")
                            .font(UlyssesDesign.Typography.sheetMeta)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
 
                        Text(viewMode == .singleDay ? "No goal progress recorded on this date" : "No goal history available")
                            .font(.caption)
                            .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                    if viewMode == .singleDay {
                        LazyVStack(spacing: UlyssesDesign.Spacing.sm) {
                            ForEach(historyData, id: \.history.id) { item in
                                DailyGoalListRow(goal: item.goal, history: item.history, date: selectedDate)
                            }
                        }
                        .padding()
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(groupedByDate.enumerated()), id: \.offset) { index, group in
                                let isAlternate = index % 2 == 1

                                Section {
                                    ForEach(group.items, id: \.history.id) { item in
                                        DailyGoalListRow(goal: item.goal, history: item.history, date: item.date)
                                            .padding(.horizontal)
                                            .padding(.vertical, 4)
                                    }
                                } header: {
                                    HStack {
                                        Text(formatDateHeader(group.date))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                                        Spacer()
                                        Text("\(group.items.count) goal\(group.items.count == 1 ? "" : "s")")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(
                                        isAlternate
                                            ? Color.secondary.opacity(colorScheme == .dark ? 0.15 : 0.08)
                                            : Color.clear
                                    )
                                }
                                .background(
                                    isAlternate
                                        ? Color.secondary.opacity(colorScheme == .dark ? 0.10 : 0.05)
                                        : Color.clear
                                )
                            }
                        }
                        .padding(.top)
                    }
                }
                }
            }
            .navigationTitle("Goals History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            if viewMode == .singleDay {
                loadHistory()
            } else {
                loadRecentHistory()
            }
        }
        .onChange(of: selectedDate) { _, _ in
            if viewMode == .singleDay {
                loadHistory()
            }
        }
        .onChange(of: viewMode) { _, _ in
            if viewMode == .multiDay {
                loadRecentHistory()
            } else {
                loadHistory()
            }
        }
    }
 
    private var canGoToNextDay: Bool {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: selectedDate)!
        return tomorrow <= Date()
    }
 
    private func previousDay() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = newDate
        }
    }
 
    private func nextDay() {
        guard canGoToNextDay else { return }
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
            selectedDate = newDate
        }
    }
 
    private func loadHistory() {
        historyData = goalsService.getAllGoalHistoryForDate(selectedDate)
    }
    
    private func loadRecentHistory() {
        recentHistory = goalsService.getAllGoalHistoryRecent(limit: 50)
    }
}
 
#Preview {
    GoalHistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
