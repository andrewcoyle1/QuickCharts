//
//  ChartAccessories.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// A label and value in a capsule, for `ChartScreen`'s accessories, like Health's
/// "Latest: 12:50 p.m. · 38 BPM". Given a `highlight`, tapping it fills it with the highlight's
/// colour and shows the highlight on the chart; tapping it again, or another row, clears it.
public struct ChartValueRow: View {
    let title: LocalizedStringKey
    let value: String
    let unit: String
    let highlight: ChartHighlight?

    @Environment(\.chartHighlightSelection) private var selection
    /// Identifies this row to the screen, which keeps track of the selected one.
    @State private var id = UUID()

    /// `title` on the left; `value`, then `unit` in smaller grey text, on the right. `highlight` is
    /// what tapping it shows on the chart; without one, or outside a `ChartScreen`, it can't be tapped.
    public init(_ title: LocalizedStringKey, value: String, unit: String = "", highlight: ChartHighlight? = nil) {
        self.title = title
        self.value = value
        self.unit = unit
        self.highlight = highlight
    }

    private var isSelected: Bool { highlight != nil && selection?.id == id }

    public var body: some View {
        if let highlight, let selection {
            Button {
                selection.select(isSelected ? nil : id)
            } label: {
                content(color: highlight.color)
            }
            // Plain, so only the row responds, not the whole list row it shares with the chart,
            // and its text isn't tinted.
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .preference(key: ChartHighlightsKey.self, value: [id: highlight])
        } else {
            content(color: nil)
        }
    }

    private func content(color: Color?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .fontWeight(.bold)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? AnyShapeStyle(Color.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                }
            }
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary))
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        // Unselected, one step lighter than the chart section's background.
        .background(Capsule().fill(isSelected ? color ?? .accentColor : Color(.tertiarySystemGroupedBackground)))
        .contentShape(Capsule())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
    }
}

/// A plain, centred text button in the accent colour, for `ChartScreen`'s accessories, like
/// Health's "Show More Heart Rate Data".
public struct ChartTextButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    public init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .font(.subheadline)
            // Explicitly tinted: before iOS 26 the chart sits in a section header, whose primary
            // foreground style would otherwise colour the button too.
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity)
            // Borderless, so only the button responds, not the whole row it shares with the chart.
            .buttonStyle(.borderless)
    }
}

#Preview {
    List {
        VStack(spacing: 12) {
            ChartValueRow("Latest: 12:50 p.m.", value: "38", unit: "BPM")
            ChartValueRow("Range", value: "35–75", unit: "BPM")
            ChartTextButton("Show More Heart Rate Data") {}
        }
    }
}
