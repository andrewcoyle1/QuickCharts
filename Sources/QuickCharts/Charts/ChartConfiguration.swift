//
//  ChartConfiguration.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// How a chart combines, labels and draws its data. Every chart variant takes one; a few fix a
/// setting their marks depend on (`RangeChart` always uses `.range`, `ScatterChart` `.none`).
public nonisolated struct ChartConfiguration: Sendable {

    /// What the header shows for the range on screen.
    public enum Summary: Sendable {
        /// The readings on screen combined by `aggregation`: their average, total or range.
        case combined
        /// Each day's readings combined by `aggregation`, then averaged across the days, like
        /// Health's steps ("Average 8,214 steps" a day, not the week's total).
        case dailyAverage
    }

    /// How readings are combined into each bucket and the callout.
    public var aggregation: Aggregation = .average

    /// What the header shows.
    public var summary: Summary = .combined

    /// Shown after each value, e.g. "steps" or "BPM". Empty for none.
    public var unit: String = ""

    /// How values (and band bounds) are written in the header and callout.
    public var valueFormat: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(1))

    /// The ranges the picker offers, always shown in D, W, M, 6M, Y order. Leave out ones the data
    /// doesn't suit, e.g. D for a weight trend with one reading a day. With only one, the picker is
    /// hidden. Empty means all.
    public var availableScales: Set<TimeScale> = Set(TimeScale.allCases)

    /// The range the chart opens on. If it isn't available, the chart opens on the first that is.
    public var initialScale: TimeScale = .week

    /// One colour per series, in order, repeating if there are more series.
    public var seriesColors: [Color] = [.blue, .green, .orange, .purple, .pink]

    /// Drawn as a dashed line when set. The y axis stretches to include it.
    public var goal: Double?

    /// The plot's height, not counting the picker and header.
    public var height: CGFloat = 160

    /// What VoiceOver calls the chart, e.g. "Steps". Used for its audio graph.
    public var accessibilityTitle: String = ""

    /// Every setting has a default, so pass only the ones you need.
    public init(
        aggregation: Aggregation = .average,
        summary: Summary = .combined,
        unit: String = "",
        valueFormat: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(1)),
        availableScales: Set<TimeScale> = Set(TimeScale.allCases),
        initialScale: TimeScale = .week,
        seriesColors: [Color] = [.blue, .green, .orange, .purple, .pink],
        goal: Double? = nil,
        height: CGFloat = 160,
        accessibilityTitle: String = ""
    ) {
        self.aggregation = aggregation
        self.summary = summary
        self.unit = unit
        self.valueFormat = valueFormat
        self.availableScales = availableScales
        self.initialScale = initialScale
        self.seriesColors = seriesColors
        self.goal = goal
        self.height = height
        self.accessibilityTitle = accessibilityTitle
    }
}
