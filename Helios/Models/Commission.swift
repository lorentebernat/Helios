//
//  Commission.swift
//  Helios
//
//  Created by Bernat on 13/10/2026.
//


// Commission.swift
// The optional half of the Empire's demands: a contract you may take or ignore.
//
// - Opting in and delivering earns credits and repairs Standing directly.
// - Opting in and failing costs more Standing than never opting in at all.
// - Ignoring is always safe, and always leaves value on the table.
//
// Commissions are the reconciliation path — the way out of Scrutinised is to
// volunteer for something and deliver it. And because they are opt-in they can
// be *harder* than quotas without being unfair, which makes them the right
// place for genuine difficulty spikes. HELIOS.md §4.3.
//
// PASS OR FAIL, not graded. A quota is graded because it is compulsory: you
// are judged on how much of what you were ordered to ship arrived. A
// commission is a bet you chose to take, so 99% delivered pays exactly what 0%
// pays. That difference is most of what makes the two feel unalike.
//
// NO FAVOUR IN THIS PHASE. Commissions pay Standing and credits. Favour
// arrives in Phase 5 alongside Dispensations, which give it a sink —
// introducing a currency with a source and no sink is precisely how `credits`
// became S3, and doing it twice would be careless. HELIOS.md §18 S3, §4.4.

import Foundation

struct Commission: Codable, Hashable, Identifiable {

    let id: Int

    /// The goods and amounts asked for. Narrow and intense where a quota is
    /// broad and steady — a rush order, not an assessment.
    let lines: [Resource.ID: Double]

    let offeredAtTick: Int
    let deadlineTick: Int

    /// Game-minutes the window covers. Display only; the deadline itself is a
    /// tick count, for the same reason a quota's is.
    let windowMinutes: Double

    /// Added to `Standing.reliability` on delivery — a direct bump, not folded
    /// into the EMA.
    let standingReward: Double

    /// Subtracted on failure, after accepting. Deliberately larger than the
    /// reward: accepting has to be a real bet, or ignoring would be a
    /// dominated choice and the "always safe" promise would be hollow.
    let standingPenalty: Double

    let creditReward: Int

    /// Opt-in. Nothing happens to an un-accepted commission at its deadline.
    var accepted: Bool

    // MARK: - Reading the contract

    var lineCount: Int { lines.count }
    var isEmpty: Bool { lines.isEmpty }

    func amount(of good: Resource.ID) -> Double { lines[good] ?? 0 }

    /// Registry order, so the UI is stable and delivery iterates predictably.
    var sortedLines: [(good: Resource.ID, amount: Double)] {
        Resource.all.compactMap { resource in
            guard let amount = lines[resource.id] else { return nil }
            return (good: resource.id, amount: amount)
        }
    }

    // MARK: - The window

    var windowTicks: Int { max(1, deadlineTick - offeredAtTick) }

    func isDue(atTick tick: Int) -> Bool { tick >= deadlineTick }

    func ticksRemaining(atTick tick: Int) -> Int { max(0, deadlineTick - tick) }

    func minutesRemaining(atTick tick: Int) -> Double {
        windowMinutes * Double(ticksRemaining(atTick: tick)) / Double(windowTicks)
    }

    // MARK: - Outcome

    /// Progress, for the card's bar. Not what decides payment — see `isMet`.
    func fill(from ledger: QuotaLedger) -> Double {
        guard !isEmpty else { return 0 }
        let total = lines.reduce(0.0) { partial, line in
            guard line.value > 0 else { return partial + 1 }
            return partial + min(1, ledger.amountDelivered(of: line.key) / line.value)
        }
        return total / Double(lineCount)
    }

    /// Pass or fail. Every line, in full, by the deadline.
    func isMet(by ledger: QuotaLedger) -> Bool {
        guard !isEmpty else { return false }
        return lines.allSatisfy { line in
            line.value <= 0 || ledger.amountDelivered(of: line.key) >= line.value - 1e-6
        }
    }

    // MARK: - Sample

    static let sample = Commission(
        id: 1,
        lines: ["raw-ice": 87.5, "oxygen": 49, "power-cells": 70],
        offeredAtTick: 240,
        deadlineTick: 360,
        windowMinutes: 120,
        standingReward: 0.10,
        standingPenalty: 0.15,
        creditReward: 225,
        accepted: false
    )
}

/// What became of the last commission. Kept for the panel, so the player sees
/// the consequence of a decision they made a cycle ago.
enum CommissionOutcome: String, Codable, Hashable {
    case delivered
    case failed
    case ignored
}