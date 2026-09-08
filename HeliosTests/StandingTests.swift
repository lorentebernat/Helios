//
//  StandingTests.swift
//  Helios
//
//  Created by Bernat on 08/09/2026.
//


//
//  StandingTests.swift
//  HeliosTests
//
//  Phase 2 Step 5.
//

// Standing's arithmetic, its stickiness, and the one property that must never
// break: failure shortens the interval, it never raises the rate.

import Testing
import Foundation
@testable import Helios

@Suite("Standing")
struct StandingTests {

    private func run(_ state: GameState, ticks: Int) {
        for _ in 0..<ticks { state.tick() }
    }

    private func manifest(_ state: GameState, at band: StandingBand) -> Quota {
        QuotaGenerator.generate(
            id: 1,
            colony: state.colonies[0],
            economyRate: GameState.economyRate,
            issuedAtTick: 0,
            intervalMinutes: band.cadenceMinutesFromBase,
            load: QuotaGenerator.standardLoad
        )
    }

    // MARK: - THE test

    /// **The single most important test in this phase.**
    ///
    /// Falling Standing shortens the interval and shrinks each shipment
    /// proportionally. Total demand per game-minute is identical at
    /// Receivership and at Indifferent — and at every band in between. Getting
    /// this wrong makes a bad cycle make the next one harder, which is
    /// structurally the same failure as a brownout throttling the power plant
    /// that would end it. HELIOS.md §4.1.
    ///
    /// Measured: 19.9000 per game-minute at all five bands, and Power Cells at
    /// 5.2500 per game-minute at all five. The property is not defended by a
    /// guard — it falls out of sizing each line as
    /// `capacity × interval × load`, so `line / interval` cancels the interval.
    /// Which means the way this breaks in future is somebody changing the
    /// sizing formula, and this test is what catches that.
    @Test func failureNeverRaisesTheDemandRate() {
        let state = GameState.seeded()

        let indifferent = manifest(state, at: .indifferent)

        // Ten settled cycles delivering nothing at all.
        for _ in 0..<10 { state.standing.settle(fill: 0) }
        #expect(state.standing.band == .receivership,
                "ten failed cycles should reach the bottom band, got \(state.standing.band.displayName)")

        let receivership = manifest(state, at: .receivership)

