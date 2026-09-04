//
//  QuotaTests.swift
//  Helios
//
//  Created by Bernat on 04/09/2026.
//


//
//  QuotaTests.swift
//  HeliosTests
//
//  Phase 2 Step 2.
//

// Pins manifest sizing. The expected figures are the seed network's measured
// export capacity (CapacityTests) times a 240-game-minute interval at load 1.0:
//
//   Power Cells 5.25 → 1260    Raw Ice     2.00 →  480
//   Raw Ore     5.00 → 1200    Grain       2.00 →  480
//   Alloy Tools 2.75 →  660    Water       0.50 →  120
//   Oxygen      2.25 →  540    Ration Bars 0.15 →   36
//
//   Refined Alloy 0.00 → not named at all.

import Testing
import Foundation
@testable import Helios

@Suite("Quota")
struct QuotaTests {

    private func seedColony() -> Colony {
        GameState.seeded().colonies[0]
    }

    private func generate(
        colony: Colony? = nil,
        id: Int = 1,
        issuedAtTick: Int = 0,
        interval: Double = QuotaGenerator.baseIntervalMinutes,
        load: Double = QuotaGenerator.standardLoad,
        economyRate: Double = 1.0
    ) -> Quota {
        QuotaGenerator.generate(
            id: id,
            colony: colony ?? seedColony(),
            economyRate: economyRate,
            issuedAtTick: issuedAtTick,
            intervalMinutes: interval,
            load: load
        )
    }

    // MARK: - Breadth

