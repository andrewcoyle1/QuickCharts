//
//  TimeScale.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

/// The ranges a chart's picker offers: how much time one screen shows (a day, week, month,
/// half-year or year) and how readings are bucketed for it.
public nonisolated enum TimeScale: String, CaseIterable, Identifiable, Sendable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"
    
    public var id: Self { self }
    
    /// The calendar period containing `date` that one screen shows: its day, week, month, half-year
    /// (Jan–Jun or Jul–Dec) or year. The chart opens on the current one, like Health.
    func currentPeriod(containing date: Date = .now) -> DateInterval {
        let calendar = Calendar.current
        switch self {
        case .day:
            return calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
        case .month:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 30 * 86_400)
        case .sixMonths:
            let year = calendar.component(.year, from: date)
            let firstMonth = calendar.component(.month, from: date) <= 6 ? 1 : 7
            let start = calendar.date(from: DateComponents(year: year, month: firstMonth, day: 1)) ?? date
            let end = calendar.date(byAdding: .month, value: 6, to: start) ?? date
            return DateInterval(start: start, end: end)
        case .year:
            return calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, duration: 365 * 86_400)
        }
    }
    
    /// Where scrolling comes to rest: the start of the nearest bucket (the hour for D, midnight for
    /// W and M, the first day of the week for 6M, the 1st of the month for Y).
    var scrollSnap: DateComponents {
        switch self {
        case .day: DateComponents(minute: 0)
        case .week, .month: DateComponents(hour: 0)
        case .sixMonths: DateComponents(hour: 0, weekday: Calendar.current.firstWeekday)
        case .year: DateComponents(day: 1, hour: 0)
        }
    }
    
    /// Where a flick comes to rest: the next day (D), week (W), month (M and 6M) or year (Y) boundary.
    var flickSnap: DateComponents {
        switch self {
        case .day: DateComponents(hour: 0)
        case .week: DateComponents(hour: 0, weekday: Calendar.current.firstWeekday)
        case .month, .sixMonths: DateComponents(day: 1, hour: 0)
        case .year: DateComponents(month: 1, day: 1, hour: 0)
        }
    }
    
    /// What one plotted point represents. Longer scales average into bigger buckets so the line stays readable.
    var bucket: Calendar.Component {
        switch self {
        case .day: .hour
        case .week, .month: .day
        case .sixMonths: .weekOfYear
        case .year: .month
        }
    }
    
    /// Spacing between x-axis labels, in `axisStrideCount`s of this component.
    var axisStride: Calendar.Component {
        switch self {
        case .day: .hour
        case .week: .day
        case .month: .weekOfYear
        case .sixMonths, .year: .month
        }
    }
    
    /// How many `axisStride`s apart the x-axis labels are: every 6 hours on D, otherwise every one.
    var axisStrideCount: Int {
        self == .day ? 6 : 1
    }

    var axisLabelFormat: Date.FormatStyle {
        switch self {
        case .day: .dateTime.hour()
        case .week: .dateTime.weekday(.abbreviated)
        case .month: .dateTime.day()
        case .sixMonths: .dateTime.month(.abbreviated)
        case .year: .dateTime.month(.narrow)
        }
    }
    
    /// Whether the header's range is snapped to whole days. Not on D, whose screen is scrolled by
    /// the hour and so can start partway through a day.
    var snapsRangeToDays: Bool {
        self != .day
    }

    /// Centre the label in its slot when there's one label per plotted bucket (W and Y),
    /// so each label sits under its point rather than at the bucket's left edge.
    var centersAxisLabels: Bool {
        self == .week || self == .year
    }
}
