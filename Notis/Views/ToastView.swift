//
//  ToastView.swift
//  Notis
//
//  Created by Claude on 11/3/25.
//

import SwiftUI

struct ToastView: View {
    let message: String
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(message)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                    Spacer()
                }
                .padding(.bottom, 80)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .zIndex(1000)
        }
    }
}

class ToastManager: ObservableObject {
    @Published var message: String = ""
    @Published var isVisible: Bool = false
    
    private var hideTask: Task<Void, Never>?
    
    func show(_ message: String, duration: TimeInterval = 3.0) {
        print("🍞 Toast requested: \(message)")
        hideTask?.cancel()
        
        DispatchQueue.main.async {
            print("🍞 Toast showing: \(message)")
            self.message = message
            self.isVisible = true
        }
        
        hideTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            DispatchQueue.main.async {
                print("🍞 Toast hiding")
                self.isVisible = false
            }
        }
    }
    
    func hide() {
        hideTask?.cancel()
        DispatchQueue.main.async {
            self.isVisible = false
        }
    }
}

struct ToastOverlay: View {
    @ObservedObject private var toastManager = ExportService.shared.toastManager
    
    var body: some View {
        ToastView(message: toastManager.message, isVisible: toastManager.isVisible)
    }
}

extension View {
    func toast(_ toastManager: ToastManager) -> some View {
        self.overlay(
            ToastView(message: toastManager.message, isVisible: toastManager.isVisible)
                .allowsHitTesting(false)
        )
    }
}