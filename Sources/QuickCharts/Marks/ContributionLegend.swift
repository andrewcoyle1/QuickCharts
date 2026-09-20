//
//  ContributionLegend.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 20/09/2026.
//

import SwiftUI

/// The empty-to-full key for a contribution grid: one swatch per shade, in order.
///
/// Public on its own so a caller composing the grid into their own card can put the key wherever
/// it belongs — or leave it out — without rebuilding the swatches by hand and drifting out of step
/// with the grid's shades.
public struct ContributionLegend: View {

    let color: Color
    let style: ContributionStyle
    /// What the empty and full ends are called.
    let lowLabel: String
    let highLabel: String

    private let swatchSize: CGFloat = 10

    public init(
        color: Color = .green,
        style: ContributionStyle = ContributionStyle(),
        lowLabel: String = "Less",
        highLabel: String = "More"
    ) {
        self.color = color
        self.style = style
        self.lowLabel = lowLabel
        self.highLabel = highLabel
    }

    public var body: some View {
        HStack(spacing: style.spacing * 2) {
            Text(lowLabel)
            ForEach(0..<style.levels, id: \.self) { level in
                RoundedRectangle(cornerRadius: style.cornerRadius * swatchSize / 16, style: .continuous)
                    .fill(style.color(forLevel: level, base: color))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius * swatchSize / 16, style: .continuous)
                            .stroke(style.borderColor, lineWidth: 0.5)
                    )
                    .frame(width: swatchSize, height: swatchSize)
            }
            Text(highLabel)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Key: \(lowLabel) to \(highLabel), in \(style.levels) steps")
    }
}

#Preview {
    ContributionLegend(color: .green)
        .padding()
}