        #expect(abs(receivership.totalDemandPerGameMinute - indifferent.totalDemandPerGameMinute) < 1e-9,
                "demand rate moved: \(receivership.totalDemandPerGameMinute) at Receivership vs \(indifferent.totalDemandPerGameMinute) at Indifferent")

        for good in indifferent.lines.keys {
            #expect(abs(receivership.demandPerGameMinute(of: good) - indifferent.demandPerGameMinute(of: good)) < 1e-9,
                    "\(good): rate moved between bands")
        }

        // What *does* change: a shorter interval, and a smaller shipment.
        #expect(receivership.intervalMinutes < indifferent.intervalMinutes)
        #expect(receivership.lines.values.reduce(0, +) < indifferent.lines.values.reduce(0, +),
                "a shorter cadence must mean a smaller shipment, not the same one sooner")
    }

    @Test func everyBandDemandsTheSameRate() {
        let state = GameState.seeded()
        let rates = StandingBand.allCases.map { manifest(state, at: $0).totalDemandPerGameMinute }
        guard let first = rates.first else { return }
        for (band, rate) in zip(StandingBand.allCases, rates) {
            #expect(abs(rate - first) < 1e-9,
                    "\(band.displayName) demands \(rate)/min against \(first)/min at Receivership")
        }
    }

    @Test func cadenceLengthensWithStanding() {
        let cadences = StandingBand.allCases.map(\.cadenceMinutesFromBase)
        #expect(cadences == [96, 168, 240, 360, 600],
                "cadence ladder changed: \(cadences)")
        #expect(cadences == cadences.sorted(),
                "a better band must mean a longer planning horizon")
    }

    // MARK: - Reliability

    @Test func reliabilityIsAnEMAOverSettledFills() {
        var standing = Standing.initial
        #expect(standing.reliability == 1.0)
        #expect(standing.band == .indifferent, "you begin at Indifferent")

        standing.settle(fill: 0)
        #expect(abs(standing.reliability - 0.7) < 1e-9, "0.7 × 1.0 + 0.3 × 0.0, got \(standing.reliability)")
        standing.settle(fill: 0)
        #expect(abs(standing.reliability - 0.49) < 1e-9, "got \(standing.reliability)")
    }

    @Test func reliabilityIsClampedToTheUnitRange() {
        var standing = Standing(reliability: 0.5, band: .indifferent)
        standing.settle(fill: 5)
        #expect(standing.reliability <= 1, "over-delivery cannot push reliability above 1")
        standing.settle(fill: -3)
        #expect(standing.reliability >= 0, "a negative fill cannot push reliability below 0")
    }

    // MARK: - Stickiness

    /// A slope, not a switch. Sixteen cycles of fill oscillating either side of
    /// the 0.75/0.65 threshold pair must not flip the band, because the EMA
    /// parks reliability inside the hysteresis gap (measured: 0.67–0.73).
    @Test func bandsAreSticky() {
        var standing = Standing(reliability: 0.70, band: .scrutinised)
        var seen: [StandingBand] = []

        for i in 0..<16 {
            standing.settle(fill: i.isMultiple(of: 2) ? 0.85 : 0.55)
            seen.append(standing.band)
        }

        #expect(Set(seen).count == 1,
                "the band flipped across oscillating cycles: \(seen.map(\.displayName))")
        #expect(standing.band == .scrutinised)
    }

    @Test func riseAndFallThresholdsDoNotOverlap() {
        for i in Standing.riseThresholds.indices {
            #expect(Standing.fallThresholds[i] < Standing.riseThresholds[i],
                    "band \(i) has no hysteresis: rise \(Standing.riseThresholds[i]), fall \(Standing.fallThresholds[i])")
        }
    }

    @Test func bandsMoveOneStepPerSettlement() {
        #expect(Standing.band(after: .receivership, reliability: 1.0) == .scrutinised,
                "perfect reliability should not vault from the bottom to the top")
        #expect(Standing.band(after: .patron, reliability: 0.0) == .favourable,
                "total failure should not drop four bands at once")
        #expect(Standing.band(after: .indifferent, reliability: 0.80) == .indifferent,
                "0.80 is inside Indifferent's window and should hold")
    }

    // MARK: - Receivership has a floor

    /// From the bottom band, deliver perfectly and you climb back. Measured:
    /// three cycles to leave Receivership, four to reach Indifferent.
    @Test func receivershipIsRecoverable() {
        var standing = Standing(reliability: 0, band: .receivership)
        var cycles = 0
        while standing.band < .indifferent && cycles < 50 {
            standing.settle(fill: 1.0)
            cycles += 1
        }
        #expect(standing.band == .indifferent, "never climbed out, ended at \(standing.band.displayName)")
        #expect(cycles == 4, "measured four perfect cycles back to Indifferent, got \(cycles)")
    }

    /// And the fall is a slope too: four settled failures from Patron to
    /// Receivership, not one.
    @Test func collapseIsAlsoASlope() {
        var standing = Standing(reliability: 1.0, band: .patron)
        var cycles = 0
        while standing.band > .receivership && cycles < 50 {
            standing.settle(fill: 0)
            cycles += 1
        }
        #expect(standing.band == .receivership)
        #expect(cycles == 4, "measured four failed cycles from Patron to Receivership, got \(cycles)")
    }

    /// Receivership is unpleasant and slow to leave, and that is all it is: it
    /// never takes population, never takes buildings, never cascades. 5,000
    /// ticks on the bottom band's 96-minute cadence with no player action.
    @Test func receivershipDoesNotKillTheColony() {
        let state = GameState.seeded()
        state.standing = Standing(reliability: 0.1, band: .receivership)
        state.quotaCadenceOverrideMinutes = StandingBand.receivership.cadenceMinutesFromBase
        reissueManifests(state)

        run(state, ticks: 5_000)

        #expect(state.colonies[0].population.total > 0,
                "the bottom band emptied the colony")
        #expect(abs(state.colonies[0].population.total - 450) <= 2,
                "population should be untouched by the cadence alone, got \(state.colonies[0].population.total)")
        // And because the demand rate never rose, the colony keeps meeting it
        // and climbs straight back out.
        #expect(state.standing.band > .receivership,
                "delivering perfectly on the bottom band should climb out of it")
    }

    /// The harsher version: the bottom band's cadence *and* a load well past
    /// the usable window. Measured: 101 colonists left after 5,000 ticks, which
    /// is bounded loss rather than collapse.
    @Test func receivershipUnderAPunishingLoadStillLeavesAColony() {
        let state = GameState.seeded()
        state.standing = Standing(reliability: 0.1, band: .receivership)
        state.quotaCadenceOverrideMinutes = StandingBand.receivership.cadenceMinutesFromBase
        state.quotaLoad = 4.0
        reissueManifests(state)

        run(state, ticks: 5_000)
        #expect(state.colonies[0].population.total > 0,
                "load 4.0 at Receivership emptied the colony")
    }

    // MARK: - Reliability, not size

    /// Standing measures reliability, not size. A sector with four of its ten
    /// chains gone, delivering perfectly against its own smaller assessment,
    /// reaches Patron exactly like a full one.
    ///
    /// This is what stops "stay small" being doubly rewarded once Standing is
    /// public: OGame's points double as a raiding-target indicator and push
    /// people to stay deliberately small, and if Standing *also* drove quota,
    /// staying small would win twice. HELIOS.md §4.1.
    @Test func standingIgnoresColonySize() {
        let state = GameState.seeded()
        let removed: Set<String> = ["Ore Extractor", "Alloy Smelter", "Alloy Tool Fab", "Cell Factory"]
        state.colonies[0].productionChains.removeAll { removed.contains($0.name) }
        #expect(state.colonies[0].productionChains.count == 6, "precondition: a smaller colony")

        state.quotaCadenceOverrideMinutes = QuotaGenerator.baseIntervalMinutes
        reissueManifests(state)

        // Its own manifest is sized from its own capacity, so it names only
        // what it can actually spare.
        #expect(state.currentQuota?.lineCount == 5,
                "expected five lines for the reduced network, got \(state.currentQuota?.lineCount ?? -1)")

        run(state, ticks: 2_400)

        for settlement in state.settlementHistory {
            #expect(settlement.fill > 0.99,
                    "cycle \(settlement.quotaID) came in at \(settlement.fill) — the smaller colony should meet its own quota")
        }
        #expect(state.standing.band == .patron,
                "a small, perfectly reliable sector should reach Patron, got \(state.standing.band.displayName)")
    }

    // MARK: - The band actually drives the cadence

    @Test func theBandDrivesTheAnnouncedCadence() {
        let state = GameState.seeded()
        #expect(state.quotaCadenceMinutes == 240, "a fresh game runs at the Indifferent cadence")

        guard let first = state.currentQuota else { return }
        run(state, ticks: first.dueAtTick)

        #expect(state.standing.band == .favourable,
                "one perfect cycle should promote from Indifferent, got \(state.standing.band.displayName)")
        #expect(state.quotaCadenceMinutes == 360)

        // The promoted manifest keeps the window it was published with — the
        // new cadence shapes the one announced now, which is the promise that
        // an announced manifest does not change under you.
        #expect(state.currentQuota?.intervalMinutes == 240,
                "the promoted manifest should keep its published cadence")
        #expect(state.nextQuota?.intervalMinutes == 360,
                "the newly announced manifest should carry the new cadence")
    }

    // MARK: - Persistence

    @Test func standingSurvivesARoundTrip() throws {
        let original = GameState.seeded()
        for _ in 0..<6 { original.standing.settle(fill: 0.4) }
        #expect(original.standing.band != .indifferent, "precondition: standing moved")

        let data = try JSONEncoder().encode(original.snapshot)
        let restored = GameState(save: try JSONDecoder().decode(GameSave.self, from: data))

        #expect(restored.standing == original.standing, "standing did not survive the round trip")
    }

    @Test func standingRoundTripsThroughCodable() throws {
        for band in StandingBand.allCases {
            let standing = Standing(reliability: 0.4321, band: band)
            let data = try JSONEncoder().encode(standing)
            #expect(try JSONDecoder().decode(Standing.self, from: data) == standing)
        }
    }

    // MARK: - Helper

    /// Re-issues both manifests from the colony as it currently stands, at the
    /// state's current cadence. Needed whenever a test changes the colony or
    /// the knobs after `GameState.seeded()` has already sized a manifest.
    private func reissueManifests(_ state: GameState) {
        let cadence = state.quotaCadenceMinutes
        let current = QuotaGenerator.generate(
            id: state.mintQuotaID(),
            colony: state.colonies[0],
            economyRate: GameState.economyRate,
            issuedAtTick: state.tickCount,
            intervalMinutes: cadence,
            load: state.quotaLoad
        )
        let next = QuotaGenerator.generate(
            id: state.mintQuotaID(),
            colony: state.colonies[0],
            economyRate: GameState.economyRate,
            issuedAtTick: current.dueAtTick,
            intervalMinutes: cadence,
            load: state.quotaLoad
        )
        state.currentQuota = current
        state.nextQuota = next
        state.ledger = .empty(for: current)
    }
}

// MARK: - Test convenience

private extension StandingBand {
    var cadenceMinutesFromBase: Double {
        QuotaGenerator.baseIntervalMinutes * cadenceMultiplier
    }
}