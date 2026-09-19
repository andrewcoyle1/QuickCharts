//
//  SeriesSummary.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// One column per series, then a divider and a footer line. Shared by the header and the
/// callout so the two look the same. With no rows, says "No Data" in their place, at the same size.
struct SeriesSummary: View {
    let rows: [SelectionRow]
    let footer: Text
    /// Shown after each value, e.g. "steps". Empty for none.
    var unit: String = ""
    var valueFormat: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(1))

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if rows.isEmpty {
                noData
            } else {
                columns
            }
            Divider()
            footer
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }

    private var noData: some View {
        // Blank series-name line, so the header doesn't change height when data comes and goes.
        VStack(alignment: .leading, spacing: 6) {
            Text(" ")
                .font(.callout)
            Text("No Data")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
    }

    private var columns: some View {
        EqualWidthHStack {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.series.name)
                        .font(.callout)
                        .foregroundStyle(row.color)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(row.point.value, format: valueFormat)
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        Group {
                            if let band = row.band {
                                VStack {
                                    Text(band.upper, format: valueFormat)
                                    Text(band.lower, format: valueFormat)
                                }
                                .font(.caption2)
                            }
                            if !unit.isEmpty {
                                Text(unit)
                            }
                        }
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
                // One element per series, read as "Sample Set 1, 7.6 kcal, from 6.6 to 8.6" rather
                // than each number on its own.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.series.name)
                .accessibilityValue(row.accessibilityValue(unit: unit, format: valueFormat))
            }
        }
    }
}

#Preview {
    List {
        SeriesSummary(rows: SelectionRow.mocks, footer: Text("Hey"), unit: "kcal")
        SeriesSummary(rows: [], footer: Text("14 – 20 Sep 2026"))
    }
}
