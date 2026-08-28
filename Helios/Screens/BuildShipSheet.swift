// BuildShipSheet.swift
// Ship construction form: pick a role, name it, pay credits and materials,
// queue it at the active colony's shipyard.

import SwiftUI

struct BuildShipSheet: View {
    @Environment(GameState.self) private var game
    @Environment(\.dismiss) private var dismiss

    @State private var role: ShipRole = .freighter
    @State private var name: String = ShipNameGenerator.random()

    private var cost: BuildCost { role.buildCost }
    private var affordable: Bool { game.canAfford(cost) }

    var body: some View {
        ZStack {
            VoidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: GameTheme.Spacing.xl) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SHIPYARD")
                                .font(GameTheme.Font.label)
                                .foregroundStyle(GameTheme.textSecondary)
                                .tracking(1)
                            Text(game.activeColony.name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(GameTheme.textPrimary)
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            CircleGlassButton(systemImage: "xmark")
                        }
                    }
                    .padding(.top, GameTheme.Spacing.lg)

                    // Role
                    VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
                        Text("Role")
                            .font(GameTheme.Font.rowTitle)
                            .foregroundStyle(GameTheme.textPrimary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ShipRole.allCases, id: \.self) { option in
                                    Button {
                                        role = option
                                    } label: {
                                        CategoryChip(
                                            icon: option.icon,
                                            label: option.rawValue,
                                            isActive: role == option
                                        )
                                    }
                                }
                            }
                        }

                        RoleStatRow(role: role)
                    }

                    // Name
                    VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
                        Text("Name")
                            .font(GameTheme.Font.rowTitle)
                            .foregroundStyle(GameTheme.textPrimary)

                        HStack(spacing: GameTheme.Spacing.sm) {
                            TextField("Ship name", text: $name)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .font(GameTheme.Font.rowTitle)
                                .foregroundStyle(GameTheme.textPrimary)
                                .padding(.horizontal, GameTheme.Spacing.md)
                                .padding(.vertical, 12)
                                .glass(cornerRadius: GameTheme.Radius.row,
                                       strokeOpacity: GameTheme.GlassStroke.subtle)

                            Button {
                                name = ShipNameGenerator.random()
                            } label: {
                                CircleGlassButton(systemImage: "die.face.5")
                            }
                        }
                    }

                    // Cost
                    VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
                        Text("Cost")
                            .font(GameTheme.Font.rowTitle)
                            .foregroundStyle(GameTheme.textPrimary)

                        VStack(spacing: 10) {
                            costRow(
                                icon: "dollarsign.circle.fill",
                                name: "Credits",
                                haveText: Format.integer(game.credits),
                                needText: Format.integer(cost.credits),
                                short: game.credits < cost.credits
                            )

                            ForEach(cost.materials, id: \.self) { material in
                                let have = game.activeColony.stock.amount(of: material.resourceID)
                                costRow(
                                    icon: material.icon,
                                    name: material.name,
                                    haveText: Format.decimal(have),
                                    needText: Format.decimal(material.amount),
                                    short: have < material.amount
                                )
                            }
                        }
                        .padding(GameTheme.Spacing.md)
                        .glass(cornerRadius: GameTheme.Radius.row,
                               strokeOpacity: GameTheme.GlassStroke.subtle)

                        Label(Format.duration(minutes: role.buildMinutes),
                              systemImage: "clock.fill")
                            .font(GameTheme.Font.caption)
                            .foregroundStyle(GameTheme.textSecondary)

                        if !affordable {
                            Text("Insufficient resources at \(game.activeColony.name).")
                                .font(GameTheme.Font.caption)
                                .foregroundStyle(GameTheme.warn)
                        }
                    }

                    Button {
                        game.queueShip(role: role, name: name)
                        dismiss()
                    } label: {
                        Text("Begin construction")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(affordable ? .black : GameTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule().fill(affordable ? GameTheme.accent : Color.white.opacity(0.08))
                            )
                    }
                    .disabled(!affordable)

                    Spacer(minLength: GameTheme.Spacing.xl)
                }
                .padding(.horizontal, GameTheme.Spacing.lg)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.fraction(0.8), .large])
        .presentationBackground(.clear)
    }

    @ViewBuilder
    private func costRow(icon: String, name: String, haveText: String,
                         needText: String, short: Bool) -> some View {
        HStack(spacing: GameTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(short ? GameTheme.warn : GameTheme.accent)
                .frame(width: 18)
            Text(name)
                .font(GameTheme.Font.caption)
                .foregroundStyle(GameTheme.textPrimary)
            Spacer()
            Text("\(haveText) / \(needText)")
                .font(GameTheme.Font.body)
                .foregroundStyle(short ? GameTheme.warn : GameTheme.textPrimary)
        }
    }
}

#Preview {
    BuildShipSheet()
        .environment(GameState.seeded())
}
