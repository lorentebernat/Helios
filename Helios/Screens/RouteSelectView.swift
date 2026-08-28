// RouteSelectView.swift
// Destination picker for setting a ship's course. Looks the ship up LIVE in
// GameState by id; auto-dismisses if it's gone.

import SwiftUI

struct RouteSelectView: View {
    let shipID: Ship.ID
    @Environment(GameState.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDestinationID: Destination.ID?
    @ViewBuilder
        private func destinationButton(_ destination: Destination, ship: Ship) -> some View {
            let isHere = destination.id == ship.locationID
            Button {
                guard !isHere else { return }
                selectedDestinationID = destination.id
            } label: {
                DestinationCard(
                    destination: destination,
                    isSelected: selectedDestinationID == destination.id,
                    isCurrentLocation: isHere
                )
            }
            .disabled(isHere)
        }

    private let destinations: [Destination] = Destination.samples

    private var ship: Ship? {
        game.ships.first { $0.id == shipID }
    }

    private var selectedDestination: Destination? {
        destinations.first { $0.id == selectedDestinationID }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VoidBackground()

            if let ship {
                content(for: ship)
                confirmBar(for: ship)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .onChange(of: ship == nil) { _, gone in
            if gone { dismiss() }
        }
    }

    @ViewBuilder
    private func content(for ship: Ship) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GameTheme.Spacing.xl) {
                HStack {
                    Button { dismiss() } label: {
                        CircleGlassButton(systemImage: "chevron.left")
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("SET COURSE")
                            .font(GameTheme.Font.label)
                            .foregroundStyle(GameTheme.textSecondary)
                            .tracking(1)
                        Text(ship.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(GameTheme.textPrimary)
                    }
                    Spacer()
                    CircleGlassButton(systemImage: "ellipsis")
                        .opacity(0)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
                    Text("Destinations")
                        .font(GameTheme.Font.sectionTitle)
                        .foregroundStyle(GameTheme.textPrimary)

                    VStack(spacing: 10) {
                        ForEach(destinations) { destination in
                            destinationButton(destination, ship: ship)
                        }
                    }
                }

                Spacer(minLength: 140)
            }
            .padding(.horizontal, GameTheme.Spacing.lg)
        }
    }

    @ViewBuilder
    private func confirmBar(for ship: Ship) -> some View {
        if let selectedDestination {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Course set to")
                        .font(.system(size: 11))
                        .foregroundStyle(GameTheme.textSecondary)
                    Text(selectedDestination.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(GameTheme.textPrimary)
                }
                Spacer()
                Button {
                    game.dispatch(shipID: ship.id, to: selectedDestination)
                    dismiss()
                } label: {
                    Text("Depart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(GameTheme.accent))
                }
            }
            .padding(GameTheme.Spacing.md)
            .glass(cornerRadius: GameTheme.Radius.panel, strokeOpacity: GameTheme.GlassStroke.prominent)
            .padding(.horizontal, GameTheme.Spacing.lg)
            .padding(.bottom, 88)
        }
    }
}

#Preview {
    let state = GameState.seeded()
    NavigationStack {
        RouteSelectView(shipID: state.ships[1].id)   // Dust Runner (idle)
    }
    .environment(state)
}
