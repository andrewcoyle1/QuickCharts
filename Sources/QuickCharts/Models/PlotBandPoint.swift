//
//  PlotBandPoint.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

/// One plotted band point, flattened out of its series for the vectorized plots.
nonisolated struct PlotBandPoint: Identifiable, Sendable {
    let series: String
    let date: Date
    let lower: Double
    let upper: Double

    /// Unique per series and date, for marks drawn one per point.
    var id: String { "\(series)|\(date.timeIntervalSinceReferenceDate)" }
}
