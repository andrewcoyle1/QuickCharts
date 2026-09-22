//
//  StackedBarChart.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Charts
import SwiftUI

/// Each bucket's total as one bar, split into the series stacked on each other, e.g. active and
/// resting energy.
public struct StackedBarChart: View {

    let data: [TimeSeries]
    @State private var presenter: ChartPresenter

    /// New `data` passed in later is picked up; the configuration is read once, when the view first
    /// appears. To change it, give the view a new `.id`.
    public init(data: [TimeSeries], configuration: ChartConfiguration = ChartConfiguration(aggregation: .sum)) {
        self.data = data
        _presenter = State(initialValue: ChartPresenter(data: data, configuration: configuration, traits: ChartPresenter.Traits(stacksSeries: true, isContinuous: false, startsAtZero: true)))
    }

    public var body: some View {
        TimeSeriesChart(presenter: presenter, data: data) {
            if let selection = presenter.selection {
                SelectionStick(date: selection.date, bucket: presenter.bucket)
            }
            SeriesBars(points: presenter.linePoints, bucket: presenter.bucket) // no slots, so they stack
        }
    }
}

#Preview {
    StackedBarChart(data: TimeSeries.samples())
}
