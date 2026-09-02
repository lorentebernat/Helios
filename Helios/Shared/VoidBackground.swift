// VoidBackground.swift
// Shared starfield/nebula background used behind every screen.

import SwiftUI

struct VoidBackground: View {
    // Generated once per launch and shared by every instance. Previously
    // @State: RootView selects tabs with a `switch`, so each tab is a
    // different view identity, and switching tabs tore the subtree down and
    // discarded @State — regenerating a fresh starfield every time. The
    // starfield is purely decorative and identical everywhere, so it never
    // wanted per-view identity in the first place; a static computed once
    // is both correct and cheaper (no per-tick recomputation to throw away).
    // HELIOS.md §18 S12.
    private static let stars: [Star] = (0..<40).map { _ in
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
            // Starfield — positions frozen in the static above.
            ForEach(Self.stars, id: \.self) { star in
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
