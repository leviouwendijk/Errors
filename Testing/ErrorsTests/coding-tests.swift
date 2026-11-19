import Errors
import Foundation
import Testing

enum CodingTests {
    static func diagnosticValuesArePlainJSON() throws {
        let value = ErrorDiagnosticValue.object([
            "mailbox": .string("INBOX"),
            "count": .integer(12),
            "ratio": .double(0.5),
            "moved": .boolean(false),
            "uids": .array([.integer(1), .integer(2)]),
            "owner": .redacted,
            "note": .null,
        ])

        let json = try String(
            decoding: encoder().encode(value),
            as: UTF8.self
        )

        try Expect.equal(
            json,
            #"{"count":12,"mailbox":"INBOX","moved":false,"note":null,"owner":{"$redacted":true},"ratio":0.5,"uids":[1,2]}"#,
            "values encode as plain JSON; redacted as the reserved object"
        )
        try Expect.equal(
            try JSONDecoder().decode(
                ErrorDiagnosticValue.self,
                from: Data(json.utf8)
            ),
            value,
            "plain JSON decodes back to the same values"
        )
        try Expect.equal(
            try JSONDecoder().decode(
                ErrorDiagnosticValue.self,
                from: Data(#"{"$redacted":true,"other":1}"#.utf8)
            ),
            .object([
                "$redacted": .boolean(true),
                "other": .integer(1),
            ]),
            "only the exact one-key object is the redaction marker"
        )
    }

    static func reportKeysAreSnakeCase() throws {
        let report = ErrorReport(
            presentation: ErrorPresentation(
                message: "Failed.",
                reason: "NO",
                recoverySuggestion: "Retry.",
                helpAnchor: "help",
                reasonOrigin: .remote
            ),
            diagnostic: ErrorDiagnostic(
                typeName: "Fixture",
                identity: ErrorIdentity(
                    namespace: "fixture.imap",
                    code: "move_failed"
                ),
                disposition: .transient
            ),
            contexts: [
                ErrorContext(
                    message: "while moving",
                    messageSensitivity: .potentially_sensitive
                ),
            ]
        )

        let json = try String(
            decoding: encoder().encode(report),
            as: UTF8.self
        )

        for key in [
            "recovery_suggestion",
            "recovery_options",
            "help_anchor",
            "message_sensitivity",
            "reason_sensitivity",
            "reason_origin",
            "type_name",
        ] {
            try Expect.true(
                json.contains("\"\(key)\""),
                "\(key) is written snake_case: \(json)"
            )
        }

        try Expect.false(
            json.contains("typeName") || json.contains("recoverySuggestion"),
            "no camelCase keys remain: \(json)"
        )
        try Expect.true(
            json.contains(#""identity":"fixture.imap.move_failed""#),
            "the identity is its dotted string: \(json)"
        )
        try Expect.equal(
            try JSONDecoder().decode(
                ErrorReport.self,
                from: Data(json.utf8)
            ),
            report,
            "the snake_case report decodes back"
        )

        let policy = try String(
            decoding: encoder().encode(ErrorCapturePolicy.model),
            as: UTF8.self
        )

        try Expect.true(
            policy.contains("\"maximum_relations_per_error\"")
                && policy.contains("\"user_info\""),
            "capture policy keys are snake_case: \(policy)"
        )

        let redaction = try String(
            decoding: encoder().encode(ErrorRedactionPolicy.public_safe),
            as: UTF8.self
        )

        try Expect.equal(
            redaction,
            #"{"includes_potentially_sensitive":false,"includes_secrets":false}"#,
            "redaction policy keys are snake_case"
        )
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
