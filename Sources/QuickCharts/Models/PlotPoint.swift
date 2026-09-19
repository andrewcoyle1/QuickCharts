//
//  PlotPoint.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

/// One plotted point, flattened out of its series for the vectorized plots.
nonisolated struct PlotPoint: Identifiable, Sendable {
    let series: String
    let date: Date
    let value: Double

    /// Unique per series and date, for marks drawn one per point.
    var id: String { "\(series)|\(date.timeIntervalSinceReferenceDate)" }
}
