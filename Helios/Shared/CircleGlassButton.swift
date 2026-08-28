// CircleGlassButton.swift
// Shared circular glass icon button (back, more, add) used across all screens.

import SwiftUI

struct CircleGlassButton: View {
    let systemImage: String
    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(GameTheme.textPrimary)
            .frame(width: 40, height: 40)
            .glass(cornerRadius: GameTheme.Radius.circleButton, strokeOpacity: GameTheme.GlassStroke.standard)
    }
}
