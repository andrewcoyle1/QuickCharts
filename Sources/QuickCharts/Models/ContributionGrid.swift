//
//  ContributionGrid.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Foundation

/// The days of a contribution chart, arranged into columns and graded against a goal.
///
/// All of the chart's date and value reasoning lives here, with no SwiftUI in sight, so it can be
/// tested directly and reused by anything that wants to draw the same days its own way:
/// `ContributionChart` is one presentation of a grid, not the only possible one.
public nonisolated struct ContributionGrid: Equatable, Sendable {

    /// The squares, column by column, each column holding `rows` days top to bottom. Days run down
    /// a column and then on to the next, so flattening this is the grid in date order.
    public let columns: [[ContributionCell]]

    /// How the days were arranged.
    public let layout: ContributionLayout

    /// The value a day is measured against: a day at or past it takes the fullest shade.
    public let goal: Double

    /// How many shades a square can take, counting empty.
    public let levels: Int

    /// The first day of the grid, which may be earlier than the first reading.
    public let startDate: Date

    /// The last day the grid counts. Days after it are placeholders.
    public let endDate: Date

    private let calendar: Calendar

    public var rows: Int {
        layout.rows
    }

    public var columnCount: Int {
        layout.columns
    }

    /// Every square in date order, oldest first.
    public var cells: [ContributionCell] {
        columns.flatMap { $0 }
    }

    /// The squares standing for real days, oldest first.
    public var days: [ContributionCell] {
        cells.filter { !$0.isPlaceholder }
    }

    /// Builds the grid from a series' readings.
    ///
    /// - Parameters:
    ///   - series: The readings to plot. Readings on the same day are combined by `aggregation`;
    ///     days with no reading are drawn empty. Pass nil for an empty grid of the right shape.
    ///   - layout: How the days are arranged.
    ///   - goal: What a full square means. Values at or above it take the top shade. Clamped above
    ///     zero, since it divides.
    ///   - levels: How many shades a square can take, counting empty.
    ///   - aggregation: How one day's readings combine. `.none` is treated as `.average`, since a
    ///     square has one shade whatever the day holds.
    ///   - endDate: The last day the grid counts, normally today.
    public init(
        series: TimeSeries?,
        layout: ContributionLayout = .calendar(),
        goal: Double = 1,
        levels: Int = 5,
        aggregation: Aggregation = .average,
        endDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        let levels = max(2, levels)
        let goal = max(.leastNormalMagnitude, goal)
        let lastDay = calendar.startOfDay(for: endDate)
        let startDate = Self.startDate(for: layout, endDate: endDate, calendar: calendar)

        var valuesByDay: [Date: Double] = [:]
        for (day, readings) in Dictionary(grouping: series?.data ?? [], by: { calendar.startOfDay(for: $0.date) }) {
            valuesByDay[day] = aggregation.combine(readings.map(\.value), band: []).value
        }

        var columns: [[ContributionCell]] = []
        columns.reserveCapacity(layout.columns)
        for column in 0..<layout.columns {
            var cells: [ContributionCell] = []
            cells.reserveCapacity(layout.rows)
            for row in 0..<layout.rows {
                let offset = column * layout.rows + row
                let date = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
                // A week-aligned grid runs to the end of the week in progress; those days haven't
                // happened yet, so they hold the shape without claiming a zero.
                let value: Double? = date > lastDay ? nil : (valuesByDay[date] ?? 0)
                cells.append(
                    ContributionCell(
                        date: date,
                        value: value,
                        level: Self.level(for: value, goal: goal, levels: levels),
                        row: row,
                        column: column
                    )
                )
            }
            columns.append(cells)
        }

        self.columns = columns
        self.layout = layout
        self.goal = goal
        self.levels = levels
        self.startDate = startDate
        self.endDate = lastDay
        self.calendar = calendar
    }

    /// The first day a grid of this shape covers, given the day it ends on. A `.calendar` grid
    /// backs up to the start of the week holding `endDate` and then counts whole weeks, so its
    /// rows stay on one weekday; a `.packed` grid simply counts back `rows * columns` days.
    public static func startDate(for layout: ContributionLayout, endDate: Date, calendar: Calendar = .current) -> Date {
        let lastDay = calendar.startOfDay(for: endDate)
        switch layout {
        case .calendar(let weeks):
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: lastDay)?.start ?? lastDay
            return calendar.date(byAdding: .day, value: -7 * (max(1, weeks) - 1), to: weekStart) ?? weekStart
        case .packed(let rows, let columns):
            let totalDays = max(1, rows) * max(1, columns)
            return calendar.date(byAdding: .day, value: -(totalDays - 1), to: lastDay) ?? lastDay
        }
    }

    /// Which shade a day earns: empty for nothing logged, then evenly spaced steps up to the top
    /// shade at the goal. Any reading above zero is worth at least the first step, so a day that
    /// barely counts still looks different from one that didn't happen.
    static func level(for value: Double?, goal: Double, levels: Int) -> Int {
        guard let value, value > 0 else { return 0 }
        let top = max(1, levels - 1)
        let ratio = min(1, value / goal)
        return min(top, max(1, Int((ratio * Double(top)).rounded(.up))))
    }

    // MARK: - Labels

    /// The one-letter name of the weekday in `row`, or nil when the rows aren't weekdays.
    public func weekdayLabel(forRow row: Int) -> String? {
        guard layout.isWeekAligned else { return nil }
        guard let date = calendar.date(byAdding: .day, value: row, to: startDate) else { return nil }
        let weekday = calendar.component(.weekday, from: date)
        return calendar.veryShortWeekdaySymbols[safe: weekday - 1]
    }

    /// The short name of the month `column` starts in.
    public func monthLabel(forColumn column: Int) -> String {
        Self.monthFormatter.string(from: columns[safe: column]?.first?.date ?? startDate)
    }

    /// Whether `column` is where a new month starts, and so should carry its label. The first
    /// column only claims a label when the next column isn't also a boundary, so two labels never
    /// sit side by side.
    public func showsMonthLabel(forColumn column: Int) -> Bool {
        guard layout.isWeekAligned, let current = columns[safe: column]?.first?.date else { return false }
        func month(_ column: Int) -> Int? {
            columns[safe: column]?.first.map { calendar.component(.month, from: $0.date) }
        }
        let currentMonth = calendar.component(.month, from: current)
        if let previous = month(column - 1) {
            return previous != currentMonth
        }
        guard let next = month(column + 1) else { return true }
        return next == currentMonth
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()

    // MARK: - Summaries

    /// The days that had something logged.
    public var activeDayCount: Int {
        days.count { ($0.value ?? 0) > 0 }
    }

    /// The share of the grid's real days that had something logged, from 0 to 1.
    public var completionRate: Double {
        let days = days
        guard !days.isEmpty else { return 0 }
        return Double(activeDayCount) / Double(days.count)
    }

    /// The run of logged days ending on the grid's last day, counting back. Zero if the last day
    /// is empty.
    public var currentStreak: Int {
        days.reversed().prefix { ($0.value ?? 0) > 0 }.count
    }

    /// The longest run of logged days anywhere in the grid.
    public var longestStreak: Int {
        var longest = 0
        var run = 0
        for day in days {
            run = (day.value ?? 0) > 0 ? run + 1 : 0
            longest = max(longest, run)
        }
        return longest
    }

    /// Everything logged across the grid.
    public var total: Double {
        days.reduce(0) { $0 + ($1.value ?? 0) }
    }
}
