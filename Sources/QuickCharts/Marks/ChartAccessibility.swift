//
//  ChartAccessibility.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Accessibility
import SwiftUI

/// Describes the plotted data to VoiceOver, which uses it for the chart's audio graph and data
/// table. Covers the loaded range (a few screens either side of what's visible), bucketed as drawn.
struct TimeSeriesChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let series: [TimeSeries]
    /// Lines join their points; bars, ranges and scatter points stand alone.
    let isContinuous: Bool
    let dates: ClosedRange<Date>
    let values: ClosedRange<Double>
    let dateFormat: Date.FormatStyle
    let unit: String
    let valueFormat: FloatingPointFormatStyle<Double>

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Date"),
            range: dates.lowerBound.timeIntervalSinceReferenceDate...dates.upperBound.timeIntervalSinceReferenceDate,
            gridlinePositions: []
        ) { [dateFormat] in
            Date(timeIntervalSinceReferenceDate: $0).formatted(dateFormat)
        }
        let yAxis = AXNumericDataAxisDescriptor(
            title: unit.isEmpty ? String(localized: "Value") : unit,
            range: values,
            gridlinePositions: []
        ) { [unit, valueFormat] in
            unit.isEmpty ? $0.formatted(valueFormat) : "\($0.formatted(valueFormat)) \(unit)"
        }
        return AXChartDescriptor(
            title: title,
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series.map { series in
                AXDataSeriesDescriptor(
                    name: series.name,
                    isContinuous: isContinuous,
                    dataPoints: series.sortedByDate.map {
                        AXDataPoint(x: $0.date.timeIntervalSinceReferenceDate, y: $0.value)
                    }
                )
            }
        )
    }
}

extension SelectionRow {
    /// "7.6 kcal, from 6.6 to 8.6": what VoiceOver reads for this series in the header or callout.
    func accessibilityValue(unit: String, format: FloatingPointFormatStyle<Double>) -> String {
        func written(_ value: Double) -> String {
            unit.isEmpty ? value.formatted(format) : "\(value.formatted(format)) \(unit)"
        }
        guard let band else { return written(point.value) }
        return String(localized: "\(written(point.value)), from \(band.lower.formatted(format)) to \(band.upper.formatted(format))")
    }
}
