//
//  ChartPresenter.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// Everything the chart and its header show, worked out from the data and the interaction state,
/// so the views only lay it out.
///
/// Observation passes straight through to `interaction`: a view re-renders only for the
/// interaction properties its reads of this presenter touch. So the chart still rebuilds only when
/// the chunk, scale or selection changes, and the header on each bucket crossed while scrolling.
@Observable
final class ChartPresenter {

    /// The bucket under the finger and each series' figures for it.
    struct Selection {
        let date: Date
        let rows: [SelectionRow]
    }

    /// Each series' readings on screen combined by `aggregation`, what that figure is called, and
    /// the range on screen. `rows` is empty when nothing on screen has data.
    struct RangeSummary {
        let rows: [SelectionRow]
        let label: String
        /// End exclusive, e.g. a week runs to the next week's midnight.
        let dates: Range<Date>
    }

    private let interaction: ChartInteractionModel

    /// Raw data, at its original resolution. Observed, so replacing it with `update(data:)` redraws
    /// the chart and header.
    private(set) var data: [TimeSeries]

    /// How the data is combined, labelled and drawn.
    let configuration: ChartConfiguration

    /// How readings are combined into buckets, the callout and the header.
    var aggregation: Aggregation { configuration.aggregation }

    /// What a chart variant's marks need from the presenter. Set by the variant, not the
    /// configuration, since it follows from how the variant draws.
    struct Traits {
        /// The series are stacked on each other (e.g. stacked bars), so the y axis must fit their
        /// total rather than the largest one.
        var stacksSeries = false
        /// The chart draws each series' band (e.g. line bands, range capsules), so the header and
        /// callout show its bounds and the y axis fits it. Otherwise the band is ignored.
        var showsBand = false
        /// The marks join their points (lines, areas), rather than each standing alone (bars,
        /// ranges, scatter). Tells VoiceOver's audio graph whether to play a continuous tone.
        var isContinuous = true
        /// The marks place the series side by side in each bucket (bars, ranges), so a highlighted
        /// reading is drawn over its own series' mark rather than the bucket's middle.
        var placesSeriesSideBySide = false
    }

    let traits: Traits

    /// Explicit colours so the header and callout rows can match the lines.
    var seriesColors: [Color] { configuration.seriesColors }

    /// What a selected accessory row shows on the chart. While set, the series' marks turn grey so
    /// it stands out.
    var highlight: ChartHighlight?

    /// The series' colours for their marks: `seriesColors`, or grey while something is highlighted.
    /// The header keeps the series' colours.
    var markColors: [Color] {
        highlight == nil ? seriesColors : seriesColors.map { _ in Self.dimmedColor }
    }

    private static let dimmedColor = Color.gray.opacity(0.25)

    /// Where each series' mark sits in a bucket, for charts that place the series side by side.
    var seriesSlots: SeriesSlots { SeriesSlots(series: data.map(\.name), bucket: bucket) }

    /// The highlight's readings, each with its series' colour, for series the chart has. In each
    /// bucket the highest keeps its label above, unless it's near the top of the chart, where the
    /// label wouldn't fit; the rest put theirs below.
    var highlightPoints: [HighlightPoint] {
        guard let highlight else { return [] }
        let points = data.enumerated().flatMap { index, series in
            (highlight.points[series.name] ?? []).map {
                HighlightPoint(series: series.name, date: $0.date, value: $0.value, color: color(at: index))
            }
        }
        let calendar = Calendar.current
        let bucket = bucket
        func bucketStart(_ point: HighlightPoint) -> Date {
            calendar.dateInterval(of: bucket, for: point.date)?.start ?? point.date
        }
        // The first of the highest in each bucket, so a tie still gives one label above.
        var highestIDs = Set<String>()
        for group in Dictionary(grouping: points, by: bucketStart).values {
            if let highest = group.max(by: { $0.value < $1.value }) { highestIDs.insert(highest.id) }
        }
        // Roughly a label's height, as a share of the plot.
        let domain = yDomain
        let roomAbove = domain.upperBound - (domain.upperBound - domain.lowerBound) / 8
        return points.map { point in
            var point = point
            point.labelBelow = !highestIDs.contains(point.id) || point.value > roomAbove
            return point
        }
    }

    /// The highlight's readings as a sentence for VoiceOver, e.g. "Sample Set 1, 7 BPM. Sample Set
    /// 2, 9 BPM." Nil with no highlight.
    var highlightDescription: String? {
        let points = highlightPoints
        guard !points.isEmpty else { return nil }
        let unit = configuration.unit.isEmpty ? "" : " \(configuration.unit)"
        return points
            .map { "\($0.series), \($0.value.formatted(configuration.valueFormat))\(unit)" }
            .joined(separator: ". ") + "."
    }

