import Foundation

/// How much of an error an audience may see: a model, a log, another
/// service, the public. It names the audience's share, not who the audience
/// is; deciding that (an anonymous request, a trusted token) is the caller's.
public struct ErrorDisclosure:
    Sendable,
    Codable,
    Hashable
{
    public enum Detail:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        /// Message, reason, suggestion, context, fields and causes, after
        /// redaction.
        case full
        /// The detail only of an error the audience can act on
        /// (`invalid_input`, `requires_access`), without context; any other
        /// error is withheld behind a generic message that keeps its
        /// disposition, so the audience still knows whether to retry.
        ///
        /// Redaction protects text marked sensitive; this also protects
        /// ordinary text that still tells how the system is built
        /// ("Postgres connector is unavailable").
        case actionable
    }

    public let capture: ErrorCapturePolicy
    public let redaction: ErrorRedactionPolicy
    /// How many levels of causes a summary keeps.
    public let maximumDepth: Int
    public let detail: Detail

    private enum CodingKeys:
        String,
        CodingKey
    {
        case capture
        case redaction
        case maximumDepth = "maximum_depth"
        case detail
    }

    public init(
        capture: ErrorCapturePolicy,
        redaction: ErrorRedactionPolicy,
        maximumDepth: Int,
        detail: Detail
    ) {
        self.capture = capture
        self.redaction = redaction
        self.maximumDepth = max(0, maximumDepth)
        self.detail = detail
    }

    /// Anyone, unauthenticated: actionable errors only, nothing potentially
    /// sensitive, no causes.
    public static let `public` = Self(
        capture: .minimal,
        redaction: .public_safe,
        maximumDepth: 0,
        detail: .actionable
    )

    /// Models and the owner's own services: everything but secrets, a few
    /// levels of causes.
    public static let trusted = Self(
        capture: .model,
        redaction: .internal_diagnostic,
        maximumDepth: 4,
        detail: .full
    )

    /// Logs and stored reports: everything but secrets, as deep as captured.
    public static let diagnostic = Self(
        capture: .diagnostic,
        redaction: .internal_diagnostic,
        maximumDepth: 12,
        detail: .full
    )

    /// Whether an error with this disposition shows its own detail.
    public func shows(
        _ disposition: ErrorDisposition?
    ) -> Bool {
        switch detail {
        case .full:
            return true

        case .actionable:
            return disposition == .invalid_input
                || disposition == .requires_access
        }
    }

    /// `report`, captured and redacted for this audience, as it may see it.
    /// The disposition is read from the whole report, so a cause below the
    /// depth cut still decides it.
    public func disclose(
        _ report: ErrorReport
    ) -> ErrorSummary {
        let disposition =
            report.effectiveDisposition
        let summary =
            report.summary(
                maximumDepth: maximumDepth
            )

        guard shows(disposition) else {
            return .withheld(
                disposition: disposition
            )
        }

        switch detail {
        case .full:
            return summary

        case .actionable:
            return ErrorSummary(
                code: summary.code,
                message: summary.message,
                reason: summary.reason,
                reasonOrigin: summary.reasonOrigin,
                suggestion: summary.suggestion,
                disposition: disposition,
                fields: summary.fields,
                causes: summary.causes,
                truncated: summary.truncated
            )
        }
    }
}

public extension ErrorSummary {
    /// What stands in for an error an audience may not see. It has no code:
    /// whoever withholds it may give one of its own.
    static func withheld(
        disposition: ErrorDisposition?
    ) -> Self {
        switch disposition {
        case .transient:
            return .init(
                message: "Temporarily unavailable.",
                suggestion: "Try again later.",
                disposition: .transient
            )

        default:
            return .init(
                message: "An internal error occurred.",
                disposition: disposition
            )
        }
    }
}

public extension Error {
    /// The report as `disclosure` captures and redacts it, for records kept
    /// whole (`.diagnostic`).
    func report(
        for disclosure: ErrorDisclosure
    ) -> ErrorReport {
        report(
            policy: disclosure.capture
        )
        .redacted(
            policy: disclosure.redaction
        )
    }

    /// The summary `disclosure`'s audience may see.
    func summary(
        for disclosure: ErrorDisclosure
    ) -> ErrorSummary {
        disclosure.disclose(
            report(
                for: disclosure
            )
        )
    }

    /// As `summary(for:)`, scrubbing the text the redaction lets through
    /// with `redactor`.
    func summary<Redactor: ErrorTextRedactor>(
        for disclosure: ErrorDisclosure,
        text redactor: inout Redactor
    ) -> ErrorSummary {
        disclosure.disclose(
            report(
                policy: disclosure.capture
            )
            .redacted(
                policy: disclosure.redaction,
                text: &redactor
            )
        )
    }
}
