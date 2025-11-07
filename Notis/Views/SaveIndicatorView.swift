//
//  SaveIndicatorView.swift
//  Notis
//
//  Created by Mike on 11/3/25.
//

import SwiftUI

enum SaveState: Equatable {
    case idle
    case saving
    case saved
    case error(String)
}

struct SaveIndicatorView: View {
    let state: SaveState
    @State private var isAnimating = false
    @State private var showCheckmark = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: UlyssesDesign.Spacing.xs) {
            switch state {
            case .idle:
                EmptyView()
                
            case .saving:
                Image(systemName: "doc.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(UlyssesDesign.Colors.accent)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
                
                Text("Saving...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                    .scaleEffect(showCheckmark ? 1.2 : 0.8)
                    .onAppear {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showCheckmark = true
                        }
                        
                        // Hide after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showCheckmark = false
                            }
                        }
                    }
                
                Text("Saved")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                    .opacity(showCheckmark ? 1 : 0)
                
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, UlyssesDesign.Spacing.sm)
        .padding(.vertical, UlyssesDesign.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: UlyssesDesign.CornerRadius.small)
                .fill(UlyssesDesign.Colors.background(for: colorScheme))
                .opacity(state == .idle ? 0 : 1)
        )
        .animation(UlyssesDesign.Animations.quick, value: state)
    }
}

struct WordCountAnimatedView: View {
    let wordCount: Int
    @State private var displayedCount: Int = 0
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: UlyssesDesign.Spacing.xs) {
            Image(systemName: "textformat.123")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                .scaleEffect(isAnimating ? 1.1 : 1.0)
            
            Text("\(displayedCount) words")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(UlyssesDesign.Colors.tertiary(for: colorScheme))
                .contentTransition(.numericText())
        }
        .onChange(of: wordCount) { oldValue, newValue in
            // Animate the word count change
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isAnimating = true
            }
            
            withAnimation(.easeInOut(duration: 0.5)) {
                displayedCount = newValue
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isAnimating = false
                }
            }
        }
        .onAppear {
            displayedCount = wordCount
        }
    }
}

struct ProgressBarView: View {
    let progress: Double // 0.0 to 1.0
    let color: Color
    @State private var animatedProgress: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(UlyssesDesign.Colors.secondary(for: colorScheme).opacity(0.2))
                    .frame(height: 4)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geometry.size.width * animatedProgress, height: 4)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)
            }
        }
        .frame(height: 4)
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    @State private var isVisible = false
    
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, UlyssesDesign.Spacing.sm)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color)
            )
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isVisible = true
                }
            }
    }
}

#Preview {
    VStack(spacing: UlyssesDesign.Spacing.lg) {
        SaveIndicatorView(state: .saving)
        SaveIndicatorView(state: .saved)
        SaveIndicatorView(state: .error("Failed to save"))
        
        WordCountAnimatedView(wordCount: 1247)
        
        ProgressBarView(progress: 0.75, color: UlyssesDesign.Colors.accent)
            .frame(width: 200)
        
        StatusPill(text: "Draft", color: .orange)
        StatusPill(text: "Published", color: .green)
    }
    .padding()
    .frame(width: 300, height: 400)
}