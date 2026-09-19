//
//  TimeSeriesChart.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Charts
import SwiftUI

/// The picker, range header and scrolling, selectable chart shared by every chart variant. The
/// variant supplies only the marks, e.g. lines (`LineChart`) or bars (`BarChart`).
struct TimeSeriesChart<Marks: ChartContent>: View {
    @Bindable var presenter: ChartPresenter
    /// The data the variant was last given. Handed on to the presenter when it changes, since the
    /// presenter lives in the variant's @State and only saw the data it was first created with.
    let data: [TimeSeries]
    @ChartContentBuilder let marks: () -> Marks

    var body: some View {
        VStack(alignment: .leading) {
            // Nothing to pick between with a single range.
            if presenter.scales.count > 1 {
                timeScalePicker
            }

            RangeHeader(presenter: presenter)

            chart
        }
        .onChange(of: data) { presenter.update(data: data) }
    }

    private var timeScalePicker: some View {
        Picker("Time scale", selection: $presenter.scale) {
            ForEach(presenter.scales) { scale in
                Text(scale.rawValue).tag(scale)
            }
        }
        .pickerStyle(.segmented)
    }

    private var chart: some View {
        Chart {
            marks()
            if let goal = presenter.configuration.goal {
                GoalLine(value: goal)
            }
        }
        .chartForegroundStyleScale(domain: presenter.data.map(\.name), range: presenter.seriesColors)
        .chartLegend(.hidden) // the header and callout name the series
        .chartXScale(domain: presenter.fullDomain)
        .chartYScale(domain: presenter.yDomain)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: presenter.visibleLength)
        .chartScrollPosition(x: $presenter.scrollPosition)
        // Settle on the nearest day/week/month; a flick carries on to the next period boundary.
        .chartScrollTargetBehavior(.valueAligned(
            matching: presenter.scale.scrollSnap,
            majorAlignment: .matching(presenter.scale.flickSnap)
        ))
        // On a scrolling chart, Swift Charts' built-in selection is press-and-hold then drag, so it
        // doesn't fight the scroll. It clears when the finger lifts.
        .chartXSelection(value: $presenter.rawSelection)
        .chartCallout(item: presenter.selection, date: \.date, bucket: presenter.bucket) { selection in
            SeriesSummary(
                rows: selection.rows,
                footer: presenter.scale.bucketLabel(for: selection.date),
                unit: presenter.configuration.unit,
                valueFormat: presenter.configuration.valueFormat
            )
        }
        .chartXAxis {
            // Only the loaded range gets axis marks. `.stride` would build a gridline, tick and label
            // for every day of the whole scrollable history (~370 on W), and all of them are laid out
            // again whenever the chart rebuilds.
            AxisMarks(values: presenter.axisDates) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: presenter.scale.axisLabelFormat, centered: presenter.scale.centersAxisLabels)
            }
        }
        .chartYAxis {
            AxisMarks(preset: .extended)
            // The goal's value beside the axis, so it stays labelled however far the chart scrolls.
            // (An annotation on the goal line would sit at one end of the whole scrollable history.)
            if let goal = presenter.configuration.goal {
                AxisMarks(values: [goal]) {
                    AxisValueLabel {
                        Text(goal, format: presenter.configuration.valueFormat)
                            .fontWeight(.bold)
                    }
                }
            }
        }
        .accessibilityChartDescriptor(presenter.accessibilityDescriptor)
        .frame(height: presenter.configuration.height)
    }
}
