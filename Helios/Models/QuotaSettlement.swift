//
//  QuotaSettlement.swift
//  Helios
//
//  Created by Bernat on 07/09/2026.
//


// QuotaSettlement.swift
// The archived outcome of one settled quota cycle.
//
// Step 5 reads `fill` to move Standing (an EMA over settled fills), Step 6
// reads it to pay the stipend, and Step 8's UI reads `lineFills` to show what
// went short last cycle. Keeping the record rather than only the latest number
// is what lets Standing be a slope measured over several cycles rather than a
// switch flipped by one bad shipment. HELIOS.md §4.1.

import Foundation

struct QuotaSettlement: Codable, Hashable, Identifiable {
    let quotaID: Int
    let settledAtTick: Int

    /// Normalised per line, so a big line and a small line count equally.
    let fill: Double

    /// Per-line fill, for showing which lines missed rather than only that the
    /// cycle did.
    let lineFills: [Resource.ID: Double]

    var id: Int { quotaID }

    var wasMet: Bool { fill >= 0.999 }

    /// Lines that came in short, worst first — what the player actually needs
    /// to see after a miss.
    var shortfalls: [(good: Resource.ID, fill: Double)] {
        lineFills
            .filter { $0.value < 0.999 }
            .sorted { $0.value < $1.value }
            .map { (good: $0.key, fill: $0.value) }
    }
}