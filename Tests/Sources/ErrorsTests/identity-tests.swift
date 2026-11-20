import Errors
import Foundation
import Primitives
import Testing

enum IdentityTests {
    static func authoredIdentitiesNormalize() throws {
        let identity = ErrorIdentity(
            namespace: "Mail.IMAP",
            code: "commandFailed"
        )

        try Expect.equal(
            identity.raw,
            "mail.imap.command_failed",
            "authored parts normalize to snake_case segments"
        )
        try Expect.equal(
            ErrorIdentity(namespace: "", code: "").raw,
            "unnamed.unknown",
            "empty parts get a placeholder instead of failing"
        )
        try Expect.equal(
            try ErrorIdentity(identity.raw),
            identity,
            "a normalized identity always parses back"
        )
    }

    static func parsedIdentitiesAreStrict() throws {
        try Expect.equal(
            try ErrorIdentity("agentic_mail.invalid_input").namespace,
            "agentic_mail",
            "the last segment is the code, the rest the namespace"
        )
        try Expect.throwsError("one segment has no namespace") {
            _ = try ErrorIdentity("command_failed")
        }
        try Expect.throwsError("upper case is not snake_case") {
            _ = try ErrorIdentity("Mail.command_failed")
        }
        try Expect.throwsError("an empty segment is malformed") {
            _ = try ErrorIdentity("mail..command_failed")
        }
        try Expect.throwsError("decoding goes through the strict parse") {
            _ = try JSONDecoder().decode(
                ErrorIdentity.self,
                from: Data(#""Mail.Bad""#.utf8)
            )
        }
    }

    static func namespacesMatchByPrefix() throws {
        let identity = NamespacedFixtureError.commandFailed.errorIdentity

        try Expect.equal(
            identity.raw,
            "mail.imap.command_failed",
            "ErrorNamespaced combines the type's namespace with the case's code"
        )
        try Expect.true(
            identity.isWithin("mail") && identity.isWithin("mail.imap"),
            "an identity is within each enclosing namespace"
        )
        try Expect.false(
            identity.isWithin("mail.im"),
            "a namespace matches whole segments only"
        )

        let report = Errors([
            NamespacedFixtureError.connectionDropped,
        ]).report

        try Expect.true(
            report.contains(namespace: "mail.imap"),
            "traversal finds identities within a namespace"
        )
        try Expect.false(
            report.contains(namespace: "mail.smtp"),
            "traversal does not match other namespaces"
        )
    }
}

enum NamespacedFixtureError:
    SemanticError,
    ErrorNamespaced
{
    case commandFailed
    case connectionDropped

    static let errorNamespace = "mail.imap"

    var errorCode: String {
        switch self {
        case .commandFailed:
            return "command_failed"

        case .connectionDropped:
            return "connection_dropped"
        }
    }

    var errorPresentation: ErrorPresentation {
        .init(
            message: "The IMAP fixture failed."
        )
    }
}