    @Test func manifestNamesAtLeastFiveGoods() {
        let quota = generate()
        #expect(quota.lineCount >= QuotaGenerator.minimumLineCount,
                "manifest named \(quota.lineCount) goods: \(quota.sortedLines.map(\.good))")
    }

    /// Breadth is what unsticks the economy: a manifest naming one good leaves
    /// every other store saturated. For the seed network, every good the colony
    /// can actually spare should be named.
    @Test func namesEveryGoodTheColonyCanSpare() {
        let quota = generate()
        let capacity = CapacityProbe.measure(colony: seedColony(), economyRate: 1.0)
        let sparable = capacity
            .filter { $0.value >= QuotaGenerator.minimumCapacityPerGameMinute }
            .keys
            .sorted()

        #expect(quota.sortedLines.map(\.good).sorted() == sparable,
                "named \(quota.sortedLines.map(\.good).sorted()), expected \(sparable)")
        #expect(quota.lineCount == 8, "expected eight lines for the seed network, got \(quota.lineCount)")
    }

    // MARK: - Sizing

    @Test func sizesEachGoodAtItsOwnRate() {
        let quota = generate()

        let powerCells = quota.amount(of: "power-cells")
        let water = quota.amount(of: "water")
        let rations = quota.amount(of: "ration-bars")

        #expect(powerCells > water, "Power Cells (\(powerCells)) should dwarf Water (\(water))")
        #expect(water > rations, "Water (\(water)) should exceed Ration Bars (\(rations))")

        // Each line is its own capacity × interval × load, so the ratio between
        // two lines is exactly the ratio between their capacities.
        let capacity = CapacityProbe.measure(colony: seedColony(), economyRate: 1.0)
        let expectedRatio = (capacity["power-cells"] ?? 0) / (capacity["water"] ?? 1)
        let actualRatio = powerCells / water
        #expect(abs(actualRatio - expectedRatio) <= 0.05,
                "line ratio \(actualRatio) should track the capacity ratio \(expectedRatio)")

        // And the absolute figures, pinned.
        let expected: [Resource.ID: Double] = [
            "power-cells": 1_260, "raw-ore": 1_200, "alloy-tools": 660, "oxygen": 540,
            "raw-ice": 480, "grain": 480, "water": 120, "ration-bars": 36
        ]
        for (good, want) in expected {
            let got = quota.amount(of: good)
            #expect(abs(got - want) <= max(1, want * 0.05),
                    "\(good): expected \(want) ± 5%, got \(got)")
        }
    }

    @Test func neverNamesAStructurallyBottleneckedGood() {
        // Refined Alloy has no exportable surplus at all: the Smelter supplies
        // 7/min and the Tool Fab plus Cell Factory demand 5 + 3 = 8. Naming it
        // would be asking for nothing.
        for interval in [60.0, 240.0, 960.0, 2_880.0] {
            let quota = generate(interval: interval)
            #expect(quota.lines["refined-alloy"] == nil,
                    "Refined Alloy was named at interval \(interval)")
        }
    }

    @Test func linesScaleWithTheInterval() {
        let short = generate(interval: 60)
        let long = generate(interval: 960)

        #expect(long.amount(of: "power-cells") > short.amount(of: "power-cells"))
        #expect(long.lineCount == short.lineCount, "interval length must not change breadth")
    }

    /// The property Step 5's cadence bands rest on: a shorter interval is a
    /// smaller shipment, not a heavier one. Demand *per game-minute* is
    /// identical whatever the interval.
    @Test func demandPerGameMinuteIsIndependentOfTheInterval() {
        let rates = [60.0, 240.0, 960.0, 2_880.0].map {
            generate(interval: $0).totalDemandPerGameMinute
        }
        guard let first = rates.first else { return }
        for rate in rates {
            #expect(abs(rate - first) <= 0.01,
                    "demand per game-minute drifted with the interval: \(rates)")
        }
    }

    @Test func loadScalesTheWholeManifest() {
        let one = generate(load: 1.0)
        let half = generate(load: 0.5)
        for (good, amount) in one.lines {
            #expect(abs(half.amount(of: good) - amount / 2) <= max(0.2, amount * 0.01),
                    "\(good): half load should halve the line")
        }
    }

    // MARK: - Determinism

    @Test func generationIsDeterministic() {
        let a = generate(id: 7, issuedAtTick: 1_234)
        let b = generate(id: 7, issuedAtTick: 1_234)
        #expect(a == b, "two identical generations differed")
        #expect(a.lines == b.lines, "manifests differed")
    }

    /// Quota is sized from *installed* capacity, so a throttled colony is
    /// assessed exactly like a colony running flat out. The same anti-exploit
    /// as CapacityTests, asserted one level up where it actually bites.
    @Test func isNotSizedByThrottling() {
        var quiet = seedColony()
        for i in quiet.productionChains.indices {
            quiet.productionChains[i].outputPercent = 0.25
        }

        let normal = generate()
        let throttled = generate(colony: quiet)

        #expect(normal.lines == throttled.lines,
                "throttling changed the manifest — the Empire must not reward running at minimum")
    }

    // MARK: - The deadline is a tick count, not a Date

    @Test func deadlineIsAnAbsoluteTickCount() {
        let quota = generate(issuedAtTick: 1_000, interval: 240, economyRate: 1.0)
        #expect(quota.dueAtTick == 1_240,
                "240 game-minutes at economyRate 1.0 is 240 ticks; got \(quota.dueAtTick - 1_000)")
    }

    /// Phase 4 dials economyRate to 1/60. The same 240 game-minutes then take
    /// sixty times as many ticks — and the manifest itself is unchanged, because
    /// capacity is per game-minute.
    @Test func deadlineFollowsEconomyRateButTheManifestDoesNot() {
        let fast = generate(issuedAtTick: 0, interval: 240, economyRate: 1.0)
        let honest = generate(issuedAtTick: 0, interval: 240, economyRate: 1.0 / 60.0)

        #expect(honest.dueAtTick == 14_400,
                "240 game-minutes at 1/60 is 14,400 ticks; got \(honest.dueAtTick)")
        for (good, amount) in fast.lines {
            #expect(abs(honest.amount(of: good) - amount) <= max(1, amount * 0.05),
                    "\(good): the manifest should not change with the tick size")
        }
    }

    // MARK: - Persistence readiness (Step 4 saves this)

    @Test func quotaRoundTripsThroughCodable() throws {
        let quota = generate(id: 42, issuedAtTick: 555)
        let data = try JSONEncoder().encode(quota)
        let decoded = try JSONDecoder().decode(Quota.self, from: data)
        #expect(decoded == quota, "quota did not survive a round trip")
    }
}