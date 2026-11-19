import Foundation

public extension ErrorDiagnosticValue {
    /// The one key of the object that stands for `redacted`.
    static let redactedKey = "$redacted"

    init(
        from decoder: any Decoder
    ) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let values = try? container.decode([ErrorDiagnosticValue].self) {
            self = .array(values)
        } else if let values = try? container.decode([String: ErrorDiagnosticValue].self) {
            self =
                values.count == 1
                    && values[Self.redactedKey] == .boolean(true)
                ? .redacted
                : .object(values)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Not a JSON value."
            )
        }
    }

    func encode(
        to encoder: any Encoder
    ) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)

        case .integer(let value):
            try container.encode(value)

        case .double(let value):
            try container.encode(value)

        case .boolean(let value):
            try container.encode(value)

        case .array(let values):
            try container.encode(values)

        case .object(let values):
            try container.encode(values)

        case .redacted:
            try container.encode([
                Self.redactedKey: true,
            ])

        case .null:
            try container.encodeNil()
        }
    }
}
