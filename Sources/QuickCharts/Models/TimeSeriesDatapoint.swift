//
//  TimeSeriesDatapoint.swift
//  QuickCharts
//
//  Created by Andrew Coyle on 19/09/2026.
//

import Foundation

/// One reading: a value at a moment in time.
public nonisolated struct TimeSeriesDatapoint: Identifiable, Equatable, Sendable {
    public let id: String
    public let date: Date
    public let value: Double

    public init(id: String = UUID().uuidString, date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
    
    static var mock: Self {
        .init(date: Date(), value: 5)
    }
}
