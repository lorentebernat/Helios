// PlanetBackdrop.swift
// Reusable rotating-planet background, placeholder texture only.

import SwiftUI

struct PlanetBackdrop: View {
    var diameter: CGFloat = 340
    var baseColor: Color = Color(red: 0.35, green: 0.55, blue: 0.75)
    var bandColor: Color = Color(red: 0.15, green: 0.30, blue: 0.45)
    var rotationDuration: Double = 40   // seconds per full "rotation"

    @State private var scrollX: CGFloat = 0

    var body: some View {
        ZStack {
            // Outer atmosphere glow
            Circle()
                .fill(baseColor.opacity(0.35))
                .frame(width: diameter * 1.25, height: diameter * 1.25)
                .blur(radius: 40)

            // Sphere with scrolling surface texture, masked to a circle
            ZStack {
                surfaceTexture
                    .frame(width: diameter * 2.2, height: diameter)
                    .offset(x: scrollX)
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(sphereShading)
            .overlay(rimLight)
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            withAnimation(.linear(duration: rotationDuration).repeatForever(autoreverses: false)) {
                scrollX = -diameter * 1.2
            }
        }
    }

    // Placeholder "continents" — replace with a real texture/sprite later
    private var surfaceTexture: some View {
        ZStack {
            baseColor
            ForEach(0..<14, id: \.self) { i in
                Ellipse()
                    .fill(bandColor.opacity(0.6))
                    .frame(
                        width: CGFloat.random(in: 40...140),
                        height: CGFloat.random(in: 20...60)
                    )
                    .position(
                        x: CGFloat(i) * (diameter * 2.2 / 14) + CGFloat.random(in: -20...20),
                        y: CGFloat.random(in: 20...(diameter - 20))
                    )
                    .blur(radius: 6)
            }
        }
    }

    // Lit/shadowed sphere look (terminator line)
    private var sphereShading: some View {
        ZStack {
            RadialGradient(
                colors: [.white.opacity(0.25), .clear],
                center: .init(x: 0.32, y: 0.28),
                startRadius: 0,
                endRadius: diameter * 0.6
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(Circle())
    }

    // Thin bright edge to sell the "planet against space" silhouette
    private var rimLight: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.4), .clear, .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PlanetBackdrop()
    }
}
