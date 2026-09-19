//
//  HighlightPoint.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// One highlighted reading, flattened out of a `ChartHighlight` with its series' colour.
struct HighlightPoint: Identifiable {
    let series: String
    let date: Date
    let value: Double
    let color: Color
    /// Whether its label goes under the dot rather than over it: every point but the highest in its
    /// bucket, so the labels of series side by side don't run into each other.
    var labelBelow = false

    /// Unique per series and date.
    var id: String { "\(series)|\(date.timeIntervalSinceReferenceDate)" }
}
