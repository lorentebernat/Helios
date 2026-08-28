//
//  Format.swift
//  Helios
//
//  Created by Bernat on 11/08/2026.
//


// Format.swift
// Single source for display formatting. Anything that turns a number into
// player-facing text belongs here.

import Foundation

enum Format {

    /// One-decimal rounding — stock, rates, multipliers.
    static func decimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Locale-grouped integer — credits, research points, population.
    static func integer(_ value: Int) -> String {
        value.formatted(.number)
    }

    /// Game-minutes as a countdown clock: "3h:20:00" over an hour, "20:00" under.
    static func duration(minutes: Double) -> String {
        let total = Int((minutes * 60).rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%dh:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}