// PlanetBackdrop.swift
// Reusable rotating-planet background, placeholder texture only.

import SwiftUI

struct PlanetBackdrop: View {
    var diameter: CGFloat
    var baseColor: Color
    var bandColor: Color
    var rotationDuration: Double   // seconds per full "rotation"

    @State private var scrollX: CGFloat = 0

    // @State, not a plain let: MainColonyView's body re-evaluates on every
    // tick, which re-runs this struct's initializer. A plain `let` computed
    // in init has no memory across that reconstruction, so it silently
    // re-rolled every tick — that was the actual bug, not just "not enough
    // randomness moved out of body". @State's storage persists across
    // reconstruction, keyed to this view's identity in the tree: the
    // `initialValue` passed in `init` below is used only the very first
    // time this view is created, and ignored on every subsequent tick's
    // reconstruction. HELIOS.md §18 S12.
    @State private var surfaceBlobs: [SurfaceBlob]

    init(
        diameter: CGFloat = 340,
        baseColor: Color = Color(red: 0.35, green: 0.55, blue: 0.75),
        bandColor: Color = Color(red: 0.15, green: 0.30, blue: 0.45),
        rotationDuration: Double = 40
    ) {
        self.diameter = diameter
        self.baseColor = baseColor
        self.bandColor = bandColor
        self.rotationDuration = rotationDuration
        _surfaceBlobs = State(initialValue: (0..<14).map { i in
            SurfaceBlob(
                width: CGFloat.random(in: 40...140),
                height: CGFloat.random(in: 20...60),
                x: CGFloat(i) * (diameter * 2.2 / 14) + CGFloat.random(in: -20...20),
                y: CGFloat.random(in: 20...(diameter - 20))
            )
        })
    }

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
            ForEach(surfaceBlobs, id: \.self) { blob in
                Ellipse()
                    .fill(bandColor.opacity(0.6))
                    .frame(width: blob.width, height: blob.height)
                    .position(x: blob.x, y: blob.y)
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

    private struct SurfaceBlob: Hashable {
        let width: CGFloat
        let height: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PlanetBackdrop()
    }
}
