//
//  AreaChart.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Charts

/// Each series as a filled area under a smoothed line, with a lollipop on the selected bucket.
public struct AreaChart: View {

    let data: [TimeSeries]
    @State private var presenter: ChartPresenter

    /// New `data` passed in later is picked up; the configuration is read once, when the view first
    /// appears. To change it, give the view a new `.id`.
    public init(data: [TimeSeries], configuration: ChartConfiguration = ChartConfiguration()) {
        self.data = data
        _presenter = State(initialValue: ChartPresenter(data: data, configuration: configuration))
    }

    public var body: some View {
        TimeSeriesChart(presenter: presenter, data: data) {
            SeriesAreas(points: presenter.linePoints, colors: presenter.colorsBySeries)
            SeriesLines(points: presenter.linePoints, showsPoints: false)
            if let selection = presenter.selection {
                SelectionLollipop(selection: selection, bucket: presenter.bucket)
            }
        }
    }
}

#Preview {
    AreaChart(data: TimeSeries.samples())
}
