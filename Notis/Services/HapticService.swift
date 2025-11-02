//
//  HapticService.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import UIKit
import SwiftUI

class HapticService {
    static let shared = HapticService()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enableHapticFeedback else { return }
        
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        @unknown default:
            impactMedium.impactOccurred()
        }
    }
    
    func selection() {
        guard enableHapticFeedback else { return }
        selectionFeedback.selectionChanged()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enableHapticFeedback else { return }
        notificationFeedback.notificationOccurred(type)
    }
    
    // Convenience methods for common actions
    func buttonTap() {
        impact(.light)
    }
    
    func itemSelected() {
        selection()
    }
    
    func actionCompleted() {
        notification(.success)
    }
    
    func actionFailed() {
        notification(.error)
    }
    
    func dragStarted() {
        impact(.medium)
    }
    
    func dragEnded() {
        impact(.light)
    }
}