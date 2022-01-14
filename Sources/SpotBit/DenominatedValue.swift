import Foundation

public struct DenominatedValue {
    public var denomination: String
    public var value: Double
    
    public init(denomination: String, value: Double) {
        self.denomination = denomination
        self.value = value
    }
}

extension DenominatedValue: CustomStringConvertible {
    public var description: String {
        return "\(denomination) \(value)"
    }
}
