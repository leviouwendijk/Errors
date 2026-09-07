import DSL
import Errors

public struct ErrorStructuredContentOptions:
    Sendable,
    Codable,
    Hashable
{
    public let includesDiagnostics: Bool
    public let includesRelations: Bool
    public let redaction: ErrorRedactionPolicy

    public init(
        includesDiagnostics: Bool = true,
        includesRelations: Bool = true,
        redaction: ErrorRedactionPolicy = .publicsafe
    ) {
        self.includesDiagnostics = includesDiagnostics
        self.includesRelations = includesRelations
        self.redaction = redaction
    }

    public static let summary = Self(
        includesDiagnostics: false,
        includesRelations: false,
        redaction: .publicsafe
    )

    public static let diagnostic = Self(
        includesDiagnostics: true,
        includesRelations: true,
        redaction: .internaldiagnostic
    )

    public static let complete = Self(
        includesDiagnostics: true,
        includesRelations: true,
        redaction: .complete
    )
}

public extension StructuredContent.Role {
    static let error = Self(
        rawValue: "error"
    )

    static let errorReason = Self(
        rawValue: "error.reason"
    )

    static let errorRecovery = Self(
        rawValue: "error.recovery"
    )

    static let errorHelp = Self(
        rawValue: "error.help"
    )

    static let errorDiagnostics = Self(
        rawValue: "error.diagnostics"
    )

    static let errorUnderlying = Self(
        rawValue: "error.underlying"
    )

    static let errorAggregate = Self(
        rawValue: "error.aggregate"
    )

    static let errorRelated = Self(
        rawValue: "error.related"
    )

    static let errorContext = Self(
        rawValue: "error.context"
    )

    static let errorTruncation = Self(
        rawValue: "error.truncation"
    )
}

public extension ErrorReport {
    var structuredContent: StructuredContent {
        structuredContent(
            options: .diagnostic
        )
    }

    func structuredContent(
        options: ErrorStructuredContentOptions
    ) -> StructuredContent {
        var content: [StructuredContent] = [
            .paragraph([
                .text(
                    presentation.message
                ),
            ]),
        ]

        if let reason =
            presentation.reason
        {
            content.append(
                presentationGroup(
                    role: .errorReason,
                    title: "Reason",
                    value: reason
                )
            )
        }

        if let recoverySuggestion =
            presentation.recoverySuggestion
        {
            content.append(
                presentationGroup(
                    role: .errorRecovery,
                    title: "Recovery",
                    value: recoverySuggestion
                )
            )
        }

        if let helpAnchor =
            presentation.helpAnchor
        {
            content.append(
                presentationGroup(
                    role: .errorHelp,
                    title: "Help",
                    value: helpAnchor
                )
            )
        }

        if !presentation.recoveryOptions.isEmpty {
            content.append(
                .group(
                    role: .errorRecovery,
                    title: [
                        .text(
                            "Recovery options"
                        ),
                    ],
                    content: .list(
                        style: .unordered,
                        items:
                            presentation.recoveryOptions.map {
                                .paragraph([
                                    .text($0),
                                ])
                            }
                    )
                )
            )
        }

        if !contexts.isEmpty {
            content.append(
                .group(
                    role: .errorContext,
                    title: [
                        .text(
                            "Context"
                        ),
                    ],
                    content: .collection(
                        contexts.map {
                            contextContent(
                                $0,
                                options: options
                            )
                        }
                    )
                )
            )
        }

        if options.includesDiagnostics {
            content.append(
                diagnosticContent(
                    options: options
                )
            )
        }

        if options.includesRelations {
            content.append(
                contentsOf:
                    relations.map {
                        relationContent(
                            $0,
                            options: options
                        )
                    }
            )
        }

        return .group(
            role: .error,
            title: [
                .text(
                    presentation.title
                    ?? shortTypeName
                ),
            ],
            content: .collection(
                content
            )
        )
    }
}

private extension ErrorReport {
    var shortTypeName: String {
        diagnostic.typeName
            .split(
                separator: "."
            )
            .last
            .map(String.init)
        ?? diagnostic.typeName
    }

    func presentationGroup(
        role: StructuredContent.Role,
        title: String,
        value: String
    ) -> StructuredContent {
        .group(
            role: role,
            title: [
                .text(
                    title
                ),
            ],
            content: .paragraph([
                .text(
                    value
                ),
            ])
        )
    }

