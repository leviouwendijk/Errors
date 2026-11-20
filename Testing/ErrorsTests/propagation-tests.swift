import Errors
import Foundation
import Testing

/// Relation discovery, dispositions and context wrapping.
enum PropagationTests {
    static func relationsAreDiscovered() throws {
        let cause = PayloadFixtureError.leaf

        let single = PayloadFixtureError.io(cause).report

        try Expect.equal(
            single.underlying?.diagnostic.typeName,
            String(reflecting: PayloadFixtureError.self),
            "a single-value payload is the underlying error"
        )

        let labelled = PayloadFixtureError.failed(
            path: "/tmp/x",
            underlying: cause
        ).report

        try Expect.notNil(
            labelled.underlying,
            "an error inside a multi-value payload is found"
        )

        let holder = HolderFixtureError(
            cause: cause,
            others: [cause, cause]
        ).report

        try Expect.notNil(
            holder.underlying,
            "an optional stored error is the underlying error"
        )
        try Expect.equal(
            holder.aggregates.count,
            2,
            "errors in a stored collection are aggregates"
        )

        let forgetful = ForgetfulSemanticError(
            underlying: cause
        ).report

        try Expect.notNil(
            forgetful.underlying,
            "a semantic error that names no relations still yields its cause"
        )
        try Expect.true(
            PayloadFixtureError.leaf.report.relations.isEmpty,
            "an error holding no errors has no relations"
        )
    }

    static func dispositions() throws {
        try Expect.equal(
            URLError(.timedOut).report.diagnostic.disposition,
            .transient,
            "a URL timeout is transient"
        )
        try Expect.equal(
            POSIXError(.EACCES).report.diagnostic.disposition,
            .requires_access,
            "EACCES requires access"
        )
        try Expect.equal(
            DispositionFixtureError().report.diagnostic.disposition,
            .requires_configuration,
            "a provided disposition is captured"
        )
        try Expect.isNil(
            PayloadFixtureError.leaf.report.diagnostic.disposition,
            "no disposition is invented"
        )

        let wrapped = Errors([
            DispositionFixtureError(),
        ])

        try Expect.equal(
            wrapped.report.effectiveDisposition,
            .requires_configuration,
            "a report's effective disposition comes from its causes too"
        )
        try Expect.equal(
            wrapped.summary().effectiveDisposition,
            .requires_configuration,
            "the effective disposition comes from a cause when the outer error has none"
        )
    }

    static func contextWrapsTransparently() throws {
        let error = NamespacedFixtureError.commandFailed
            .inContext("moving 12 messages")
            .inContext(
                "applying plan for noor@example.com",
                sensitivity: .potentially_sensitive
            )

        try Expect.equal(
            error.localizedDescription,
            "The IMAP fixture failed.",
            "the wrapper keeps the underlying message"
        )
        try Expect.equal(
            error.explanation,
            "The IMAP fixture failed. (while moving 12 messages; while applying plan for noor@example.com)",
            "the explanation is one line with its contexts"
        )
        try Expect.true(
            error.withoutContext is NamespacedFixtureError,
            "withoutContext reaches the original error"
        )

        let report = error.report

        try Expect.equal(
            report.diagnostic.identity?.raw,
            "mail.imap.command_failed",
            "the report is the underlying error's report"
        )
        try Expect.equal(
            report.contexts.map(\.message),
            [
                "moving 12 messages",
                "applying plan for noor@example.com",
            ],
            "contexts are innermost first"
        )
        try Expect.equal(
            report.redacted(policy: .public_safe).contexts.last?.message,
            ErrorRedactionPolicy.placeholder,
            "a sensitive context is redacted like any other"
        )

        do {
            try withErrorContext("loading the index") {
                throw NamespacedFixtureError.connectionDropped
            }
        } catch {
            try Expect.equal(
                error.report.contexts.first?.message,
                "loading the index",
                "withErrorContext annotates what the body throws"
            )
        }
    }
}

enum PayloadFixtureError: Error {
    case leaf
    case io(any Error)
    case failed(path: String, underlying: any Error)
}

struct HolderFixtureError: Error {
    let cause: (any Error)?
    let others: [any Error]
}

struct ForgetfulSemanticError: SemanticError {
    let underlying: any Error

    var errorIdentity: ErrorIdentity {
        .init(namespace: "fixture", code: "forgetful")
    }

    var errorPresentation: ErrorPresentation {
        .init(message: "The forgetful fixture failed.")
    }
}

struct DispositionFixtureError:
    Error,
    ErrorDispositionProviding
{
    var errorDisposition: ErrorDisposition? {
        .requires_configuration
    }
}
