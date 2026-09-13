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

    public let key: ErrorDiagnosticKey
    public let value: ErrorDiagnosticValue
    public let sensitivity: Sensitivity

    public var name: String {
        key.rawValue
    }

    public init(
        key: ErrorDiagnosticKey,
        value: ErrorDiagnosticValue,
        sensitivity: Sensitivity = .ordinary
    ) {
        self.key = key
        self.value = value
        self.sensitivity = sensitivity
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
        field key: ErrorDiagnosticKey
    ) -> ErrorDiagnosticField? {
        fields.first {
            $0.key == key
        }
    }
}

public struct ErrorRelation: Sendable {
    public struct Kind:
        Sendable,
        Hashable
    {
        public let rawValue: String

        public init(
            rawValue: String
        ) {
            self.rawValue = rawValue
        }

        public static let underlying: Self =
            "underlying"
        public static let aggregate: Self =
            "aggregate"
        public static let related: Self =
            "related"
        public static let context: Self =
            "context"
        public static let recoveryattempt: Self =
            "recoveryattempt"
        public static let remotecause: Self =
            "remotecause"
        public static let toolfailure: Self =
            "toolfailure"
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

/// An error that provides stable semantic presentation and identity while
/// participating in the structured diagnostic and relation capture model.
///
/// Diagnostic fields and relations default to empty so semantic errors only
/// need to author the evidence they actually possess.
public protocol SemanticError:
    PresentableError,
    ErrorIdentityProviding,
    ErrorDiagnosticFieldsProviding,
    ErrorRelationsProviding
{}

public extension SemanticError {
    var errorDiagnosticFields: [ErrorDiagnosticField] {
        []
    }

    var errorRelations: [ErrorRelation] {
        []
    }
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

    public enum ValidationError:
        Error,
        Sendable,
        Hashable,
        LocalizedError
    {
        case negativeLimit(
            field: String,
            value: Int
        )
        case maximumTotalReportsBelowOne(Int)

        public var errorDescription: String? {
            switch self {
            case .negativeLimit(
                let field,
                let value
            ):
                return "Error capture limit '\(field)' cannot be negative; received \(value)."

            case .maximumTotalReportsBelowOne(let value):
                return "Error capture maximumTotalReports must be at least 1; received \(value)."
            }
        }
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case maximumDepth
        case maximumRelationsPerError
        case maximumFieldsPerError
        case userInfo
        case maximumDiagnosticValueDepth
        case maximumStringLength
        case maximumCollectionCount
        case maximumTotalReports
        case maximumTotalFields
    }

    public let maximumDepth: Int
    public let maximumRelationsPerError: Int
    public let maximumFieldsPerError: Int
    public let userInfo: UserInfoCapture
    public let maximumDiagnosticValueDepth: Int
    public let maximumStringLength: Int
    public let maximumCollectionCount: Int
    public let maximumTotalReports: Int
    public let maximumTotalFields: Int

    public init(
        maximumDepth: Int = 12,
        maximumRelationsPerError: Int = 32,
        maximumFieldsPerError: Int = 64,
        userInfo: UserInfoCapture = .all,
        maximumDiagnosticValueDepth: Int = 4,
        maximumStringLength: Int = 8192,
        maximumCollectionCount: Int = 128,
        maximumTotalReports: Int = 256,
        maximumTotalFields: Int = 1024
    ) throws {
        try Self.requireNonnegative(
            maximumDepth,
            field: "maximumDepth"
        )
        try Self.requireNonnegative(
            maximumRelationsPerError,
            field: "maximumRelationsPerError"
        )
        try Self.requireNonnegative(
            maximumFieldsPerError,
            field: "maximumFieldsPerError"
        )
        try Self.requireNonnegative(
            maximumDiagnosticValueDepth,
            field: "maximumDiagnosticValueDepth"
        )
        try Self.requireNonnegative(
            maximumStringLength,
            field: "maximumStringLength"
        )
        try Self.requireNonnegative(
            maximumCollectionCount,
            field: "maximumCollectionCount"
        )
        try Self.requireNonnegative(
            maximumTotalFields,
            field: "maximumTotalFields"
        )

        guard maximumTotalReports >= 1 else {
            throw ValidationError
                .maximumTotalReportsBelowOne(
                    maximumTotalReports
                )
        }

        self.init(
            validatedMaximumDepth: maximumDepth,
            maximumRelationsPerError: maximumRelationsPerError,
            maximumFieldsPerError: maximumFieldsPerError,
            userInfo: userInfo,
            maximumDiagnosticValueDepth: maximumDiagnosticValueDepth,
            maximumStringLength: maximumStringLength,
            maximumCollectionCount: maximumCollectionCount,
            maximumTotalReports: maximumTotalReports,
            maximumTotalFields: maximumTotalFields
        )
    }

    public init(
        from decoder: any Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        try self.init(
            maximumDepth: container.decode(
                Int.self,
                forKey: .maximumDepth
            ),
            maximumRelationsPerError: container.decode(
                Int.self,
                forKey: .maximumRelationsPerError
            ),
            maximumFieldsPerError: container.decode(
                Int.self,
                forKey: .maximumFieldsPerError
            ),
            userInfo: container.decode(
                UserInfoCapture.self,
                forKey: .userInfo
            ),
            maximumDiagnosticValueDepth: container.decode(
                Int.self,
                forKey: .maximumDiagnosticValueDepth
            ),
            maximumStringLength: container.decode(
                Int.self,
                forKey: .maximumStringLength
            ),
            maximumCollectionCount: container.decode(
                Int.self,
                forKey: .maximumCollectionCount
            ),
            maximumTotalReports: container.decode(
                Int.self,
                forKey: .maximumTotalReports
            ),
            maximumTotalFields: container.decode(
                Int.self,
                forKey: .maximumTotalFields
            )
        )
    }

    public func encode(
        to encoder: any Encoder
    ) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            maximumDepth,
            forKey: .maximumDepth
        )
        try container.encode(
            maximumRelationsPerError,
            forKey: .maximumRelationsPerError
        )
        try container.encode(
            maximumFieldsPerError,
            forKey: .maximumFieldsPerError
        )
        try container.encode(
            userInfo,
            forKey: .userInfo
        )
        try container.encode(
            maximumDiagnosticValueDepth,
            forKey: .maximumDiagnosticValueDepth
        )
        try container.encode(
            maximumStringLength,
            forKey: .maximumStringLength
        )
        try container.encode(
            maximumCollectionCount,
            forKey: .maximumCollectionCount
        )
        try container.encode(
            maximumTotalReports,
            forKey: .maximumTotalReports
        )
        try container.encode(
            maximumTotalFields,
            forKey: .maximumTotalFields
        )
    }

