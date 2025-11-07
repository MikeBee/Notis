//
//  GoalHistoryView.swift
//  Notis
//
//  Created by Claude on 11/7/25.
//
 
import SwiftUI
import CoreData
 
struct GoalHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var goalsService = GoalsService.shared
    @State private var selectedDate: Date = Date()
    @State private var historyData: [(goal: Goal, history: GoalHistory)] = []
 
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
 
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Date picker
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
 
                // History content
                if historyData.isEmpty {
                    VStack(spacing: UlyssesDesign.Spacing.md) {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
 
                        Text("No Goal History")
                            .font(UlyssesDesign.Typography.sheetMeta)
                            .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
 
                        Text("No goals were tracked on this date")
                            .font(.caption)
                            .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: UlyssesDesign.Spacing.md) {
                            ForEach(historyData, id: \.history.id) { item in
                                HistoryCard(goal: item.goal, history: item.history)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Goal History")
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
            loadHistory()
        }
        .onChange(of: selectedDate) { _, _ in
            loadHistory()
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
}
 
struct HistoryCard: View {
    let goal: Goal
    let history: GoalHistory
    @Environment(\.colorScheme) private var colorScheme
 
    private var progressPercentage: Double {
        guard history.targetCount > 0 else { return 0 }
        return min(1.0, Double(history.completedCount) / Double(history.targetCount))
    }
 
    private var progressColor: Color {
        if history.wasCompleted {
            return .green
        } else {
            return UlyssesDesign.Colors.accent
        }
    }
 
    var body: some View {
        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.sm) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
                        .lineLimit(1)
 
                    Text(goal.typeEnum.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                }
 
                Spacer()
 
                if history.wasCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
            }
 
            // Progress bar
            VStack(spacing: 4) {
                HStack {
                    Text("\(history.completedCount) / \(history.targetCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
 
                    Spacer()
 
                    Text("\(Int(progressPercentage * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(progressColor)
                }
 
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(UlyssesDesign.Colors.hover.opacity(0.3))
                            .frame(height: 6)
                            .cornerRadius(3)
 
                        Rectangle()
                            .fill(progressColor)
                            .frame(width: geometry.size.width * progressPercentage, height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(UlyssesDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.medium)
                .fill(UlyssesDesign.Colors.hover.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.medium)
                .stroke(progressColor.opacity(0.3), lineWidth: 1)
        )
    }
}
 
#Preview {
    GoalHistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
