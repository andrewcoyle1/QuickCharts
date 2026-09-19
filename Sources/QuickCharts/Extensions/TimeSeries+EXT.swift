//
//  TimeSeries+EXT.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

nonisolated extension TimeSeries {
    /// The line's points flattened for the vectorized plots, which split series by name.
    var plotPoints: [PlotPoint] {
        sortedByDate.map { PlotPoint(series: name, date: $0.date, value: $0.value) }
    }

    /// The band's points flattened for the vectorized plots.
    var plotBandPoints: [PlotBandPoint] {
        band.map { PlotBandPoint(series: name, date: $0.date, lower: $0.lower, upper: $0.upper) }
    }

    /// The points in the same `component` bucket (day, week, month…) as `date`.
    func points(inBucketOf date: Date, component: Calendar.Component) -> [TimeSeriesDatapoint] {
        sortedByDate.filter { Calendar.current.isDate($0.date, equalTo: date, toGranularity: component) }
    }

    /// The band points in the same `component` bucket as `date`.
    func bandPoints(inBucketOf date: Date, component: Calendar.Component) -> [TimeSeriesBandDatapoint] {
        band.filter { Calendar.current.isDate($0.date, equalTo: date, toGranularity: component) }
    }
}

nonisolated extension TimeSeries {
    /// Random sample data, for previews and demos: two series over the past year, the first with a ±1 band. Use several
    /// `readingsPerDay` to give each day a spread, e.g. for a range chart.
    public static func samples(readingsPerDay: Int = 1) -> [TimeSeries] {
        let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
        return [
            .mock(name: "Sample Set 1", startDate: yearAgo, lowerBound: 5, upperBound: 10, readingsPerDay: readingsPerDay)
                .withBand { ($0.value - 1)...($0.value + 1) },
            .mock(name: "Sample Set 2", startDate: yearAgo, lowerBound: 6, upperBound: 12, readingsPerDay: readingsPerDay),
        ]
    }
}
