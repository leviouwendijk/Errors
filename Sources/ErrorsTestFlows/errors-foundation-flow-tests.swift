import Errors
import Foundation
import Primitives
import TestFlows

private func makeErrorsFoundationLeafReport()
    -> ErrorReport
{
    ErrorReport(
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
}

private func makeErrorsFoundationReport()
    -> ErrorReport
{
    ErrorReport(
        presentation: ErrorPresentation(
            title: "Fixture failure",
            message: "The fixture operation could not complete.",
            reason: "A nested operation failed.",
            recoverySuggestion: "Inspect diagnostics.",
            recoveryOptions: [
                "Retry",
                "Abort",
            ],
            helpAnchor: "fixture-errors"
        ),
        diagnostic: ErrorDiagnostic(
            typeName: "FixtureError",
            identity: ErrorIdentity(
                namespace: "fixture",
                code: "operation_failed"
            ),
            domain: "fixture",
            code: 42,
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
                    sensitivity: .potentiallySensitive
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
                report: makeErrorsFoundationLeafReport()
            ),
        ],
        truncations: [
            ErrorCaptureTruncation(
                reason: .maximumstringlength,
                limit: 1024
            ),
        ]
    )
}

let errorsFoundationFlows: [TestFlow] = [
    TestFlow(
        "errors-string-identifiers",
        tags: [
            "errors",
            "primitives",
            "identifiers",
            "codable",
        ]
    ) {
        let key: ErrorDiagnosticKey = .endpoint
        let truncation: ErrorCaptureTruncation.Reason =
            .maximumdiagnosticvaluedepth
        let relation: ErrorRelation.Kind =
            .recoveryattempt

        try Expect.equal(
            key.rawValue,
            "endpoint",
            "diagnostic keys preserve their established raw value"
        )
        try Expect.equal(
            truncation.rawValue,
            "maximumdiagnosticvaluedepth",
            "capture truncation reasons preserve their established raw value"
        )
        try Expect.equal(
            relation.rawValue,
            "recoveryattempt",
            "relation kinds preserve their established raw value"
        )

        let encodedKey = try JSONEncoder().encode(
            key
        )
        let decodedKey = try JSONDecoder().decode(
            ErrorDiagnosticKey.self,
            from: encodedKey
        )

        try Expect.equal(
            decodedKey,
            key,
            "StringIdentifier adoption preserves single-value Codable round trips"
        )

        let integerField = ErrorDiagnosticField(
            key: .attempt,
            value: 3
        )
        let doubleField = ErrorDiagnosticField(
            key: .response,
            value: 1.5
        )
        let boolField = ErrorDiagnosticField(
            key: .request,
            value: true
        )

        try Expect.equal(
            integerField.value,
            .integer(3),
            "integer diagnostic convenience initializer is public and typed"
        )
        try Expect.equal(
            doubleField.value,
            .double(1.5),
            "double diagnostic convenience initializer is public and typed"
        )
        try Expect.equal(
            boolField.value,
            .boolean(true),
            "boolean diagnostic convenience initializer is public and typed"
        )

        return [
            .field(
                "diagnostic_key",
                key.rawValue
            ),
            .field(
                "truncation_reason",
                truncation.rawValue
            ),
            .field(
                "relation_kind",
                relation.rawValue
            ),
        ]
    },
    TestFlow(
        "error-diagnostic-value-json-roundtrip",
        tags: [
            "errors",
            "primitives",
            "json",
            "redaction",
        ]
    ) {
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

        let json = try value.jsonvalue()
        let restored = try ErrorDiagnosticValue(
            jsonvalue: json
        )

        try Expect.equal(
            restored,
            value,
            "diagnostic values round-trip losslessly through Primitives.JSONValue"
        )

        guard case .object(let fields) = restored,
              case .array(let nested)? = fields["nested"]
        else {
            throw NSError(
                domain: "ErrorsTestFlows",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "restored diagnostic value lost its object/array structure",
                ]
            )
        }

        try Expect.equal(
            nested[1],
            .redacted,
            "redaction survives JSONValue materialization without becoming an ordinary scalar"
        )

        return [
            .field(
                "roundtrip",
                "true"
            ),
            .field(
                "redacted_preserved",
                "true"
            ),
        ]
    },
    TestFlow(
        "error-report-json-roundtrip",
        tags: [
            "errors",
            "report",
            "primitives",
            "json",
            "relations",
        ]
    ) {
        let report = makeErrorsFoundationReport()
        let json = try report.jsonvalue()
        let restored = try ErrorReport(
            jsonvalue: json
        )

        try Expect.equal(
            restored,
            report,
            "complete recursive ErrorReport round-trips through Primitives.JSONValue"
        )
        try Expect.equal(
            restored.relations.count,
            1,
            "related reports survive machine serialization"
        )
        try Expect.equal(
            restored.relations.first?.kind,
            .underlying,
            "relation semantics survive machine serialization"
        )
        try Expect.equal(
            restored.contexts.count,
            1,
            "error contexts survive machine serialization"
        )
        try Expect.equal(
            restored.truncations.first?.reason,
            .maximumstringlength,
            "capture truncation evidence survives machine serialization"
        )
        try Expect.equal(
            restored.diagnostic.identity,
            ErrorIdentity(
                namespace: "fixture",
                code: "operation_failed"
            ),
            "stable error identity survives machine serialization"
        )

        return [
            .field(
                "relations",
                String(restored.relations.count)
            ),
            .field(
                "contexts",
                String(restored.contexts.count)
            ),
            .field(
                "truncations",
                String(restored.truncations.count)
            ),
            .field(
                "identity",
                restored.diagnostic.identity?.code
                    ?? "none"
            ),
        ]
    },
]
