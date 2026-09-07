import Foundation

public typealias MultiError = Errors

public struct Errors:
    Error,
    Sendable,
    ErrorRelationsProviding
{
    public let errors: [any Error]

    public init(
        _ errors: [any Error]
    ) {
        self.errors =
            errors
    }

    public var errorRelations: [ErrorRelation] {
        errors.map(
            ErrorRelation.aggregate
        )
    }
}

extension Errors: LocalizedError {
    public var errorDescription: String? {
        switch errors.count {
        case 0:
            return "No errors."

        case 1:
            return "1 error occurred."

        default:
            return "\(errors.count) errors occurred."
        }
    }
}
