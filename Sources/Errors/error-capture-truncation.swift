import Primitives

public struct ErrorCaptureTruncation:
    Sendable,
    Codable,
    Hashable
{
    public struct Reason: StringIdentifier {
        public let rawValue: String

        public init(
            rawValue: String
        ) {
            self.rawValue = rawValue
        }

        public static let maximum_depth: Self =
            "maximum_depth"
        public static let maximum_relations: Self =
            "maximum_relations"
        public static let maximum_fields: Self =
            "maximum_fields"
        public static let maximum_diagnostic_value_depth: Self =
            "maximum_diagnostic_value_depth"
        public static let maximum_string_length: Self =
            "maximum_string_length"
        public static let maximum_collection_count: Self =
            "maximum_collection_count"
        public static let maximum_total_reports: Self =
            "maximum_total_reports"
        public static let maximum_total_fields: Self =
            "maximum_total_fields"
        public static let cycle: Self =
            "cycle"
    }

    public let reason: Reason
    public let limit: Int?

    public init(
        reason: Reason,
        limit: Int? = nil
    ) {
        self.reason = reason
        self.limit = limit
    }
}
