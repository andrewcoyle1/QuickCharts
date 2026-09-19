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

    /// Unique per series and date.
    var id: String { "\(series)|\(date.timeIntervalSinceReferenceDate)" }
}