    /// Scrolls to the period holding the highlight's newest reading, if none of its readings are on
    /// screen, e.g. after scrolling back a few weeks and then tapping "Latest".
    func revealHighlight() {
        let dates = highlightPoints.map(\.date)
        guard let newest = dates.max() else { return }
        let start = interaction.scrollPosition
        let visible = start..<start.addingTimeInterval(visibleLength)
        guard !dates.contains(where: visible.contains) else { return }
        interaction.scrollPosition = scale.currentPeriod(containing: newest).start
    }

    /// Each series' mark colour by name, for marks that style series individually (e.g. area
    /// gradients).
    var colorsBySeries: [String: Color] {
        Dictionary(uniqueKeysWithValues: data.enumerated().map { ($1.name, markColors[$0 % markColors.count]) })
    }

    /// How many screens of data are loaded either side of what's visible.
    private static let marginScreens = 2

    /// The y axis for each scale, worked out the first time it's shown.
    @ObservationIgnored private var yDomains: [TimeScale: ClosedRange<Double>] = [:]

    init(data: [TimeSeries], configuration: ChartConfiguration = ChartConfiguration(), traits: Traits = Traits()) {
        let scales = Self.scales(in: configuration)
        interaction = ChartInteractionModel(
            scale: scales.contains(configuration.initialScale) ? configuration.initialScale : scales[0]
        )
        self.data = data
        self.configuration = configuration
        self.traits = traits
    }

    /// Replaces the data, e.g. after a new HealthKit load, keeping the scale and scroll position.
    /// Clears everything worked out from the old data first, so the redraw this triggers loads afresh.
    func update(data newData: [TimeSeries]) {
        interaction.clearLoadedSeries()
        yDomains = [:]
        data = newData
    }

    // MARK: - Scale

    /// How much time is on screen, picked by the segmented control. Kept only in the model: a
    /// separate view copy updated in `.onChange` gave one render with the new scale over the old
    /// scale's loaded range, e.g. daily axis marks across six years (~2,200) going from Y to W.
    var scale: TimeScale {
        get { interaction.scale }
        set { interaction.setScale(newValue) }
    }

    /// The ranges the picker offers, in D, W, M, 6M, Y order.
    var scales: [TimeScale] { Self.scales(in: configuration) }

    private static func scales(in configuration: ChartConfiguration) -> [TimeScale] {
        let available = TimeScale.allCases.filter(configuration.availableScales.contains)
        return available.isEmpty ? TimeScale.allCases : available
    }

    /// The bucket each plotted point represents: a day for W and M, a week for 6M, a month for Y.
    var bucket: Calendar.Component { scale.bucket }

    /// Fixed per scale, from all the data bucketed for that scale (and the goal), so the y axis
    /// doesn't jump as data loads in while scrolling. Per scale because bucket values can differ
    /// hugely between scales, e.g. a month's total steps against a day's.
    var yDomain: ClosedRange<Double> {
        let scale = scale
        if let domain = yDomains[scale] { return domain }
        let bucketed = data.map { $0.bucketed(by: scale.bucket, aggregation: aggregation) }
        let dataValues = traits.stacksSeries
            // Stacked: each bucket's total across the series. Buckets share midpoint dates.
            ? Dictionary(grouping: bucketed.flatMap(\.data), by: \.date).values.map { $0.reduce(0) { $0 + $1.value } }
            : bucketed.flatMap { $0.data.map(\.value) + (traits.showsBand ? $0.band.flatMap { [$0.lower, $0.upper] } : []) }
        let values = dataValues + [configuration.goal].compactMap { $0 }
        // 5% headroom so points at the maximum aren't half cut off at the top of the plot.
        let domain = min(0, values.min() ?? 0)...((values.max() ?? 1) * 1.05)
        yDomains[scale] = domain
        return domain
    }

    /// How much time is on screen: the length of the current period.
    var visibleLength: TimeInterval { interaction.visibleLength }

    // MARK: - Chart bindings

    /// The chart's leading edge. Passes through to the model, which doesn't observe it.
    var scrollPosition: Date {
        get { interaction.scrollPosition }
        set { interaction.scrollPosition = newValue }
    }

    /// The raw x value under the finger. Passes through to the model, which doesn't observe it.
    var rawSelection: Date? {
        get { interaction.rawSelection }
        set { interaction.rawSelection = newValue }
    }

    /// Whether the user is pressing on the chart (even over a bucket with no data).
    var isSelecting: Bool { interaction.selectedDate != nil }

    // MARK: - Plot

    /// The data around the visible range, averaged into the scale's buckets. Only changes when the
    /// scroll crosses into another chunk or the scale changes, never per scroll frame.
    var plottedData: [TimeSeries] {
        interaction.loadedSeries(margin: Self.marginScreens) { [data, bucket, aggregation] range in
            data.map { $0.filtered(to: range).bucketed(by: bucket, aggregation: aggregation) }
        }
    }

