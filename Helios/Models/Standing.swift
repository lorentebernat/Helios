//
//  StandingBand.swift
//  Helios
//
//  Created by Bernat on 08/09/2026.
//


// Standing.swift
// What the Empire thinks of you, and what that changes.
//
// STANDING MEASURES RELIABILITY, NOT SIZE: what you delivered against what was
// demanded, over time. A modest sector that always delivers has excellent
// standing; a sprawling one that misses quarters does not. This matters beyond
// flavour — Standing will eventually be visible to other administrators, and
// OGame's public points double as a raiding-target indicator, which pushes
// people to stay deliberately small. Keeping the three inputs separate (quota
// from assessed capacity, Standing from reliability, raid attractiveness from
// stockpile) is what makes "stay modest, stay reliable, keep stores low" a
// coherent playstyle rather than an exploit. HELIOS.md §4.1.
//
// THE RULE THAT KEEPS THIS FROM BEING A DEATH SPIRAL: falling Standing
// shortens the interval and shrinks each shipment proportionally. Total demand
// per game-minute never rises. The Empire checks on you more often; it does not
// squeeze harder. What you lose is planning horizon and attention, which is
// punishing without being an economic trap.
//
// That property is not enforced here by a guard — it falls out of how a
// manifest is sized. `QuotaGenerator` sets each line to
// `capacity × interval × load`, so the per-minute rate is `line / interval` and
// the interval cancels. Measured across all five bands: total demand 19.9000
// per game-minute and Power Cells 5.2500 per game-minute at every one of them,
// identical rather than approximate. `StandingTests` pins it, because the way
// this breaks in future is somebody changing the sizing formula.

import Foundation

enum StandingBand: Int, Codable, CaseIterable, Comparable {
    case receivership = 0
    case scrutinised
    case indifferent
    case favourable
    case patron

    static func < (lhs: StandingBand, rhs: StandingBand) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .receivership: return "Receivership"
        case .scrutinised:  return "Scrutinised"
        case .indifferent:  return "Indifferent"
        case .favourable:   return "Favourable"
        case .patron:       return "Patron"
        }
    }

    /// One word for what the Empire feels about a sector in this band.
    /// HELIOS.md §4.1.
    var posture: String {
        switch self {
        case .receivership: return "Extractive"
        case .scrutinised:  return "Displeased"
        case .indifferent:  return "Procedural"
        case .favourable:   return "Pleased"
        case .patron:       return "Invested"
        }
    }

    /// Multiplier on the base cadence. Rare and large at the top, constant and
    /// small at the bottom — and because each shipment is sized from the
    /// interval, a shorter cadence is a *smaller* shipment at the same rate.
    var cadenceMultiplier: Double {
        switch self {
        case .receivership: return 0.4   //  96 game-minutes
        case .scrutinised:  return 0.7   // 168
        case .indifferent:  return 1.0   // 240
        case .favourable:   return 1.5   // 360
        case .patron:       return 2.5   // 600
        }
    }

    /// **Receivership has a floor.** It collects at the dock instead of paying
    /// (Step 6), and that is the whole of it: it never takes population, never
    /// takes buildings, and never cascades. Measured over 5,000 ticks at the
    /// 96-minute cadence, population holds at 450 under a load-1.0 manifest and
    /// at 101 under a punishing load-4.0 one. Consistent with the bounded-loss
    /// decision. HELIOS.md §4.1, §21.
    var isExtractive: Bool { self == .receivership }

    var next: StandingBand? { StandingBand(rawValue: rawValue + 1) }
    var previous: StandingBand? { StandingBand(rawValue: rawValue - 1) }
}

struct Standing: Codable, Hashable {

    /// Exponential moving average of settled fills. Deliberately not the last
    /// fill and not a plain mean: an EMA forgets slowly enough that a band is a
    /// judgement over several cycles, and quickly enough that a genuine change
    /// of behaviour shows up within a handful of them.
    var reliability: Double

    var band: StandingBand

    /// `reliability = 0.7 × old + 0.3 × fill`.
    static let smoothing: Double = 0.3

    /// You begin at Indifferent with a clean record — neither reward nor
    /// punishment, simply what the Empire feels about a sector it has not
    /// thought about. HELIOS.md §4.1.
    static let initialReliability: Double = 1.0
    static let initial = Standing(reliability: initialReliability, band: .indifferent)

    /// Reliability needed to climb out of band *i*, indexed by `rawValue`.
    static let riseThresholds: [Double] = [0.55, 0.75, 0.90, 0.97]

    /// Reliability below which band *i* drops, indexed by `rawValue - 1`.
    static let fallThresholds: [Double] = [0.45, 0.65, 0.82, 0.92]

    // MARK: - Settlement

    /// Folds one settled cycle into the record and moves the band at most one
    /// step.
    mutating func settle(fill: Double) {
        let clamped = min(1, max(0, fill))
        reliability = (1 - Self.smoothing) * reliability + Self.smoothing * clamped
        band = Self.band(after: band, reliability: reliability)
    }

    /// **Bands are sticky, and in two separate ways.**
    ///
    /// The rise and fall thresholds are deliberately different — 0.55/0.45,
    /// 0.75/0.65, 0.90/0.82, 0.97/0.92 — and that gap is the hysteresis.
    /// Measured: sixteen cycles of fill oscillating 0.85/0.55 either side of the
    /// 0.75/0.65 pair produce **zero** band changes, because the EMA parks
    /// reliability at 0.67–0.73, inside the gap.
    ///
    /// And a band moves at most one step per settlement, whatever reliability
    /// says. A collapse from Patron to Receivership therefore takes four
    /// settlements, and the climb back from Receivership to Indifferent takes
    /// four perfect ones. Standing should read as a slope, not a switch.
    static func band(after current: StandingBand, reliability: Double) -> StandingBand {
        if let up = current.next, reliability >= riseThresholds[current.rawValue] {
            return up
        }
        if let down = current.previous, reliability < fallThresholds[current.rawValue - 1] {
            return down
        }
        return current
    }

    // MARK: - Readouts (Step 8's panel)

    /// Reliability needed for the next promotion, or `nil` at Patron.
    var riseThreshold: Double? {
        guard band.next != nil else { return nil }
        return Self.riseThresholds[band.rawValue]
    }

    /// Reliability at which this band is lost, or `nil` at Receivership.
    var fallThreshold: Double? {
        guard band.previous != nil else { return nil }
        return Self.fallThresholds[band.rawValue - 1]
    }

    func cadenceMinutes(base: Double) -> Double {
        base * band.cadenceMultiplier
    }
}