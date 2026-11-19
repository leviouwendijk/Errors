import Errors
import Foundation
import Primitives
import Testing

enum FoundationTests {
    static func stringIdentifiersAreSnakeCase() throws {
        try Expect.equal(
            ErrorCaptureTruncation.Reason.maximum_diagnostic_value_depth.rawValue,
            "maximum_diagnostic_value_depth",
            "truncation reasons are snake_case"
        )
        try Expect.equal(
            ErrorRelation.Kind.recovery_attempt.rawValue,
            "recovery_attempt",
            "relation kinds are snake_case"
        )
        try Expect.equal(
            ErrorRelation.Kind.remote_cause.rawValue,
            "remote_cause",
            "relation kinds are snake_case"
        )
        try Expect.equal(
            ErrorRelation.Kind.tool_failure.rawValue,
            "tool_failure",
            "relation kinds are snake_case"
        )
        try Expect.equal(
            ErrorSensitivity.potentially_sensitive.rawValue,
            "potentially_sensitive",
            "sensitivities are snake_case"
        )

        let decoding = DecodingError.keyNotFound(
            FixtureKey(stringValue: "mailboxName"),
            .init(
                codingPath: [FixtureKey(stringValue: "plan")],
                debugDescription: "missing"
            )
        ).report

        try Expect.equal(
            decoding.diagnostic[field: "decoding.kind"]?.value,
            .string("key_not_found"),
            "decoding kinds are snake_case"
        )
        try Expect.notNil(
            decoding.diagnostic[field: "decoding.coding_path"],
            "decoding field keys are snake_case"
        )

        let key: ErrorDiagnosticKey = .endpoint
        let decodedKey = try JSONDecoder().decode(
            ErrorDiagnosticKey.self,
            from: JSONEncoder().encode(key)
        )

        try Expect.equal(
            decodedKey,
            key,
            "StringIdentifier adoption preserves single-value Codable round trips"
        )
        try Expect.equal(
            ErrorDiagnosticField(key: .attempt, value: 3).value,
            .integer(3),
            "integer diagnostic convenience initializer"
        )
        try Expect.equal(
            ErrorDiagnosticField(key: .response, value: 1.5).value,
            .double(1.5),
            "double diagnostic convenience initializer"
        )
        try Expect.equal(
            ErrorDiagnosticField(key: .request, value: true).value,
            .boolean(true),
            "boolean diagnostic convenience initializer"
        )
    }

    static func diagnosticValueJSONRoundTrip() throws {
        let value = ErrorDiagnosticValue.object([
            "message": .string("fixture"),
            "attempt": .integer(2),
            "ratio": .double(0.5),
            "retryable": .boolean(true),
            "nested": .array([
                .string("visible"),
                .redacted,
                .null,
            ]),
        ])

        let restored = try ErrorDiagnosticValue(
            jsonvalue: value.jsonvalue()
        )

        try Expect.equal(
            restored,
            value,
            "diagnostic values round-trip losslessly through Primitives.JSONValue"
        )

        guard case .object(let fields) = restored,
              case .array(let nested)? = fields["nested"]
        else {
            try Expect.true(false, "restored diagnostic value keeps its object and array structure")
            return
        }

        try Expect.equal(
            nested[1],
            .redacted,
            "redaction survives JSONValue materialization without becoming an ordinary scalar"
        )
    }

    static func reportJSONRoundTrip() throws {
        let report = makeReport()
        let restored = try ErrorReport(
            jsonvalue: report.jsonvalue()
        )

        try Expect.equal(
            restored,
            report,
            "complete recursive ErrorReport round-trips through Primitives.JSONValue"
        )
        try Expect.equal(
            restored.relations.first?.kind,
            .underlying,
            "relation semantics survive machine serialization"
        )
        try Expect.equal(
            restored.presentation.reasonOrigin,
            .remote,
            "the reason's origin survives machine serialization"
        )
        try Expect.equal(
            restored.truncations.first?.reason,
            .maximum_string_length,
            "capture truncation evidence survives machine serialization"
        )
    }

    private static func makeReport() -> ErrorReport {
        let leaf = ErrorReport(
            presentation: ErrorPresentation(
                title: "Underlying failure",
                message: "The remote operation failed.",
                reason: "The connection ended unexpectedly.",
                recoverySuggestion: "Retry the operation.",
                recoveryOptions: [
                    "Retry",
                ]
            ),
            diagnostic: ErrorDiagnostic(
                typeName: "FixtureUnderlyingError",
                identity: ErrorIdentity(
                    namespace: "fixture",
                    code: "transport"
                ),
                domain: "fixture.transport",
                code: 503,
                fields: [
                    ErrorDiagnosticField(
                        key: .endpoint,
                        value: "https://example.invalid"
                    ),
                ]
            )
        )

        return ErrorReport(
            presentation: ErrorPresentation(
                title: "Fixture failure",
                message: "The fixture operation could not complete.",
                reason: "NO [NONEXISTENT] Unknown namespace.",
                recoverySuggestion: "Inspect diagnostics.",
                recoveryOptions: [
                    "Retry",
                    "Abort",
                ],
                helpAnchor: "fixture-errors",
                reasonSensitivity: .potentially_sensitive,
                reasonOrigin: .remote
            ),
            diagnostic: ErrorDiagnostic(
                typeName: "FixtureError",
                identity: ErrorIdentity(
                    namespace: "fixture",
                    code: "operation_failed"
                ),
                fields: [
                    ErrorDiagnosticField(
                        key: .attempt,
                        value: 2
                    ),
                    ErrorDiagnosticField(
                        key: .request,
                        value: .object([
                            "operation": .string("fixture"),
                            "flags": .array([
                                .boolean(true),
                                .redacted,
                                .null,
                            ]),
                        ]),
                        sensitivity: .potentially_sensitive
                    ),
                ]
            ),
            contexts: [
                ErrorContext(
                    message: "while exercising Errors JSON interoperability",
                    fields: [
                        ErrorDiagnosticField(
                            key: .host,
                            value: "fixture-host"
                        ),
                    ]
                ),
            ],
            relations: [
                ErrorReport.Relation(
                    kind: .underlying,
                    report: leaf
                ),
            ],
            truncations: [
                ErrorCaptureTruncation(
                    reason: .maximum_string_length,
                    limit: 1024
                ),
            ]
        )
    }
}

private struct FixtureKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }
}
