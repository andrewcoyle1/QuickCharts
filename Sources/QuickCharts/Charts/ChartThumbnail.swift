//
//  ChartThumbnail.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 30/09/2026.
//

import Charts
import SwiftUI

/// A chart with nothing to operate: no picker, header, axes, scrolling or selection, and it takes
/// no touches. For a summary card whose whole surface is one button that opens the full chart,
/// where a chart of its own would fight the button for the press.
///
/// Each reading is drawn as given, one mark per day, so pass the window the card describes (e.g.
/// the last seven days). A reading of zero in a bar chart draws as a short grey stub, so a week
/// with rest days still shows seven slots.
public struct ChartThumbnail: View {

    public nonisolated enum Style: Sendable, Equatable {
        /// Each series as a line over a fading area.
        case line
        /// A bar per reading. More than one series stack on each other.
        case bars
        /// The series named in `lineSeries` as lines over the others' bars, e.g. calories burned
        /// over calories eaten.
        case combo(lineSeries: Set<String>)
    }

    let data: [TimeSeries]
    let style: Style
    let colors: [Color]
    let goal: Double?
    let height: CGFloat

    /// - Parameters:
    ///   - colors: one per series, in order, repeating if there are more series.
    ///   - goal: drawn as a dashed line. The y axis stretches to include it.
    public init(data: [TimeSeries], style: Style, colors: [Color], goal: Double? = nil, height: CGFloat = 36) {
        self.data = data
        self.style = style
        self.colors = colors.isEmpty ? [.accentColor] : colors
        self.goal = goal
        self.height = height
    }

