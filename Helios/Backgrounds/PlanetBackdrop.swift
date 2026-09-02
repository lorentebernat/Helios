// PlanetBackdrop.swift
// Reusable rotating-planet background, placeholder texture only.

import SwiftUI

struct PlanetBackdrop: View {
    var diameter: CGFloat
    var baseColor: Color
    var bandColor: Color
    var rotationDuration: Double   // seconds per full "rotation"

    // Identifies which planet this is, so its surface texture is stable
    // across re-renders and view-identity resets but still differs between
    // worlds. HELIOS.md §18 S12 (second half): the surface blobs used to be
    // regenerated with `@State`, which is stable only for the lifetime of a
    // single view identity — meaning MainColonyView's planet re-rolled every
    // time you switched tabs and back, and every DestinationCard re-rolled
    // on every render. Deriving the blobs from a seed instead makes them a
    // pure function of "which planet is this", so identity resets no longer
    // matter at all — nothing needs to persist.
    var seed: Int

    @State private var scrollX: CGFloat = 0

    init(
        diameter: CGFloat = 340,
        baseColor: Color = Color(red: 0.35, green: 0.55, blue: 0.75),
        bandColor: Color = Color(red: 0.15, green: 0.30, blue: 0.45),
        rotationDuration: Double = 40,
        seed: Int = 0
    ) {
        self.diameter = diameter
        self.baseColor = baseColor
        self.bandColor = bandColor
        self.rotationDuration = rotationDuration
        self.seed = seed
    }

    // Deterministic from `seed` alone — same seed always yields the same 14
    // blobs, so this is safe to recompute on every body evaluation (every
    // tick) without drifting or needing @State.
    //
    // NOTE: call sites currently seed from `String.hashValue` (e.g.
    // `destination.id.hashValue`), which Swift explicitly does NOT guarantee
    // stable across process launches (it's randomised per-launch to resist
    // hash-flooding). That's fine here — within one launch a given planet
    // stays consistent, which is all "looks the same every time you open it"
    // requires *within a session*. Do not "fix" this by assuming hashValue
    // is stable across launches. If cross-launch stability is ever wanted,
    // seed from the summed UTF-8 bytes of the id instead.
    private var surfaceBlobs: [SurfaceBlob] {
        var rng = SeededGenerator(seed: seed)
        return (0..<14).map { i in
            SurfaceBlob(
                width: CGFloat.random(in: 40...140, using: &rng),
                height: CGFloat.random(in: 20...60, using: &rng),
                x: CGFloat(i) * (diameter * 2.2 / 14) + CGFloat.random(in: -20...20, using: &rng),
                y: CGFloat.random(in: 20...(diameter - 20), using: &rng)
            )
        }
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
        PlanetBackdrop(seed: 42)
    }
}
