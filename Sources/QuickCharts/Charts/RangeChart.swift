//
//  RangeChart.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Charts

/// Each series' lowest to highest reading per bucket as a floating capsule, e.g. heart rate.
public struct RangeChart: View {

    let data: [TimeSeries]
    @State private var presenter: ChartPresenter

    /// New `data` passed in later is picked up; the configuration is read once, when the view first
    /// appears. To change it, give the view a new `.id`.
    public init(data: [TimeSeries], configuration: ChartConfiguration = ChartConfiguration()) {
        var configuration = configuration
        configuration.aggregation = .range // the capsules are each bucket's lowest to highest reading
        self.data = data
        _presenter = State(initialValue: ChartPresenter(data: data, configuration: configuration, traits: ChartPresenter.Traits(showsBand: true, isContinuous: false, placesSeriesSideBySide: true)))
    }

    public var body: some View {
        TimeSeriesChart(presenter: presenter, data: data) {
            if let selection = presenter.selection {
                SelectionStick(date: selection.date, bucket: presenter.bucket)
            }
            SeriesRanges(points: presenter.bandPoints, slots: presenter.seriesSlots)
        }
    }
}

#Preview {
    // Several readings a day, so each day has a spread to show.
    RangeChart(data: TimeSeries.samples(readingsPerDay: 12))
}
