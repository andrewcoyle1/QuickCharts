//
//  ContributionCell.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Foundation

/// One square of a contribution grid: the day it stands for, that day's combined reading, and which
/// shade of the series colour it earns.
///
/// A cell with no `value` is one the grid drew to keep its shape — the days before the series
/// starts, or the days after `endDate` in the week still in progress. It is laid out but not
/// filled, so a week-aligned grid stays rectangular without inventing zeroes.
public nonisolated struct ContributionCell: Identifiable, Equatable, Sendable {

    /// The start of the day this square stands for.
    public let date: Date

    /// The day's readings combined by the chart's aggregation, or nil for a placeholder day.
    public let value: Double?

    /// How full the square is drawn, from 0 (empty) to `ContributionStyle.levels - 1` (at or past
    /// the goal). A placeholder day is 0.
    public let level: Int

    /// Where the square sits: row down the column, column across the grid, both 0-based.
    public let row: Int
    public let column: Int

    public var id: Date {
        date
    }

    /// Whether this square stands for a real day inside the grid's range.
    public var isPlaceholder: Bool {
        value == nil
    }

    init(date: Date, value: Double?, level: Int, row: Int, column: Int) {
        self.date = date
        self.value = value
        self.level = level
        self.row = row
        self.column = column
    }
}
