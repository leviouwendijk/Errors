import Foundation

/// The compact, JSON-shaped form of an error report: what a model reads in a
/// tool result, what a log line stores, what is counted across sessions.
///
/// It summarizes the report as given; redact first (`report.redacted(…)`,
/// or `error.summary(…)`, which captures and redacts in one step). Withheld
/// fields are left out; withheld text stays as the placeholder.
public struct ErrorSummary:
    Sendable,
    Codable,
    Hashable
{
    public struct Cause:
        Sendable,
        Codable,
        Hashable
    {
        public let relation: ErrorRelation.Kind
        public let summary: ErrorSummary

        public init(
            relation: ErrorRelation.Kind,
            summary: ErrorSummary
        ) {
            self.relation = relation
            self.summary = summary
        }
    }

    public let code: ErrorIdentity?
    public let message: String
    public let reason: String?
    public let reasonOrigin: ErrorTextOrigin
    public let suggestion: String?
    public let disposition: ErrorDisposition?
    /// What was being done, innermost first.
    public let context: [String]
    public let fields: [String: ErrorDiagnosticValue]
    public let causes: [Cause]
    /// Capture or summary left something out.
    public let truncated: Bool

    public init(
        code: ErrorIdentity? = nil,
        message: String,
        reason: String? = nil,
        reasonOrigin: ErrorTextOrigin = .local,
        suggestion: String? = nil,
        disposition: ErrorDisposition? = nil,
        context: [String] = [],
        fields: [String: ErrorDiagnosticValue] = [:],
        causes: [Cause] = [],
        truncated: Bool = false
    ) {
        self.code = code
        self.message = message
        self.reason = reason
        self.reasonOrigin = reasonOrigin
        self.suggestion = suggestion
        self.disposition = disposition
        self.context = context
        self.fields = fields
        self.causes = causes
        self.truncated = truncated
    }

    /// The first disposition in this summary or its causes, outermost
    /// first: what to do about the failure as a whole.
    public var effectiveDisposition: ErrorDisposition? {
        disposition
            ?? causes.lazy.compactMap(\.summary.effectiveDisposition).first
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case code
        case message
        case reason
        case reasonOrigin = "reason_origin"
        case suggestion
        case disposition
        case context
        case fields
        case causes
        case truncated
    }

    public init(
        from decoder: any Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        self.init(
            code: try container.decodeIfPresent(
                ErrorIdentity.self,
                forKey: .code
            ),
            message: try container.decode(
                String.self,
                forKey: .message
            ),
            reason: try container.decodeIfPresent(
                String.self,
                forKey: .reason
            ),
            reasonOrigin: try container.decodeIfPresent(
                ErrorTextOrigin.self,
                forKey: .reasonOrigin
            ) ?? .local,
            suggestion: try container.decodeIfPresent(
                String.self,
                forKey: .suggestion
            ),
            disposition: try container.decodeIfPresent(
                ErrorDisposition.self,
                forKey: .disposition
            ),
            context: try container.decodeIfPresent(
                [String].self,
                forKey: .context
            ) ?? [],
            fields: try container.decodeIfPresent(
                [String: ErrorDiagnosticValue].self,
                forKey: .fields
            ) ?? [:],
            causes: try container.decodeIfPresent(
                [Cause].self,
                forKey: .causes
            ) ?? [],
            truncated: try container.decodeIfPresent(
                Bool.self,
                forKey: .truncated
            ) ?? false
        )
    }

    /// Leaves out what is empty or default, so a simple error is a
    /// one-line object.
    public func encode(
        to encoder: any Encoder
    ) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encodeIfPresent(
            code,
            forKey: .code
        )
        try container.encode(
            message,
            forKey: .message
        )
        try container.encodeIfPresent(
            reason,
            forKey: .reason
        )

        if reason != nil, reasonOrigin != .local {
            try container.encode(
                reasonOrigin,
                forKey: .reasonOrigin
            )
        }

        try container.encodeIfPresent(
            suggestion,
            forKey: .suggestion
        )
        try container.encodeIfPresent(
            disposition,
            forKey: .disposition
        )

        if !context.isEmpty {
            try container.encode(
                context,
                forKey: .context
            )
        }

        if !fields.isEmpty {
            try container.encode(
                fields,
                forKey: .fields
            )
        }

        if !causes.isEmpty {
            try container.encode(
                causes,
                forKey: .causes
            )
        }

        if truncated {
            try container.encode(
                truncated,
                forKey: .truncated
            )
        }
    }
}

public extension ErrorReport {
    /// This report as it stands, with causes down to `maximumDepth` levels.
    func summary(
        maximumDepth: Int = 4
    ) -> ErrorSummary {
        let withinDepth =
            maximumDepth > 0

        var fields: [String: ErrorDiagnosticValue] = [:]

        for field in diagnostic.fields where field.value != .redacted {
            fields[field.name] = field.value
        }

        return ErrorSummary(
            code: diagnostic.identity,
            message: presentation.message,
            reason: presentation.reason,
            reasonOrigin: presentation.reasonOrigin,
            suggestion: presentation.recoverySuggestion,
            disposition: diagnostic.disposition,
            context: contexts.map(\.message),
            fields: fields,
            causes:
                withinDepth
                ? relations.map {
                    .init(
                        relation: $0.kind,
                        summary: $0.report.summary(
                            maximumDepth: maximumDepth - 1
                        )
                    )
                }
                : [],
            truncated:
                !truncations.isEmpty
                || (!withinDepth && !relations.isEmpty)
        )
    }
}

public extension Error {
    /// Captures, redacts and summarizes in one step, for output that leaves
    /// the process (a model's tool result, a shared log).
    func summary(
        capture: ErrorCapturePolicy = .model,
        redaction: ErrorRedactionPolicy = .public_safe,
        maximumDepth: Int = 4
    ) -> ErrorSummary {
        report(
            policy: capture
        )
        .redacted(
            policy: redaction
        )
        .summary(
            maximumDepth: maximumDepth
        )
    }

    /// As `summary(capture:redaction:maximumDepth:)`, scrubbing the text the
    /// policy lets through with `redactor`.
    func summary<Redactor: ErrorTextRedactor>(
        capture: ErrorCapturePolicy = .model,
        redaction: ErrorRedactionPolicy = .public_safe,
        maximumDepth: Int = 4,
        text redactor: inout Redactor
    ) -> ErrorSummary {
        report(
            policy: capture
        )
        .redacted(
            policy: redaction,
            text: &redactor
        )
        .summary(
            maximumDepth: maximumDepth
        )
    }
}
