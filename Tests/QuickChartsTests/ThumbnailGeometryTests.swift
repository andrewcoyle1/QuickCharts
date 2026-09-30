//
//  ThumbnailGeometryTests.swift
//  QuickChartsTests
//
//  Created by Andrew Coyle on 30/09/2026.
//

import Foundation
import Testing
@testable import QuickCharts

/// The scales a thumbnail is drawn on.
struct ThumbnailGeometryTests {

    private let calendar = Calendar.current
    private let today = Calendar.current.startOfDay(for: .now)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func series(_ name: String, _ values: [Double]) -> TimeSeries {
        TimeSeries(name: name, data: values.enumerated().map { TimeSeriesDatapoint(date: day($0.offset), value: $0.element) })
    }

    @Test func aLineFitsItsValuesRatherThanZero() {
        let geometry = ThumbnailGeometry(data: [series("Weight", [82, 83])], style: .line, goal: nil)
        #expect(geometry.yDomain.lowerBound > 81 && geometry.yDomain.lowerBound < 82)
        #expect(geometry.yDomain.upperBound > 83 && geometry.yDomain.upperBound < 84)
    }

    @Test func barsStackSoTheAxisFitsEachDaysTotal() {
        let geometry = ThumbnailGeometry(data: [series("Protein", [100, 50]), series("Fat", [40, 10])], style: .bars, goal: nil)
        #expect(geometry.yDomain == 0...140)
    }

    @Test func aComboFitsItsLinesAndBarsFromZero() {
        let geometry = ThumbnailGeometry(
            data: [series("Intake", [2_000, 1_800]), series("Burned", [2_400, 2_300])],
            style: .combo(lineSeries: ["Burned"]),
            goal: nil
        )
        #expect(geometry.yDomain == 0...2_400)
        #expect(geometry.isLine("Burned"))
        #expect(!geometry.isLine("Intake"))
    }

    @Test func allZeroBarsStillHaveHeightForTheirStubs() {
        let geometry = ThumbnailGeometry(data: [series("Sets", [0, 0, 0])], style: .bars, goal: nil)
        #expect(geometry.yDomain == 0...1)
        #expect(geometry.stubHeight > 0)
    }

    @Test func theGoalIsInsideTheAxis() {
        let geometry = ThumbnailGeometry(data: [series("Sets", [3, 4])], style: .bars, goal: 10)
        #expect(geometry.yDomain.upperBound == 10)
    }

    @Test func theXAxisRunsWholeDays() {
        let geometry = ThumbnailGeometry(data: [series("Sets", [1, 2, 3])], style: .bars, goal: nil)
        #expect(geometry.xDomain == day(0)...day(3))
    }

    @Test func aLoneReadingDrawsAsALineFromTheDayBefore() {
        let points = ThumbnailGeometry.linePoints(series("Weight", [82]))
        #expect(points.count == 2)
        #expect(points.first?.date == day(-1))
        let geometry = ThumbnailGeometry(data: [series("Weight", [82])], style: .line, goal: nil)
        #expect(geometry.xDomain.lowerBound == day(-1))
    }
}
