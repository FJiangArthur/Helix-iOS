/*
Duplicate Codable conformance removed. `Locale` has been `Codable` in Foundation since Swift 4.
This extension is kept commented out to avoid breaking project references while eliminating
the redundant conformance error.

import Foundation

extension Locale: Codable {
    private enum CodingKeys: CodingKey {
        case identifier
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.identifier)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(String.self)
        self = Locale(identifier: id)
    }
}
*/