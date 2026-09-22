//
//  StepChart.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Charts
import SwiftUI

/// Each series as a line that holds its value across each bucket, with a lollipop on the selected
/// bucket.
public struct StepChart: View {

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
            SeriesLines(points: presenter.linePoints, interpolation: .stepCenter, showsPoints: false)
            if let selection = presenter.selection {
                SelectionLollipop(selection: selection, bucket: presenter.bucket)
            }
        }
    }
}

#Preview {
    StepChart(data: TimeSeries.samples())
}
