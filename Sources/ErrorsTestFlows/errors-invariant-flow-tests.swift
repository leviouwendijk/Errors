import Errors
import Foundation
import TestFlows

private struct SemanticContractFixtureError:
    SemanticError
{
    let errorPresentation = ErrorPresentation(
        title: "Semantic fixture",
        message: "The semantic fixture failed.",
        reason: "The fixture requested a structured report.",
        recoverySuggestion: "Inspect the captured report."
    )

    let errorIdentity = ErrorIdentity(
        namespace: "errors.fixture",
        code: "semantic_contract"
    )
}

let errorsInvariantFlows: [TestFlow] = [
    TestFlow(
        "error-capture-policy-invariants",
        tags: [
            "errors",
            "capture-policy",
            "invariants",
            "codable",
        ]
    ) {
        let zeroBounded = try ErrorCapturePolicy(
            maximumDepth: 0,
            maximumRelationsPerError: 0,
            maximumFieldsPerError: 0,
            userInfo: .none,
            maximumDiagnosticValueDepth: 0,
            maximumStringLength: 0,
            maximumCollectionCount: 0,
            maximumTotalReports: 1,
            maximumTotalFields: 0
        )

        try Expect.equal(
            zeroBounded.maximumDepth,
            0,
            "valid zero-valued limits are preserved exactly"
        )
        try Expect.equal(
            zeroBounded.maximumTotalReports,
            1,
            "capture policy preserves the minimum legal total report count"
        )

        var rejectedNegativeDepth = false

        do {
            _ = try ErrorCapturePolicy(
                maximumDepth: -1
            )
        } catch {
            rejectedNegativeDepth = true
        }

        try Expect.equal(
            rejectedNegativeDepth,
            true,
            "negative capture limits are rejected rather than silently clamped"
        )

        var rejectedZeroReports = false

        do {
            _ = try ErrorCapturePolicy(
                maximumTotalReports: 0
            )
        } catch {
            rejectedZeroReports = true
        }

        try Expect.equal(
            rejectedZeroReports,
            true,
            "maximumTotalReports below one is rejected because capture always contains a root report"
        )

        let configured = try ErrorCapturePolicy(
            maximumDepth: 3,
            maximumRelationsPerError: 5,
            maximumFieldsPerError: 7,
            userInfo: .standard,
            maximumDiagnosticValueDepth: 2,
            maximumStringLength: 512,
            maximumCollectionCount: 16,
            maximumTotalReports: 9,
            maximumTotalFields: 21
        )
        let roundTrip = try JSONDecoder().decode(
            ErrorCapturePolicy.self,
            from: JSONEncoder().encode(
                configured
            )
        )

        try Expect.equal(
            roundTrip,
            configured,
            "valid capture policies round-trip through Codable without normalization"
        )

        let malformed = Data(
            """
            {
              "maximumDepth": -1,
              "maximumRelationsPerError": 1,
              "maximumFieldsPerError": 1,
              "userInfo": "none",
              "maximumDiagnosticValueDepth": 1,
              "maximumStringLength": 1,
              "maximumCollectionCount": 1,
              "maximumTotalReports": 1,
              "maximumTotalFields": 1
            }
            """.utf8
        )
        var decoderRejectedMalformedPolicy = false

        do {
            _ = try JSONDecoder().decode(
                ErrorCapturePolicy.self,
                from: malformed
            )
        } catch {
            decoderRejectedMalformedPolicy = true
        }

        try Expect.equal(
            decoderRejectedMalformedPolicy,
            true,
            "Codable decoding delegates to invariant-preserving construction"
        )

        return [
            .field(
                "zero_depth",
                String(zeroBounded.maximumDepth)
            ),
            .field(
                "minimum_reports",
                String(zeroBounded.maximumTotalReports)
            ),
            .field(
                "negative_rejected",
                String(rejectedNegativeDepth)
            ),
            .field(
                "decoder_rejected_invalid",
                String(decoderRejectedMalformedPolicy)
            ),
        ]
    },
    TestFlow(
        "semantic-error-contract",
        tags: [
            "errors",
            "semantic-error",
            "report",
            "identity",
        ]
    ) {
        let error = SemanticContractFixtureError()
        let report = error.report

        try Expect.equal(
            report.presentation,
            error.errorPresentation,
            "SemanticError presentation participates in normal ErrorReport capture"
        )
        try Expect.equal(
            report.diagnostic.identity,
            error.errorIdentity,
            "SemanticError identity participates in normal ErrorReport capture"
        )
        try Expect.equal(
            report.diagnostic.fields.isEmpty,
            true,
            "SemanticError defaults diagnostic fields to empty"
        )
        try Expect.equal(
            report.relations.isEmpty,
            true,
            "SemanticError defaults related errors to empty"
        )

        let relation: ErrorRelation.Kind =
            .recoveryattempt
        let restoredRelation = try JSONDecoder().decode(
            ErrorRelation.Kind.self,
            from: JSONEncoder().encode(
                relation
            )
        )

        try Expect.equal(
            restoredRelation,
            relation,
            "ErrorRelation.Kind keeps its established single-string Codable representation through StringIdentifier"
        )

        return [
            .field(
                "identity_namespace",
                report.diagnostic.identity?.namespace
                    ?? "none"
            ),
            .field(
                "identity_code",
                report.diagnostic.identity?.code
                    ?? "none"
            ),
            .field(
                "relation_kind",
                restoredRelation.rawValue
            ),
        ]
    },
]