    public var body: some View {
        Group {
            if data.allSatisfy({ $0.data.isEmpty }) {
                EmptyThumbnail()
            } else {
                chart
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }

    private var chart: some View {
        let geometry = ThumbnailGeometry(data: data, style: style, goal: goal)
        return Chart {
            ForEach(Array(data.enumerated()), id: \.element.name) { index, series in
                if geometry.isLine(series.name) {
                    lineMarks(series, color: color(at: index), floor: geometry.yDomain.lowerBound)
                } else {
                    barMarks(series, stub: geometry.stubHeight)
                }
            }
            if let goal {
                RuleMark(y: .value("Goal", goal))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
        }
        .chartForegroundStyleScale(domain: data.map(\.name), range: data.indices.map(color(at:)))
        .chartXScale(domain: geometry.xDomain)
        .chartYScale(domain: geometry.yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    @ChartContentBuilder
    private func lineMarks(_ series: TimeSeries, color: Color, floor: Double) -> some ChartContent {
        let points = ThumbnailGeometry.linePoints(series)
        // An area only for a line on its own; under a combo's line it would hide the bars.
        if style == .line {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Day", point.date, unit: .day),
                    yStart: .value("Floor", floor),
                    yEnd: .value("Value", point.value),
                    series: .value("Series", series.name)
                )
                .foregroundStyle(LinearGradient(
                    colors: [color.opacity(0.35), color.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .interpolationMethod(.catmullRom)
            }
        }
        ForEach(points) { point in
            LineMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Value", point.value),
                series: .value("Series", series.name)
            )
            .foregroundStyle(by: .value("Series", series.name))
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            .interpolationMethod(.catmullRom)
        }
    }

    @ChartContentBuilder
    private func barMarks(_ series: TimeSeries, stub: Double) -> some ChartContent {
        ForEach(series.sortedByDate) { point in
            if point.value > 0 {
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Series", series.name))
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            } else {
                // An explicit style, outside the series scale, so the stub stays grey.
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    yStart: .value("Base", 0),
                    yEnd: .value("Stub", stub)
                )
                .foregroundStyle(Color.gray.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            }
        }
    }

    private func color(at index: Int) -> Color {
        colors[index % colors.count]
    }
}

/// The scales a thumbnail is drawn on, worked out from its data. Separate from the view so it can
/// be tested.
nonisolated struct ThumbnailGeometry {
    let lineSeries: Set<String>
    let xDomain: ClosedRange<Date>
    let yDomain: ClosedRange<Double>
    /// A zero bar's height, in values: a sliver of the axis, so it reads as an empty slot.
    let stubHeight: Double

    init(data: [TimeSeries], style: ChartThumbnail.Style, goal: Double?) {
        let lines: Set<String>
        switch style {
        case .line: lines = Set(data.map(\.name))
        case .bars: lines = []
        case .combo(let names): lines = names
        }
        lineSeries = lines

        let calendar = Calendar.current
        let dates = data.flatMap { $0.data.map(\.date) }
        let first = calendar.startOfDay(for: dates.min() ?? .now)
        let lastDay = calendar.startOfDay(for: dates.max() ?? .now)
        // Whole days either end, so the first and last bars aren't cut in half.
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay.addingTimeInterval(86_400)
        // A single day's line needs somewhere to run from.
        let start = style == .line && first == lastDay ? (calendar.date(byAdding: .day, value: -1, to: first) ?? first) : first
        xDomain = start...end

        let lineValues = data.filter { lines.contains($0.name) }.flatMap { $0.data.map(\.value) }
        // Bars stack, so the axis fits each day's total.
        var barTotals: [Date: Double] = [:]
        for series in data where !lines.contains(series.name) {
            for point in series.data {
                barTotals[calendar.startOfDay(for: point.date), default: 0] += max(0, point.value)
            }
        }

        let goalValues = goal.map { [$0] } ?? []
        if lines.count == data.count {
            // Lines alone fit their values at both ends, so a weight moving between 82 and 83 kg
            // isn't flattened against a zero it never comes near.
            let values = lineValues + goalValues
            let low = values.min() ?? 0
            let high = values.max() ?? 1
            let padding = high > low ? (high - low) * 0.1 : max(abs(high) * 0.05, 1)
            yDomain = (low - padding)...(high + padding)
            stubHeight = 0
        } else {
            let high = (lineValues + Array(barTotals.values) + goalValues).max() ?? 0
            let top = high > 0 ? high : 1
            yDomain = 0...top
            stubHeight = top * 0.06
        }
    }

    func isLine(_ name: String) -> Bool {
        lineSeries.contains(name)
    }

    /// A series' points for a line: sorted, with a lone reading given a twin the day before so it
    /// draws as a line rather than nothing.
    static func linePoints(_ series: TimeSeries) -> [TimeSeriesDatapoint] {
        let points = series.sortedByDate
        guard points.count == 1, let only = points.first,
              let before = Calendar.current.date(byAdding: .day, value: -1, to: only.date) else { return points }
        return [TimeSeriesDatapoint(id: "\(only.id)-before", date: before, value: only.value), only]
    }
}

/// A dashed rule across the middle, for a thumbnail with no readings yet.
private struct EmptyThumbnail: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }
}

/// How far a single value has come towards its target, as a bar across a track with a tick at the
/// target, e.g. today's protein against the day's goal. Like `ChartThumbnail`, it takes no touches.
public struct ProgressThumbnail: View {

    let value: Double
    let target: Double?
    let maxValue: Double
    let color: Color
    let height: CGFloat

    /// - Parameter maxValue: the track's full length. Values past it fill the track.
    public init(value: Double, target: Double? = nil, maxValue: Double, color: Color, height: CGFloat = 36) {
        self.value = value
        self.target = target
        self.maxValue = maxValue > 0 ? maxValue : 1
        self.color = color
        self.height = height
    }

    public var body: some View {
        // The track is 8 pt tall and the target tick runs 4 pt past it either side; the plot is
        // just that tall, centred in the card's chart height.
        Chart {
            BarMark(xStart: .value("Start", 0), xEnd: .value("Track", maxValue), y: .value("Row", ""), height: .fixed(8))
                .foregroundStyle(Color.gray.opacity(0.25))
                .clipShape(Capsule())
            if value > 0 {
                BarMark(xStart: .value("Start", 0), xEnd: .value("Value", min(value, maxValue)), y: .value("Row", ""), height: .fixed(8))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }
            if let target, target > 0 {
                RuleMark(x: .value("Target", min(target, maxValue)))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
        .chartXScale(domain: 0...maxValue)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 16)
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

#Preview("Thumbnails") {
    let week = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
    VStack(spacing: 24) {
        ChartThumbnail(data: [TimeSeries.mock(name: "Weight", startDate: week, lowerBound: 82, upperBound: 83)], style: .line, colors: [.blue])
        ChartThumbnail(
            data: [TimeSeries(name: "Sets", data: (0..<7).map { TimeSeriesDatapoint(date: Calendar.current.date(byAdding: .day, value: $0, to: week) ?? .now, value: Double([0, 3, 6, 0, 8, 5, 2][$0])) })],
            style: .bars,
            colors: [.orange]
        )
        ChartThumbnail(
            data: [
                TimeSeries.mock(name: "Protein", startDate: week, lowerBound: 100, upperBound: 160),
                TimeSeries.mock(name: "Carbs", startDate: week, lowerBound: 150, upperBound: 250),
                TimeSeries.mock(name: "Fat", startDate: week, lowerBound: 50, upperBound: 80)
            ],
            style: .bars,
            colors: [.red, .blue, .yellow]
        )
        ChartThumbnail(
            data: [
                TimeSeries.mock(name: "Intake", startDate: week, lowerBound: 1800, upperBound: 2600),
                TimeSeries.mock(name: "Expenditure", startDate: week, lowerBound: 2300, upperBound: 2500)
            ],
            style: .combo(lineSeries: ["Expenditure"]),
            colors: [.orange, .pink]
        )
        ProgressThumbnail(value: 112, target: 150, maxValue: 180, color: .red)
        ChartThumbnail(data: [TimeSeries(name: "Empty", data: [])], style: .line, colors: [.blue])
    }
    .padding()
}
