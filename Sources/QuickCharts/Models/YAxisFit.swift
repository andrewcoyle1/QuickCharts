//
//  YAxisFit.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

/// The y axis for a set of plotted values. Bars and areas measure from zero, so they keep it and fit
/// only their top; lines, points and ranges fit their values at both ends, so a weight moving between
/// 72 and 73 kg fills the plot rather than sitting in a flat line at the top of 0–75.
nonisolated enum YAxisFit {
    /// Room above the top of a chart that starts at zero, so marks at the maximum aren't cut off.
    static let headroom = 0.05
    /// Room either side of fitted values, as a share of their spread.
    static let padding = 0.1
    /// Roughly how many steps a fitted axis's ends are rounded to, so they land on round numbers
    /// without leaving much empty space.
    static let steps = 8.0

    static func domain(for values: [Double], startsAtZero: Bool) -> ClosedRange<Double> {
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        return startsAtZero ? fromZero(low: low, high: high) : fitted(low: low, high: high)
    }

    private static func fromZero(low: Double, high: Double) -> ClosedRange<Double> {
        let lower = min(0, low)
        let upper = max(0, high) * (1 + headroom)
        return upper > lower ? lower...upper : lower...(lower + 1)
    }

    private static func fitted(low: Double, high: Double) -> ClosedRange<Double> {
        let spread = high - low
        // A flat line still gets some room, relative to its size.
        let pad = spread > 0 ? spread * padding : max(abs(high) * padding, 1) / 2
        var lower = low - pad
        let upper = high + pad
        // Padding shouldn't take positive data below zero, where it can't go.
        if low >= 0 { lower = max(0, lower) }
        let step = roundStep(for: (upper - lower) / steps)
        return (lower / step).rounded(.down) * step...(upper / step).rounded(.up) * step
    }

    /// The smallest of 1, 2, 2.5, 5 and 10 times a power of ten that's at least `raw`.
    static func roundStep(for raw: Double) -> Double {
        guard raw > 0, raw.isFinite else { return 1 }
        let magnitude = pow(10, (log10(raw)).rounded(.down))
        let multiple = [1, 2, 2.5, 5, 10].first { $0 * magnitude >= raw * (1 - 1e-9) } ?? 10
        return multiple * magnitude
    }
}
