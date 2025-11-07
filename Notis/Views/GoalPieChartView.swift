//
//  GoalPieChartView.swift
//  Notis
//
//  Created by Claude on 11/7/25.
//
 
import SwiftUI
 
struct GoalPieChartView: View {
    let goal: Goal
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme
 
    private var progressColor: Color {
        if goal.isCompleted {
            return .green
        } else if goal.isOverdue {
            return .red
        } else {
            return UlyssesDesign.Colors.accent
        }
    }
 
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    UlyssesDesign.Colors.hover.opacity(0.3),
                    lineWidth: size * 0.12
                )
 
            // Progress arc
            Circle()
                .trim(from: 0, to: goal.progressPercentage)
                .stroke(
                    progressColor,
                    style: StrokeStyle(
                        lineWidth: size * 0.12,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: goal.progressPercentage)
 
            // Center content
            VStack(spacing: size * 0.05) {
                // Current/Target count
                Text("\(goal.currentCount)")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundColor(UlyssesDesign.Colors.primary(for: colorScheme))
 
                Text("/ \(goal.targetCount)")
                    .font(.system(size: size * 0.16, weight: .medium))
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
 
                // Type unit
                Text(goal.typeEnum.unit)
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
            }
 
            // Completion/overdue indicator
            if goal.isCompleted {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: size * 0.2))
                            .foregroundColor(.green)
                            .padding(size * 0.08)
                    }
                    Spacer()
                }
            } else if goal.isOverdue {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: size * 0.2))
                            .foregroundColor(.red)
                            .padding(size * 0.08)
                    }
                    Spacer()
                }
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    let goal = Goal(context: context)
    goal.id = UUID()
    goal.title = "Daily Writing Goal"
    goal.goalType = "words"
    goal.currentCount = 750
    goal.targetCount = 1000
    goal.isCompleted = false
    
    let completedGoal = Goal(context: context)
    completedGoal.id = UUID()
    completedGoal.title = "Completed Goal"
    completedGoal.goalType = "words"
    completedGoal.currentCount = 1000
    completedGoal.targetCount = 1000
    completedGoal.isCompleted = true
    
    return VStack(spacing: 40) {
        GoalPieChartView(goal: goal, size: 120)
        GoalPieChartView(goal: completedGoal, size: 120)
    }
    .padding()
}