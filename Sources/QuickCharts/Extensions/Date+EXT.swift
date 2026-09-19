//
//  Date+EXT.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

nonisolated extension Date {
    /// The midnight closest to this date. A fixed-length window can land an hour off midnight
    /// across a daylight-saving change; this snaps it back.
    func nearestMidnight(in calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: addingTimeInterval(12 * 3600))
    }
}

nonisolated extension Calendar {
    /// The start of every `count`th `component` (day, week, month…) through `range`, from the one
    /// `range` starts partway through.
    func starts(of component: Calendar.Component, every count: Int = 1, in range: Range<Date>) -> [Date] {
        guard var date = dateInterval(of: component, for: range.lowerBound)?.start else { return [] }
        var dates: [Date] = []
        while date < range.upperBound {
            dates.append(date)
            guard let next = self.date(byAdding: component, value: max(1, count), to: date) else { break }
            date = next
        }
        return dates
    }
}
