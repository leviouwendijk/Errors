import Foundation

/// An error annotated with what was being done when it passed through:
///
///     do { try move(uids, to: mailbox) }
///     catch { throw error.inContext("applying review plan 3") }
///
/// Capture is transparent: the report is the underlying error's own report
/// with this context appended, innermost context first. It adds no case and
/// no identity; for a distinct failure, add a case with an `underlying`
/// relation instead. Type checks see the wrapper, so match with
/// `withoutContext` (`error.withoutContext as? IMAPError`).
public struct ContextualError:
    Error,
    Sendable,
    LocalizedError
{
    public let context: ErrorContext
    public let underlying: any Error

    public init(
        _ context: ErrorContext,
        underlying: any Error
    ) {
        self.context = context
        self.underlying = underlying
    }

    public var errorDescription: String? {
        underlying.localizedDescription
    }

    public var failureReason: String? {
        (underlying as? any LocalizedError)?.failureReason
    }

    public var recoverySuggestion: String? {
        (underlying as? any LocalizedError)?.recoverySuggestion
    }
}

public extension Error {
    func inContext(
        _ message: String,
        fields: [ErrorDiagnosticField] = [],
        sensitivity: ErrorSensitivity = .ordinary
    ) -> ContextualError {
        ContextualError(
            ErrorContext(
                message: message,
                fields: fields,
                messageSensitivity: sensitivity
            ),
            underlying: self
        )
    }

    /// The error under every `ContextualError` wrapper.
    var withoutContext: any Error {
        var error: any Error = self

        while let contextual = error as? ContextualError {
            error = contextual.underlying
        }

        return error
    }
}

/// Runs `body`, annotating anything it throws with `message`.
public func withErrorContext<Value>(
    _ message: String,
    fields: [ErrorDiagnosticField] = [],
    sensitivity: ErrorSensitivity = .ordinary,
    _ body: () throws -> Value
) rethrows -> Value {
    do {
        return try body()
    } catch {
        throw error.inContext(
            message,
            fields: fields,
            sensitivity: sensitivity
        )
    }
}

public func withErrorContext<Value>(
    _ message: String,
    fields: [ErrorDiagnosticField] = [],
    sensitivity: ErrorSensitivity = .ordinary,
    _ body: () async throws -> Value
) async rethrows -> Value {
    do {
        return try await body()
    } catch {
        throw error.inContext(
            message,
            fields: fields,
            sensitivity: sensitivity
        )
    }
}
