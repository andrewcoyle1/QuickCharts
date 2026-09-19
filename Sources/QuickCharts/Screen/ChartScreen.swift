//
//  ChartScreen.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// A Health-style screen: `chart` in an edge-to-edge top section whose colour carries on up behind
/// the nav bar, with any `accessories` under it on the same colour, then any further `sections`. Put
/// it in a NavigationStack, and add toolbar items with `.toolbar { }` as on any view.
public struct ChartScreen<Chart: View, Accessories: View, Sections: View>: View {
    let title: String
    let chart: Chart
    let accessories: Accessories
    let sections: Sections

    /// A screen titled `title`, with `chart` at the top, `accessories` under it, e.g. a
    /// `ChartValueRow` or a `ChartTextButton`, and then `sections`: list sections, e.g. a `Section`
    /// of related values.
    ///
    /// The accessories share one list row with the chart, so give any other buttons among them
    /// `.buttonStyle(.borderless)`; otherwise a tap anywhere in the row triggers them all.
    public init(
        title: String,
        @ViewBuilder chart: () -> Chart,
        @ViewBuilder accessories: () -> Accessories,
        @ViewBuilder sections: () -> Sections
    ) {
        self.title = title
        self.chart = chart()
        self.accessories = accessories()
        self.sections = sections()
    }

    public var body: some View {
        List {
            if #available(iOS 26, *) {
                Section {
                    chartBlock
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
                    chartBlock
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

    private var chartBlock: some View {
        ChartBlock(chart: chart, accessories: accessories)
            .topFillEdge()
    }
}

/// The chart with its accessories under it. Holds which row is selected, and hands that row's
/// highlight to the chart. Kept inside the list row so the rows' preferences reach it: they don't
/// cross from one list row to another.
private struct ChartBlock<Chart: View, Accessories: View>: View {
    let chart: Chart
    let accessories: Accessories

    @State private var selectedID: UUID?
    @State private var highlights: [UUID: ChartHighlight] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chart
                .environment(\.chartHighlight, selectedID.flatMap { highlights[$0] })
            accessories
        }
        .environment(\.chartHighlightSelection, ChartHighlightSelection(id: selectedID) { selectedID = $0 })
        .onPreferenceChange(ChartHighlightsKey.self) { highlights = $0 }
    }
}

extension ChartScreen where Accessories == EmptyView {
    /// A screen with the chart and then `sections`.
    public init(title: String, @ViewBuilder chart: () -> Chart, @ViewBuilder sections: () -> Sections) {
        self.init(title: title, chart: chart, accessories: { EmptyView() }, sections: sections)
    }
}

extension ChartScreen where Sections == EmptyView {
    /// A screen with the chart and `accessories` under it.
    public init(title: String, @ViewBuilder chart: () -> Chart, @ViewBuilder accessories: () -> Accessories) {
        self.init(title: title, chart: chart, accessories: accessories, sections: { EmptyView() })
    }
}

extension ChartScreen where Accessories == EmptyView, Sections == EmptyView {
    /// A screen with just the chart.
    public init(title: String, @ViewBuilder chart: () -> Chart) {
        self.init(title: title, chart: chart, accessories: { EmptyView() }, sections: { EmptyView() })
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
