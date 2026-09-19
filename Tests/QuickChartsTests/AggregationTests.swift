//
//  AggregationTests.swift
//  QuickChartsTests
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation
import Testing
@testable import QuickCharts

struct AggregationTests {

    private let values = [2.0, 4.0, 9.0]
    private let band = [
        TimeSeriesBandDatapoint(date: .now, lower: 1, upper: 3),
        TimeSeriesBandDatapoint(date: .now, lower: 3, upper: 7),
    ]

    @Test func averageTakesTheMeanAndAveragesTheBand() {
        let result = Aggregation.average.combine(values, band: band)
        #expect(result.value == 5)
        #expect(result.band == 2...5)
    }

    @Test func averageWithoutBandReadingsHasNoBand() {
        #expect(Aggregation.average.combine(values, band: []).band == nil)
    }

    @Test func sumTotalsAndDropsTheBand() {
        let result = Aggregation.sum.combine(values, band: band)
        #expect(result.value == 15)
        #expect(result.band == nil)
    }

    @Test func rangeTakesTheMeanWithABandFromLowestToHighest() {
        let result = Aggregation.range.combine(values, band: band)
        #expect(result.value == 5)
        #expect(result.band == 2...9)
    }

    @Test func noneCombinesLikeAverage() {
        let none = Aggregation.none.combine(values, band: band)
        let average = Aggregation.average.combine(values, band: band)
        #expect(none.value == average.value)
        #expect(none.band == average.band)
    }

    @Test func labels() {
        #expect(Aggregation.average.label == "Average")
        #expect(Aggregation.none.label == "Average")
        #expect(Aggregation.sum.label == "Total")
        #expect(Aggregation.range.label == "Range")
    }
}
