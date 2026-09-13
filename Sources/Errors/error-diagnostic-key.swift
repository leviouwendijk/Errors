import Primitives

public struct ErrorDiagnosticKey: StringIdentifier {
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public static let endpoint: Self = "endpoint"
    public static let attempt: Self = "attempt"
    public static let host: Self = "host"
    public static let path: Self = "path"
    public static let url: Self = "url"
    public static let request: Self = "request"
    public static let response: Self = "response"
}

public extension ErrorDiagnosticField {
    init(
        key: ErrorDiagnosticKey,
        value: String,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            key: key,
            value: .string(value),
            sensitivity: sensitivity
        )
    }

    init(
        key: ErrorDiagnosticKey,
        value: Int,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            key: key,
            value: .integer(value),
            sensitivity: sensitivity
        )
    }

    init(
        key: ErrorDiagnosticKey,
        value: Double,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            key: key,
            value: .double(value),
            sensitivity: sensitivity
        )
    }

    init(
        key: ErrorDiagnosticKey,
        value: Bool,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            key: key,
            value: .boolean(value),
            sensitivity: sensitivity
        )
    }
}
