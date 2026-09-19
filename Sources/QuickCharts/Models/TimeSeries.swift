//
//  TimeSeries.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

/// A named set of readings, drawn as one series of a chart, with an optional band.
///
/// Equatable so a chart can tell when it's been handed new data.
public nonisolated struct TimeSeries: Identifiable, Equatable, Sendable {
    /// The series' name, shown in the header and callout. Also its identity, so keep names unique
    /// within a chart.
    public let name: String

    /// The readings, in any order.
    public let data: [TimeSeriesDatapoint]
    
    /// The readings sorted oldest first. Sorted once, when the series is made, so it's cheap to
    /// read repeatedly, e.g. to binary-search a visible range.
    public let sortedByDate: [TimeSeriesDatapoint]

    /// The latest reading, or nil if there are none.
    public let lastByDate: TimeSeriesDatapoint?

    /// Optional shaded range drawn behind the line. Empty means no band.
    public let band: [TimeSeriesBandDatapoint]

    public var id: String {
        name
    }
    
    public init(name: String, data: [TimeSeriesDatapoint], band: [TimeSeriesBandDatapoint] = []) {
        self.name = name
        self.data = data
        self.sortedByDate = data.sorted { $0.date < $1.date }
        self.lastByDate = data.max { $0.date < $1.date }
        self.band = band.sorted { $0.date < $1.date }
    }

    /// A copy of this series with a band built from each datapoint, e.g.
    /// `series.withBand { ($0.value - 1)...($0.value + 1) }`.
    public func withBand(_ bounds: (TimeSeriesDatapoint) -> ClosedRange<Double>) -> TimeSeries {
        let band = sortedByDate.map { point in
            let range = bounds(point)
            return TimeSeriesBandDatapoint(date: point.date, lower: range.lowerBound, upper: range.upperBound)
        }
        return TimeSeries(name: name, data: data, band: band)
    }

    /// A copy holding only the points (and band points) inside `range`.
    func filtered(to range: Range<Date>) -> TimeSeries {
        TimeSeries(
            name: name,
            data: data.filter { range.contains($0.date) },
            band: band.filter { range.contains($0.date) }
        )
    }

    /// A copy with one point per `component` bucket (day, week, month…), combining the readings in
    /// that bucket by `aggregation` and dated at the bucket's midpoint, which is where unit-based
    /// marks centre them and where the lollipop stick sits. `.none` returns the readings unchanged.
    func bucketed(by component: Calendar.Component, aggregation: Aggregation = .average) -> TimeSeries {
        guard aggregation != .none else { return self }
        let calendar = Calendar.current
        func bucketMidpoint(_ date: Date) -> Date {
            guard let interval = calendar.dateInterval(of: component, for: date) else { return date }
            return interval.start.addingTimeInterval(interval.duration / 2)
        }
        let bandByBucket = Dictionary(grouping: band) { bucketMidpoint($0.date) }
        var points: [TimeSeriesDatapoint] = []
        var bandPoints: [TimeSeriesBandDatapoint] = []
        for (date, readings) in Dictionary(grouping: data, by: { bucketMidpoint($0.date) }) {
            let combined = aggregation.combine(readings.map(\.value), band: bandByBucket[date] ?? [])
            let key = "\(name)-\(date.timeIntervalSinceReferenceDate)"
            points.append(TimeSeriesDatapoint(id: key, date: date, value: combined.value))
            if let band = combined.band {
                bandPoints.append(TimeSeriesBandDatapoint(id: "\(key)-band", date: date, lower: band.lowerBound, upper: band.upperBound))
            }
        }
        // Dictionary order is random; lines join points in array order. (The init sorts the band.)
        return TimeSeries(name: name, data: points.sorted { $0.date < $1.date }, band: bandPoints)
    }

    /// Random sample data, for previews and demos: a series with `readingsPerDay` datapoints a day, spread evenly from midnight, from
    /// `startDate` through `endDate` (inclusive), each value drawn uniformly at random between
    /// `lowerBound` and `upperBound`.
    public static func mock(
        name: String = "Mock",
        startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now,
        endDate: Date = .now,
        lowerBound: Double = 0,
        upperBound: Double = 1,
        readingsPerDay: Int = 1
    ) -> TimeSeries {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let range = min(lowerBound, upperBound)...max(lowerBound, upperBound)

        var data: [TimeSeriesDatapoint] = []
        var date = start
        while date <= end {
            for reading in 0..<max(1, readingsPerDay) {
                let time = date.addingTimeInterval(Double(reading) * 86_400 / Double(max(1, readingsPerDay)))
                data.append(TimeSeriesDatapoint(date: time, value: Double.random(in: range)))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return TimeSeries(name: name, data: data)
    }
}
