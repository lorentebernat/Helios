// VoidBackground.swift
// Shared starfield/nebula background used behind every screen.

import SwiftUI

struct VoidBackground: View {
    // @State, not a plain let: MainColonyView's body re-evaluates on every
    // tick, which re-runs this struct's initializer. A plain `let` has no
    // memory across that reconstruction and would re-roll every tick.
    // @State's storage persists across it, keyed to this view's identity in
    // the tree, so this default expression only ever runs once. HELIOS.md §18 S12.
    @State private var stars: [Star] = (0..<40).map { _ in
        Star(
            opacity: Double.random(in: 0.1...0.6),
            size: CGFloat.random(in: 1...2.5),
            x: CGFloat.random(in: 0...420),
            y: CGFloat.random(in: 0...900)
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GameTheme.voidTop, GameTheme.voidBottom],
                startPoint: .top, endPoint: .bottom
            )
            // Soft nebula glow
            Circle()
                .fill(GameTheme.accent.opacity(0.25))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(x: -120, y: -260)
            Circle()
                .fill(Color.purple.opacity(0.18))
                .frame(width: 350, height: 350)
                .blur(radius: 130)
                .offset(x: 160, y: 100)
            // Starfield — positions frozen in @State (see above).
            ForEach(stars, id: \.self) { star in
                Circle()
                    .fill(.white.opacity(star.opacity))
                    .frame(width: star.size)
                    .position(x: star.x, y: star.y)
            }
        }
        .ignoresSafeArea()
    }

    private struct Star: Hashable {
        let opacity: Double
        let size: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}
