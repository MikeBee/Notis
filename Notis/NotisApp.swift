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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
