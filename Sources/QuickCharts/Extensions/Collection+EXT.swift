//
//  Collection+EXT.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

nonisolated extension Collection {
    /// Arithmetic mean of `value` over the collection. Call only on a non-empty collection.
    func mean(of value: (Element) -> Double) -> Double {
        reduce(0) { $0 + value($1) } / Double(count)
    }

    /// The element at `index`, or nil when it's out of bounds. For walking a grid's neighbours,
    /// where running off the end is an ordinary case rather than a mistake.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
