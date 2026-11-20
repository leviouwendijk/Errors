import Foundation

extension DecodingError {
    /// What was expected and where, instead of Foundation's "isn't in the
    /// correct format". The decoder's own text is the reason; it may quote
    /// the input.
    var presentation: ErrorPresentation {
        switch self {
        case .typeMismatch(let type, let context):
            return Self.presentation(
                "Expected \(Self.name(type))",
                context
            )
        case .valueNotFound(let type, let context):
            return Self.presentation(
                "Missing a \(Self.name(type)) value",
                context
            )
        case .keyNotFound(let key, let context):
            return Self.presentation(
                "Missing '\(key.stringValue)'",
                context
            )
        case .dataCorrupted(let context):
            return Self.presentation(
                "Invalid data",
                context
            )
        @unknown default:
            return .init(
                message: "The data could not be decoded."
            )
        }
    }

    /// `entries[2].tags`, or nil at the root.
    static func path(
        _ codingPath: [any CodingKey]
    ) -> String? {
        var path = ""
        for key in codingPath {
            if let index = key.intValue {
                path += "[\(index)]"
            } else {
                path += path.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return path.isEmpty ? nil : path
    }

    private static func presentation(
        _ what: String,
        _ context: Context
    ) -> ErrorPresentation {
        .init(
            message: path(context.codingPath).map { "\(what) at \($0)." } ?? "\(what).",
            reason: context.debugDescription.isEmpty ? nil : context.debugDescription,
            reasonSensitivity: .potentially_sensitive
        )
    }

    private static func name(
        _ type: Any.Type
    ) -> String {
        String(describing: type)
    }
}
