import DSL
import Errors
import ErrorsDSL
import Foundation
import Testing

enum CaptureTests {
    static func semanticCapture() throws {
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
    }

    static func foundationChain() throws {
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
    }

    static func swiftErrorsHaveNoFoundationDomain() throws {
        let plain =
            PlainFixtureError.second.report

        try Expect.isNil(
            plain.diagnostic.domain,
            "a Swift enum has no Foundation domain"
        )
        try Expect.isNil(
            plain.diagnostic.code,
            "a Swift enum's case position is not recorded as a code"
        )
        try Expect.true(
            plain.diagnostic.fields.isEmpty,
            "a Swift error's bridged userInfo is not captured: \(plain.diagnostic.fields.map(\.name))"
        )
        try Expect.equal(
            plain.presentation.message,
            "The second fixture failed.",
            "LocalizedError text is still the message"
        )

        let described = PayloadFixtureError.failed(
            path: "/tmp/x",
            underlying: PayloadFixtureError.leaf
        ).report

        try Expect.true(
            described.presentation.message.hasPrefix("failed(path: \"/tmp/x\""),
            "a plain Swift error without text is described by its case: \(described.presentation.message)"
        )
        try Expect.equal(
            described.presentation.messageSensitivity,
            .potentially_sensitive,
            "a described case is marked, since its payload may hold anything"
        )

        let custom =
            CustomDomainFixtureError().report

        try Expect.equal(
            custom.diagnostic.domain,
            "fixture.custom",
            "CustomNSError keeps its declared domain"
        )
        try Expect.equal(
            custom.diagnostic.code,
            12,
            "CustomNSError keeps its declared code"
        )
    }

    static func aggregateIsSemantic() throws {
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
        try Expect.equal(
            report.diagnostic.identity,
            ErrorIdentity(
                namespace: "errors",
                code: "aggregate"
            ),
            "the aggregate has an identity"
        )
        try Expect.equal(
            aggregate.localizedDescription,
            "2 errors occurred.",
            "the aggregate's message counts its failures"
        )

        let content =
            report.structuredContent(
                options: .diagnostic
            )

        try Expect.true(
            StructuredContentProbe.contains(
                role: "error.diagnostics",
                in: content
            ),
            "DSL projection diagnostics role"
        )
        try Expect.true(
            StructuredContentProbe.contains(
                role: "error.aggregate",
                in: content
            ),
            "DSL projection aggregate role"
        )
    }

    static func semanticUtilities() throws {
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
                code: "transport_failed"
            ),
            "semantic identity captured"
        )

        let enriched = report
            .adding.field(
                .host,
                value: "malinois.lan",
                sensitivity: .potentially_sensitive
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
            policy: .public_safe
        )

        try Expect.equal(
            publicReport.diagnostic[
                field: .host
            ]?.value,
            .redacted,
            "public redaction removes sensitive field"
        )

        let internalReport = enriched.redacted(
            policy: .internal_diagnostic
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
                    code: "transport_failed"
                )
            ),
            "report traversal finds semantic identity"
        )
        try Expect.equal(
            report.deepest_underlying.diagnostic.domain,
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
    }
}

private enum PlainFixtureError:
    Error,
    LocalizedError
{
    case first
    case second

    var errorDescription: String? {
        switch self {
        case .first:
            return "The first fixture failed."

        case .second:
            return "The second fixture failed."
        }
    }
}

private struct CustomDomainFixtureError:
    CustomNSError
{
    static var errorDomain: String {
        "fixture.custom"
    }

    var errorCode: Int {
        12
    }
}

struct SemanticFixtureError:
    SemanticError
{
    let underlying: any Error

    var errorIdentity: ErrorIdentity {
        .init(
            namespace: "fixture.request",
            code: "transport_failed"
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
                sensitivity: .potentially_sensitive
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

enum StructuredContentProbe {
    static func contains(
        role rawValue: String,
        in content: StructuredContent
    ) -> Bool {
        first(in: content) {
            if case .group(let role, _, _) = $0 {
                return role?.rawValue == rawValue
            }
            return false
        } != nil
    }

    static func first(
        in content: StructuredContent,
        where predicate: (StructuredContent) -> Bool
    ) -> StructuredContent? {
        if predicate(content) {
            return content
        }

        switch content {
        case .collection(let content):
            for child in content {
                if let match = first(in: child, where: predicate) {
                    return match
                }
            }
            return nil

        case .quote(let content):
            return first(in: content, where: predicate)

        case .list(_, let items):
            for item in items {
                if let match = first(in: item, where: predicate) {
                    return match
                }
            }
            return nil

        case .group(_, _, let content):
            return first(in: content, where: predicate)

        case .table(let header, let rows):
            for cell in header + rows.flatMap({ $0 }) {
                if let match = first(in: cell, where: predicate) {
                    return match
                }
            }
            return nil

        case .paragraph,
             .code:
            return nil
        }
    }
}
