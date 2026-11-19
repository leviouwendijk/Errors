import Foundation
import Primitives

/// A stable name for an error case: `mail.imap.command_failed`. The
/// namespace is the library and module, the code the case; both are
/// snake_case segments (`[a-z][a-z0-9_]*`), and the code never changes once
/// published.
///
/// Encoded as its dotted string and decoded through `init(_:)`, so a decoded
/// identity is always well formed. Authored identities use
/// `init(namespace:code:)`, which normalizes instead of throwing, so an error
/// path can never fail on its own name.
public struct ErrorIdentity:
    CodableInvariant,
    Sendable,
    Hashable,
    CustomStringConvertible
{
    public struct Malformed: InvarianceReason {
        public let detail: String

        public var code: InvarianceCode {
            .custom("malformed_error_identity")
        }

        public var message: String {
            "not an error identity: \(detail)"
        }
    }

    public let namespace: String
    public let code: String

    public var raw: String {
        "\(namespace).\(code)"
    }

    public var description: String {
        raw
    }

    /// Normalizes each part to snake_case segments (`transportFailed` →
    /// `transport_failed`); an empty part becomes `unnamed` or `unknown`.
    public init(
        namespace: String,
        code: String
    ) {
        let segments =
            namespace
                .split(separator: ".")
                .map {
                    Self.normalizedSegment(String($0))
                }
                .filter {
                    !$0.isEmpty
                }

        self.namespace =
            segments.isEmpty
            ? "unnamed"
            : segments.joined(separator: ".")

        let normalizedCode =
            Self.normalizedSegment(code)

        self.code =
            normalizedCode.isEmpty
            ? "unknown"
            : normalizedCode
    }

    /// Parses `namespace.code`: at least two segments, each snake_case.
    public init(
        _ raw: String
    ) throws(InvarianceFailure) {
        let segments =
            raw.split(
                separator: ".",
                omittingEmptySubsequences: false
            )
            .map(String.init)

        guard segments.count >= 2 else {
            throw Self.failure("\(raw) has no namespace")
        }

        for segment in segments where !Self.isWellFormed(segment) {
            throw Self.failure("\(raw) has a segment '\(segment)' outside [a-z][a-z0-9_]*")
        }

        self.namespace =
            segments.dropLast().joined(separator: ".")
        self.code =
            segments[segments.count - 1]
    }

    /// Whether this identity's namespace is `namespace` or nested under it:
    /// `mail.imap.command_failed` is within `mail` and `mail.imap`.
    public func isWithin(
        _ namespace: String
    ) -> Bool {
        self.namespace == namespace
            || self.namespace.hasPrefix(namespace + ".")
    }

    private static func failure(
        _ detail: String
    ) -> InvarianceFailure {
        InvarianceFailure(
            .init(
                Malformed(detail: detail),
                path: [.field("identity")]
            )
        )
    }

    private static func isWellFormed(
        _ segment: String
    ) -> Bool {
        guard let first = segment.unicodeScalars.first,
              ("a"..."z").contains(first)
        else {
            return false
        }

        return segment.unicodeScalars.allSatisfy {
            ("a"..."z").contains($0)
                || ("0"..."9").contains($0)
                || $0 == "_"
        }
    }

    private static func normalizedSegment(
        _ segment: String
    ) -> String {
        var normalized =
            segment.casing.snake()
                .lowercased()
                .unicodeScalars
                .map {
                    ("a"..."z").contains($0) || ("0"..."9").contains($0)
                        ? String($0)
                        : "_"
                }
                .joined()

        while normalized.contains("__") {
            normalized = normalized.replacingOccurrences(of: "__", with: "_")
        }

        normalized = String(
            normalized
                .drop { $0 == "_" || $0.isNumber }
                .reversed()
                .drop { $0 == "_" }
                .reversed()
        )

        return normalized
    }
}

public protocol ErrorIdentityProviding: Error {
    var errorIdentity: ErrorIdentity { get }
}

/// Declares the namespace once per type and a code per case:
///
///     enum IMAPError: SemanticError, ErrorNamespaced {
///         static let errorNamespace = "mail.imap"
///         var errorCode: String { switch self { case .commandFailed: "command_failed" … } }
///     }
public protocol ErrorNamespaced: ErrorIdentityProviding {
    static var errorNamespace: String { get }
    var errorCode: String { get }
}

public extension ErrorNamespaced {
    var errorIdentity: ErrorIdentity {
        .init(
            namespace: Self.errorNamespace,
            code: errorCode
        )
    }
}
