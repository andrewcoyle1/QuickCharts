//
//  TimeScale+EXT.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

extension TimeScale {
    /// Names the bucket containing `date`, for the callout: "Sat 19 Sep, 15:00 – 16:00" for an hour,
    /// "Sat 19 Sep" for a day, "14 – 20 Sep" for a week, "September 2026" for a month (en_GB).
    func bucketDescription(for date: Date, locale: Locale = .current) -> String {
        let calendar = Calendar.current
        switch bucket {
        case .hour:
            // The hour as a span: an hour alone ("15") means nothing in a 24-hour locale.
            guard let hour = calendar.dateInterval(of: .hour, for: date) else { fallthrough }
            return (hour.start..<hour.end)
                .formatted(.interval.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(locale))
        case .weekOfYear:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { fallthrough }
            // The interval ends at the next week's start, so step back a moment to end on the last day.
            return (week.start..<week.end.addingTimeInterval(-1))
                .formatted(.interval.day().month(.abbreviated).locale(locale))
        case .month:
            return date.formatted(.dateTime.month(.wide).year().locale(locale))
        default:
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale))
        }
    }

    /// The callout's footer: `bucketDescription(for:)` as Text.
    func bucketLabel(for date: Date) -> Text {
        Text(bucketDescription(for: date))
    }

    /// Names the range on screen (end exclusive), for the header: "14 – 20 Sep 2026" on W and up.
    /// On D, "Sat, 19 Sep 2026" for a whole day, or "19 Sep at 15:00 – 20 Sep at 15:00" when
    /// scrolled partway through one (en_GB).
    func rangeDescription(_ range: Range<Date>, locale: Locale = .current) -> String {
        let calendar = Calendar.current
        guard self == .day else {
            // Step back a moment so the range ends on its last day, not the next one's midnight.
            return (range.lowerBound..<range.upperBound.addingTimeInterval(-1))
                .formatted(.interval.day().month(.abbreviated).year().locale(locale))
        }
        let isWholeDay = calendar.startOfDay(for: range.lowerBound) == range.lowerBound
            && calendar.date(byAdding: .day, value: 1, to: range.lowerBound) == range.upperBound
        if isWholeDay {
            return range.lowerBound.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().locale(locale))
        }
        // Hours, with the exclusive end: a 24-hour span reads "15:00 – 15:00", not "15:00 – 14:59".
        return range.formatted(.interval.day().month(.abbreviated).hour().minute().locale(locale))
    }
}
