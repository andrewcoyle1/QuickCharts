//
//  ComboChart.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Charts

/// Bars with a line drawn over them, for comparing a total against a level: calories eaten against
/// calories burned, spend against budget, rainfall against average. The series named in `lineSeries`
/// become the lines; the rest are bars, side by side in each bucket.
///
/// The line is a series like any other, so it appears in the header, the callout and the accessory
/// rows, and it can be highlighted. Unlike `ChartConfiguration.goal`, which is one fixed value, it
/// moves with the data.
public struct ComboChart: View {

    let data: [TimeSeries]
    let lineSeries: Set<String>
    @State private var presenter: ChartPresenter

    /// New `data` passed in later is picked up; the configuration is read once, when the view first
    /// appears. To change it, give the view a new `.id`.
    ///
    /// - Parameter lineSeries: the names of the series to draw as lines. A name with no series is
    ///   ignored, and naming every series gives a chart of lines alone.
    public init(data: [TimeSeries], lineSeries: Set<String>, configuration: ChartConfiguration = ChartConfiguration()) {
        self.data = data
        self.lineSeries = lineSeries
        _presenter = State(initialValue: ChartPresenter(
            data: data,
            configuration: configuration,
            // The bars measure from zero, so the axis keeps it even when the line sits well above.
            traits: ChartPresenter.Traits(
                isContinuous: false,
                placesSeriesSideBySide: true,
                startsAtZero: true,
                lineSeries: lineSeries
            )
        ))
    }

    public var body: some View {
        TimeSeriesChart(presenter: presenter, data: data) {
            if let selection = presenter.selection {
                SelectionStick(date: selection.date, bucket: presenter.bucket)
            }
            SeriesBars(points: barPoints, bucket: presenter.bucket, slots: presenter.seriesSlots)
            // Over the bars, so the level being compared against stays readable.
            SeriesLines(points: linePoints, showsPoints: false)
            if let selection = presenter.selection {
                SelectionLollipop(selection: selection, bucket: presenter.bucket, series: lineSeries)
            }
        }
    }

    private var barPoints: [PlotPoint] {
        presenter.linePoints.filter { !lineSeries.contains($0.series) }
    }

    private var linePoints: [PlotPoint] {
        presenter.linePoints.filter { lineSeries.contains($0.series) }
    }
}

#Preview {
    ComboChart(
        data: TimeSeries.samples(),
        lineSeries: ["Sample Set 2"],
        configuration: ChartConfiguration(unit: "kcal")
    )
}
