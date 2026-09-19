//
//  ChartPresenterTests.swift
//  QuickChartsTests
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation
import Testing
@testable import QuickCharts
internal import SwiftUI

/// The header, callout and y axis figures. The presenter opens on the current period, so the data
/// is built around this week.
@MainActor
struct ChartPresenterTests {

    private let calendar = Calendar.current
    private let week = TimeScale.week.currentPeriod()

    /// The start of day `index` (0...6) of this week.
    private func day(_ index: Int) -> Date {
        calendar.date(byAdding: .day, value: index, to: week.start)!
    }

    /// Two readings a day this week, both worth `index + 1` on day `index`: 1, 1, 2, 2 … 7, 7.
    /// A ±1 band on each.
    private func series(_ name: String = "S") -> TimeSeries {
        let readings = (0..<7).flatMap { index in
            [8, 20].map { hour in
                TimeSeriesDatapoint(date: day(index).addingTimeInterval(Double(hour) * 3600), value: Double(index + 1))
            }
        }
        return TimeSeries(name: name, data: readings).withBand { ($0.value - 1)...($0.value + 1) }
    }

    private func presenter(
        _ configuration: ChartConfiguration = ChartConfiguration(),
        traits: ChartPresenter.Traits = ChartPresenter.Traits(),
        data: [TimeSeries]? = nil
    ) -> ChartPresenter {
        ChartPresenter(data: data ?? [series()], configuration: configuration, traits: traits)
    }

    // MARK: - Header

    @Test func headerAveragesTheWeek() throws {
        let summary = try #require(presenter().rangeSummary)
        #expect(summary.label == "Average")
        #expect(summary.rows.map(\.point.value) == [4])
    }

    @Test func headerTotalsTheWeek() throws {
        let summary = try #require(presenter(ChartConfiguration(aggregation: .sum)).rangeSummary)
        #expect(summary.label == "Total")
        #expect(summary.rows.map(\.point.value) == [56])
    }

    @Test func headerAveragesTheDailyTotals() throws {
        let summary = try #require(presenter(ChartConfiguration(aggregation: .sum, summary: .dailyAverage)).rangeSummary)
        #expect(summary.label == "Daily Average")
        #expect(summary.rows.map(\.point.value) == [8])
    }

    @Test func headerSaysNoDataForAnEmptyWeek() throws {
        let summary = try #require(presenter(data: []).rangeSummary)
        #expect(summary.rows.isEmpty)
    }

    @Test func bandShowsOnlyWhenTheChartDrawsIt() throws {
        let hidden = try #require(presenter().rangeSummary)
        #expect(hidden.rows.first?.band == nil)
        let shown = try #require(presenter(traits: ChartPresenter.Traits(showsBand: true)).rangeSummary)
        #expect(shown.rows.first.map { $0.band?.lower } == 3)
        #expect(shown.rows.first.map { $0.band?.upper } == 5)
    }

    // MARK: - Callout

    @Test func selectionShowsTheBucketUnderTheFinger() throws {
        let presenter = presenter(ChartConfiguration(aggregation: .sum))
        #expect(presenter.selection == nil)
        presenter.rawSelection = day(2).addingTimeInterval(3 * 3600)
        let selection = try #require(presenter.selection)
        #expect(selection.rows.map(\.point.value) == [6])
        #expect(presenter.isSelecting)
    }

    // MARK: - Y axis

    /// Whether two domains match, allowing for rounding in the step arithmetic.
    private func approximately(_ lhs: ClosedRange<Double>, _ rhs: ClosedRange<Double>) -> Bool {
        abs(lhs.lowerBound - rhs.lowerBound) < 1e-9 && abs(lhs.upperBound - rhs.upperBound) < 1e-9
    }

    @Test func barsStartAtZeroWithHeadroom() {
        #expect(presenter(traits: ChartPresenter.Traits(startsAtZero: true)).yDomain == 0...(7 * 1.05))
    }

    @Test func linesFitTheirValues() {
        // 1…7, padded by 10% of the spread and rounded out to whole steps of 1. Kept above zero.
        #expect(presenter().yDomain == 0...8)
    }

    @Test func linesFitReadingsFarFromZero() {
        let readings = (0..<7).map { TimeSeriesDatapoint(date: day($0).addingTimeInterval(12 * 3600), value: 72 + Double($0) / 10) }
        // 72.0…72.6, padded to 71.94…72.66 and rounded out to steps of 0.1.
        #expect(approximately(presenter(data: [TimeSeries(name: "S", data: readings)]).yDomain, 71.9...72.7))
    }

    @Test func yAxisFitsTheBandOnlyWhenDrawn() {
        // 0…8 with the band, padded to 8.8 and rounded up to a step of 2.
        #expect(presenter(traits: ChartPresenter.Traits(showsBand: true)).yDomain == 0...10)
    }

    @Test func yAxisStretchesToTheGoal() {
        #expect(presenter(ChartConfiguration(goal: 20)).yDomain == 0...25)
    }

    @Test func yAxisFitsStackedTotals() {
        let presenter = presenter(
            ChartConfiguration(aggregation: .sum),
            traits: ChartPresenter.Traits(stacksSeries: true),
            data: [series("A"), series("B")]
        )
        // The biggest day is day 6: 7 + 7 in each series, stacked to 28. Stacks always start at zero.
        #expect(presenter.yDomain == 0...(28 * 1.05))
    }

    @Test func yAxisIgnoresDataOffScreen() {
        let lastYear = TimeSeriesDatapoint(date: calendar.date(byAdding: .year, value: -1, to: day(0))!, value: 500)
        let withOutlier = TimeSeries(name: "S", data: series().data + [lastYear])
        #expect(presenter(data: [withOutlier]).yDomain == 0...8)
    }

