//
//  ChartCallout.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Charts
import SwiftUI

extension View {
    /// On a Chart: shows `content` for `item` in a callout just above the plot, centred on the
    /// `bucket` (day, week, month…) containing the item's `date` and kept inside the chart's width.
    /// It pops in and out; nil `item` hides it.
    func chartCallout<Item, Content: View>(
        item: Item?,
        date: KeyPath<Item, Date>,
        bucket: Calendar.Component,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(ChartCalloutModifier(item: item, date: date, bucket: bucket, content: content))
    }
}

private struct ChartCalloutModifier<Item, CalloutContent: View>: ViewModifier {
    let item: Item?
    let date: KeyPath<Item, Date>
    let bucket: Calendar.Component
    let content: (Item) -> CalloutContent

    /// Measured so the callout can be kept inside the chart's width.
    @State private var size: CGSize = .zero

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content chart: Content) -> some View {
        chart.chartOverlay { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame,
                   let item,
                   let stickX = proxy.centerX(ofBucketContaining: item[keyPath: date], component: bucket) {
                    let plot = geo[plotFrame]
                    // Keep the callout inside the chart horizontally, sitting just above the plot
                    // where the header is (the header hides while it's shown).
                    let halfWidth = size.width / 2
                    let x = min(max(plot.minX + stickX, halfWidth), geo.size.width - halfWidth)
                    content(item)
                        .padding(8)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                        // Before `.position`, so the scale anchors on the callout, not the whole overlay.
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                        .position(x: x, y: plot.minY - size.height / 2 - 8)
                        .allowsHitTesting(false) // never steal the drag that's driving it
                }
            }
            // Pops the callout in and out. Keyed on whether there's an item, not which bucket, so it
            // jumps between buckets rather than sliding. Scoped to the overlay: on the Chart it would
            // animate every mark.
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: item != nil)
        }
    }
}
