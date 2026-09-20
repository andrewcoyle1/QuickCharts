//
//  ContributionGridTests.swift
//  QuickChartsTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Foundation
import Testing
@testable import QuickCharts

/// Which day each square stands for, and which shade it earns.
struct ContributionGridTests {

    private let calendar = Calendar.current
    /// A Wednesday, at noon so the day is a full 24 hours whatever the time zone does.
    private let endDate = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 12))!

    private func day(_ offset: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: date))!
    }

    private func series(_ values: [(dayOffset: Int, value: Double)], endingAt endDate: Date) -> TimeSeries {
        TimeSeries(
            name: "Test",
            data: values.map { TimeSeriesDatapoint(date: day($0.dayOffset, from: endDate), value: $0.value) }
        )
    }

    // MARK: - Shape

    @Test func aPackedGridCountsBackFromTheEndDate() {
        let grid = ContributionGrid(series: nil, layout: .packed(rows: 3, columns: 10), endDate: endDate)
        #expect(grid.rows == 3)
        #expect(grid.columnCount == 10)
        #expect(grid.cells.count == 30)
        #expect(grid.startDate == day(-29, from: endDate))
        #expect(grid.cells.last?.date == day(0, from: endDate))
        // Every day is real: a packed grid stops on the end date, so nothing is a placeholder.
        #expect(grid.days.count == 30)
    }

    @Test func daysRunDownEachColumnInTurn() {
        let grid = ContributionGrid(series: nil, layout: .packed(rows: 3, columns: 10), endDate: endDate)
        #expect(grid.columns[0][0].date == grid.startDate)
        #expect(grid.columns[0][1].date == day(1, from: grid.startDate))
        // The second column picks up where the first left off.
        #expect(grid.columns[1][0].date == day(3, from: grid.startDate))
    }

    @Test func aCalendarGridStartsOnTheFirstWeekday() {
        let grid = ContributionGrid(series: nil, layout: .calendar(weeks: 4), endDate: endDate)
        #expect(grid.rows == 7)
        #expect(grid.columnCount == 4)
        #expect(calendar.component(.weekday, from: grid.startDate) == calendar.firstWeekday)
        // Four whole weeks, ending with the one in progress.
        #expect(grid.cells.count == 28)
        #expect(grid.startDate == day(-21, from: calendar.dateInterval(of: .weekOfYear, for: endDate)!.start))
    }

    @Test func everyRowOfACalendarGridIsOneWeekday() {
        let grid = ContributionGrid(series: nil, layout: .calendar(weeks: 4), endDate: endDate)
        for row in 0..<7 {
            let weekdays = Set(grid.columns.map { calendar.component(.weekday, from: $0[row].date) })
            #expect(weekdays.count == 1)
        }
    }

    @Test func daysAfterTheEndDateAreHeldOpenButNotCounted() {
        let grid = ContributionGrid(series: nil, layout: .calendar(weeks: 2), endDate: endDate)
        let future = grid.cells.filter { $0.date > calendar.startOfDay(for: endDate) }
        #expect(!future.isEmpty)
        #expect(future.contains { !$0.isPlaceholder } == false)
        #expect(grid.days.contains { $0.date > calendar.startOfDay(for: endDate) } == false)
    }

    // MARK: - Values

    @Test func readingsLandOnTheirOwnDay() {
        let grid = ContributionGrid(
            series: series([(0, 5), (-3, 2)], endingAt: endDate),
            layout: .packed(rows: 3, columns: 10),
            goal: 5,
            endDate: endDate
        )
        #expect(grid.cells.last?.value == 5)
        #expect(grid.days.first(where: { $0.date == day(-3, from: endDate) })?.value == 2)
        #expect(grid.days.first(where: { $0.date == day(-4, from: endDate) })?.value == 0)
    }

    @Test func aDaysReadingsAreCombinedByTheAggregation() {
        let readings = series([(0, 2), (0, 4)], endingAt: endDate)
        let oneDay = ContributionLayout.packed(rows: 1, columns: 1)
        let summed = ContributionGrid(series: readings, layout: oneDay, aggregation: .sum, endDate: endDate)
        let averaged = ContributionGrid(series: readings, layout: oneDay, aggregation: .average, endDate: endDate)
        #expect(summed.cells.first?.value == 6)
        #expect(averaged.cells.first?.value == 3)
    }

    // MARK: - Levels

    @Test func anEmptyDayIsTheEmptyShade() {
        #expect(ContributionGrid.level(for: 0, goal: 10, levels: 5) == 0)
        #expect(ContributionGrid.level(for: nil, goal: 10, levels: 5) == 0)
    }

    @Test func anyReadingAtAllEarnsTheFirstShade() {
        // 1% of the goal rounds to nothing, but the day still happened, so it must not look empty.
        #expect(ContributionGrid.level(for: 0.1, goal: 10, levels: 5) == 1)
    }

    @Test func theGoalEarnsTheFullestShade() {
        #expect(ContributionGrid.level(for: 10, goal: 10, levels: 5) == 4)
        #expect(ContributionGrid.level(for: 40, goal: 10, levels: 5) == 4)
    }

    @Test func shadesStepEvenlyUpToTheGoal() {
        #expect(ContributionGrid.level(for: 2.5, goal: 10, levels: 5) == 1)
        #expect(ContributionGrid.level(for: 5, goal: 10, levels: 5) == 2)
        #expect(ContributionGrid.level(for: 7.5, goal: 10, levels: 5) == 3)
    }

    @Test func aGoalOfZeroDoesntDivideByZero() {
        let grid = ContributionGrid(
            series: series([(0, 1)], endingAt: endDate),
            layout: .packed(rows: 1, columns: 1),
            goal: 0,
            endDate: endDate
        )
        #expect(grid.cells.first?.level == grid.levels - 1)
    }

    // MARK: - Summaries

    @Test func theStreakCountsBackFromTheLastDay() {
        let grid = ContributionGrid(
            series: series([(0, 1), (-1, 1), (-2, 1), (-4, 1)], endingAt: endDate),
            layout: .packed(rows: 1, columns: 10),
            endDate: endDate
        )
        #expect(grid.currentStreak == 3)
        #expect(grid.longestStreak == 3)
        #expect(grid.activeDayCount == 4)
    }

    @Test func anEmptyLastDayEndsTheStreak() {
        let grid = ContributionGrid(
            series: series([(-1, 1), (-2, 1)], endingAt: endDate),
            layout: .packed(rows: 1, columns: 10),
            endDate: endDate
        )
        #expect(grid.currentStreak == 0)
        #expect(grid.longestStreak == 2)
    }

    @Test func theStreakIgnoresTheDaysStillToCome() {
        // A week-aligned grid holds days open past the end date; they must not break the streak.
        let grid = ContributionGrid(
            series: series([(0, 1), (-1, 1)], endingAt: endDate),
            layout: .calendar(weeks: 2),
            endDate: endDate
        )
        #expect(grid.currentStreak == 2)
    }

    @Test func completionRateCountsOnlyTheDaysTheGridReaches() {
        let grid = ContributionGrid(
            series: series([(0, 1), (-1, 1)], endingAt: endDate),
            layout: .packed(rows: 1, columns: 10),
            endDate: endDate
        )
        #expect(abs(grid.completionRate - 0.2) < 0.0001)
        #expect(grid.total == 2)
    }

    // MARK: - Labels

    @Test func monthLabelsSitWhereTheMonthTurnsOver() {
        let grid = ContributionGrid(series: nil, layout: .calendar(weeks: 12), endDate: endDate)
        let labelled = (0..<grid.columnCount).filter { grid.showsMonthLabel(forColumn: $0) }
        for column in labelled where column > 0 {
            let previous = calendar.component(.month, from: grid.columns[column - 1][0].date)
            let current = calendar.component(.month, from: grid.columns[column][0].date)
            #expect(previous != current)
        }
        // Never two labels side by side.
        #expect(!zip(labelled, labelled.dropFirst()).contains { $1 - $0 == 1 })
    }

    @Test func aPackedGridHasNoWeekdayLabels() {
        let grid = ContributionGrid(series: nil, layout: .packed(rows: 3, columns: 10), endDate: endDate)
        #expect(grid.weekdayLabel(forRow: 0) == nil)
        #expect(grid.showsMonthLabel(forColumn: 0) == false)
    }

    @Test func weekdayLabelsFollowTheRows() {
        let grid = ContributionGrid(series: nil, layout: .calendar(weeks: 4), endDate: endDate)
        let labels = (0..<7).compactMap { grid.weekdayLabel(forRow: $0) }
        #expect(labels.count == 7)
        #expect(labels.first == calendar.veryShortWeekdaySymbols[calendar.firstWeekday - 1])
    }
}