    @Test func yAxisFitsWhereALineCrossesTheEdge() {
        let lastSunday = TimeSeriesDatapoint(date: day(0).addingTimeInterval(-12 * 3600), value: 30)
        // The line from last Sunday's 30 to Monday's 1 crosses the week's start at 15.5: fitted 1…15.5,
        // padded to 0…16.95, in steps of 2.5.
        #expect(presenter(data: [TimeSeries(name: "S", data: series().data + [lastSunday])]).yDomain == 0...17.5)
        // Bars stand alone, so last Sunday's doesn't reach into this week.
        let bars = presenter(traits: ChartPresenter.Traits(isContinuous: false), data: [TimeSeries(name: "S", data: series().data + [lastSunday])])
        #expect(bars.yDomain == 0...8)
    }

    @Test func yAxisFallsBackToAllTheDataForAnEmptyPeriod() {
        let lastYear = calendar.date(byAdding: .year, value: -1, to: day(0))!
        let old = TimeSeries(name: "S", data: [
            TimeSeriesDatapoint(date: lastYear, value: 10),
            TimeSeriesDatapoint(date: calendar.date(byAdding: .day, value: 2, to: lastYear)!, value: 20)
        ])
        // Nothing this week, so it fits 10…20 from last year: padded to 9…21, in steps of 2.
        #expect(presenter(data: [old]).yDomain == 8...22)
    }

    @Test func yAxisRefitsOnlyOnceScrollingSettles() {
        let lastWeek = (0..<7).map {
            TimeSeriesDatapoint(date: day($0).addingTimeInterval(-7 * 86_400 + 12 * 3600), value: 100 + Double($0))
        }
        // Marks that stand alone, so the jump from last week's 106 to this week's 1 doesn't cross
        // either week's edge (see `yAxisFitsWhereALineCrossesTheEdge`).
        let presenter = presenter(
            traits: ChartPresenter.Traits(isContinuous: false),
            data: [TimeSeries(name: "S", data: series().data + lastWeek)]
        )
        #expect(presenter.yDomain == 0...8)
        presenter.scrollPosition = calendar.date(byAdding: .day, value: -7, to: week.start)!
        #expect(presenter.yDomain == 0...8) // still scrolling
        presenter.settleYAxis()
        // 100…106, padded to 99.4…106.6, in steps of 1.
        #expect(presenter.yDomain == 99...107)
    }

    @Test func yAxisMakesRoomForAHighlightedReading() {
        let presenter = presenter()
        presenter.highlight = ChartHighlight(points: ["S": [TimeSeriesDatapoint(date: day(3), value: 12)]])
        // 1…12, padded to 0…13.1, in steps of 2.
        #expect(presenter.yDomain == 0...14)
        presenter.highlight = nil
        #expect(presenter.yDomain == 0...8)
    }

    // MARK: - Updates

    @Test func updatedDataReplacesTheOld() throws {
        let presenter = presenter()
        _ = presenter.plottedData // load and cache the old data first
        _ = presenter.yDomain
        let doubled = TimeSeries(name: "S", data: series().data.map {
            TimeSeriesDatapoint(date: $0.date, value: $0.value * 2)
        })
        presenter.update(data: [doubled])
        #expect(try #require(presenter.rangeSummary).rows.map(\.point.value) == [8])
        #expect(presenter.plottedData.first?.data.map(\.value).max() == 14)
        // 2…14, padded to 0.8…15.2, in steps of 2.
        #expect(presenter.yDomain == 0...16)
    }

    @Test func scaleChangesTheBucket() {
        let presenter = presenter()
        presenter.scale = .day
        #expect(presenter.bucket == .hour)
        presenter.scale = .year
        #expect(presenter.bucket == .month)
    }
}

/// What VoiceOver reads for each series in the header and callout.
struct AccessibilityTests {
    private func row(value: Double, band: ClosedRange<Double>?) -> SelectionRow {
        SelectionRow(
            series: TimeSeries(name: "S", data: []),
            point: TimeSeriesDatapoint(date: .now, value: value),
            band: band.map { TimeSeriesBandDatapoint(date: .now, lower: $0.lowerBound, upper: $0.upperBound) },
            color: .blue
        )
    }

    @Test func valueWithUnit() {
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))
        #expect(row(value: 7.6, band: nil).accessibilityValue(unit: "kcal", format: format) == "7.6 kcal")
    }

    @Test func valueWithBand() {
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0)).locale(Locale(identifier: "en_US"))
        #expect(row(value: 7, band: 5...10).accessibilityValue(unit: "", format: format) == "7, from 5 to 10")
    }
}

/// Which ranges the picker offers, and which one the chart opens on.
@MainActor
struct AvailableScalesTests {
    private func presenter(_ configuration: ChartConfiguration) -> ChartPresenter {
        ChartPresenter(data: [], configuration: configuration)
    }

    @Test func allRangesByDefault() {
        #expect(presenter(ChartConfiguration()).scales == TimeScale.allCases)
    }

    @Test func leavesOutUnavailableRangesInTheUsualOrder() {
        let presenter = presenter(ChartConfiguration(availableScales: [.year, .week, .month]))
        #expect(presenter.scales == [.week, .month, .year])
    }

    @Test func opensOnTheFirstAvailableRangeIfTheInitialOneIsnt() {
        let presenter = presenter(ChartConfiguration(availableScales: [.month, .year], initialScale: .day))
        #expect(presenter.scale == .month)
    }

    @Test func noneAvailableMeansAll() {
        #expect(presenter(ChartConfiguration(availableScales: [])).scales == TimeScale.allCases)
    }
}
