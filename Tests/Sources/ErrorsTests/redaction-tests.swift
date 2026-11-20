import DSL
import Errors
import ErrorsDSL
import Foundation
import Testing

enum RedactionTests {
    static func presentationSensitivity() throws {
        let report = MoveFixtureError().report

        let publicReport = report.redacted(
            policy: .public_safe
        )

        try Expect.equal(
            publicReport.presentation.message,
            ErrorRedactionPolicy.placeholder,
            "a potentially sensitive message is withheld from public output"
        )
        try Expect.equal(
            publicReport.presentation.reason,
            ErrorRedactionPolicy.placeholder,
            "a potentially sensitive reason is withheld from public output"
        )
        try Expect.equal(
            publicReport.presentation.recoverySuggestion,
            "Write the path with /; it is put in the server's form.",
            "authored suggestions stay"
        )
        try Expect.equal(
            publicReport.presentation.reasonOrigin,
            .remote,
            "redaction keeps the reason's origin"
        )

        let internalReport = report.redacted(
            policy: .internal_diagnostic
        )

        try Expect.equal(
            internalReport.presentation.message,
            "UID MOVE to Review/noor@example.com failed.",
            "internal diagnostics keep potentially sensitive text"
        )
    }

    static func textRedactorScrubsWhatPasses() throws {
        var redactor = FixtureTextRedactor()

        let report = MoveFixtureError()
            .report
            .adding.context(
                "while applying the plan for noor@example.com"
            )
            .redacted(
                policy: .internal_diagnostic,
                text: &redactor
            )

        try Expect.equal(
            report.presentation.message,
            "UID MOVE to Review/Contact A failed.",
            "allowed message text is scrubbed"
        )
        try Expect.equal(
            report.presentation.reason,
            "NO [NONEXISTENT] Contact A is not a mailbox.",
            "allowed reason text is scrubbed"
        )
        try Expect.equal(
            report.contexts.first?.message,
            "while applying the plan for Contact A",
            "context messages are scrubbed"
        )
        try Expect.equal(
            report.diagnostic[field: "mailbox"]?.value,
            .object([
                "path": .string("Review/Contact A"),
                "depth": .integer(2),
            ]),
            "strings nested in field values are scrubbed"
        )
        try Expect.equal(
            report.diagnostic[field: "password"]?.value,
            .redacted,
            "secrets stay redacted, not scrubbed"
        )
        try Expect.true(
            redactor.calls > 0,
            "the redactor keeps state across texts"
        )

        var unused = FixtureTextRedactor()
        let withheld = MoveFixtureError()
            .report
            .redacted(
                policy: .public_safe,
                text: &unused
            )

        try Expect.equal(
            withheld.presentation.message,
            ErrorRedactionPolicy.placeholder,
            "withheld text stays withheld when a redactor is given"
        )
    }

    static func dslRendersRedactedAndQuotesRemote() throws {
        let report = MoveFixtureError().report

        let summary = report.structuredContent(
            options: .summary
        )

        try Expect.isNil(
            StructuredContentProbe.first(in: summary) {
                if case .paragraph(let inlines) = $0 {
                    return inlines.contains(.text("UID MOVE to Review/noor@example.com failed."))
                }
                return false
            },
            "public rendering does not show the sensitive message"
        )

        let diagnostic = report.structuredContent(
            options: .diagnostic
        )
        let reason = try Expect.notNil(
            StructuredContentProbe.first(in: diagnostic) {
                if case .group(let role, _, _) = $0 {
                    return role == .errorReason
                }
                return false
            },
            "the reason is rendered"
        )

        guard case .group(_, _, let content) = reason else {
            try Expect.true(false, "the reason is a group")
            return
        }

        guard case .quote = content else {
            try Expect.true(false, "a remote reason is rendered as a quote: \(content)")
            return
        }
    }
}

private struct MoveFixtureError:
    SemanticError
{
    var errorIdentity: ErrorIdentity {
        .init(
            namespace: "fixture.imap",
            code: "move_failed"
        )
    }

    var errorPresentation: ErrorPresentation {
        .init(
            message: "UID MOVE to Review/noor@example.com failed.",
            reason: "NO [NONEXISTENT] noor@example.com is not a mailbox.",
            recoverySuggestion: "Write the path with /; it is put in the server's form.",
            messageSensitivity: .potentially_sensitive,
            reasonSensitivity: .potentially_sensitive,
            reasonOrigin: .remote
        )
    }

    var errorDiagnosticFields: [ErrorDiagnosticField] {
        [
            .init(
                key: "mailbox",
                value: .object([
                    "path": .string("Review/noor@example.com"),
                    "depth": .integer(2),
                ]),
                sensitivity: .potentially_sensitive
            ),
            .init(
                key: "password",
                value: "hunter2",
                sensitivity: .secret
            ),
        ]
    }
}

/// Stands in for a detector: one known address becomes one pseudonym.
private struct FixtureTextRedactor: ErrorTextRedactor {
    var calls = 0

    mutating func redact(
        _ text: String
    ) -> String {
        calls += 1

        return text.replacingOccurrences(
            of: "noor@example.com",
            with: "Contact A"
        )
    }
}
