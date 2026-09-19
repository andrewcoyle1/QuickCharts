//
//  ChartInteractionModel.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation
import Charts

/// Scroll, loading and selection state for the chart. It's `@Observable` so each view only
/// re-renders for the properties it reads. `scrollPosition` changes every frame while scrolling, so
/// it is not observed at all (reading it through the chart's binding would otherwise rebuild the
/// whole chart every frame). Instead it feeds `visibleStart`, which only changes when the leading
/// edge crosses into another day/week/month, and `chunk`, which changes once per screen.
@Observable
final class ChartInteractionModel {
    /// Observed (like `currentPeriod`) so the chart redraws on a scale change. Neither changes while
    /// scrolling, and a scale change often leaves `chunk` at 0, so nothing else would trigger it.
    private(set) var scale: TimeScale

    /// The calendar period containing today: this week, month, half-year or year.
    private(set) var currentPeriod: DateInterval

    /// How much time is on screen: the length of the current period.
    var visibleLength: TimeInterval { currentPeriod.duration }

    /// The date at the chart's leading (left) edge. Bound to `chartScrollPosition`. Not observed.
    @ObservationIgnored var scrollPosition: Date {
        didSet {
            updateChunk()
            updateVisibleStart()
        }
    }
    
    /// `scrollPosition` snapped to the nearest bucket boundary. The header reads this, so it updates
    /// live while scrolling but only a few times per screen, not every frame.
    private(set) var visibleStart: Date

    /// `visibleStart` once scrolling has paused, which the y axis fits. Separate so the axis refits
    /// once per scroll, not each time the leading edge crosses a bucket.
    private(set) var settledStart: Date

    /// Which screen-length stretch of time the leading edge is in, counting back from the current
    /// period (0). Data is loaded around this, so it's the only scroll state the chart re-renders for.
    private(set) var chunk = 0

    /// The raw x value under the user's finger, from `chartXSelection`. Not observed, because it
    /// changes on every drag frame; it's snapped to a bucket in `selectedDate` instead.
    @ObservationIgnored var rawSelection: Date? {
        didSet {
            let snapped = rawSelection.flatMap { Calendar.current.dateInterval(of: scale.bucket, for: $0)?.start }
            if snapped != selectedDate { selectedDate = snapped }
        }
    }

    /// The start of the bucket the lollipop is showing. Nil when the user isn't pressing.
    private(set) var selectedDate: Date?

    /// Series already loaded around a chunk, so scrolling back doesn't reload them.
    @ObservationIgnored private var cache: [String: [TimeSeries]] = [:]

    init(scale: TimeScale) {
        self.scale = scale
        let period = scale.currentPeriod()
        currentPeriod = period
        scrollPosition = period.start
        visibleStart = period.start
        settledStart = period.start
    }

    /// Switches scale and, like Health, opens on the current period.
    func setScale(_ newScale: TimeScale) {
        scale = newScale
        currentPeriod = newScale.currentPeriod()
        scrollPosition = currentPeriod.start
        settledStart = visibleStart
        rawSelection = nil
    }

    /// Fits the y axis to what's on screen now.
    func settle() {
        if settledStart != visibleStart { settledStart = visibleStart }
    }

    /// Data for the loaded chunks around the leading edge, loaded (and cached) the first time it's
    /// needed. `margin` screens are loaded beyond each side of what's visible, so lines already run
    /// to the plot's edges and are there when the user scrolls. This is the hook for real lazy
    /// loading: swap `load` for a query of just that date range.
    func loadedSeries(margin: Int, load: (Range<Date>) -> [TimeSeries]) -> [TimeSeries] {
        let key = "\(scale.rawValue)|\(chunk)"
        if let cached = cache[key] { return cached }
        let loaded = load(loadedRange(margin: margin))
        cache[key] = loaded
        return loaded
    }

    /// Forgets every loaded chunk, e.g. when the data changes. Call before the chart next renders.
    func clearLoadedSeries() {
        cache = [:]
    }

    /// The dates currently loaded: the visible range (which spans chunks `chunk` and `chunk + 1`)
    /// plus `margin` screens either side.
    func loadedRange(margin: Int) -> Range<Date> {
        chunkStart(chunk - margin)..<chunkStart(chunk + 1 + margin + 1)
    }
    
    private func chunkStart(_ chunk: Int) -> Date {
        currentPeriod.start.addingTimeInterval(Double(chunk) * visibleLength)
    }

    private func updateVisibleStart() {
        guard let bucket = Calendar.current.dateInterval(of: scale.bucket, for: scrollPosition) else { return }
        let snapped = scrollPosition.timeIntervalSince(bucket.start) < bucket.duration / 2 ? bucket.start : bucket.end
        if snapped != visibleStart { visibleStart = snapped }
    }
    
    private func updateChunk() {
        let newChunk = Int((scrollPosition.timeIntervalSince(currentPeriod.start) / visibleLength).rounded(.down))
        if newChunk != chunk { chunk = newChunk }
    }
}
