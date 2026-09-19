//
//  RangeHeader.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// The averages above the chart for the range on screen. Updates live while scrolling, like Health.
/// Its own view so that only it re-renders on every scroll frame, not the chart.
struct RangeHeader: View {
    let presenter: ChartPresenter

    var body: some View {
        // Same layout as the callout. Hidden while the lollipop is up.
        if let summary = presenter.rangeSummary {
            SeriesSummary(
                rows: summary.rows,
                footer: footer(for: summary),
                unit: presenter.configuration.unit,
                valueFormat: presenter.configuration.valueFormat
            )
            .padding(8) // matches the callout's padding so the text lines up
            .opacity(presenter.isSelecting ? 0 : 1)
            // Crossfades with the callout, which fades in as this fades out.
            .animation(.easeInOut(duration: 0.15), value: presenter.isSelecting)
        }
    }

    /// "Average, 14 – 20 Sep 2026", or just the dates when there's no data to describe.
    private func footer(for summary: ChartPresenter.RangeSummary) -> Text {
        let dates = Text(presenter.scale.rangeDescription(summary.dates))
        return summary.rows.isEmpty ? dates : Text("\(summary.label), \(dates)")
    }
}

#Preview {
    List {
        RangeHeader(presenter: ChartPresenter(
            data: [.mock()],
            configuration: ChartConfiguration(unit: "kcal", initialScale: .month, seriesColors: [.accentColor])
        ))
    }
}
