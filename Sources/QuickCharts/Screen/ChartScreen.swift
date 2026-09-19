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
///
/// Given `moreRows`, a "Show More <title> Data" button under the accessories opens a sheet with the
/// chart pinned at the top, on the same range and scroll position, and the rows scrolling under it.
public struct ChartScreen<Chart: View, Accessories: View, MoreRows: View, Sections: View>: View {
    let title: String
    let chart: Chart
    let accessories: Accessories
    let moreRows: MoreRows
    /// Whether `moreRows` was given, so there's a sheet to offer.
    let hasMoreRows: Bool
    let sections: Sections

    /// The range and scroll position shared by the chart here and the sheet's copy of it.
    @State private var viewport = ChartViewportLink()
    @State private var showsMore = false

    /// A screen titled `title`, with `chart` at the top, `accessories` under it, e.g. a
    /// `ChartValueRow` or a `ChartTextButton`, then a button opening a sheet of `moreRows`, and then
    /// `sections`: list sections, e.g. a `Section` of related values.
    ///
    /// The accessories share one list row with the chart, so give any other buttons among them
    /// `.buttonStyle(.borderless)`; otherwise a tap anywhere in the row triggers them all.
    public init(
        title: String,
        @ViewBuilder chart: () -> Chart,
        @ViewBuilder accessories: () -> Accessories,
        @ViewBuilder moreRows: () -> MoreRows,
        @ViewBuilder sections: () -> Sections
    ) {
        self.init(title: title, chart: chart(), accessories: accessories(), moreRows: moreRows(), hasMoreRows: true, sections: sections())
    }

    private init(title: String, chart: Chart, accessories: Accessories, moreRows: MoreRows, hasMoreRows: Bool, sections: Sections) {
        self.title = title
        self.chart = chart
        self.accessories = accessories
        self.moreRows = moreRows
        self.hasMoreRows = hasMoreRows
        self.sections = sections
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
        // The chart here stayed on screen under the sheet, so it takes on any range or scroll
        // change made there.
        .sheet(isPresented: $showsMore, onDismiss: viewport.pushToCharts) {
            ChartMoreSheet(title: title, chart: chart, rows: moreRows)
                .environment(\.chartViewportLink, viewport)
        }
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            chart
                .environment(\.chartViewportLink, viewport)
            accessories
            if hasMoreRows {
                ChartTextButton("Show More \(title) Data") { showsMore = true }
            }
        }
        .chartHighlightScope()
        .topFillEdge()
    }
}

/// The "Show More" sheet: the chart pinned at the top, with the rows scrolling under it. Tapping a
/// row highlights it on this chart, as on the screen.
private struct ChartMoreSheet<Chart: View, Rows: View>: View {
    let title: String
    let chart: Chart
    let rows: Rows

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chart
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                // A scroll view, not a list: the rows' highlights reach the scope through it.
                ScrollView {
                    VStack(spacing: 8) {
                        rows
                    }
                    .padding(16)
                }
                // Rows fade out as they scroll up under the chart, rather than being cut off. At
                // rest the first row sits below the fade.
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: 16)
                        Color.black
                    }
                }
            }
            .chartHighlightScope()
            .background(Color(.secondarySystemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

extension ChartScreen where MoreRows == EmptyView {
    /// A screen with the chart, `accessories` under it, and then `sections`.
    public init(
        title: String,
        @ViewBuilder chart: () -> Chart,
        @ViewBuilder accessories: () -> Accessories,
        @ViewBuilder sections: () -> Sections
    ) {
        self.init(title: title, chart: chart(), accessories: accessories(), moreRows: EmptyView(), hasMoreRows: false, sections: sections())
    }
}

extension ChartScreen where Sections == EmptyView {
    /// A screen with the chart, `accessories` under it, and a button opening a sheet of `moreRows`.
    public init(
        title: String,
        @ViewBuilder chart: () -> Chart,
        @ViewBuilder accessories: () -> Accessories,
        @ViewBuilder moreRows: () -> MoreRows
    ) {
        self.init(title: title, chart: chart, accessories: accessories, moreRows: moreRows, sections: { EmptyView() })
    }
}

extension ChartScreen where Accessories == EmptyView, MoreRows == EmptyView {
    /// A screen with the chart and then `sections`.
    public init(title: String, @ViewBuilder chart: () -> Chart, @ViewBuilder sections: () -> Sections) {
        self.init(title: title, chart: chart, accessories: { EmptyView() }, sections: sections)
    }
}

extension ChartScreen where MoreRows == EmptyView, Sections == EmptyView {
    /// A screen with the chart and `accessories` under it.
    public init(title: String, @ViewBuilder chart: () -> Chart, @ViewBuilder accessories: () -> Accessories) {
        self.init(title: title, chart: chart, accessories: accessories, sections: { EmptyView() })
    }
}

extension ChartScreen where Accessories == EmptyView, MoreRows == EmptyView, Sections == EmptyView {
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
