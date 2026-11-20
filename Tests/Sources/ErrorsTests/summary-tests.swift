import Errors
import Foundation
import Testing

enum SummaryTests {
    static func summaryCarriesTheStructure() throws {
        let error = MailMoveFixtureError(
            underlying: URLError(.networkConnectionLost)
        )
        .inContext("applying review plan 3")

        let summary = error.summary()

        try Expect.equal(
            summary.code?.raw,
            "mail.imap.move_failed",
            "the code is the identity"
        )
        try Expect.equal(
            summary.message,
            ErrorRedactionPolicy.placeholder,
            "a sensitive message is withheld by default"
        )
        try Expect.equal(
            summary.reasonOrigin,
            .remote,
            "the reason's origin is kept"
        )
        try Expect.equal(
            summary.suggestion,
            "Write the path with /.",
            "the suggestion is kept"
        )
        try Expect.equal(
            summary.context,
            ["applying review plan 3"],
            "context messages are kept"
        )
        try Expect.equal(
            summary.fields,
            ["uid_count": .integer(12)],
            "withheld fields are left out; ordinary ones stay"
        )
        try Expect.equal(
            summary.causes.first?.relation,
            .underlying,
            "causes keep their relation"
        )
        try Expect.equal(
            summary.effectiveDisposition,
            .transient,
            "a dropped connection under the move makes the whole transient"
        )

        try Expect.equal(
            MailMoveFixtureError(underlying: URLError(.timedOut)).report.presentation.line,
            "UID MOVE to Review/noor@example.com failed. NO [NONEXISTENT] Mailbox does not exist. Write the path with /.",
            "a presentation reads as one line"
        )

        let shallow = error.report.summary(maximumDepth: 0)

        try Expect.true(
            shallow.causes.isEmpty && shallow.truncated,
            "a depth cut drops causes and says so"
        )
    }

    static func summaryEncodesCompactly() throws {
        let plain = ErrorSummary(
            message: "Failed."
        )

        try Expect.equal(
            try String(
                decoding: CodingTests.encoder().encode(plain),
                as: UTF8.self
            ),
            #"{"message":"Failed."}"#,
            "empty and default parts are left out"
        )

        let full = MailMoveFixtureError(
            underlying: URLError(.timedOut)
        )
        .summary(
            redaction: .internal_diagnostic
        )
        let json = try CodingTests.encoder().encode(full)

        try Expect.equal(
            try JSONDecoder().decode(
                ErrorSummary.self,
                from: json
            ),
            full,
            "a summary round-trips"
        )
        try Expect.true(
            String(decoding: json, as: UTF8.self).contains(#""reason_origin":"remote""#),
            "a remote reason is marked"
        )
    }

    static func summaryScrubsWithARedactor() throws {
        var redactor = AddressRedactor()

        let summary = MailMoveFixtureError(
            underlying: URLError(.timedOut)
        )
        .summary(
            redaction: .internal_diagnostic,
            text: &redactor
        )

        try Expect.equal(
            summary.message,
            "UID MOVE to Review/Contact A failed.",
            "allowed text is scrubbed"
        )
        try Expect.equal(
            summary.fields["mailbox"],
            .string("Review/Contact A"),
            "allowed field strings are scrubbed"
        )
    }
}

private struct MailMoveFixtureError: SemanticError {
    let underlying: any Error

    var errorIdentity: ErrorIdentity {
        .init(namespace: "mail.imap", code: "move_failed")
    }

    var errorPresentation: ErrorPresentation {
        .init(
            message: "UID MOVE to Review/noor@example.com failed.",
            reason: "NO [NONEXISTENT] Mailbox does not exist.",
            recoverySuggestion: "Write the path with /.",
            messageSensitivity: .potentially_sensitive,
            reasonOrigin: .remote
        )
    }

    var errorDiagnosticFields: [ErrorDiagnosticField] {
        [
            .init(
                key: "mailbox",
                value: "Review/noor@example.com",
                sensitivity: .potentially_sensitive
            ),
            .init(
                key: "uid_count",
                value: 12
            ),
        ]
    }

    var errorRelations: [ErrorRelation] {
        [.underlying(underlying)]
    }
}

private struct AddressRedactor: ErrorTextRedactor {
    mutating func redact(
        _ text: String
    ) -> String {
        text.replacingOccurrences(
            of: "noor@example.com",
            with: "Contact A"
        )
    }
}
