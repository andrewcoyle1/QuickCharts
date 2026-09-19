//
//  YAxisFitTests.swift
//  QuickChartsTests
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation
import Testing
@testable import QuickCharts

/// How the y axis fits the values on screen.
struct YAxisFitTests {

    /// Whether two domains match, allowing for rounding in the step arithmetic.
    private func approximately(_ lhs: ClosedRange<Double>, _ rhs: ClosedRange<Double>) -> Bool {
        abs(lhs.lowerBound - rhs.lowerBound) < 1e-9 && abs(lhs.upperBound - rhs.upperBound) < 1e-9
    }

    @Test func noValuesGiveAUnitAxis() {
        #expect(YAxisFit.domain(for: [], startsAtZero: false) == 0...1)
        #expect(YAxisFit.domain(for: [], startsAtZero: true) == 0...1)
    }

    @Test func fromZeroKeepsZeroAndAddsHeadroom() {
        #expect(YAxisFit.domain(for: [3, 7], startsAtZero: true) == 0...(7 * 1.05))
    }

    @Test func fromZeroReachesDownToNegativeValues() {
        #expect(YAxisFit.domain(for: [-4, 7], startsAtZero: true) == -4...(7 * 1.05))
    }

    @Test func fromZeroWithOnlyZeroesStillHasHeight() {
        #expect(YAxisFit.domain(for: [0, 0], startsAtZero: true) == 0...1)
    }

    @Test func fittedValuesAreRoundedOutToSteps() {
        // 72.0…72.8, padded by 0.08 each side and rounded out to steps of 0.2.
        #expect(approximately(YAxisFit.domain(for: [72, 72.8], startsAtZero: false), 71.8...73))
    }

    @Test func aFlatLineGetsRoomAroundIt() {
        // No spread, so 10% of the value (7.2) is shared either side: 68.4…75.6, in steps of 1.
        #expect(YAxisFit.domain(for: [72, 72], startsAtZero: false) == 68...76)
    }

    @Test func paddingDoesNotTakePositiveValuesBelowZero() {
        #expect(YAxisFit.domain(for: [1, 7], startsAtZero: false).lowerBound == 0)
    }

    @Test func negativeValuesFitBelowZero() {
        // -5…-1, padded to -5.4…-0.6, in steps of 1.
        #expect(YAxisFit.domain(for: [-5, -1], startsAtZero: false) == -6...0)
    }

    @Test func stepsAreRoundNumbers() {
        #expect(YAxisFit.roundStep(for: 0.12) == 0.2)
        #expect(YAxisFit.roundStep(for: 1) == 1)
        #expect(YAxisFit.roundStep(for: 3) == 5)
        #expect(YAxisFit.roundStep(for: 22) == 25)
        #expect(YAxisFit.roundStep(for: 0) == 1)
    }
}
