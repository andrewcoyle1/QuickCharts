//
//  ChartViewportLink.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import SwiftUI

/// The range and scroll position shared by `ChartScreen`'s chart and the Show More sheet's copy of
/// it, each of which has its own presenter. Every chart given one writes its range and scroll
/// position here; a chart appearing takes them on, so the sheet opens where the screen was, and
/// `pushToCharts()` makes charts already on screen take them on, so the screen follows the sheet.
@Observable
final class ChartViewportLink {
    /// Not observed: the scroll position changes every frame while scrolling.
    @ObservationIgnored var scale: TimeScale?
    @ObservationIgnored var scrollPosition: Date?

    /// Bumped by `pushToCharts()`; charts watch it.
    private(set) var revision = 0

    /// Makes the charts on screen take on `scale` and `scrollPosition`.
    func pushToCharts() {
        revision += 1
    }
}

extension EnvironmentValues {
    @Entry var chartViewportLink: ChartViewportLink?
}
