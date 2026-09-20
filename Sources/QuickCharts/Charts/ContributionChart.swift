//
//  ContributionChart.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 20/09/2026.
//

import SwiftUI

/// A day per square, shaded by how close that day came to the goal — a commit graph for anything
/// done daily.
///
/// Built from the same pieces as the other charts: readings come in as `TimeSeries`, the goal,
/// colour, unit and number format come from `ChartConfiguration`, and `ContributionStyle` covers
/// the things only a grid has — its shape, how many shades it steps through, and which labels it
/// carries.
///
/// ```swift
/// ContributionChart(
///     data: [workouts],
///     configuration: ChartConfiguration(aggregation: .sum, unit: "workouts", goal: 1),
///     style: ContributionStyle(layout: .calendar(weeks: 16))
/// )
/// ```
///
/// The chart is a composition, not a black box: `ContributionGrid` does the date and value work
/// with no SwiftUI attached, `ContributionGridView` draws the squares, and `ContributionLegend`
/// draws the key. A card that wants the squares under its own heading, with its own streak figure
/// from `grid.currentStreak`, should use those directly rather than switching pieces of this off.
public struct ContributionChart: View {

    let grid: ContributionGrid
    let configuration: ChartConfiguration
    let style: ContributionStyle

    @State private var selection: ContributionCell?

    /// - Parameters:
    ///   - data: The series to plot. A grid draws one value per day, so only the first series is
    ///     used; the array is there to match the other charts' shape.
    ///   - configuration: The goal each day is measured against (`goal`, defaulting to 1), the
    ///     colour (`seriesColors` first), how a day's readings combine (`aggregation`), and how
    ///     values are written (`unit`, `valueFormat`).
    ///   - style: How the grid is drawn.
    ///   - endDate: The last day the grid counts, normally today.
    public init(
        data: [TimeSeries],
        configuration: ChartConfiguration = ChartConfiguration(),
        style: ContributionStyle = ContributionStyle(),
        endDate: Date = Date()
    ) {
        self.grid = ContributionGrid(
            series: data.first,
            layout: style.layout,
            goal: configuration.goal ?? 1,
            levels: style.levels,
            aggregation: configuration.aggregation,
            endDate: endDate
        )
        self.configuration = configuration
        self.style = style
    }

    /// Plots a value per day straight from an array, oldest first, aligned to the start of the
    /// grid. Values past the end of the array are drawn as days with nothing logged.
    ///
    /// For callers that already hold a day-by-day array and have no dates to hand. Everything
    /// else is the same as the main initialiser, which is the one to prefer: it keeps each
    /// reading's own date, so a day can't quietly shift by one when the array is short.
    public init(
        values: [Double],
        configuration: ChartConfiguration = ChartConfiguration(),
        style: ContributionStyle = ContributionStyle(),
        endDate: Date = Date()
    ) {
        let calendar = Calendar.current
        let start = ContributionGrid.startDate(for: style.layout, endDate: endDate, calendar: calendar)
        let points = values.enumerated().map { offset, value in
            TimeSeriesDatapoint(
                id: "contribution-\(offset)",
                date: calendar.date(byAdding: .day, value: offset, to: start) ?? start,
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
        VStack(alignment: .leading, spacing: 8) {
            if style.allowsSelection {
                caption
            }

            ContributionGridView(grid: grid, color: color, style: style, selection: $selection)

            if style.showsLegend {
                ContributionLegend(color: color, style: style)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .accessibilityLabel(configuration.accessibilityTitle)
    }

    /// One line above the grid: the selected day, or the range on show when nothing is selected.
    /// Always one line, so selecting a day doesn't shift the grid under the finger that did it.
    private var caption: some View {
        Text(captionText)
            .font(.footnote)
            .foregroundStyle(selection == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .lineLimit(1)
            .animation(nil, value: selection)
    }

    private var captionText: String {
        guard let selection, let value = selection.value else {
            let start = grid.startDate.formatted(date: .abbreviated, time: .omitted)
            let end = grid.endDate.formatted(date: .abbreviated, time: .omitted)
            return "\(start) – \(end)"
        }
        let date = selection.date.formatted(date: .abbreviated, time: .omitted)
        let formatted = value.formatted(configuration.valueFormat)
        return configuration.unit.isEmpty ? "\(date) · \(formatted)" : "\(date) · \(formatted) \(configuration.unit)"
    }

    private var color: Color {
        configuration.seriesColors.first ?? .green
    }
}

#Preview("Calendar") {
    ContributionChart(
        data: TimeSeries.samples(),
        configuration: ChartConfiguration(unit: "sessions", goal: 9, accessibilityTitle: "Workouts"),
        style: ContributionStyle(layout: .calendar(weeks: 16))
    )
    .padding()
}

#Preview("Packed card") {
    ContributionChart(
        data: TimeSeries.samples(),
        configuration: ChartConfiguration(aggregation: .sum, seriesColors: [.orange], goal: 9),
        style: .card()
    )
    .padding()
}
