import DSL
import Errors
import ErrorsDSL
import Foundation
import TestFlows

enum ErrorsFlowTesting {
    static func runSemanticCapture() async throws -> [TestFlowDiagnostic] {
        let cause = NSError(
            domain: "fixture.underlying",
            code: 7,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Underlying fixture failure",
            ]
        )

        let report =
            SemanticFixtureError(
                underlying: cause
            ).report

        try Expect.equal(
            report.presentation.title,
            "Request failed",
            "semantic capture title"
        )
        try Expect.equal(
            report.presentation.message,
            "The fixture request could not complete.",
            "semantic capture message"
        )
        try Expect.equal(
            report.diagnostic[field: "endpoint"]?.value,
            .string("/fixture"),
            "semantic capture typed field"
        )
        try Expect.equal(
            report.underlying?.diagnostic.domain,
            "fixture.underlying",
            "semantic capture underlying domain"
        )
        try Expect.equal(
            report.underlying?.presentation.message,
            "Underlying fixture failure",
            "semantic capture underlying message"
        )

        return [
            .field(
                "domain",
                report.underlying?.diagnostic.domain
                ?? "<none>"
            ),
            .field(
                "relations",
                String(report.relations.count)
            ),
        ]
    }

    static func runFoundationChain() async throws -> [TestFlowDiagnostic] {
        let security = NSError(
            domain: "NSOSStatusErrorDomain",
            code: -9807,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Certificate verification failed",
            ]
        )

        let cfNetwork = NSError(
            domain: "kCFErrorDomainCFNetwork",
            code: -1200,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "CFNetwork secure connection failed",
                NSUnderlyingErrorKey:
                    security,
                "_kCFStreamErrorDomainKey":
                    3,
                "_kCFStreamErrorCodeKey":
                    -9807,
            ]
        )

        let urlError = NSError(
            domain: NSURLErrorDomain,
            code: -1200,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "A TLS error caused the secure connection to fail.",
                NSUnderlyingErrorKey:
                    cfNetwork,
                "NSErrorFailingURLStringKey":
                    "https://example.invalid/api/chat",
            ]
        )

        let report =
            urlError.report

        try Expect.equal(
            report.diagnostic.domain,
            NSURLErrorDomain,
            "foundation chain root domain"
        )
        try Expect.equal(
            report.diagnostic.code,
            -1200,
            "foundation chain root code"
        )
        try Expect.equal(
            report.underlying?.diagnostic.domain,
            "kCFErrorDomainCFNetwork",
            "foundation chain CFNetwork domain"
        )
        try Expect.equal(
            report.underlying?.underlying?.diagnostic.domain,
            "NSOSStatusErrorDomain",
            "foundation chain Security domain"
        )
        try Expect.equal(
            report.underlying?.underlying?.diagnostic.code,
            -9807,
            "foundation chain Security code"
        )
        try Expect.equal(
            report.underlying?.diagnostic[
                field: "_kCFStreamErrorCodeKey"
            ]?.value,
            .integer(-9807),
            "foundation chain stream error code"
        )
        try Expect.equal(
            report.diagnostic[
                field: "NSErrorFailingURLStringKey"
            ]?.value,
            .string(
                "https://example.invalid/api/chat"
            ),
            "foundation chain failing URL"
        )

        return [
            .field(
                "root",
                "\(report.diagnostic.domain ?? "<none>") \(report.diagnostic.code ?? 0)"
            ),
            .field(
                "deepest",
                "\(report.underlying?.underlying?.diagnostic.domain ?? "<none>") \(report.underlying?.underlying?.diagnostic.code ?? 0)"
            ),
        ]
    }

    static func runAggregateDSL() async throws -> [TestFlowDiagnostic] {
        let aggregate = Errors([
            NSError(
                domain: "fixture.first",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "First fixture failure",
                ]
            ),
            NSError(
                domain: "fixture.second",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Second fixture failure",
                ]
            ),
        ])

        let report =
            aggregate.report

        try Expect.equal(
            report.aggregates.count,
            2,
            "aggregate capture count"
        )

        let content =
            report.structuredContent(
                options: .diagnostic
            )

        try Expect.true(
            contains(
                role: "error.diagnostics",
                in: content
            ),
            "DSL projection diagnostics role"
        )
        try Expect.true(
            contains(
                role: "error.aggregate",
                in: content
            ),
            "DSL projection aggregate role"
        )

        return [
            .field(
                "aggregates",
                String(report.aggregates.count)
            ),
            .field(
                "projection",
                "structured-content"
            ),
        ]
    }

    static func runSemanticUtilities() async throws -> [TestFlowDiagnostic] {
        let underlying = NSError(
            domain: "fixture.deep",
            code: 42,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Deep fixture failure",
            ]
        )

        let error = SemanticFixtureError(
            underlying: underlying
        )

        let report = error.report

        try Expect.equal(
            error.localizedDescription,
            "The fixture request could not complete.",
            "presentation provider bridges LocalizedError"
        )

        try Expect.equal(
            report.diagnostic.identity,
            ErrorIdentity(
                namespace: "fixture.request",
                code: "transportfailed"
            ),
            "semantic identity captured"
        )

        let enriched = report
            .adding.field(
                .host,
                value: "malinois.lan",
                sensitivity: .potentiallySensitive
            )
            .adding.context(
                "Loading model response"
            )
            .adding.context(
                "Streaming transport active"
            )
            .adding.field(
                "authorization",
                value: "Bearer fixture-secret",
                sensitivity: .secret
            )

        try Expect.equal(
            enriched.diagnostic[
                field: .host
            ]?.value,
            .string("malinois.lan"),
            "adding.field typed key"
        )

        try Expect.equal(
            enriched.contexts.map {
                $0.message
            },
            [
                "Loading model response",
                "Streaming transport active",
            ],
            "adding.context accumulates first-class error contexts"
        )

        let publicReport = enriched.redacted(
            policy: .publicsafe
        )

        try Expect.equal(
            publicReport.diagnostic[
                field: .host
            ]?.value,
            .redacted,
            "public redaction removes sensitive field"
        )

        let internalReport = enriched.redacted(
            policy: .internaldiagnostic
        )

        try Expect.equal(
            internalReport.diagnostic[
                field: .host
            ]?.value,
            .string("malinois.lan"),
            "internal diagnostics retain potentially sensitive field"
        )

        try Expect.equal(
            internalReport.diagnostic[
                field: "authorization"
            ]?.value,
            .redacted,
            "internal diagnostics redact secret field"
        )

        try Expect.true(
            report.contains(
                identity: ErrorIdentity(
                    namespace: "fixture.request",
                    code: "transportfailed"
                )
            ),
            "report traversal finds semantic identity"
        )

        try Expect.equal(
            report.deepestunderlying.diagnostic.domain,
            "fixture.deep",
            "deepest underlying traversal"
        )

        let custom: ErrorRelation.Kind =
            "rollback"

        try Expect.equal(
            custom.rawValue,
            "rollback",
            "relation kinds are extensible"
        )

        try Expect.equal(
            ErrorRelation.Kind.recoveryattempt.rawValue,
            "recoveryattempt",
            "recoveryattempt is flatcase"
        )

        try Expect.equal(
            ErrorRelation.Kind.remotecause.rawValue,
            "remotecause",
            "remotecause is flatcase"
        )

        try Expect.equal(
            ErrorRelation.Kind.toolfailure.rawValue,
            "toolfailure",
            "toolfailure is flatcase"
        )

        return [
            .field(
                "identity",
                "\(report.diagnostic.identity?.namespace ?? "<none>").\(report.diagnostic.identity?.code ?? "<none>")"
            ),
            .field(
                "context-count",
                "2"
            ),
            .field(
                "deepest-domain",
                report.deepestunderlying.diagnostic.domain
                ?? "<none>"
            ),
        ]
    }
}

