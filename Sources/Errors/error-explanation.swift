import Foundation

public extension ErrorPresentation {
    /// Message, reason and suggestion as one line, for places that show an
    /// error as a single string (a command line, a warning).
    var line: String {
        [message, reason, recoverySuggestion]
            .compactMap { $0 }
            .map(Self.sentence)
            .joined(separator: " ")
    }

    private static func sentence(
        _ text: String
    ) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".!?:)".contains(last) else {
            return trimmed
        }
        return trimmed + "."
    }
}

public extension ErrorReport {
    /// `presentation.line`, then what was being done, innermost first.
    var explanation: String {
        guard !contexts.isEmpty else {
            return presentation.line
        }
        return presentation.line
            + " (while "
            + contexts.map(\.message).joined(separator: "; while ")
            + ")"
    }
}

public extension Error {
    /// The whole presentation of this error as one line, unredacted: for
    /// the owner's own screens. Output that leaves the process goes through
    /// `summary(…)` instead.
    var explanation: String {
        report(
            policy: .minimal
        )
        .explanation
    }
}
