//
//  ScatterChart.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Charts

/// Every raw reading as a point, not bucketed, e.g. weight or blood pressure. The callout averages
/// the readings in the selected bucket.
public struct ScatterChart: View {

    let data: [TimeSeries]
    @State private var presenter: ChartPresenter

    /// New `data` passed in later is picked up; the configuration is read once, when the view first
    /// appears. To change it, give the view a new `.id`.
    public init(data: [TimeSeries], configuration: ChartConfiguration = ChartConfiguration()) {
        var configuration = configuration
        configuration.aggregation = .none // every raw reading is plotted
        self.data = data
        _presenter = State(initialValue: ChartPresenter(data: data, configuration: configuration, traits: ChartPresenter.Traits(isContinuous: false)))
    }

    public var body: some View {
        TimeSeriesChart(presenter: presenter, data: data) {
            if let selection = presenter.selection {
                SelectionStick(date: selection.date, bucket: presenter.bucket)
            }
            SeriesPoints(points: presenter.linePoints, size: pointSize, unit: .day)
        }
    }

    /// Smaller points on the longer scales, where there are many more readings on screen.
    private var pointSize: CGFloat {
        switch presenter.scale {
        case .day, .week: 16
        case .month: 10
        case .sixMonths, .year: 4
        }
    }
}

#Preview {
    ScatterChart(data: TimeSeries.samples())
}