private struct SemanticFixtureError:
    Error,
    PresentableError,
    ErrorIdentityProviding,
    ErrorDiagnosticFieldsProviding,
    ErrorRelationsProviding
{
    let underlying: any Error

    var errorIdentity: ErrorIdentity {
        .init(
            namespace: "fixture.request",
            code: "transportfailed"
        )
    }

    var errorPresentation: ErrorPresentation {
        .init(
            title: "Request failed",
            message:
                "The fixture request could not complete.",
            reason:
                "The transport rejected the fixture request.",
            recoverySuggestion:
                "Inspect the underlying error."
        )
    }

    var errorDiagnosticFields: [ErrorDiagnosticField] {
        [
            .init(
                key: .endpoint,
                value: "/fixture",
                sensitivity: .potentiallySensitive
            ),
            .init(
                key: .attempt,
                value: 2
            ),
        ]
    }

    var errorRelations: [ErrorRelation] {
        [
            .underlying(
                underlying
            ),
        ]
    }
}

private func contains(
    role rawValue: String,
    in content: StructuredContent
) -> Bool {
    switch content {
    case .collection(let content):
        return content.contains {
            contains(
                role: rawValue,
                in: $0
            )
        }

    case .quote(let content):
        return contains(
            role: rawValue,
            in: content
        )

    case .list(_, let items):
        return items.contains {
            contains(
                role: rawValue,
                in: $0
            )
        }

    case .group(
        let role,
        _,
        let content
    ):
        return role?.rawValue == rawValue
            || contains(
                role: rawValue,
                in: content
            )

    case .paragraph,
         .code:
        return false
    }
}
