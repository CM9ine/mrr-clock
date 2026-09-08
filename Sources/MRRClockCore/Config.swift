/// Calculator settings introduced by T08 and extended by T13.
public struct Config: Equatable, Sendable {
    public var currency: String
    public var includeTrials: Bool

    public init(currency: String = "usd", includeTrials: Bool = false) {
        self.currency = currency.lowercased()
        self.includeTrials = includeTrials
    }
}
