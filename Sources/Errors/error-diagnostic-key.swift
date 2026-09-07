import Foundation

public struct ErrorDiagnosticKey:
    RawRepresentable,
    ExpressibleByStringLiteral,
    Sendable,
    Codable,
    Hashable
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public init(
        stringLiteral value: String
    ) {
        self.init(
            rawValue: value
        )
    }

    public init(
        from decoder: any Decoder
    ) throws {
        let container = try decoder
            .singleValueContainer()

        self.init(
            rawValue: try container.decode(
                String.self
            )
        )
    }

    public func encode(
        to encoder: any Encoder
    ) throws {
        var container = encoder
            .singleValueContainer()

        try container.encode(
            rawValue
        )
    }

    public static let endpoint: Self = "endpoint"
    public static let attempt: Self = "attempt"
    public static let host: Self = "host"
    public static let path: Self = "path"
    public static let url: Self = "url"
    public static let request: Self = "request"
    public static let response: Self = "response"
    public static let context: Self = "context"
}

public extension ErrorDiagnosticField {
    var key: ErrorDiagnosticKey {
        .init(
            rawValue: name
        )
    }

    init(
        key: ErrorDiagnosticKey,
        value: ErrorDiagnosticValue,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            name: key.rawValue,
            value: value,
            sensitivity: sensitivity
        )
    }

    init(
        key: ErrorDiagnosticKey,
        value: String,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            name: key.rawValue,
            value: value,
            sensitivity: sensitivity
        )
    }

    init(
        key: ErrorDiagnosticKey,
        value: Int,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            name: key.rawValue,
            value: value,
            sensitivity: sensitivity
        )
    }

    init(
        key: ErrorDiagnosticKey,
        value: Double,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            name: key.rawValue,
            value: value,
            sensitivity: sensitivity
        )
    }

    init(
        key: ErrorDiagnosticKey,
        value: Bool,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            name: key.rawValue,
            value: value,
            sensitivity: sensitivity
        )
    }
}

public extension ErrorDiagnostic {
    subscript(
        field key: ErrorDiagnosticKey
    ) -> ErrorDiagnosticField? {
        self[
            field: key.rawValue
        ]
    }
}
