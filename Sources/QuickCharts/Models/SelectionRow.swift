//
//  SelectionRow.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// One series' figures for a day/week/month (callout) or for the visible range (header).
struct SelectionRow: Identifiable {
    let series: TimeSeries
    let point: TimeSeriesDatapoint
    let band: TimeSeriesBandDatapoint?
    let color: Color
    var id: String { series.id }
    
    static var mock: Self {
        .init(
            series: .mock(),
            point: .mock,
            band: .mock,
            color: .accentColor
        )
    }
    
    static var mocks: [Self] {
        [
            Self.init(
                series: .mock(name: "Series 1"),
                point: .mock,
                band: .mock,
                color: Color.blue
            ),
            Self.init(
                series: .mock(name: "Series 2"),
                point: .mock,
                band: .mock,
                color: Color.green
            )
        ]
    }
}
