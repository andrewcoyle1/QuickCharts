//
//  SeriesSlotsTests.swift
//  QuickChartsTests
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation
import Testing
@testable import QuickCharts

/// Where side-by-side bars and capsules sit in a bucket, which the highlight dots must match.
struct SeriesSlotsTests {

    private let calendar = Calendar.current
    /// Noon on a day well clear of daylight-saving changes, so the day is 24 hours long.
    private let noon = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 14, hour: 12))!
    private var dayStart: Date { calendar.startOfDay(for: noon) }

    /// Seconds from the start of the day, in hours.
    private func hours(_ date: Date) -> Double {
        date.timeIntervalSince(dayStart) / 3600
    }

    @Test func aSingleSeriesIsCentred() {
        let slots = SeriesSlots(series: ["A"], bucket: .day)
        #expect(hours(slots.center(of: "A", at: noon)) == 12)
        let span = slots.span(of: "A", at: noon)
        // 60% of the day, then 75% of that.
        #expect(abs(hours(span.upperBound) - hours(span.lowerBound) - 24 * 0.6 * 0.75) < 0.001)
        #expect(abs((hours(span.lowerBound) + hours(span.upperBound)) / 2 - 12) < 0.001)
    }

    @Test func twoSeriesSplitTheGroupEvenly() {
        let slots = SeriesSlots(series: ["A", "B"], bucket: .day)
        // The group runs from 4.8h to 19.2h; each slot is 7.2h wide.
        #expect(abs(hours(slots.center(of: "A", at: noon)) - 8.4) < 0.001)
        #expect(abs(hours(slots.center(of: "B", at: noon)) - 15.6) < 0.001)
    }

    @Test func anyTimeInTheBucketGivesTheSameSlot() {
        let slots = SeriesSlots(series: ["A", "B"], bucket: .day)
        let early = dayStart.addingTimeInterval(60)
        let late = dayStart.addingTimeInterval(23 * 3600)
        #expect(slots.center(of: "B", at: early) == slots.center(of: "B", at: late))
        #expect(slots.span(of: "B", at: early) == slots.span(of: "B", at: late))
    }

    @Test func theDotSitsInTheMiddleOfItsBar() {
        let slots = SeriesSlots(series: ["A", "B", "C"], bucket: .day)
        for name in ["A", "B", "C"] {
            let span = slots.span(of: name, at: noon)
            let middle = span.lowerBound.addingTimeInterval(span.upperBound.timeIntervalSince(span.lowerBound) / 2)
            #expect(abs(middle.timeIntervalSince(slots.center(of: name, at: noon))) < 0.001)
        }
    }

    @Test func slotsDoNotOverlap() {
        let slots = SeriesSlots(series: ["A", "B", "C"], bucket: .day)
        let spans = ["A", "B", "C"].map { slots.span(of: $0, at: noon) }
        #expect(spans[0].upperBound <= spans[1].lowerBound)
        #expect(spans[1].upperBound <= spans[2].lowerBound)
    }
}
