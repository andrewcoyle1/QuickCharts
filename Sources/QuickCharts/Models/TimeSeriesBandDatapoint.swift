//
//  TimeSeriesBandDatapoint.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

/// A lower and upper bound at a moment in time, e.g. a reading's error margin. Drawn as a shaded
/// band behind a line chart's line. The bounds are swapped if given the wrong way round.
public nonisolated struct TimeSeriesBandDatapoint: Identifiable, Equatable, Sendable {
    public let id: String
    public let date: Date
    public let lower: Double
    public let upper: Double

    public init(id: String = UUID().uuidString, date: Date, lower: Double, upper: Double) {
        self.id = id
        self.date = date
        self.lower = min(lower, upper)
        self.upper = max(lower, upper)
    }
    
    static var mock: Self {
        .init(
            date: Date(),
            lower: 2.5,
            upper: 7.5
        )
    }
}
