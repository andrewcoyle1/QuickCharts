//
//  BucketingTests.swift
//  QuickChartsTests
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation
import Testing
@testable import QuickCharts

/// `TimeSeries.bucketed(by:aggregation:)` and the calendar helpers it and the axis rely on. Dates
/// are built with `Calendar.current`, like the code under test, so the tests pass in any time zone.
struct BucketingTests {

    private let calendar = Calendar.current

    /// Midnight on 1 Sep 2026, plus `hours`.
    private func date(day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    /// Two readings on 1 Sep and one on 2 Sep, out of order.
    private var series: TimeSeries {
        TimeSeries(
            name: "S",
            data: [
                TimeSeriesDatapoint(date: date(day: 2, hour: 9), value: 6),
                TimeSeriesDatapoint(date: date(day: 1, hour: 8), value: 1),
                TimeSeriesDatapoint(date: date(day: 1, hour: 20), value: 3),
            ],
            band: [
                TimeSeriesBandDatapoint(date: date(day: 1, hour: 8), lower: 0, upper: 2),
                TimeSeriesBandDatapoint(date: date(day: 1, hour: 20), lower: 2, upper: 4),
            ]
        )
    }

    @Test func averagesEachDayAtItsMidpointInDateOrder() {
        let bucketed = series.bucketed(by: .day)
        #expect(bucketed.data.map(\.value) == [2, 6])
        #expect(bucketed.data.map(\.date) == [date(day: 1, hour: 12), date(day: 2, hour: 12)])
        #expect(bucketed.band.map(\.lower) == [1])
        #expect(bucketed.band.map(\.upper) == [3])
    }

    @Test func sumsEachDay() {
        #expect(series.bucketed(by: .day, aggregation: .sum).data.map(\.value) == [4, 6])
    }

    @Test func rangeBandsEachDayFromLowestToHighest() {
        let bucketed = series.bucketed(by: .day, aggregation: .range)
        #expect(bucketed.band.map(\.lower) == [1, 6])
        #expect(bucketed.band.map(\.upper) == [3, 6])
    }

    @Test func noneLeavesTheReadingsAlone() {
        let series = series // one copy: each access makes new random ids
        #expect(series.bucketed(by: .day, aggregation: .none) == series)
    }

    @Test func bucketsByWeek() {
        // 1 and 2 Sep 2026 are a Tuesday and Wednesday, in the same week whichever day it starts on.
        #expect(series.bucketed(by: .weekOfYear, aggregation: .sum).data.map(\.value) == [10])
    }

    @Test func pointsInABucket() {
        #expect(series.points(inBucketOf: date(day: 1, hour: 23), component: .day).map(\.value) == [1, 3])
        #expect(series.bandPoints(inBucketOf: date(day: 2), component: .day).isEmpty)
    }

    @Test func startsEverySixHours() {
        let starts = calendar.starts(of: .hour, every: 6, in: date(day: 1)..<date(day: 2))
        #expect(starts == [0, 6, 12, 18].map { date(day: 1, hour: $0) })
    }

    @Test func startsIncludeThePartialFirstPeriod() {
        let starts = calendar.starts(of: .day, in: date(day: 1, hour: 15)..<date(day: 3, hour: 1))
        #expect(starts == [date(day: 1), date(day: 2), date(day: 3)])
    }

    @Test func nearestMidnightAcrossADaylightSavingChange() throws {
        // London's clocks go back an hour on 25 Oct 2026, so a week-long window from the start of
        // that week ends an hour before midnight. It should snap forward, not back a day.
        var london = Calendar(identifier: .gregorian)
        london.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let weekStart = try #require(london.date(from: DateComponents(year: 2026, month: 10, day: 19)))
        let nextWeek = try #require(london.date(from: DateComponents(year: 2026, month: 10, day: 26)))
        #expect(weekStart.addingTimeInterval(7 * 86_400).nearestMidnight(in: london) == nextWeek)
    }

    @Test func mockReadingsPerDay() {
        let mock = TimeSeries.mock(startDate: date(day: 1), endDate: date(day: 2), readingsPerDay: 4)
        #expect(mock.data.count == 8)
        #expect(Set(mock.data.map { calendar.component(.hour, from: $0.date) }) == [0, 6, 12, 18])
    }
}
