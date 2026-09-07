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
        ErrorReport(
            presentation: presentation,
            diagnostic: ErrorDiagnostic(
                typeName: diagnostic.typeName,
                identity: diagnostic.identity,
                domain: diagnostic.domain,
                code: diagnostic.code,
                fields:
                    diagnostic.fields.map {
                        $0.redacted(
                            policy: policy
                        )
                    }
            ),
            contexts:
                contexts.map {
                    $0.redacted(
                        policy: policy
                    )
                },
            relations:
                relations.map {
                    .init(
                        kind: $0.kind,
                        report: $0.report.redacted(
                            policy: policy
                        )
                    )
                },
            truncations: truncations
        )
    }
}

private extension ErrorDiagnosticField {
    func redacted(
        policy: ErrorRedactionPolicy
    ) -> ErrorDiagnosticField {
        guard policy.allows(
            sensitivity
        ) else {
            return ErrorDiagnosticField(
                key: key,
                value: .redacted,
                sensitivity: sensitivity
            )
        }

        return self
    }
}

private extension ErrorContext {
    func redacted(
        policy: ErrorRedactionPolicy
    ) -> ErrorContext {
        ErrorContext(
            message:
                policy.allows(
                    messageSensitivity
                )
                ? message
                : "<redacted>",
            fields:
                fields.map {
                    $0.redacted(
                        policy: policy
                    )
                },
            messageSensitivity:
                messageSensitivity
        )
    }
}
