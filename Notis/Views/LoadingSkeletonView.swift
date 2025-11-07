//
//  LoadingSkeletonView.swift
//  Notis
//
//  Created by Mike on 11/3/25.
//

import SwiftUI

struct LoadingSkeletonView: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.md) {
            ForEach(0..<8, id: \.self) { _ in
                SheetRowSkeleton()
            }
        }
        .padding(UlyssesDesign.Spacing.lg)
    }
}

struct SheetRowSkeleton: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: UlyssesDesign.Spacing.xs) {
            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(skeletonGradient)
                .frame(height: 18)
                .frame(maxWidth: .infinity)
            
            // Preview lines skeleton
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(skeletonGradient)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(skeletonGradient)
                    .frame(height: 14)
                    .frame(width: .random(in: 200...300))
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(skeletonGradient)
                    .frame(height: 14)
                    .frame(width: .random(in: 150...250))
            }
            
            // Meta info skeleton
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(skeletonGradient)
                    .frame(width: 60, height: 10)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(skeletonGradient)
                    .frame(width: 40, height: 10)
            }
        }
        .padding(UlyssesDesign.Spacing.md)
        .background(UlyssesDesign.Colors.background(for: colorScheme))
        .cornerRadius(UlyssesDesign.CornerRadius.medium)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private var skeletonGradient: LinearGradient {
        let baseColor = UlyssesDesign.Colors.secondary(for: colorScheme).opacity(0.1)
        let highlightColor = UlyssesDesign.Colors.secondary(for: colorScheme).opacity(0.2)
        
        return LinearGradient(
            gradient: Gradient(colors: [baseColor, highlightColor, baseColor]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct LoadingStateView: View {
    let message: String
    @State private var rotation: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: UlyssesDesign.Spacing.lg) {
            // Animated loading indicator
            Image(systemName: "doc.text")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(UlyssesDesign.Colors.accent)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            Text(message)
                .font(UlyssesDesign.Typography.sheetMeta)
                .foregroundColor(UlyssesDesign.Colors.secondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UlyssesDesign.Colors.background(for: colorScheme))
    }
}

struct PulsingButton: View {
    let action: () -> Void
    let label: String
    let icon: String
    @State private var isPulsing = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: UlyssesDesign.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, UlyssesDesign.Spacing.lg)
            .padding(.vertical, UlyssesDesign.Spacing.sm)
            .background(
                UlyssesDesign.Colors.accent
                    .scaleEffect(isPulsing ? 1.05 : 1.0)
            )
            .cornerRadius(UlyssesDesign.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPulsing = hovering
            }
        }
    }
}

#Preview {
    VStack {
        LoadingSkeletonView()
        
        Divider()
        
        LoadingStateView(message: "Loading your documents...")
        
        Divider()
        
        PulsingButton(action: {}, label: "Create New", icon: "plus.circle")
    }
    .frame(width: 360, height: 600)
}