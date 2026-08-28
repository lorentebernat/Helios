//
//  ResearchProjectRow.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
//
// Single research project row: icon, name, progress or lock state.

import SwiftUI

struct ResearchProjectRow: View {
    let project: ResearchProject

    var isLocked: Bool {
        if case .locked = project.status { return true }
        return false
    }

    var statusTint: Color {
        switch project.status {
        case .locked: return GameTheme.textSecondary
        case .available: return GameTheme.accent
        case .inProgress: return GameTheme.accent
        case .completed: return .green
        }
    }

    var statusLabel: String {
        switch project.status {
        case .locked(let tier): return "Requires \(tier) tier"
        case .available: return "\(project.pointCost) RP · Ready to start"
        case .inProgress(let invested): return "\(invested)/\(project.pointCost) RP"
        case .completed: return "Completed"
        }
    }

    var body: some View {
        HStack(spacing: GameTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: GameTheme.Radius.iconBadge, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .frame(width: GameTheme.Size.iconBadge, height: GameTheme.Size.iconBadge)
                Image(systemName: isLocked ? "lock.fill" : project.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isLocked ? GameTheme.textSecondary : GameTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(GameTheme.Font.rowTitle)
                    .foregroundStyle(isLocked ? GameTheme.textSecondary : GameTheme.textPrimary)

                if !isLocked {
                    Text(project.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(GameTheme.textSecondary)
                        .lineLimit(1)
                }

                if project.status != .completed {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.08))
                            Capsule()
                                .fill(statusTint.opacity(0.8))
                                .frame(width: geo.size.width * project.progress)
                        }
                    }
                    .frame(height: 4)
                }

                Text(statusLabel)
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(statusTint)
            }

            Spacer()

            if project.status == .completed {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(GameTheme.Spacing.md)
        .opacity(isLocked ? 0.55 : 1)
        .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
    }
}
