//
//  ChartProxy+EXT.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Charts
import Foundation

extension ChartProxy {
    /// The x position, relative to the plot, of the centre of the `component` bucket containing
    /// `date`. Marks plotted with `unit: component` sit at the bucket centre, so this lines up with them.
    func centerX(ofBucketContaining date: Date, component: Calendar.Component) -> CGFloat? {
        guard let interval = Calendar.current.dateInterval(of: component, for: date),
              let start = position(forX: interval.start),
              let end = position(forX: interval.end) else { return nil }
        return (start + end) / 2
    }
}
