//
//  NotisApp.swift
//  Notis
//
//  Created by Mike on 11/1/25.
//

import SwiftUI

@main
struct NotisApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        // Check and reset daily goals on app launch
        GoalsService.shared.checkAndResetDailyGoals()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        #if os(macOS)
        .commands {
            NotisCommands()
        }
        #endif
    }
}
