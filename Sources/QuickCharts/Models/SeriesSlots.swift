//
//  SeriesSlots.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

/// Where each series' mark sits in a bucket when the series stand side by side (bars, range
/// capsules), as dates. Worked out here rather than left to Charts' `position(by:)`, so marks drawn
/// over them, like a highlighted reading's dot, can land on exactly the same spot.
nonisolated struct SeriesSlots {
    /// Every series' name, in order: one slot each, left to right, whether or not it has data.
    let series: [String]
    let bucket: Calendar.Component

    /// How much of the bucket the slots take up together, leaving a gap between buckets.
    static let groupRatio = 0.6
    /// How much of its slot each mark fills, leaving a gap between series.
    static let markRatio = 0.75

    /// The span of `name`'s mark in the bucket holding `date`.
    func span(of name: String, at date: Date) -> Range<Date> {
        let (center, slotLength) = slot(of: name, at: date)
        let half = slotLength * Self.markRatio / 2
        return center.addingTimeInterval(-half)..<center.addingTimeInterval(half)
    }

    /// The middle of `name`'s mark in the bucket holding `date`.
    func center(of name: String, at date: Date) -> Date {
        slot(of: name, at: date).center
    }

    private func slot(of name: String, at date: Date) -> (center: Date, length: TimeInterval) {
        guard let interval = Calendar.current.dateInterval(of: bucket, for: date) else { return (date, 0) }
        let middle = interval.start.addingTimeInterval(interval.duration / 2)
        // A series with no slot of its own, e.g. a combo chart's line, sits in the middle of the
        // bucket rather than borrowing the first series' slot.
        guard let index = series.firstIndex(of: name) else { return (middle, 0) }
        let count = max(1, series.count)
        let groupLength = interval.duration * Self.groupRatio
        let slotLength = groupLength / Double(count)
        let groupStart = interval.start.addingTimeInterval((interval.duration - groupLength) / 2)
        return (groupStart.addingTimeInterval(slotLength * (Double(index) + 0.5)), slotLength)
    }
}
