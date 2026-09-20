//
//  ContributionChart.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Charts
import SwiftUI

/// A day per square, shaded by how close that day came to the goal — a commit graph for anything
/// done daily, with a week per column and the weekdays down the rows.
///
/// Built from the same pieces as the other charts, and inspected the same way: it scrolls back
/// through every week there is data for, settling on a week and flicking on to a month; the header
/// says how many days on screen were logged and updates as you scroll; and pressing and holding
/// puts a callout on the day under your finger, which you can drag around the grid.
///
/// ```swift
/// ContributionChart(
///     data: [workouts],
///     configuration: ChartConfiguration(aggregation: .sum, unit: "workouts", goal: 1)
/// )
/// ```
///
/// Squares are a fixed size, so how much history fits on screen follows from the width — there is
/// no range picker, because a day is a day at any zoom. For a small, static grid inside a card,
/// use `ContributionGridView`, which draws the same squares with no scrolling or selection.
public struct ContributionChart: View {

    let data: [TimeSeries]
    @State private var presenter: ContributionPresenter

    /// Set by `ChartScreen` while one of its accessory rows is selected.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far apart the squares sit, as a share of a column, worked out from the style's spacing
    /// and the size the squares are drawn at.
    private var gapRatio: Double {
        min(0.4, presenter.style.spacing / max(1, cellSize))
    }

    /// The side of one square. The grid's height follows from it, and so does how many weeks fit.
    private var cellSize: CGFloat {
        presenter.style.cellSize ?? 18
    }

    /// - Parameters:
    ///   - data: The series to plot. A grid draws one value per day, so only the first series is
    ///     used; the array is there to match the other charts' shape.
    ///   - configuration: The goal a day is measured against (`goal`, defaulting to 1), the colour
    ///     (`seriesColors` first), how a day's readings combine (`aggregation`), and how values are
    ///     written (`unit`, `valueFormat`).
    ///   - style: How the squares are drawn. `layout` is ignored — the chart is always a week per
    ///     column; it is `ContributionGridView` that arranges days some other way.
    ///   - endDate: The last day the chart counts, normally today.
    public init(
        data: [TimeSeries],
        configuration: ChartConfiguration = ChartConfiguration(),
        style: ContributionStyle = ContributionStyle(),
        endDate: Date = Date()
    ) {
        self.data = data
        _presenter = State(
            initialValue: ContributionPresenter(
                data: data,
                configuration: configuration,
                style: style,
                endDate: endDate
            )
        )
    }

    /// Plots a value per day straight from an array, oldest first, ending on `endDate`.
    ///
    /// For callers that hold a day-by-day array and have no dates to hand. Prefer the main
    /// initialiser: it keeps each reading's own date, so a day can't quietly shift by one.
    public init(
        values: [Double],
        configuration: ChartConfiguration = ChartConfiguration(),
        style: ContributionStyle = ContributionStyle(),
        endDate: Date = Date()
    ) {
        let calendar = Calendar.current
        let lastDay = calendar.startOfDay(for: endDate)
        let points = values.enumerated().map { offset, value in
            TimeSeriesDatapoint(
                id: "contribution-\(offset)",
                date: calendar.date(byAdding: .day, value: offset - (values.count - 1), to: lastDay) ?? lastDay,
                value: value
            )
        }
        self.init(
            data: [TimeSeries(name: configuration.accessibilityTitle, data: points)],
            configuration: configuration,
            style: style,
            endDate: endDate
        )
    }

