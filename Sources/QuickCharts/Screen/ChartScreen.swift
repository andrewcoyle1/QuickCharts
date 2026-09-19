//
//  ChartScreen.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// A Health-style screen: `chart` in an edge-to-edge top section whose colour carries on up behind
/// the nav bar, then any further `sections`. Put it in a NavigationStack, and add toolbar items with
/// `.toolbar { }` as on any view.
public struct ChartScreen<Chart: View, Sections: View>: View {
    let title: String
    let chart: Chart
    let sections: Sections

    /// A screen titled `title`, with `chart` at the top and then `sections`: list sections, e.g. a
    /// `Section` of related values.
    public init(title: String, @ViewBuilder chart: () -> Chart, @ViewBuilder sections: () -> Sections) {
        self.title = title
        self.chart = chart()
        self.sections = sections()
    }

    public var body: some View {
        List {
            if #available(iOS 26, *) {
                Section {
                    chart
                        .topFillEdge()
                        .listRowInsets(.top, 0) // so the chart's colour meets the nav bar
                }
                .listSectionMargins(.all, 0) // edge to edge, leaving other sections inset
                .listSectionSeparator(.hidden)
            } else {
                // Before iOS 26 a section's margins can't be changed, but a header can span the full
                // width. So the chart goes in the header of a section with no rows, and the sections
                // below keep their usual inset look.
                Section {
                } header: {
                    chart
                        .topFillEdge()
                        .fullWidthHeader()
                }
                // The empty section adds its own space below the header; keep the gap to the next
                // section close to iOS 26's.
                .listSectionSpacing(.compact)
            }

            sections
        }
        .coordinateSpace(.named(FullWidthHeader.listSpace))
        .topFill(Color(.secondarySystemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension ChartScreen where Sections == EmptyView {
    /// A screen with just the chart.
    public init(title: String, @ViewBuilder chart: () -> Chart) {
        self.init(title: title, chart: chart, sections: { EmptyView() })
    }
}

private extension View {
    func fullWidthHeader() -> some View {
        modifier(FullWidthHeader())
    }
}

/// Makes a list section header look like a full-width row. Headers are inset by the section's
/// margins, have no background, and make their text small, grey and upper case; this undoes all of
/// that. The margin varies by device, so it's measured rather than assumed.
private struct FullWidthHeader: ViewModifier {
    /// The list's coordinate space, which ChartScreen sets, so the margin is measured from its edge.
    static let listSpace = "ChartScreen.list"

    /// How far in from the list's edge the header has been placed: the section's margin. Nil until
    /// measured.
    @State private var margin: CGFloat?

    func body(content: Content) -> some View {
        Group {
            if let margin {
                content
                    .font(.body)
                    // Color.primary, not .primary: in a header, .primary resolves to the header's
                    // grey, which the summary's .secondary text would then be relative to.
                    .foregroundStyle(Color.primary)
                    .textCase(nil)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    // Widen past the margins. The padding view keeps the header's own frame, so the
                    // measurement below reads the margin, not this widened size.
                    .padding(.horizontal, -margin)
            } else {
                // Nothing until the margin is known: a chart first laid out narrower keeps its
                // scroll offset in points when it widens, which shifts the dates it shows.
                Color.clear.frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.listSpace)).minX } action: { margin = max(0, $0) }
    }
}
