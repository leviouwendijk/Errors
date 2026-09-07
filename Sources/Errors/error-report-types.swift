import Foundation

public struct ErrorPresentation:
    Sendable,
    Codable,
    Hashable
{
    public let title: String?
    public let message: String
    public let reason: String?
    public let recoverySuggestion: String?
    public let recoveryOptions: [String]
    public let helpAnchor: String?

    public init(
        title: String? = nil,
        message: String,
        reason: String? = nil,
        recoverySuggestion: String? = nil,
        recoveryOptions: [String] = [],
        helpAnchor: String? = nil
    ) {
        self.title = title
        self.message = message
        self.reason = reason
        self.recoverySuggestion = recoverySuggestion
        self.recoveryOptions = recoveryOptions
        self.helpAnchor = helpAnchor
    }
}

public indirect enum ErrorDiagnosticValue:
    Sendable,
    Codable,
    Hashable
{
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([ErrorDiagnosticValue])
    case object([String: ErrorDiagnosticValue])
    case redacted
    case null
}

public struct ErrorDiagnosticField:
    Sendable,
    Codable,
    Hashable
{
    public enum Sensitivity:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        case ordinary
        case potentiallySensitive
        case secret
    }

    public let name: String
    public let value: ErrorDiagnosticValue
    public let sensitivity: Sensitivity

    public init(
        name: String,
        value: ErrorDiagnosticValue,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.name = name
        self.value = value
        self.sensitivity = sensitivity
    }

    public init(
        name: String,
        value: String,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            name: name,
            value: .string(value),
            sensitivity: sensitivity
        )
    }

    public init(
        name: String,
        value: Int,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            name: name,
            value: .integer(value),
            sensitivity: sensitivity
        )
    }

    public init(
        name: String,
        value: Double,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            name: name,
            value: .double(value),
            sensitivity: sensitivity
        )
    }

    public init(
        name: String,
        value: Bool,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.init(
            name: name,
            value: .boolean(value),
            sensitivity: sensitivity
        )
    }
}

public struct ErrorDiagnostic:
    Sendable,
    Codable,
    Hashable
{
    public let typeName: String
    public let identity: ErrorIdentity?
    public let domain: String?
    public let code: Int?
    public let fields: [ErrorDiagnosticField]

    public init(
        typeName: String,
        identity: ErrorIdentity? = nil,
        domain: String? = nil,
        code: Int? = nil,
        fields: [ErrorDiagnosticField] = []
    ) {
        self.typeName = typeName
        self.identity = identity
        self.domain = domain
        self.code = code
        self.fields = fields
    }

    public subscript(
        field name: String
    ) -> ErrorDiagnosticField? {
        fields.first {
            $0.name == name
        }
    }
}

public struct ErrorRelation: Sendable {
    public struct Kind:
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

        public static let underlying = Self(
            rawValue: "underlying"
        )

        public static let aggregate = Self(
            rawValue: "aggregate"
        )

        public static let related = Self(
            rawValue: "related"
        )

        public static let context = Self(
            rawValue: "context"
        )

        public static let recoveryattempt = Self(
            rawValue: "recoveryattempt"
        )

        public static let remotecause = Self(
            rawValue: "remotecause"
        )

        public static let toolfailure = Self(
            rawValue: "toolfailure"
        )
    }

    public let kind: Kind
    public let error: any Error

    public init(
        kind: Kind,
        error: any Error
    ) {
        self.kind = kind
        self.error = error
    }

    public static func underlying(
        _ error: any Error
    ) -> Self {
        .init(
            kind: .underlying,
            error: error
        )
    }

    public static func aggregate(
        _ error: any Error
    ) -> Self {
        .init(
            kind: .aggregate,
            error: error
        )
    }

    public static func related(
        _ error: any Error
    ) -> Self {
        .init(
            kind: .related,
            error: error
        )
    }

    public static func context(
        _ error: any Error
    ) -> Self {
        .init(
            kind: .context,
            error: error
        )
    }
}

public protocol PresentableError:
    Error,
    LocalizedError
{
    var errorPresentation: ErrorPresentation { get }
}

public extension PresentableError {
    var errorDescription: String? {
        errorPresentation.message
    }

    var failureReason: String? {
        errorPresentation.reason
    }

    var recoverySuggestion: String? {
        errorPresentation.recoverySuggestion
    }

    var helpAnchor: String? {
        errorPresentation.helpAnchor
    }
}

public protocol ErrorDiagnosticFieldsProviding: Error {
    var errorDiagnosticFields: [ErrorDiagnosticField] { get }
}

public protocol ErrorRelationsProviding: Error {
    var errorRelations: [ErrorRelation] { get }
}

public struct ErrorCapturePolicy:
    Sendable,
    Codable,
    Hashable
{
    public enum UserInfoCapture:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        case none
        case standard
        case all
    }

    public let maximumDepth: Int
    public let maximumRelationsPerError: Int
    public let maximumFieldsPerError: Int
    public let userInfo: UserInfoCapture
    public let maximumDiagnosticValueDepth: Int

    public init(
        maximumDepth: Int = 12,
        maximumRelationsPerError: Int = 32,
        maximumFieldsPerError: Int = 64,
        userInfo: UserInfoCapture = .all,
        maximumDiagnosticValueDepth: Int = 4
    ) {
        self.maximumDepth = max(0, maximumDepth)
        self.maximumRelationsPerError = max(0, maximumRelationsPerError)
        self.maximumFieldsPerError = max(0, maximumFieldsPerError)
        self.userInfo = userInfo
        self.maximumDiagnosticValueDepth = max(0, maximumDiagnosticValueDepth)
    }

    public static let diagnostic = Self()

    public static let minimal = Self(
        maximumDepth: 4,
        maximumRelationsPerError: 8,
        maximumFieldsPerError: 16,
        userInfo: .none,
        maximumDiagnosticValueDepth: 2
    )

    public static let `default` = diagnostic
}

public struct ErrorReport:
    Sendable,
    Codable,
    Hashable
{
    public struct Relation:
        Sendable,
        Codable,
        Hashable
    {
        public let kind: ErrorRelation.Kind
        public let report: ErrorReport

        public init(
            kind: ErrorRelation.Kind,
            report: ErrorReport
        ) {
            self.kind = kind
            self.report = report
        }
    }

    public let presentation: ErrorPresentation
    public let diagnostic: ErrorDiagnostic
    public let relations: [Relation]
    public let isTruncated: Bool

    public init(
        presentation: ErrorPresentation,
        diagnostic: ErrorDiagnostic,
        relations: [Relation] = [],
        isTruncated: Bool = false
    ) {
        self.presentation = presentation
        self.diagnostic = diagnostic
        self.relations = relations
        self.isTruncated = isTruncated
    }

    public init(
        capturing error: any Error,
        policy: ErrorCapturePolicy = .default
    ) {
        self = ErrorReportCapture.capture(
            error,
            policy: policy
        )
    }

    public var underlying: ErrorReport? {
        relations.first {
            $0.kind == .underlying
        }?.report
    }

    public var aggregates: [ErrorReport] {
        reports(
            relatedBy: .aggregate
        )
    }

    public var related: [ErrorReport] {
        reports(
            relatedBy: .related
        )
    }

    public var context: [ErrorReport] {
        reports(
            relatedBy: .context
        )
    }

    public func reports(
        relatedBy kind: ErrorRelation.Kind
    ) -> [ErrorReport] {
        relations.compactMap {
            $0.kind == kind
                ? $0.report
                : nil
        }
    }
}
