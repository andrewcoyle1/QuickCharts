//
//  BarChart.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Charts

/// Each series as a bar per bucket, side by side, with a stick on the selected bucket.
public struct BarChart: View {

    let data: [TimeSeries]
    @State private var presenter: ChartPresenter

    /// New `data` passed in later is picked up; the configuration is read once, when the view first
    /// appears. To change it, give the view a new `.id`.
    public init(data: [TimeSeries], configuration: ChartConfiguration = ChartConfiguration()) {
        self.data = data
        _presenter = State(initialValue: ChartPresenter(data: data, configuration: configuration, traits: ChartPresenter.Traits(isContinuous: false, placesSeriesSideBySide: true)))
    }

    public var body: some View {
        TimeSeriesChart(presenter: presenter, data: data) {
            if let selection = presenter.selection {
                SelectionStick(date: selection.date, bucket: presenter.bucket)
            }
            SeriesBars(points: presenter.linePoints, bucket: presenter.bucket, slots: presenter.seriesSlots)
        }
    }
}

#Preview {
    BarChart(data: TimeSeries.samples(), configuration: ChartConfiguration(goal: 9))
}
