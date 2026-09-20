//
//  ContributionStyle.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 20/09/2026.
//

import SwiftUI

/// How a contribution grid arranges its days.
public nonisolated enum ContributionLayout: Equatable, Sendable {

    /// A week per column, weekdays down the rows, like a commit graph. Columns are aligned to the
    /// calendar's first weekday, so a row is always the same weekday and the weekday labels mean
    /// something. `weeks` columns end with the week holding the grid's end date.
    case calendar(weeks: Int = 16)

    /// Consecutive days packed down each column in turn, with no regard for weeks: `rows * columns`
    /// days ending on the grid's end date. What a compact "last 30 days" card wants, where the
    /// shape matters more than which day is which.
    case packed(rows: Int, columns: Int)

    /// Rows down the grid.
    public var rows: Int {
        switch self {
        case .calendar: 7
        case .packed(let rows, _): max(1, rows)
        }
    }

    /// Columns across the grid.
    public var columns: Int {
        switch self {
        case .calendar(let weeks): max(1, weeks)
        case .packed(_, let columns): max(1, columns)
        }
    }

    /// Whether rows line up with weekdays, which is what makes weekday and month labels honest.
    var isWeekAligned: Bool {
        switch self {
        case .calendar: true
        case .packed: false
        }
    }
}

/// How a contribution grid is drawn: its shape, how many shades it steps through, and which pieces
/// of chrome it carries. Everything about *what* it plots — the goal each day is measured against,
/// the colour, the unit, how a day's readings combine — comes from `ChartConfiguration`, the same
/// as every other chart in the package.
public nonisolated struct ContributionStyle: Sendable {

    /// How the days are arranged.
    public var layout: ContributionLayout

    /// How many shades a square can take, counting empty. Five gives the familiar empty, quarter,
    /// half, three-quarter, full ramp. Minimum 2.
    public var levels: Int

    /// The gap between squares.
    public var spacing: CGFloat

    /// The corner radius of each square.
    public var cornerRadius: CGFloat

    /// A fixed square size, or nil to size the squares from the width the grid is given. Squares
    /// stay square either way; a grid with no height to spare shrinks them rather than clipping.
    public var cellSize: CGFloat?

    /// The single-letter weekday labels down the left. Ignored by `.packed`, whose rows aren't
    /// weekdays.
    public var showsWeekdayLabels: Bool

    /// The month labels along the top, shown on the column where a new month starts. Ignored by
    /// `.packed`.
    public var showsMonthLabels: Bool

    /// The empty-to-full key under the grid.
    public var showsLegend: Bool

    /// Whether tapping a square selects it and names it above the grid. A grid used as a button —
    /// a summary card that pushes a detail screen — wants this off, so the whole grid stays one
    /// tap target.
    public var allowsSelection: Bool

    /// The colour of a day with nothing logged, and of the empty swatch in the legend.
    public var emptyColor: Color

    /// The hairline around each square, which keeps empty days visible on a matching background.
    public var borderColor: Color

    /// A compact grid for a summary card: no chrome, no selection, the whole thing a single glance.
    public static func card(rows: Int = 3, columns: Int = 10) -> ContributionStyle {
        ContributionStyle(
            layout: .packed(rows: rows, columns: columns),
            showsWeekdayLabels: false,
            showsMonthLabels: false,
            showsLegend: false,
            allowsSelection: false
        )
    }

    /// Every setting has a default, so pass only the ones you need.
    public init(
        layout: ContributionLayout = .calendar(),
        levels: Int = 5,
        spacing: CGFloat = 2,
        cornerRadius: CGFloat = 3,
        cellSize: CGFloat? = nil,
        showsWeekdayLabels: Bool = true,
        showsMonthLabels: Bool = true,
        showsLegend: Bool = true,
        allowsSelection: Bool = true,
        emptyColor: Color = Color.secondary.opacity(0.12),
        borderColor: Color = Color.secondary.opacity(0.18)
    ) {
        self.layout = layout
        self.levels = max(2, levels)
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.cellSize = cellSize
        self.showsWeekdayLabels = showsWeekdayLabels
        self.showsMonthLabels = showsMonthLabels
        self.showsLegend = showsLegend
        self.allowsSelection = allowsSelection
        self.emptyColor = emptyColor
        self.borderColor = borderColor
    }

    /// The colour of a square at `level`, from the series colour: empty at 0, then evenly spaced
    /// tints up to the full colour at the top level.
    public func color(forLevel level: Int, base: Color) -> Color {
        guard level > 0 else { return emptyColor }
        let top = levels - 1
        let step = Double(min(level, top)) / Double(max(1, top))
        return base.opacity(step)
    }
}
