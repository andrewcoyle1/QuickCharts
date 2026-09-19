//
//  HighlightTests.swift
//  QuickChartsTests
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation
import Testing
@testable import QuickCharts
internal import SwiftUI

/// What a selected accessory row shows on the chart: which readings, in which colours, where their
/// labels go, what VoiceOver hears, and scrolling them into view.
@MainActor
struct HighlightTests {

    private let calendar = Calendar.current
    private let week = TimeScale.week.currentPeriod()

    /// Noon on day `index` (0...6) of this week.
    private func noon(_ index: Int) -> Date {
        calendar.date(byAdding: .day, value: index, to: week.start)!.addingTimeInterval(12 * 3600)
    }

    /// A reading of 10 each day this week, so the y axis of bars side by side runs from 0 to 10.5.
    private func series(_ name: String) -> TimeSeries {
        TimeSeries(name: name, data: (0..<7).map { TimeSeriesDatapoint(date: noon($0), value: 10) })
    }

    private func presenter(highlight: [String: [TimeSeriesDatapoint]]) -> ChartPresenter {
        let presenter = ChartPresenter(
            data: [series("A"), series("B")],
            configuration: ChartConfiguration(
                unit: "BPM",
                valueFormat: .number.precision(.fractionLength(0)).locale(Locale(identifier: "en_US")),
                seriesColors: [.blue, .green]
            ),
            traits: ChartPresenter.Traits(isContinuous: false, placesSeriesSideBySide: true, startsAtZero: true)
        )
        presenter.highlight = ChartHighlight(points: highlight)
        return presenter
    }

    private func point(_ value: Double, day: Int = 2) -> TimeSeriesDatapoint {
        TimeSeriesDatapoint(date: noon(day), value: value)
    }

    @Test func eachReadingTakesItsSeriesColour() {
        let points = presenter(highlight: ["A": [point(4)], "B": [point(6)]]).highlightPoints
        #expect(points.map(\.series) == ["A", "B"])
        #expect(points.map(\.color) == [.blue, .green])
    }

    @Test func seriesTheChartDoesNotHaveAreIgnored() {
        let points = presenter(highlight: ["A": [point(4)], "Nope": [point(6)]]).highlightPoints
        #expect(points.map(\.series) == ["A"])
    }

    @Test func noHighlightMeansNoPoints() {
        let presenter = presenter(highlight: [:])
        presenter.highlight = nil
        #expect(presenter.highlightPoints.isEmpty)
        #expect(presenter.highlightDescription == nil)
    }

    @Test func seriesGoGreyWhileHighlighted() {
        let presenter = presenter(highlight: ["A": [point(4)]])
        #expect(!presenter.markColors.contains(.blue))
        presenter.highlight = nil
        #expect(presenter.markColors == [.blue, .green])
    }

    // MARK: - Labels

    @Test func theHighestInABucketHasItsLabelAboveTheRestBelow() {
        let points = presenter(highlight: ["A": [point(4)], "B": [point(6)]]).highlightPoints
        #expect(points.map(\.labelBelow) == [true, false])
    }

    @Test func readingsInDifferentBucketsEachHaveTheirLabelAbove() {
        let points = presenter(highlight: ["A": [point(4, day: 1)], "B": [point(6, day: 2)]]).highlightPoints
        #expect(points.map(\.labelBelow) == [false, false])
    }

    @Test func aTieStillGivesOneLabelAbove() {
        let points = presenter(highlight: ["A": [point(5)], "B": [point(5)]]).highlightPoints
        #expect(points.filter { !$0.labelBelow }.count == 1)
    }

    @Test func aReadingNearTheTopHasItsLabelBelow() {
        // The axis runs to 10.5, so a label above 10 wouldn't fit.
        let points = presenter(highlight: ["A": [point(10)]]).highlightPoints
        #expect(points.map(\.labelBelow) == [true])
    }

    // MARK: - VoiceOver

    @Test func describesEachReadingWithItsSeriesAndUnit() {
        let description = presenter(highlight: ["A": [point(4)], "B": [point(6)]]).highlightDescription
        #expect(description == "A, 4 BPM. B, 6 BPM.")
    }

    // MARK: - Scrolling into view

    @Test func scrollsBackToAReadingOffScreen() {
        let presenter = presenter(highlight: ["A": [point(4)]])
        presenter.scrollPosition = calendar.date(byAdding: .weekOfYear, value: -3, to: week.start)!
        presenter.revealHighlight()
        #expect(presenter.scrollPosition == week.start)
    }

    @Test func leavesTheChartWhereItIsWhenAReadingIsOnScreen() {
        let presenter = presenter(highlight: ["A": [point(4)]])
        let start = presenter.scrollPosition
        presenter.revealHighlight()
        #expect(presenter.scrollPosition == start)
    }
}
