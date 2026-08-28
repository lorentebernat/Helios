// ResearchView.swift
// Research overview: Research Points balance + project list, filterable by category.
// Reads from injected GameState.

import SwiftUI

struct ResearchView: View {
    @Environment(GameState.self) private var game
    @State private var activeCategory: ResearchCategory? = nil

    var filteredProjects: [ResearchProject] {
        guard let activeCategory else { return game.researchProjects }
        return game.researchProjects.filter { $0.category == activeCategory }
    }

    var body: some View {
        ZStack(alignment: .top) {
            VoidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: GameTheme.Spacing.xl) {
                    HStack {
                        Text("RESEARCH")
                            .font(GameTheme.Font.label)
                            .foregroundStyle(GameTheme.textSecondary)
                            .tracking(1)
                        Spacer()
                        CircleGlassButton(systemImage: "ellipsis")
                    }
                    .padding(.top, 8)

                    ResearchSummaryStrip(points: game.researchPoints, ratePerMin: game.researchRatePerMin)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ResearchCategory.allCases, id: \.self) { category in
                                Button {
                                    activeCategory = (activeCategory == category) ? nil : category
                                } label: {
                                    CategoryChip(
                                        icon: category.icon,
                                        label: category.rawValue,
                                        isActive: activeCategory == category
                                    )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
                        Text("Projects")
                            .font(GameTheme.Font.sectionTitle)
                            .foregroundStyle(GameTheme.textPrimary)

                        VStack(spacing: 10) {
                            ForEach(filteredProjects) { project in
                                ResearchProjectRow(project: project)
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, GameTheme.Spacing.lg)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NavigationStack {
        ResearchView()
    }
    .environment(GameState.seeded())
}
