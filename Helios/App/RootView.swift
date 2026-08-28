//
//  RootView.swift
//  Helios
//
//  Created by Bernat on 07/08/2026.
//


// RootView.swift
// App root: owns tab selection, hosts a NavigationStack per tab, and the
// single persistent GlassTabBar that floats above all of them.

import SwiftUI
import Combine

struct RootView: View {
    @State private var selectedTab = 0
    @Environment(GameState.self) private var game
    private let ticker = Timer.publish(every: GameState.tickInterval, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            switch selectedTab {
            case 0:
                NavigationStack {
                    MainColonyView()
                        .navigationDestination(for: ChainDetail.ID.self) { id in
                            ProductionDetailView(chainID: id)
                        }
                        .navigationDestination(for: ProductionListNav.self) { _ in
                            ProductionListView()
                        }
                }
            case 1:
                NavigationStack {
                    ProductionListView()
                }
            case 2:
                NavigationStack {
                    FleetView()
                        .navigationDestination(for: ShipRouteTarget.self) { target in
                            RouteSelectView(shipID: target.shipID)
                        }
                }
            case 3:
                NavigationStack {
                    ResearchView()
                }
            default:
                EmptyView()
            }

            GlassTabBar(selection: $selectedTab)
                .padding(.bottom, 8)
                .onReceive(ticker) { _ in
                    game.advanceOneTick()
                }
        }
    }
}

#Preview {
    RootView()
        .environment(GameState.seeded())
}

