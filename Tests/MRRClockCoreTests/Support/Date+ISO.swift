import Foundation

extension Date {
    init(iso: String) {
        guard let date = ISO8601DateFormatter().date(from: iso) else {
            preconditionFailure("Invalid ISO 8601 test date: \(iso)")
        }
        self = date
    }
}
