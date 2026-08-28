//
//  GlassTabBar.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
// Shared floating glass tab bar used across all screens.

import SwiftUI

struct GlassTabBar: View {
    @Binding var selection: Int
    let items: [(icon: String, label: String)] = [
        ("globe.europe.africa.fill", "Colony"),
        ("cube.transparent.fill", "Production"),
        ("paperplane.fill", "Fleet"),
        ("chart.bar.fill", "Research")
    ]

    var body: some View {
        HStack {
            ForEach(items.indices, id: \.self) { i in
                Button {
                    selection = i
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(items[i].label)
                            .font(GameTheme.Font.tabLabel)
                    }
                    .foregroundStyle(selection == i ? GameTheme.accent : GameTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .glass(cornerRadius: GameTheme.Radius.tabBar, strokeOpacity: GameTheme.GlassStroke.prominent)
        .padding(.horizontal, GameTheme.Spacing.lg)
    }
}
