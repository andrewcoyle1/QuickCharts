//
//  ContributionPresenter.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 20/09/2026.
//

import SwiftUI

/// Everything a scrolling contribution chart shows, worked out from the data and the scroll and
/// selection state.
///
/// Follows `ChartPresenter`'s pattern: `scrollPosition` changes every frame and so is never
/// observed, and feeds `visibleStart`, which changes only when the leading edge crosses into
/// another week, and `chunk`, which changes once per screen. So the header updates live while
/// scrolling and the squares are rebuilt about once a screen.
@Observable
final class ContributionPresenter {

    /// The days on screen and how many of them were logged.
    struct RangeSummary {
        let row: SelectionRow
        /// What follows the figure, e.g. "of 35 days".
        let label: String
        /// End exclusive.
        let dates: Range<Date>
    }

    /// A day under the finger, and what it holds.
    struct Selection: Equatable {
        let date: Date
        let value: Double
    }

    /// The readings, at their original resolution.
    private(set) var data: [TimeSeries]

    /// How the data is combined, coloured and written.
    let configuration: ChartConfiguration

    /// How the squares are drawn.
    let style: ContributionStyle

    /// The last day the chart counts, normally today.
    let endDate: Date

    private let calendar: Calendar

    /// One day's combined value, for every day that has readings.
    private var valuesByDay: [Date: Double]

    /// How many week-columns fit on screen, set from the plot's width so the squares stay square.
    var weeksVisible: Int = 16 {
        didSet {
            guard weeksVisible != oldValue else { return }
            updateChunk()
        }
    }

    /// The date at the chart's leading (left) edge. Bound to `chartScrollPosition`, so it changes
    /// every frame; not observed.
    @ObservationIgnored var scrollPosition: Date {
        didSet {
            updateVisibleStart()
            updateChunk()
        }
    }

    /// `scrollPosition` snapped to the start of the nearest week: what the header describes.
    private(set) var visibleStart: Date

    /// Which screen-length stretch of weeks the leading edge is in, counting back from the current
    /// one (0). The squares are built around this, so it's the only scroll state they rebuild for.
    private(set) var chunk = 0

    /// The raw x under the finger, from `chartXSelection`. Not observed: it changes every drag
    /// frame, and is snapped into `selection` instead.
    @ObservationIgnored var rawSelectionX: Date? {
        didSet { updateSelection() }
    }

    /// The raw y under the finger, from `chartYSelection`, as a row in the week.
    @ObservationIgnored var rawSelectionY: Double? {
        didSet { updateSelection() }
    }

    /// The day under the finger. Nil when not pressing, or when the finger is over a day the chart
    /// doesn't cover, such as one still to come.
    private(set) var selection: Selection?

    /// Whether the user is pressing on the grid.
    var isSelecting: Bool { selection != nil }

