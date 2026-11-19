import Foundation

/// Several independent failures thrown as one. Each failure is an
/// `aggregate` relation, so a report carries every one with its own
/// presentation and sensitivity; the message only counts them, so no
/// failure's text escapes its own redaction.
public struct Errors:
    SemanticError,
    Sendable
{
    public let errors: [any Error]

    public init(
        _ errors: [any Error]
    ) {
        self.errors =
            errors
    }

    public var errorIdentity: ErrorIdentity {
        .init(
            namespace: "errors",
            code: "aggregate"
        )
    }

    public var errorPresentation: ErrorPresentation {
        switch errors.count {
        case 0:
            return .init(
                message: "No errors."
            )

        case 1:
            return .init(
                message: "1 error occurred."
            )

        default:
            return .init(
                message: "\(errors.count) errors occurred."
            )
        }
    }

    public var errorRelations: [ErrorRelation] {
        errors.map(
            ErrorRelation.aggregate
        )
    }
}
