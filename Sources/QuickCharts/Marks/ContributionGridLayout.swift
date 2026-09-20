//
//  ContributionGridLayout.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 20/09/2026.
//

import SwiftUI

/// Which part of the grid a subview belongs to, so the layout can place squares and labels in one
/// pass off a single cell size. Without this the labels would have to guess the size the squares
/// settled on, which is how a month label ends up half a column out.
nonisolated enum ContributionSlot: Equatable {
    case cell(row: Int, column: Int)
    case weekday(row: Int)
    case month(column: Int)
}

nonisolated struct ContributionSlotKey: LayoutValueKey {
    static let defaultValue: ContributionSlot = .cell(row: 0, column: 0)
}

extension View {
    func contributionSlot(_ slot: ContributionSlot) -> some View {
        layoutValue(key: ContributionSlotKey.self, value: slot)
    }
}

/// Lays out a grid of square cells, with optional weekday labels down the left and month labels
/// across the top.
///
/// Cells are sized from the width the grid is offered, so it fills its row, and the layout reports
/// the height that follows — no `GeometryReader`, and no caller having to pin an aspect ratio to
/// stop the grid painting a small square in the corner of a large box. A height proposal, if there
/// is one, only ever shrinks the cells.
nonisolated struct ContributionGridLayout: Layout {

    let rows: Int
    let columns: Int
    let spacing: CGFloat
    /// A fixed cell size, or nil to size cells from the offered width.
    let cellSize: CGFloat?
    /// The width reserved for weekday labels, or 0 for none.
    let weekdayWidth: CGFloat
    /// The height reserved for month labels, or 0 for none.
    let monthHeight: CGFloat

    /// A cell size to fall back on when nothing constrains the width, matching the default a
    /// commit graph draws at.
    private static let defaultCellSize: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let cell = cellLength(for: proposal)
        return CGSize(width: leadingInset + span(cell, count: columns), height: topInset + span(cell, count: rows))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cell = cellLength(for: proposal)
        let originX = bounds.minX + leadingInset
        let originY = bounds.minY + topInset
        let step = cell + spacing

        for subview in subviews {
            switch subview[ContributionSlotKey.self] {
            case .cell(let row, let column):
                subview.place(
                    at: CGPoint(x: originX + CGFloat(column) * step, y: originY + CGFloat(row) * step),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: cell, height: cell)
                )
            case .weekday(let row):
                subview.place(
                    at: CGPoint(x: bounds.minX, y: originY + CGFloat(row) * step),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: weekdayWidth, height: cell)
                )
            case .month(let column):
                // Wider than one column, because a month's name is: the grid only shows a label
                // where the month turns over, so there's room to its right.
                subview.place(
                    at: CGPoint(x: originX + CGFloat(column) * step, y: bounds.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: max(cell, monthHeight * 3), height: monthHeight)
                )
            }
        }
    }

    /// The width taken by the weekday labels and the gap after them.
    private var leadingInset: CGFloat {
        weekdayWidth > 0 ? weekdayWidth + spacing : 0
    }

    /// The height taken by the month labels and the gap under them.
    private var topInset: CGFloat {
        monthHeight > 0 ? monthHeight + spacing : 0
    }

    /// How far `count` cells and the gaps between them reach.
    private func span(_ cell: CGFloat, count: Int) -> CGFloat {
        CGFloat(count) * cell + CGFloat(max(0, count - 1)) * spacing
    }

    /// The side of a square, from the width the grid is offered.
    ///
    /// Width decides, and a height proposal is only consulted when there is no width to go on.
    /// Sizing from both puts the grid in a loop with the stack around it: the stack offers the
    /// height the grid asked for, the grid reads that back, shrinks to fit it, and settles at a
    /// fraction of the width it was given.
    private func cellLength(for proposal: ProposedViewSize) -> CGFloat {
        if let cellSize {
            return max(1, cellSize)
        }
        if let width = proposal.width, width.isFinite, width > 0 {
            return max(1, (width - leadingInset - CGFloat(max(0, columns - 1)) * spacing) / CGFloat(max(1, columns)))
        }
        if let height = proposal.height, height.isFinite, height > 0 {
            return max(1, (height - topInset - CGFloat(max(0, rows - 1)) * spacing) / CGFloat(max(1, rows)))
        }
        return Self.defaultCellSize
    }
}