    /// Every series' line points in one array; the vectorized plots split it into series by name.
    var linePoints: [PlotPoint] { plottedData.flatMap(\.plotPoints) }

    /// Every series' band points in one array.
    var bandPoints: [PlotBandPoint] { plottedData.flatMap(\.plotBandPoints) }

    /// Axis mark positions across the loaded range: every `axisStride` boundary (day, week or month).
    var axisDates: [Date] {
        Calendar.current.starts(
            of: scale.axisStride,
            every: scale.axisStrideCount,
            in: interaction.loadedRange(margin: Self.marginScreens)
        )
    }

    /// Everything that can be scrolled to: from the bucket holding the oldest data to the end of the
    /// current period (so the rest of this week/month/year shows as empty, like Health).
    var fullDomain: ClosedRange<Date> {
        let period = interaction.currentPeriod
        let earliest = data.compactMap { $0.sortedByDate.first?.date }.min() ?? period.end
        let start = Calendar.current.dateInterval(of: bucket, for: earliest)?.start ?? earliest
        return min(start, period.start)...period.end
    }

    /// The plotted data, described for VoiceOver's audio graph and data table.
    var accessibilityDescriptor: TimeSeriesChartDescriptor {
        let loaded = interaction.loadedRange(margin: Self.marginScreens)
        return TimeSeriesChartDescriptor(
            title: configuration.accessibilityTitle,
            series: plottedData,
            isContinuous: traits.isContinuous,
            dates: loaded.lowerBound...loaded.upperBound,
            values: yDomain,
            dateFormat: scale.bucket == .hour
                ? .dateTime.weekday().day().month().hour()
                : .dateTime.weekday().day().month().year(),
            unit: configuration.unit,
            valueFormat: configuration.valueFormat
        )
    }

    // MARK: - Selection

    /// Each series' value (and band) in the bucket under the finger. Nil when not pressing, or over
    /// a bucket with no data, e.g. a future day.
    var selection: Selection? {
        guard let selectedDate = interaction.selectedDate else { return nil }
        let rows = plottedData.enumerated().compactMap { index, series -> SelectionRow? in
            let points = series.points(inBucketOf: selectedDate, component: bucket)
            guard let first = points.first else { return nil }
            // Bucketed data has one point per bucket, so this is that point. Raw readings
            // (`.none`) are averaged.
            let combined = Aggregation.average.combine(
                points.map(\.value),
                band: series.bandPoints(inBucketOf: selectedDate, component: bucket)
            )
            return row(for: series, date: first.date, combined: combined, index: index)
        }
        guard !rows.isEmpty else { return nil }
        return Selection(date: selectedDate, rows: rows)
    }

    // MARK: - Range summary

    /// Each series' raw readings on screen, combined as `configuration.summary` says.
    var rangeSummary: RangeSummary? {
        // A fixed-length window can land an hour off midnight across a daylight-saving change, so
        // snap both ends to the nearest midnight (except on D, which scrolls by the hour).
        let visibleEnd = interaction.visibleStart.addingTimeInterval(visibleLength)
        let start = scale.snapsRangeToDays ? interaction.visibleStart.nearestMidnight() : interaction.visibleStart
        let end = scale.snapsRangeToDays ? visibleEnd.nearestMidnight() : visibleEnd
        guard start < end else { return nil }
        let rows = data.map { $0.filtered(to: start..<end) }.enumerated().compactMap { index, series -> SelectionRow? in
            guard let first = series.sortedByDate.first else { return nil }
            return row(for: series, date: first.date, combined: summaryFigure(for: series), index: index)
        }
        let label = switch configuration.summary {
        case .combined: aggregation.label
        case .dailyAverage: "Daily Average"
        }
        // Like Health, name the whole range on screen, including empty future days.
        return RangeSummary(rows: rows, label: label, dates: start..<end)
    }

    /// The header's figure for `series`, already limited to the range on screen.
    private func summaryFigure(for series: TimeSeries) -> (value: Double, band: ClosedRange<Double>?) {
        switch configuration.summary {
        case .combined:
            return aggregation.combine(series.data.map(\.value), band: series.band)
        case .dailyAverage:
            // Each day's figure (e.g. its total), then the mean of those.
            let days = series.bucketed(by: .day, aggregation: aggregation)
            return Aggregation.average.combine(days.data.map(\.value), band: days.band)
        }
    }

    private func row(
        for series: TimeSeries,
        date: Date,
        combined: (value: Double, band: ClosedRange<Double>?),
        index: Int
    ) -> SelectionRow {
        SelectionRow(
            series: series,
            point: TimeSeriesDatapoint(date: date, value: combined.value),
            band: traits.showsBand ? combined.band.map { TimeSeriesBandDatapoint(date: date, lower: $0.lowerBound, upper: $0.upperBound) } : nil,
            color: color(at: index)
        )
    }

    private func color(at index: Int) -> Color {
        seriesColors[index % seriesColors.count]
    }
}
