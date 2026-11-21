import Errors
import Foundation
import Testing

enum DisclosureTests {
    static func publicSeesWhatItCanFix() throws {
        let error = PostcodeFixtureError()
            .inContext("saving the lead")

        let summary = error.summary(for: .public)

        try Expect.equal(
            summary.code?.raw,
            "invariance.postcode_format",
            "an actionable error keeps its code"
        )
        try Expect.equal(
            summary.message,
            "The postcode is not valid.",
            "an actionable error keeps its message"
        )
        try Expect.equal(
            summary.suggestion,
            "Write it as 1234 AB.",
            "an actionable error keeps its suggestion"
        )
        try Expect.equal(
            summary.fields,
            ["field": .string("postcode")],
            "ordinary fields stay; sensitive ones are left out"
        )
        try Expect.true(
            summary.context.isEmpty,
            "what the server was doing is not the caller's to know"
        )
        try Expect.equal(
            summary.disposition,
            .invalid_input,
            "the disposition is kept"
        )
    }

    static func publicDoesNotSeeInternals() throws {
        let error = ConnectorFixtureError(
            underlying: URLError(.cannotConnectToHost)
        )

        let withheld = error.summary(for: .public)

        try Expect.equal(
            withheld,
            .withheld(disposition: .transient),
            "ordinary text about internals is withheld, the retry hint kept"
        )
        try Expect.true(
            withheld.code == nil && withheld.causes.isEmpty,
            "neither the code nor the causes leave"
        )
        try Expect.equal(
            withheld.suggestion,
            "Try again later.",
            "a transient error says to retry"
        )

        let permanent = ConfigurationFixtureError()
            .summary(for: .public)

        try Expect.equal(
            permanent.message,
            "An internal error occurred.",
            "anything else is a generic message"
        )
        try Expect.equal(
            permanent.disposition,
            .requires_configuration,
            "and still says what kind of failure it is"
        )

        let trusted = error.summary(for: .trusted)

        try Expect.equal(
            trusted.message,
            "Postgres connector is unavailable.",
            "a trusted caller sees the error itself"
        )
        try Expect.equal(
            trusted.causes.first?.relation,
            .underlying,
            "with its causes"
        )
    }

    static func presetsAndCoding() throws {
        try Expect.equal(
            ErrorDisclosure.public.maximumDepth,
            0,
            "the public sees no causes"
        )
        try Expect.true(
            ErrorDisclosure.trusted.shows(.permanent)
                && !ErrorDisclosure.public.shows(.permanent)
                && ErrorDisclosure.public.shows(.requires_access)
                && !ErrorDisclosure.public.shows(nil),
            "only full detail shows what the caller cannot act on"
        )

        let report = ConfigurationFixtureError()
            .report(for: .diagnostic)

        try Expect.equal(
            report.presentation.reason,
            "DATABASE_URL is not set on dataman.",
            "a diagnostic report keeps the reason"
        )

        let json = try CodingTests.encoder()
            .encode(ErrorDisclosure.trusted)

        try Expect.true(
            String(decoding: json, as: UTF8.self)
                .contains(#""maximum_depth":4"#),
            "keys are snake_case"
        )
        try Expect.equal(
            try JSONDecoder().decode(
                ErrorDisclosure.self,
                from: json
            ),
            .trusted,
            "a disclosure round-trips"
        )
    }
}

private struct PostcodeFixtureError: SemanticError, ErrorDispositionProviding {
    var errorIdentity: ErrorIdentity {
        .init(namespace: "invariance", code: "postcode_format")
    }

    var errorPresentation: ErrorPresentation {
        .init(
            message: "The postcode is not valid.",
            recoverySuggestion: "Write it as 1234 AB."
        )
    }

    var errorDiagnosticFields: [ErrorDiagnosticField] {
        [
            .init(key: "field", value: "postcode"),
            .init(
                key: "value",
                value: "12345",
                sensitivity: .potentially_sensitive
            ),
        ]
    }

    var errorRelations: [ErrorRelation] {
        []
    }

    var errorDisposition: ErrorDisposition? {
        .invalid_input
    }
}

private struct ConnectorFixtureError: SemanticError {
    let underlying: any Error

    var errorIdentity: ErrorIdentity {
        .init(namespace: "dataman", code: "connector_unavailable")
    }

    var errorPresentation: ErrorPresentation {
        .init(message: "Postgres connector is unavailable.")
    }

    var errorDiagnosticFields: [ErrorDiagnosticField] {
        []
    }

    var errorRelations: [ErrorRelation] {
        [.underlying(underlying)]
    }
}

private struct ConfigurationFixtureError: SemanticError, ErrorDispositionProviding {
    var errorIdentity: ErrorIdentity {
        .init(namespace: "dataman", code: "unconfigured")
    }

    var errorPresentation: ErrorPresentation {
        .init(
            message: "The database is not configured.",
            reason: "DATABASE_URL is not set on dataman."
        )
    }

    var errorDiagnosticFields: [ErrorDiagnosticField] {
        []
    }

    var errorRelations: [ErrorRelation] {
        []
    }

    var errorDisposition: ErrorDisposition? {
        .requires_configuration
    }
}
