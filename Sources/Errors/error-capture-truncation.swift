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

        public static let maximumdepth: Self =
            "maximumdepth"
        public static let maximumrelations: Self =
            "maximumrelations"
        public static let maximumfields: Self =
            "maximumfields"
        public static let maximumdiagnosticvaluedepth: Self =
            "maximumdiagnosticvaluedepth"
        public static let maximumstringlength: Self =
            "maximumstringlength"
        public static let maximumcollectioncount: Self =
            "maximumcollectioncount"
        public static let maximumtotalreports: Self =
            "maximumtotalreports"
        public static let maximumtotalfields: Self =
            "maximumtotalfields"
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
