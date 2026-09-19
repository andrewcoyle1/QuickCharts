//
//  EqualWidthHStack.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// Lays its children out in a row, giving every child the width of the widest one, so a series
/// with a band takes the same space as one without. Children are top-leading aligned.
struct EqualWidthHStack: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let cell = maxIdealSize(of: subviews)
        let count = CGFloat(subviews.count)
        return CGSize(width: cell.width * count + spacing * (count - 1), height: cell.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cell = maxIdealSize(of: subviews)
        var x = bounds.minX
        for subview in subviews {
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(cell))
            x += cell.width + spacing
        }
    }
    
    private func maxIdealSize(of subviews: Subviews) -> CGSize {
        subviews.reduce(.zero) { result, subview in
            let size = subview.sizeThatFits(.unspecified)
            return CGSize(width: max(result.width, size.width), height: max(result.height, size.height))
        }
    }
}
