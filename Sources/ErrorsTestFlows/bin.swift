import TestFlows

@main
enum ErrorsFlowTestMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: ErrorsFlowSuite.self
        )
    }
}

enum ErrorsFlowSuite:
    TestFlowRegistry
{
    static let title = "Errors flow tests"

    static let flows: [TestFlow] = [
        TestFlow(
            "error-report-semantic-capture",
            tags: [
                "errors",
                "report",
                "semantic",
                "capture",
            ]
        ) {
            try await ErrorsFlowTesting
                .runSemanticCapture()
        },
        TestFlow(
            "error-report-foundation-chain",
            tags: [
                "errors",
                "report",
                "foundation",
                "recursive",
            ]
        ) {
            try await ErrorsFlowTesting
                .runFoundationChain()
        },
        TestFlow(
            "error-report-aggregate-dsl",
            tags: [
                "errors",
                "aggregate",
                "dsl",
                "structured-content",
            ]
        ) {
            try await ErrorsFlowTesting
                .runAggregateDSL()
        },
        TestFlow(
            "error-report-semantic-utilities",
            tags: [
                "errors",
                "identity",
                "redaction",
                "adding",
                "relations",
            ]
        ) {
            try await ErrorsFlowTesting
                .runSemanticUtilities()
        },
    ]
}
