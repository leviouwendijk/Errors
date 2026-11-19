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

    /// What stands in for text or values the policy does not allow.
    public static let placeholder = "<redacted>"

    public static let public_safe = Self(
        includesPotentiallySensitive: false,
        includesSecrets: false
    )

    public static let internal_diagnostic = Self(
        includesPotentiallySensitive: true,
        includesSecrets: false
    )

    public static let complete = Self(
        includesPotentiallySensitive: true,
        includesSecrets: true
    )

    public func allows(
        _ sensitivity: ErrorSensitivity
    ) -> Bool {
        switch sensitivity {
        case .ordinary:
            return true

        case .potentially_sensitive:
            return includesPotentiallySensitive

        case .secret:
            return includesSecrets
        }
    }
}

/// Scrubs free text that a redaction policy lets through, catching what an
/// error's author did not mark: an address interpolated into a message, a
/// path in a server's reply. Errors only declares the seam; a detector such
/// as the Sensitivity library conforms where the policy is chosen, so leaf
/// libraries do not pay for detection.
///
/// `redact` is mutating so a conformer can keep consistent stand-ins across
/// every text it handles (the same address is the same pseudonym).
public protocol ErrorTextRedactor {
    mutating func redact(
        _ text: String
    ) -> String
}

public extension ErrorReport {
    /// Values and text above the policy's sensitivity become
    /// `ErrorRedactionPolicy.placeholder`; everything else is kept as is.
    func redacted(
        policy: ErrorRedactionPolicy = .public_safe
    ) -> ErrorReport {
        var unscrubbed = UnscrubbedText()

        return redacted(
            policy: policy,
            text: &unscrubbed
        )
    }

    /// As `redacted(policy:)`, then every string the policy lets through
    /// (presentation text, context messages, field values) goes through
    /// `redactor`.
    func redacted<Redactor: ErrorTextRedactor>(
        policy: ErrorRedactionPolicy,
        text redactor: inout Redactor
    ) -> ErrorReport {
        ErrorReport(
            presentation:
                presentation.redacted(
                    policy: policy,
                    text: &redactor
                ),
            diagnostic: ErrorDiagnostic(
                typeName: diagnostic.typeName,
                identity: diagnostic.identity,
                domain: diagnostic.domain,
                code: diagnostic.code,
                fields:
                    diagnostic.fields.map {
                        $0.redacted(
                            policy: policy,
                            text: &redactor
                        )
                    }
            ),
            contexts:
                contexts.map {
                    $0.redacted(
                        policy: policy,
                        text: &redactor
                    )
                },
            relations:
                relations.map {
                    .init(
                        kind: $0.kind,
                        report: $0.report.redacted(
                            policy: policy,
                            text: &redactor
                        )
                    )
                },
            truncations: truncations
        )
    }
}

private struct UnscrubbedText: ErrorTextRedactor {
    mutating func redact(
        _ text: String
    ) -> String {
        text
    }
}

private extension ErrorPresentation {
    func redacted<Redactor: ErrorTextRedactor>(
        policy: ErrorRedactionPolicy,
        text redactor: inout Redactor
    ) -> ErrorPresentation {
        replacingText(
            title:
                title.map {
                    redactor.redact($0)
                },
            message:
                policy.allows(
                    messageSensitivity
                )
                ? redactor.redact(message)
                : ErrorRedactionPolicy.placeholder,
            reason:
                reason.map {
                    policy.allows(
                        reasonSensitivity
                    )
                    ? redactor.redact($0)
                    : ErrorRedactionPolicy.placeholder
                },
            recoverySuggestion:
                recoverySuggestion.map {
                    redactor.redact($0)
                },
            recoveryOptions:
                recoveryOptions.map {
                    redactor.redact($0)
                },
            helpAnchor: helpAnchor
        )
    }
}

private extension ErrorDiagnosticField {
    func redacted<Redactor: ErrorTextRedactor>(
        policy: ErrorRedactionPolicy,
        text redactor: inout Redactor
    ) -> ErrorDiagnosticField {
        ErrorDiagnosticField(
            key: key,
            value:
                policy.allows(
                    sensitivity
                )
                ? value.scrubbed(
                    text: &redactor
                )
                : .redacted,
            sensitivity: sensitivity
        )
    }
}

private extension ErrorDiagnosticValue {
    func scrubbed<Redactor: ErrorTextRedactor>(
        text redactor: inout Redactor
    ) -> ErrorDiagnosticValue {
        switch self {
        case .string(let value):
            return .string(
                redactor.redact(value)
            )

        case .array(let values):
            return .array(
                values.map {
                    $0.scrubbed(
                        text: &redactor
                    )
                }
            )

        case .object(let values):
            var scrubbed: [String: ErrorDiagnosticValue] = [:]

            for key in values.keys.sorted() {
                scrubbed[key] =
                    values[key]?.scrubbed(
                        text: &redactor
                    )
            }

            return .object(scrubbed)

        case .integer,
             .double,
             .boolean,
             .redacted,
             .null:
            return self
        }
    }
}

private extension ErrorContext {
    func redacted<Redactor: ErrorTextRedactor>(
        policy: ErrorRedactionPolicy,
        text redactor: inout Redactor
    ) -> ErrorContext {
        ErrorContext(
            message:
                policy.allows(
                    messageSensitivity
                )
                ? redactor.redact(message)
                : ErrorRedactionPolicy.placeholder,
            fields:
                fields.map {
                    $0.redacted(
                        policy: policy,
                        text: &redactor
                    )
                },
            messageSensitivity:
                messageSensitivity
        )
    }
}
