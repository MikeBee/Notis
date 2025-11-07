//
//  NotificationName+Extensions.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import Foundation

extension Notification.Name {
    static let showCommandPalette = Notification.Name("showCommandPalette")
    static let showSettings = Notification.Name("showSettings")
    static let showDashboard = Notification.Name("showDashboard")
    static let showKeyboardShortcuts = Notification.Name("showKeyboardShortcuts")
    static let showAdvancedSearch = Notification.Name("showAdvancedSearch")
    static let showTemplates = Notification.Name("showTemplates")
    static let createFromTemplate = Notification.Name("createFromTemplate")
    static let focusTagInput = Notification.Name("focusTagInput")
    static let showTagFilter = Notification.Name("showTagFilter")
}