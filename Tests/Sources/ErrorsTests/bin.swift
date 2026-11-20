import Testing

private enum ErrorsTestError: Error {
    case failed
}

@main
struct ErrorsTestMain {
    static func main() async throws {
        let reporter = PlainTextTestReporter()
        let result = await TestRunner.run(
            ErrorsTestSuite.testSuite,
            sink: reporter
        )
        let rendered = await reporter.rendered()

        if !rendered.isEmpty {
            print(rendered)
        }

        if result.isFailure {
            throw ErrorsTestError.failed
        }
    }
}

enum ErrorsTestSuite {
    static let testSuite = TestSuite(
        "errors",
        title: "Errors: capture, identity, redaction, rendering"
    ) {
        Test("semantic-capture", tags: ["capture", "semantic"]) {
            try CaptureTests.semanticCapture()
        }

        Test("foundation-chain", tags: ["capture", "foundation", "relations"]) {
            try CaptureTests.foundationChain()
        }

        Test("swift-errors-have-no-foundation-domain", tags: ["capture", "foundation"]) {
            try CaptureTests.swiftErrorsHaveNoFoundationDomain()
        }

        Test("aggregate-is-semantic", tags: ["capture", "aggregate", "dsl"]) {
            try CaptureTests.aggregateIsSemantic()
        }

        Test("semantic-utilities", tags: ["identity", "redaction", "adding", "relations"]) {
            try CaptureTests.semanticUtilities()
        }

        Test("string-identifiers-are-snake-case", tags: ["identifiers", "codable"]) {
            try FoundationTests.stringIdentifiersAreSnakeCase()
        }

        Test("diagnostic-value-json-roundtrip", tags: ["json", "redaction"]) {
            try FoundationTests.diagnosticValueJSONRoundTrip()
        }

        Test("report-json-roundtrip", tags: ["json", "relations"]) {
            try FoundationTests.reportJSONRoundTrip()
        }

        Test("capture-policy-invariants", tags: ["capture-policy", "invariant", "codable"]) {
            try InvariantTests.capturePolicyInvariants()
        }

        Test("semantic-error-contract", tags: ["semantic", "identity"]) {
            try InvariantTests.semanticErrorContract()
        }

        Test("presentation-sensitivity", tags: ["redaction", "presentation"]) {
            try RedactionTests.presentationSensitivity()
        }

        Test("text-redactor-scrubs-what-passes", tags: ["redaction", "scrubbing"]) {
            try RedactionTests.textRedactorScrubsWhatPasses()
        }

        Test("dsl-renders-redacted-and-quotes-remote", tags: ["redaction", "dsl"]) {
            try RedactionTests.dslRendersRedactedAndQuotesRemote()
        }

        Test("diagnostic-values-are-plain-json", tags: ["coding", "json"]) {
            try CodingTests.diagnosticValuesArePlainJSON()
        }

        Test("report-keys-are-snake-case", tags: ["coding", "json"]) {
            try CodingTests.reportKeysAreSnakeCase()
        }

        Test("authored-identities-normalize", tags: ["identity", "invariant"]) {
            try IdentityTests.authoredIdentitiesNormalize()
        }

        Test("parsed-identities-are-strict", tags: ["identity", "invariant"]) {
            try IdentityTests.parsedIdentitiesAreStrict()
        }

        Test("namespaces-match-by-prefix", tags: ["identity"]) {
            try IdentityTests.namespacesMatchByPrefix()
        }

        Test("relations-are-discovered", tags: ["capture", "relations"]) {
            try PropagationTests.relationsAreDiscovered()
        }

        Test("dispositions", tags: ["capture", "disposition"]) {
            try PropagationTests.dispositions()
        }

        Test("context-wraps-transparently", tags: ["capture", "context"]) {
            try PropagationTests.contextWrapsTransparently()
        }

        Test("summary-carries-the-structure", tags: ["summary"]) {
            try SummaryTests.summaryCarriesTheStructure()
        }

        Test("summary-encodes-compactly", tags: ["summary", "json"]) {
            try SummaryTests.summaryEncodesCompactly()
        }

        Test("summary-scrubs-with-a-redactor", tags: ["summary", "redaction"]) {
            try SummaryTests.summaryScrubsWithARedactor()
        }
    }
}
