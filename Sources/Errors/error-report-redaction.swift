import Foundation

public struct ErrorRedactionPolicy:
    Sendable,
    Codable,
    Hashable
{
    public let includesPotentiallySensitive: Bool
    public let includesSecrets: Bool

    public init(
        includesPotentiallySensitive: Bool,
        includesSecrets: Bool
    ) {
        self.includesPotentiallySensitive =
            includesPotentiallySensitive
        self.includesSecrets =
            includesSecrets
    }

    public static let publicsafe = Self(
        includesPotentiallySensitive: false,
        includesSecrets: false
    )

    public static let internaldiagnostic = Self(
        includesPotentiallySensitive: true,
        includesSecrets: false
    )

    public static let complete = Self(
        includesPotentiallySensitive: true,
        includesSecrets: true
    )

    public func allows(
        _ sensitivity: ErrorDiagnosticField.Sensitivity
    ) -> Bool {
        switch sensitivity {
        case .ordinary:
            return true

        case .potentiallySensitive:
            return includesPotentiallySensitive

        case .secret:
            return includesSecrets
        }
    }
}

public extension ErrorReport {
    func redacted(
        policy: ErrorRedactionPolicy = .publicsafe
    ) -> ErrorReport {
        let fields = diagnostic.fields.map { field in
            guard policy.allows(
                field.sensitivity
            ) else {
                return ErrorDiagnosticField(
                    name: field.name,
                    value: .redacted,
                    sensitivity: field.sensitivity
                )
            }

            return field
        }

        return ErrorReport(
            presentation: presentation,
            diagnostic: ErrorDiagnostic(
                typeName: diagnostic.typeName,
                identity: diagnostic.identity,
                domain: diagnostic.domain,
                code: diagnostic.code,
                fields: fields
            ),
            relations: relations.map {
                .init(
                    kind: $0.kind,
                    report: $0.report.redacted(
                        policy: policy
                    )
                )
            },
            isTruncated: isTruncated
        )
    }
}
