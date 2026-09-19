//
//  Aggregation.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

/// How readings are combined: into each plotted bucket, into the callout for the selected bucket,
/// and into the header for the range on screen.
public nonisolated enum Aggregation: Sendable {
    /// The mean, e.g. heart rate or weight. A band is averaged too.
    case average
    /// The total, e.g. steps or energy.
    case sum
    /// The mean, with a band from the lowest to the highest reading.
    case range
    /// Raw readings, not bucketed for plotting. Combined like `average` for the callout and header.
    case none

    /// Names the combined figure in the header.
    var label: String {
        switch self {
        case .average, .none: "Average"
        case .sum: "Total"
        case .range: "Range"
        }
    }

    /// Combines `values` (and their band readings, if any) into one value and optional band.
    /// Call only with at least one value.
    func combine(_ values: [Double], band: [TimeSeriesBandDatapoint]) -> (value: Double, band: ClosedRange<Double>?) {
        switch self {
        case .average, .none:
            let band = band.isEmpty ? nil : band.mean(of: \.lower)...band.mean(of: \.upper)
            return (values.mean(of: \.self), band)
        case .sum:
            return (values.reduce(0, +), nil)
        case .range:
            return (values.mean(of: \.self), (values.min() ?? 0)...(values.max() ?? 0))
        }
    }
}
