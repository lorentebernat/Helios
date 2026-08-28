//
//  HeliosApp.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
//

import SwiftUI

@main
struct HeliosApp: App {
    @State private var gameState = GameState.seeded()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gameState)
        }
    }
}