    public var body: some View {
        VStack(alignment: .leading) {
            header

            chart
                .frame(height: 7 * cellSize)
                // How many weeks fit is the width divided by a square, so the squares stay square
                // whatever the chart is given.
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    presenter.weeksVisible = max(4, Int((width / cellSize).rounded()))
                }

            if presenter.style.showsLegend {
                ContributionLegend(color: presenter.color, style: presenter.style)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .onChange(of: data) { presenter.update(data: data) }
    }

    /// How many of the days on screen were logged. Updates live while scrolling, and steps aside
    /// for the callout, exactly as `RangeHeader` does on the other charts.
    @ViewBuilder
    private var header: some View {
        if let summary = presenter.rangeSummary {
            SeriesSummary(
                rows: [summary.row],
                footer: Text("Days Logged, \(TimeScale.month.rangeDescription(summary.dates))"),
                unit: summary.label,
                valueFormat: .number.precision(.fractionLength(0))
            )
            .padding(8)
            .opacity(presenter.isSelecting ? 0 : 1)
            .animation(.easeInOut(duration: 0.15), value: presenter.isSelecting)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(presenter.cells) { cell in
                let week = weekBounds(of: cell)
                // The gap is a share of a column rather than a number of points, so it holds its
                // proportions however wide the chart is drawn — the same way the bar charts size
                // their bars within a bucket.
                let gap = week.upperBound.timeIntervalSince(week.lowerBound) * gapRatio / 2
                RectangleMark(
                    xStart: .value("Week start", week.lowerBound.addingTimeInterval(gap)),
                    xEnd: .value("Week end", week.upperBound.addingTimeInterval(-gap)),
                    yStart: .value("Row start", Double(6 - cell.row) + gapRatio / 2),
                    yEnd: .value("Row end", Double(7 - cell.row) - gapRatio / 2)
                )
                .foregroundStyle(presenter.style.color(forLevel: cell.level, base: presenter.color))
                .cornerRadius(presenter.style.cornerRadius)
                .accessibilityLabel(cell.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue(accessibilityValue(for: cell))
            }
        }
        .chartXScale(domain: presenter.fullDomain)
        .chartYScale(domain: 0...7)
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading, values: (0..<7).map { Double($0) + 0.5 }) { value in
                AxisValueLabel {
                    Text(weekdayLabel(forY: value.as(Double.self) ?? 0))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: presenter.monthStarts) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: false)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: presenter.visibleLength)
        .chartScrollPosition(x: Binding {
            presenter.scrollPosition
        } set: {
            presenter.scrollPosition = $0
        })
        // Settle on the nearest week, and let a flick carry on to the start of a month, so the
        // columns never come to rest halfway across a square.
        .chartScrollTargetBehavior(.valueAligned(
            matching: DateComponents(hour: 0, weekday: Calendar.current.firstWeekday),
            majorAlignment: .matching(DateComponents(day: 1, hour: 0))
        ))
        // Press and hold, then drag: the same gesture as the other charts, so it doesn't fight the
        // scroll. Both axes, because here a reading is a day, not a column.
        .chartXSelection(value: $presenter.rawSelectionX)
        .chartYSelection(value: $presenter.rawSelectionY)
        .chartOverlay { proxy in
            selectionOutline(proxy: proxy)
        }
        .chartCallout(item: presenter.selection, date: \.date, bucket: .weekOfYear) { _ in
            calloutContent
        }
    }

    /// A ring around the day under the finger, so it's clear which square the callout is about.
    @ViewBuilder
    private func selectionOutline(proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            if let selection = presenter.selection,
               let plotFrame = proxy.plotFrame,
               let centerX = proxy.centerX(ofBucketContaining: selection.date, component: .weekOfYear),
               let centerY = proxy.position(forY: Double(6 - row(of: selection.date)) + 0.5) {
                let plot = geo[plotFrame]
                RoundedRectangle(cornerRadius: presenter.style.cornerRadius, style: .continuous)
                    .stroke(presenter.color, lineWidth: 2)
                    .frame(width: cellSize, height: cellSize)
                    .position(x: plot.minX + centerX, y: plot.minY + centerY)
                    .allowsHitTesting(false)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: presenter.selection)
    }

    @ViewBuilder
    private var calloutContent: some View {
        if let selection = presenter.selection {
            SeriesSummary(
                rows: [presenter.selectionRow].compactMap { $0 },
                footer: Text(selection.date.formatted(Self.calloutDateFormat)),
                unit: presenter.configuration.unit,
                valueFormat: presenter.configuration.valueFormat
            )
        }
    }

    /// How the callout names the selected day.
    private static let calloutDateFormat = Date.FormatStyle.dateTime
        .weekday(.abbreviated).day().month(.abbreviated).year()

    /// What VoiceOver reads for a day: its value and unit, or that nothing was logged.
    private func accessibilityValue(for cell: ContributionCell) -> String {
        guard let value = cell.value, value > 0 else { return "No data" }
        let formatted = value.formatted(presenter.configuration.valueFormat)
        return presenter.configuration.unit.isEmpty ? formatted : "\(formatted) \(presenter.configuration.unit)"
    }

    /// The week a square sits in, which is the column it fills.
    private func weekBounds(of cell: ContributionCell) -> Range<Date> {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: cell.date) else {
            return cell.date..<cell.date.addingTimeInterval(ContributionPresenter.week)
        }
        return week.start..<week.end
    }

    /// Which row down the week a day sits in, 0 for the calendar's first weekday.
    private func row(of date: Date) -> Int {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return 0 }
        return calendar.dateComponents([.day], from: week, to: date).day ?? 0
    }

    /// The one-letter weekday for a row of the plot, whose y runs upwards while weekdays run down.
    private func weekdayLabel(forY value: Double) -> String {
        let calendar = Calendar.current
        let row = 6 - Int(value.rounded(.down))
        let index = (calendar.firstWeekday - 1 + row) % 7
        return calendar.veryShortWeekdaySymbols[safe: index] ?? ""
    }
}

#Preview("Contribution") {
    ContributionChart(
        data: TimeSeries.samples(),
        configuration: ChartConfiguration(unit: "sessions", goal: 9, accessibilityTitle: "Workouts")
    )
    .padding()
}
