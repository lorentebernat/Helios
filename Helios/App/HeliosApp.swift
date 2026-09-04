//
//  HeliosApp.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
//

import SwiftUI

@main
struct HeliosApp: App {
    @State private var gameState = GameState.load()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gameState)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Backgrounding and being interrupted (a call, Control Center)
            // are both "the user might not come back" — either is the right
            // moment to autosave. HELIOS.md §18 S4, Phase 1.5 Step 6.
            if newPhase == .background || newPhase == .inactive {
                gameState.save()
            }
        }
    }
}
