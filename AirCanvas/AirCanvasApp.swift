//
//  AirCanvasApp.swift
//  AirCanvas
//
//  Created by Khush  on 21/09/26.
//

import SwiftUI
import CoreData

@main
struct AirCanvasApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
