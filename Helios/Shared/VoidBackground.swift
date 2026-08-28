// VoidBackground.swift
// Shared starfield/nebula background used behind every screen.

import SwiftUI

struct VoidBackground: View {
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
            // Starfield
            ForEach(0..<40, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(Double.random(in: 0.1...0.6)))
                    .frame(width: CGFloat.random(in: 1...2.5))
                    .position(
                        x: CGFloat.random(in: 0...420),
                        y: CGFloat.random(in: 0...900)
                    )
            }
        }
        .ignoresSafeArea()
    }
}
