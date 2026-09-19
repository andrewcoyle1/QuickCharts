//
//  View+TopFill.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

public extension View {

    /// On a List: draws the grouped background, with `color` filling everything above the view
    /// marked `topFillEdge()`, so pulling the list down (or the see-through nav bar) shows `color`
    /// rather than the grouped background.
    func topFill(_ color: Color) -> some View {
        modifier(TopFillModifier(color: color))
    }

    /// Marks the view whose top edge the enclosing `topFill(_:)` fills down to.
    func topFillEdge() -> some View {
        modifier(TopFillEdgeModifier())
    }
}

/// Where the marked view's top edge is on screen. A class so that only `TopFill` re-renders as
/// it changes every scroll frame, not the views that own or mark it.
@Observable
final class TopFillEdge {
    var y: CGFloat = 0
}

extension EnvironmentValues {
    @Entry var topFillEdge: TopFillEdge?
}

private struct TopFillModifier: ViewModifier {
    let color: Color
    @State private var edge = TopFillEdge()

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background { TopFill(edge: edge, color: color).ignoresSafeArea() }
            .environment(\.topFillEdge, edge)
    }
}

private struct TopFillEdgeModifier: ViewModifier {
    @Environment(\.topFillEdge) private var edge

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { edge?.y = $0 }
    }
}

private struct TopFill: View {
    let edge: TopFillEdge
    let color: Color

    var body: some View {
        Color(.systemGroupedBackground)
            .overlay(alignment: .top) {
                color.frame(height: max(0, edge.y))
            }
    }
}
