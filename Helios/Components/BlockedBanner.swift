//
//  BlockedBanner.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
// Warning banner shown at the top of a production chain when an input is missing.

import SwiftUI

struct BlockedBanner: View {
    let missingInputName: String

    var body: some View {
        HStack(spacing: GameTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(GameTheme.warn)
            VStack(alignment: .leading, spacing: 2) {
                Text("Production halted")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GameTheme.textPrimary)
                Text("Missing input: \(missingInputName)")
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(GameTheme.warn)
            }
            Spacer()
        }
        .padding(GameTheme.Spacing.md)
        .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.prominent)
    }
}
