//
//  ChartMarks.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Charts
import SwiftUI

// Vectorized plots draw every point of every series in one call each, which is far cheaper than a
// mark per point. They take one flat array and split it into series by name.
//
// Never give a vectorized plot a `unit:` projection: on iOS 18 it crashes at layout ("Range
// requires comparable data"). Marks that fill a bucket (bars, ranges) are drawn one per point
// instead, which is fine since only the loaded range is plotted: a few hundred marks at most.

/// Each series' shaded band. Draw it before `SeriesLines` so the lines sit on top.
struct SeriesBands: ChartContent {
    let points: [PlotBandPoint]

    var body: some ChartContent {
        AreaPlot(
            points,
            x: .value("Day", \.date),
            yStart: .value("Lower", \.lower),
            yEnd: .value("Upper", \.upper),
            series: .value("Band", \.series)
        )
        // Same value as the line, so the band takes the line's colour with no extra legend entry.
        .foregroundStyle(by: .value("Series", \.series))
        .opacity(0.2)
        .interpolationMethod(.catmullRom) // must match SeriesLines'
    }
}

/// Each series' line, optionally with a small symbol on every point. `.stepCenter` interpolation
/// holds each value across its bucket.
struct SeriesLines: ChartContent {
    let points: [PlotPoint]
    var interpolation: InterpolationMethod = .catmullRom
    var showsPoints = true

    var body: some ChartContent {
        LinePlot(
            points,
            x: .value("Day", \.date),
            y: .value("Value", \.value),
            series: .value("Series", \.series)
        )
        .foregroundStyle(by: .value("Series", \.series))
        .interpolationMethod(interpolation)
        if showsPoints {
            SeriesPoints(points: points)
        }
    }
}

/// A small symbol on every point, shaped per series. Set `unit` to centre raw readings in their
/// day (or other unit) rather than at their exact time; bucketed points are already centred.
struct SeriesPoints: ChartContent {
    let points: [PlotPoint]
    var size: CGFloat = 24
    var unit: Calendar.Component?

    var body: some ChartContent {
        PointPlot(
            centered,
            x: .value("Day", \.date),
            y: .value("Value", \.value)
        )
        .foregroundStyle(by: .value("Series", \.series))
        .symbol(by: .value("Series", \.series))
        .symbolSize(size)
    }

    /// `points` moved to the middle of their `unit`, if set. Done here rather than with a `unit:`
    /// projection, which vectorized plots can't take on iOS 18.
    private var centered: [PlotPoint] {
        guard let unit else { return points }
        let calendar = Calendar.current
        return points.map { point in
            guard let interval = calendar.dateInterval(of: unit, for: point.date) else { return point }
            return PlotPoint(series: point.series, date: interval.start.addingTimeInterval(interval.duration / 2), value: point.value)
        }
    }
}

/// Each series' area, filled down to zero and overlapping rather than stacked, fading out towards
/// the bottom so overlaps stay light. Draw `SeriesLines` over it for a crisp edge.
struct SeriesAreas: ChartContent {
    let points: [PlotPoint]
    /// Each series' colour by name. The gradients are styled per series, so they can't take their
    /// colour from the chart's foreground style scale.
    let colors: [String: Color]

    var body: some ChartContent {
        // One plot per series, since each has its own gradient.
        ForEach(seriesPoints, id: \.series) { series, points in
            let color = colors[series] ?? .accentColor
            AreaPlot(
                points,
                x: .value("Day", \.date),
                y: .value("Value", \.value),
                // Without a series, Charts joins every plot here into one area.
                series: .value("Series", \.series),
                stacking: .unstacked
            )
            .foregroundStyle(LinearGradient(
                colors: [color.opacity(0.35), color.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .alignsMarkStylesWithPlotArea() // one gradient over the plot's height, not each mark's
            .interpolationMethod(.catmullRom) // must match the lines drawn over it
        }
    }

    /// `points` split by series, each in date order. Grouping loses the order, and an area joins
    /// its points in array order, so an unsorted one zigzags.
    private var seriesPoints: [(series: String, points: [PlotPoint])] {
        Dictionary(grouping: points, by: \.series)
            .map { (series: $0.key, points: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.series < $1.series }
    }
}

/// Each series' band as a floating capsule per bucket, side by side, e.g. a day's lowest to highest
/// reading.
struct SeriesRanges: ChartContent {
    let points: [PlotBandPoint]
    let bucket: Calendar.Component

    var body: some ChartContent {
        ForEach(points) { point in
            BarMark(
                x: .value("Day", point.date, unit: bucket),
                yStart: .value("Lower", point.lower),
                yEnd: .value("Upper", point.upper)
            )
            .foregroundStyle(by: .value("Series", point.series))
            .position(by: .value("Series", point.series))
            .clipShape(Capsule())
        }
    }
}

/// Each series as a bar per bucket, side by side or stacked on each other.
struct SeriesBars: ChartContent {
    let points: [PlotPoint]
    let bucket: Calendar.Component
    var stacked = false

    var body: some ChartContent {
        ForEach(points) { point in
            let bar = BarMark(
                x: .value("Day", point.date, unit: bucket),
                y: .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Series", point.series))
            if stacked {
                bar // bars at the same x stack by default
            } else {
                bar.position(by: .value("Series", point.series))
            }
        }
    }
}

/// A dashed line across the whole chart at a target value.
struct GoalLine: ChartContent {
    let value: Double

    var body: some ChartContent {
        RuleMark(y: .value("Goal", value))
            // Color.secondary explicitly: plain `.secondary` in a chart takes the first series' colour.
            .foregroundStyle(Color.secondary)
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
    }
}

/// The stick for the selected bucket, behind everything else. The callout is drawn in the chart's
/// overlay, above the plot.
struct SelectionStick: ChartContent {
    let date: Date
    let bucket: Calendar.Component

    var body: some ChartContent {
        RuleMark(x: .value("Selected", date, unit: bucket))
            .foregroundStyle(.secondary.opacity(0.4))
            .zIndex(-1)
    }
}

/// The lollipop for the selected bucket: the stick, plus a head on each series that has a value
/// there.
struct SelectionLollipop: ChartContent {
    let selection: ChartPresenter.Selection
    let bucket: Calendar.Component

    var body: some ChartContent {
        SelectionStick(date: selection.date, bucket: bucket)
        ForEach(selection.rows) { row in
            PointMark(
                x: .value("Day", row.point.date, unit: bucket),
                y: .value("Value", row.point.value)
            )
            .foregroundStyle(by: .value("Series", row.series.name))
            .symbolSize(120)
        }
    }
}
