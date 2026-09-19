//
//  ChartHighlight.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// What a `ChartValueRow` shows on the chart while it's selected: its readings, each drawn as a dot
/// in its series' colour and labelled with its value, while the chart's own marks fade to grey.
/// Like tapping "Latest" in Health.
public nonisolated struct ChartHighlight: Equatable, Sendable {
    /// The readings to mark, e.g. each series' latest, by the name of the series they belong to.
    /// Each dot sits in its reading's bucket, over its own series' bar or capsule. Names the chart
    /// doesn't have are ignored.
    public var points: [String: [TimeSeriesDatapoint]]

    /// The selected row's fill. Usually the (first) series' colour.
    public var color: Color

    public init(points: [String: [TimeSeriesDatapoint]], color: Color = .accentColor) {
        self.points = points
        self.color = color
    }
}

/// Which accessory row is selected, and how a row selects itself. Set by `ChartScreen` around its
/// chart and accessories; absent elsewhere, where rows are plain.
struct ChartHighlightSelection {
    let id: UUID?
    let select: (UUID?) -> Void
}

/// Each highlightable row's highlight by its id, gathered up so the screen can hand the selected
/// one to the chart. Collected rather than stored on tap, so a row given new data (a new latest
/// reading) updates the chart while selected.
nonisolated struct ChartHighlightsKey: PreferenceKey {
    static let defaultValue: [UUID: ChartHighlight] = [:]

    static func reduce(value: inout [UUID: ChartHighlight], nextValue: () -> [UUID: ChartHighlight]) {
        value.merge(nextValue()) { $1 }
    }
}

extension EnvironmentValues {
    /// The selected row's highlight, which the chart draws.
    @Entry var chartHighlight: ChartHighlight?
    @Entry var chartHighlightSelection: ChartHighlightSelection?
}
