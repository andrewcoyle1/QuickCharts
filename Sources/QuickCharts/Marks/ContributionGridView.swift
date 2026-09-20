//
//  ContributionGridView.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 20/09/2026.
//

import SwiftUI

/// The squares themselves, with the weekday and month labels the style asks for and nothing else.
///
/// This is the piece to reach for when you want the grid inside your own presentation — a card, a
/// header, a widget — rather than the whole `ContributionChart`. It sizes itself from the width
/// it's given and reports the height that follows, so it can sit in a stack without a frame.
public struct ContributionGridView: View {

    let grid: ContributionGrid
    let color: Color
    let style: ContributionStyle
    @Binding var selection: ContributionCell?

    /// The height of the month labels, which is also what sizes them.
    private let monthLabelHeight: CGFloat = 14
    private let weekdayLabelWidth: CGFloat = 16

    /// - Parameters:
    ///   - grid: The days to draw.
    ///   - color: The series colour the shades are built from.
    ///   - style: How the squares are drawn and which labels they carry.
    ///   - selection: The selected square, when the caller wants to drive or observe it. Pass
    ///     `.constant(nil)` for a grid that only shows.
    public init(
        grid: ContributionGrid,
        color: Color = .green,
        style: ContributionStyle = ContributionStyle(),
        selection: Binding<ContributionCell?> = .constant(nil)
    ) {
        self.grid = grid
        self.color = color
        self.style = style
        _selection = selection
    }

    public var body: some View {
        ContributionGridLayout(
            rows: grid.rows,
            columns: grid.columnCount,
            spacing: style.spacing,
            cellSize: style.cellSize,
            weekdayWidth: showsWeekdayLabels ? weekdayLabelWidth : 0,
            monthHeight: showsMonthLabels ? monthLabelHeight : 0
        ) {
            if showsWeekdayLabels {
                ForEach(0..<grid.rows, id: \.self) { row in
                    Text(grid.weekdayLabel(forRow: row) ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .contributionSlot(.weekday(row: row))
                }
            }
            if showsMonthLabels {
                ForEach(monthLabelColumns, id: \.self) { column in
                    Text(grid.monthLabel(forColumn: column))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .contributionSlot(.month(column: column))
                }
            }
            ForEach(grid.cells) { cell in
                square(cell)
                    .contributionSlot(.cell(row: cell.row, column: cell.column))
            }
        }
        // A layout only ever gets asked for the width it wants, never told to take what's going,
        // so without this the grid answers with its default cell size and draws a small square in
        // the corner of a wide row. With a fixed `cellSize` there's nothing to stretch.
        .frame(maxWidth: style.cellSize == nil ? .infinity : nil, alignment: .leading)
        .animation(.easeInOut(duration: 0.3), value: grid)
    }

    @ViewBuilder
    private func square(_ cell: ContributionCell) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
        shape
            .fill(style.color(forLevel: cell.level, base: color))
            .overlay(
                shape.stroke(
                    isSelected(cell) ? color : style.borderColor,
                    lineWidth: isSelected(cell) ? 1.5 : 0.5
                )
            )
            // A day that hasn't happened yet holds its place in the week without claiming a zero.
            .opacity(cell.isPlaceholder ? 0 : 1)
            .contentShape(shape)
            .accessibilityLabel(accessibilityLabel(for: cell))
            .accessibilityAddTraits(style.allowsSelection ? .isButton : [])
            .accessibilityHidden(cell.isPlaceholder)
            .onTapGesture {
                guard style.allowsSelection, !cell.isPlaceholder else { return }
                selection = isSelected(cell) ? nil : cell
            }
    }

    private func isSelected(_ cell: ContributionCell) -> Bool {
        selection?.date == cell.date
    }

    private var showsWeekdayLabels: Bool {
        style.showsWeekdayLabels && grid.layout.isWeekAligned
    }

    private var showsMonthLabels: Bool {
        style.showsMonthLabels && grid.layout.isWeekAligned
    }

    /// The columns where a new month starts, which are the only ones that carry a label.
    private var monthLabelColumns: [Int] {
        (0..<grid.columnCount).filter { grid.showsMonthLabel(forColumn: $0) }
    }

    private func accessibilityLabel(for cell: ContributionCell) -> String {
        let date = cell.date.formatted(date: .abbreviated, time: .omitted)
        guard let value = cell.value else { return date }
        return "\(date), \(value.formatted(.number.precision(.fractionLength(0...1))))"
    }
}

#Preview("Grid") {
    ContributionGridView(
        grid: ContributionGrid(series: TimeSeries.samples().first, goal: 9),
        color: .green
    )
    .padding()
}

#Preview("Card") {
    ContributionGridView(
        grid: ContributionGrid(series: TimeSeries.samples().first, layout: .packed(rows: 3, columns: 10), goal: 9),
        color: .orange,
        style: .card()
    )
    .padding()
}