    public static let diagnostic = Self(
        validatedMaximumDepth: 12,
        maximumRelationsPerError: 32,
        maximumFieldsPerError: 64,
        userInfo: .all,
        maximumDiagnosticValueDepth: 4,
        maximumStringLength: 8192,
        maximumCollectionCount: 128,
        maximumTotalReports: 256,
        maximumTotalFields: 1024
    )

    public static let minimal = Self(
        validatedMaximumDepth: 4,
        maximumRelationsPerError: 8,
        maximumFieldsPerError: 16,
        userInfo: .none,
        maximumDiagnosticValueDepth: 2,
        maximumStringLength: 1024,
        maximumCollectionCount: 32,
        maximumTotalReports: 32,
        maximumTotalFields: 128
    )

    public static let `default` = diagnostic

    private init(
        validatedMaximumDepth maximumDepth: Int,
        maximumRelationsPerError: Int,
        maximumFieldsPerError: Int,
        userInfo: UserInfoCapture,
        maximumDiagnosticValueDepth: Int,
        maximumStringLength: Int,
        maximumCollectionCount: Int,
        maximumTotalReports: Int,
        maximumTotalFields: Int
    ) {
        self.maximumDepth = maximumDepth
        self.maximumRelationsPerError = maximumRelationsPerError
        self.maximumFieldsPerError = maximumFieldsPerError
        self.userInfo = userInfo
        self.maximumDiagnosticValueDepth = maximumDiagnosticValueDepth
        self.maximumStringLength = maximumStringLength
        self.maximumCollectionCount = maximumCollectionCount
        self.maximumTotalReports = maximumTotalReports
        self.maximumTotalFields = maximumTotalFields
    }

    private static func requireNonnegative(
        _ value: Int,
        field: String
    ) throws {
        guard value >= 0 else {
            throw ValidationError.negativeLimit(
                field: field,
                value: value
            )
        }
    }
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
    public let contexts: [ErrorContext]
    public let relations: [Relation]
    public let truncations: [ErrorCaptureTruncation]

    public init(
        presentation: ErrorPresentation,
        diagnostic: ErrorDiagnostic,
        contexts: [ErrorContext] = [],
        relations: [Relation] = [],
        truncations: [ErrorCaptureTruncation] = []
    ) {
        self.presentation = presentation
        self.diagnostic = diagnostic
        self.contexts = contexts
        self.relations = relations
        self.truncations = truncations
    }

    public var isTruncated: Bool {
        !truncations.isEmpty
            || relations.contains {
                $0.report.isTruncated
            }
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
