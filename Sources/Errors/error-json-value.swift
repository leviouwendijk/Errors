import Primitives

public extension ErrorDiagnosticValue {
    /// Losslessly materializes the durable Codable representation of this
    /// diagnostic value as the canonical Primitives JSON tree.
    ///
    /// `redacted` remains an ErrorDiagnosticValue semantic case rather than
    /// being lowered into an ordinary JSON scalar.
    func jsonvalue(
        using coding: JSONCoding = .default
    ) throws -> JSONValue {
        try JSONValueCodec.encodeValue(
            self,
            using: coding.encoder()
        )
    }

    /// Reconstructs a diagnostic value from its durable Codable JSON shape.
    init(
        jsonvalue: JSONValue,
        using coding: JSONCoding = .default
    ) throws {
        self = try jsonvalue.as(
            Self.self,
            using: coding.decoder()
        )
    }
}

public extension ErrorReport {
    /// Losslessly materializes the complete recursive error report as a
    /// Primitives JSONValue using the report's existing Codable contract.
    func jsonvalue(
        using coding: JSONCoding = .default
    ) throws -> JSONValue {
        try JSONValueCodec.encodeValue(
            self,
            using: coding.encoder()
        )
    }

    /// Reconstructs a complete recursive report from its durable Codable
    /// JSON representation.
    init(
        jsonvalue: JSONValue,
        using coding: JSONCoding = .default
    ) throws {
        self = try jsonvalue.as(
            Self.self,
            using: coding.decoder()
        )
    }
}