    func diagnosticContent(
        options: ErrorStructuredContentOptions
    ) -> StructuredContent {
        var diagnostics: [StructuredContent] = [
            diagnosticLine(
                name: "type",
                value: diagnostic.typeName
            ),
        ]

        if let identity =
            diagnostic.identity
        {
            diagnostics.append(
                diagnosticLine(
                    name: "identity.namespace",
                    value: identity.namespace
                )
            )
            diagnostics.append(
                diagnosticLine(
                    name: "identity.code",
                    value: identity.code
                )
            )
        }

        if let domain =
            diagnostic.domain
        {
            diagnostics.append(
                diagnosticLine(
                    name: "domain",
                    value: domain
                )
            )
        }

        if let code =
            diagnostic.code
        {
            diagnostics.append(
                diagnosticLine(
                    name: "code",
                    value: String(code)
                )
            )
        }

        diagnostics.append(
            contentsOf:
                diagnostic.fields.map {
                    diagnosticLine(
                        name: $0.key.rawValue,
                        value:
                            diagnosticValue(
                                for: $0,
                                options: options
                            )
                    )
                }
        )

        if !truncations.isEmpty {
            diagnostics.append(
                .group(
                    role: .errorTruncation,
                    title: [
                        .text(
                            "Capture truncation"
                        ),
                    ],
                    content: .list(
                        style: .unordered,
                        items:
                            truncations.map {
                                truncationContent(
                                    $0
                                )
                            }
                    )
                )
            )
        }

        return .group(
            role: .errorDiagnostics,
            title: [
                .text(
                    "Diagnostics"
                ),
            ],
            content: .collection(
                diagnostics
            )
        )
    }

    func relationContent(
        _ relation: ErrorReport.Relation,
        options: ErrorStructuredContentOptions
    ) -> StructuredContent {
        .group(
            role:
                relation.kind.structuredContentRole,
            title: [
                .text(
                    relation.kind.presentationTitle
                ),
            ],
            content:
                relation.report.structuredContent(
                    options: options
                )
        )
    }

    func diagnosticLine(
        name: String,
        value: String
    ) -> StructuredContent {
        .paragraph([
            .strong([
                .text(
                    name
                ),
            ]),
            .text(
                "  "
            ),
            .code(
                value
            ),
        ])
    }

    func contextContent(
        _ context: ErrorContext,
        options: ErrorStructuredContentOptions
    ) -> StructuredContent {
        var content: [StructuredContent] = [
            .paragraph([
                .text(
                    options.redaction.allows(
                        context.messageSensitivity
                    )
                    ? context.message
                    : "<redacted>"
                ),
            ]),
        ]

        content.append(
            contentsOf:
                context.fields.map {
                    diagnosticLine(
                        name: $0.key.rawValue,
                        value:
                            diagnosticValue(
                                for: $0,
                                options: options
                            )
                    )
                }
        )

        return .collection(
            content
        )
    }

    func truncationContent(
        _ truncation: ErrorCaptureTruncation
    ) -> StructuredContent {
        var content: [StructuredContent.Inline] = [
            .code(
                truncation.reason.rawValue
            ),
        ]

        if let limit = truncation.limit {
            content.append(
                .text(
                    " · limit \(limit)"
                )
            )
        }

        return .paragraph(
            content
        )
    }

    func diagnosticValue(
        for field: ErrorDiagnosticField,
        options: ErrorStructuredContentOptions
    ) -> String {
        guard
            options.redaction.allows(
                field.sensitivity
            )
        else {
            return "<redacted>"
        }

        return field.value.presentation
    }
}

private extension ErrorRelation.Kind {
    var structuredContentRole: StructuredContent.Role {
        if self == .underlying {
            return .errorUnderlying
        }

        if self == .aggregate {
            return .errorAggregate
        }

        if self == .related {
            return .errorRelated
        }

        return .init(
            rawValue:
                "error.relation.\(rawValue)"
        )
    }

    var presentationTitle: String {
        if self == .underlying {
            return "Underlying error"
        }

        if self == .aggregate {
            return "Error"
        }

        if self == .related {
            return "Related error"
        }

        if self == .context {
            return "Context"
        }

        if self == .recoveryattempt {
            return "Recovery attempt"
        }

        if self == .remotecause {
            return "Remote cause"
        }

        if self == .toolfailure {
            return "Tool failure"
        }

        return rawValue
    }
}

private extension ErrorDiagnosticValue {
    var presentation: String {
        switch self {
        case .string(let value):
            return value

        case .integer(let value):
            return String(value)

        case .double(let value):
            return String(value)

        case .boolean(let value):
            return value
                ? "true"
                : "false"

        case .array(let values):
            return "["
                + values
                    .map(\.presentation)
                    .joined(
                        separator: ", "
                    )
                + "]"

        case .object(let values):
            return "{"
                + values.keys
                    .sorted()
                    .map { key in
                        let value =
                            values[key]
                                .map(\.presentation)
                            ?? "null"

                        return "\(key): \(value)"
                    }
                    .joined(
                        separator: ", "
                    )
                + "}"

        case .redacted:
            return "<redacted>"

        case .null:
            return "null"
        }
    }
}
