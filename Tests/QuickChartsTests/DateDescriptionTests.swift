//
//  DateDescriptionTests.swift
//  QuickChartsTests
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation
import Testing
@testable import QuickCharts

/// How the header and callout name dates, in a 12-hour (en_US) and a 24-hour (en_GB) locale.
struct DateDescriptionTests {

    private let calendar = Calendar.current
    private let us = Locale(identifier: "en_US")
    private let gb = Locale(identifier: "en_GB")

    /// Formatters put thin spaces round the dash and a narrow no-break space before AM/PM. Plain
    /// spaces keep the expectations readable.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2009}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// `hour` o'clock on 19 Sep 2026 (a Saturday), or on `day` Sep.
    private func date(day: Int = 19, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    @Test func hourBucketIsASpan() {
        #expect(plain(TimeScale.day.bucketDescription(for: date(hour: 15), locale: gb)) == "Sat 19 Sep, 15:00 – 16:00")
        #expect(plain(TimeScale.day.bucketDescription(for: date(hour: 15), locale: us)) == "Sat, Sep 19, 3:00 – 4:00 PM")
    }

    @Test func dayBucket() {
        #expect(plain(TimeScale.week.bucketDescription(for: date(hour: 12), locale: gb)) == "Sat 19 Sep")
    }

    @Test func wholeDayRangeIsJustTheDate() {
        #expect(plain(TimeScale.day.rangeDescription(date()..<date(day: 20), locale: gb)) == "Sat, 19 Sep 2026")
        #expect(plain(TimeScale.day.rangeDescription(date()..<date(day: 20), locale: us)) == "Sat, Sep 19, 2026")
    }

    @Test func partDayRangeShowsTheHours() {
        let range = date(hour: 15)..<date(day: 20, hour: 15)
        #expect(plain(TimeScale.day.rangeDescription(range, locale: gb)) == "19 Sep at 15:00 – 20 Sep at 15:00")
        #expect(plain(TimeScale.day.rangeDescription(range, locale: us)) == "Sep 19 at 3:00 PM – Sep 20 at 3:00 PM")
    }

    @Test func weekRangeEndsOnItsLastDay() {
        // An exclusive end at the next Monday's midnight should read as ending on the Sunday.
        #expect(plain(TimeScale.week.rangeDescription(date(day: 14)..<date(day: 21), locale: gb)) == "14 – 20 Sep 2026")
    }
}