    init(
        data: [TimeSeries],
        configuration: ChartConfiguration = ChartConfiguration(),
        style: ContributionStyle = ContributionStyle(),
        endDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.data = data
        self.configuration = configuration
        self.style = style
        self.endDate = endDate
        self.calendar = calendar
        self.valuesByDay = Self.valuesByDay(in: data, aggregation: configuration.aggregation, calendar: calendar)
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: endDate)?.start ?? endDate
        // Opens on the most recent weeks, with the current one at the trailing edge.
        self.scrollPosition = currentWeek
        self.visibleStart = currentWeek
        self.scrollPosition = Self.weeksBack(weeksVisible - 1, from: currentWeek, calendar: calendar)
        self.visibleStart = scrollPosition
    }

    /// Takes on data the view was given later. The view holds the presenter in `@State`, so it
    /// only ever saw the data it was created with.
    func update(data: [TimeSeries]) {
        guard data != self.data else { return }
        self.data = data
        valuesByDay = Self.valuesByDay(in: data, aggregation: configuration.aggregation, calendar: calendar)
    }

    // MARK: - Domain

    /// The value a full square means.
    var goal: Double { max(.leastNormalMagnitude, configuration.goal ?? 1) }

    /// How many shades a square can take.
    var levels: Int { style.levels }

    /// The series colour the shades are built from.
    var color: Color { configuration.seriesColors.first ?? .green }

    /// How much time one screen shows.
    var visibleLength: TimeInterval { Double(weeksVisible) * Self.week }

    /// Everything that can be scrolled to: from the week holding the oldest reading to the end of
    /// the week in progress, so the rest of this week shows as empty, like Health.
    var fullDomain: ClosedRange<Date> {
        let currentWeekEnd = calendar.dateInterval(of: .weekOfYear, for: endDate)?.end ?? endDate
        let earliest = data.compactMap { $0.sortedByDate.first?.date }.min() ?? currentWeekEnd
        let firstWeek = calendar.dateInterval(of: .weekOfYear, for: earliest)?.start ?? earliest
        // Always at least a screen wide, or there is nothing to scroll and Charts has no room to
        // place the visible domain.
        let start = min(firstWeek, Self.weeksBack(weeksVisible, from: currentWeekEnd, calendar: calendar))
        return start...currentWeekEnd
    }

    /// The squares to draw: the days of the weeks around the leading edge, a screen either side, so
    /// scrolling doesn't run off the end of what's been built.
    var cells: [ContributionCell] {
        let range = loadedRange
        var cells: [ContributionCell] = []
        var date = range.lowerBound
        var column = 0
        let lastDay = calendar.startOfDay(for: endDate)
        while date < range.upperBound {
            for row in 0..<7 {
                let day = calendar.date(byAdding: .day, value: row, to: date) ?? date
                // Days still to come hold no square at all: on a grid that runs to the end of the
                // week, drawing them as empty would claim they were missed.
                guard day <= lastDay else { continue }
                let value = valuesByDay[day] ?? 0
                cells.append(
                    ContributionCell(
                        date: day,
                        value: value,
                        level: ContributionGrid.level(for: value, goal: goal, levels: levels),
                        row: row,
                        column: column
                    )
                )
            }
            date = calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? range.upperBound
            column += 1
        }
        return cells
    }

    /// The week starts of the loaded range, where the x axis puts its labels.
    var monthStarts: [Date] {
        calendar.starts(of: .month, in: loadedRange)
    }

    /// The weeks loaded around the leading edge: the screen the chunk covers, plus one either side.
    private var loadedRange: Range<Date> {
        let start = chunkStart(chunk - 1)
        let end = chunkStart(chunk + 2)
        return start..<end
    }

    private func chunkStart(_ chunk: Int) -> Date {
        Self.weeksBack(-chunk * weeksVisible, from: currentWeekStart, calendar: calendar)
    }

    private var currentWeekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: endDate)?.start ?? endDate
    }

    // MARK: - Header

    /// The days on screen, and how many of them were logged: what the header says.
    var rangeSummary: RangeSummary? {
        guard let series = data.first else { return nil }
        let start = visibleStart
        let end = min(
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate,
            start.addingTimeInterval(visibleLength)
        )
        guard start < end else { return nil }
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        var logged = 0
        var date = start
        while date < end {
            if (valuesByDay[calendar.startOfDay(for: date)] ?? 0) > 0 { logged += 1 }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? end
        }
        let row = SelectionRow(
            series: series,
            point: TimeSeriesDatapoint(date: start, value: Double(logged)),
            band: nil,
            color: color
        )
        return RangeSummary(row: row, label: "of \(days) days", dates: start..<end)
    }

    /// The selected day as a header row, for the callout. Nil on a day with nothing logged, so the
    /// callout says "No Data" in the same place the figure would be, as the other charts do.
    var selectionRow: SelectionRow? {
        guard let selection, selection.value > 0, let series = data.first else { return nil }
        return SelectionRow(
            series: series,
            point: TimeSeriesDatapoint(date: selection.date, value: selection.value),
            band: nil,
            color: color
        )
    }

    // MARK: - Updates

    private func updateVisibleStart() {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: scrollPosition) else { return }
        let snapped = scrollPosition.timeIntervalSince(week.start) < week.duration / 2 ? week.start : week.end
        if snapped != visibleStart { visibleStart = snapped }
    }

    private func updateChunk() {
        let weeks = scrollPosition.timeIntervalSince(currentWeekStart) / Self.week
        let newChunk = Int((weeks / Double(max(1, weeksVisible))).rounded(.down))
        if newChunk != chunk { chunk = newChunk }
    }

    /// Turns the raw x and y under the finger into the day it is over. The y is a row in the week,
    /// counted from the bottom, because the plot's y runs upwards while the weekdays run down.
    private func updateSelection() {
        guard let pressedDate = rawSelectionX, let pressedY = rawSelectionY else {
            if selection != nil { selection = nil }
            return
        }
        guard let week = calendar.dateInterval(of: .weekOfYear, for: pressedDate)?.start else { return }
        let row = 6 - Int(pressedY.rounded(.down))
        guard (0...6).contains(row), let day = calendar.date(byAdding: .day, value: row, to: week) else {
            if selection != nil { selection = nil }
            return
        }
        let lastDay = calendar.startOfDay(for: endDate)
        guard day <= lastDay, day >= fullDomain.lowerBound else {
            if selection != nil { selection = nil }
            return
        }
        let new = Selection(date: day, value: valuesByDay[day] ?? 0)
        if new != selection { selection = new }
    }

    // MARK: - Helpers

    static let week: TimeInterval = 7 * 24 * 3600

    private static func weeksBack(_ weeks: Int, from date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .weekOfYear, value: -weeks, to: date) ?? date
    }

    private static func valuesByDay(
        in data: [TimeSeries],
        aggregation: Aggregation,
        calendar: Calendar
    ) -> [Date: Double] {
        var values: [Date: Double] = [:]
        guard let series = data.first else { return values }
        for (day, readings) in Dictionary(grouping: series.data, by: { calendar.startOfDay(for: $0.date) }) {
            values[day] = aggregation.combine(readings.map(\.value), band: []).value
        }
        return values
    }
}
