//
//  File.swift
//  
//
//  Created by Wolf McNally on 1/20/22.
//

import Foundation
import WolfBase

public struct Candle {
    public let startEnd: Range<Date>
    public let lowHigh: Range<Double>
    public let openClose: Interval<Double>
    public let volume: Double
    
    public var start: Date { startEnd.lowerBound }
    public var end: Date { startEnd.upperBound }
    public var low: Double { lowHigh.lowerBound }
    public var high: Double { lowHigh.upperBound }
    public var open: Double { openClose.a }
    public var close: Double { openClose.b }

    public init(startEnd: Range<Date>, lowHigh: Range<Double>, openClose: Interval<Double>, volume: Double) {
        self.startEnd = startEnd
        self.lowHigh = lowHigh
        self.openClose = openClose
        self.volume = max(volume, 0)
    }
    
    public init?(start: Date? = nil, end: Date, low: Double? = nil, high: Double? = nil, open: Double? = nil, close: Double, volume: Double = 0) {
        let start = start ?? end
        let low = low ?? close
        let high = high ?? close
        let open = open ?? close
        guard
            start <= end,
            low <= high,
            low <= open,
            low <= close,
            high >= open,
            high >= close
        else {
            return nil
        }
        
        self.init(startEnd: start..<end, lowHigh: low..<high, openClose: open..close, volume: volume)
    }
    
    public func combined(with other: Candle) -> Candle {
        guard self != other else {
            return self
        }
        let start = min(self.start, other.start)
        let end = max(self.end, other.end)
        let low = min(self.low, other.low)
        let high = max(self.high, other.high)
        let open = self.start < other.start ? self.open : other.open
        let close = self.end > other.end ? self.close : other.close
        let volume = self.volume + other.volume
        return Candle(startEnd: start..<end, lowHigh: low..<high, openClose: open..close, volume: volume)
    }
    
    public static func combine(_ candles: Set<Candle>) -> Candle? {
        guard !candles.isEmpty else {
            return nil
        }
        return candles.reduce(candles.first!) { partialResult, candle in
            return partialResult.combined(with: candle)
        }
    }
}

extension Candle: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(start)
        hasher.combine(end)
        hasher.combine(low)
        hasher.combine(high)
        hasher.combine(open)
        hasher.combine(close)
        hasher.combine(volume)
    }
}

extension Candle: Comparable {
    public static func < (lhs: Candle, rhs: Candle) -> Bool {
        lhs.end < rhs.end
    }
}

extension Candle: CustomStringConvertible {
    public var description: String {
        return try! Self.jsonEncoder().encode(self).utf8!
    }
}

extension Candle: Encodable {
    public static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    enum CodingKeys: String, CodingKey {
        case start
        case end
        case low
        case high
        case open
        case close
        case volume
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if start != end {
            try container.encode(start, forKey: .start)
        }
        try container.encode(end, forKey: .end)
        
        if low != high {
            try container.encode(Decimal(low), forKey: .low)
            try container.encode(Decimal(high), forKey: .high)
        }
        
        if open != close {
            try container.encode(Decimal(open), forKey: .open)
        }
        try container.encode(Decimal(close), forKey: .close)
        
        if volume > 0 {
            try container.encode(Decimal(volume), forKey: .volume)
        }
    }
}
