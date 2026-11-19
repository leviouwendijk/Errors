import Errors
import Foundation
import Testing

enum InvariantTests {
    static func capturePolicyInvariants() throws {
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
        try Expect.throwsError(
            "negative capture limits are rejected rather than silently clamped"
        ) {
            _ = try ErrorCapturePolicy(
                maximumDepth: -1
            )
        }
        try Expect.throwsError(
            "maximumTotalReports below one is rejected because capture always contains a root report"
        ) {
            _ = try ErrorCapturePolicy(
                maximumTotalReports: 0
            )
        }

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

        try Expect.throwsError(
            "Codable decoding delegates to invariant-preserving construction"
        ) {
            _ = try JSONDecoder().decode(
                ErrorCapturePolicy.self,
                from: malformed
            )
        }
    }

    static func semanticErrorContract() throws {
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
        try Expect.true(
            report.diagnostic.fields.isEmpty,
            "SemanticError defaults diagnostic fields to empty"
        )
        try Expect.true(
            report.relations.isEmpty,
            "SemanticError defaults related errors to empty"
        )
        try Expect.isNil(
            report.diagnostic.domain,
            "a semantic error is identified by identity, not a bridged domain"
        )

        let relation: ErrorRelation.Kind =
            .recovery_attempt
        let restoredRelation = try JSONDecoder().decode(
            ErrorRelation.Kind.self,
            from: JSONEncoder().encode(
                relation
            )
        )

        try Expect.equal(
            restoredRelation,
            relation,
            "ErrorRelation.Kind keeps its single-string Codable representation"
        )
    }
}

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
