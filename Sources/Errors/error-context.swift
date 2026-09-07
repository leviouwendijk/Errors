import Foundation

public struct ErrorContext:
    Sendable,
    Codable,
    Hashable
{
    public let message: String
    public let fields: [ErrorDiagnosticField]
    public let messageSensitivity: ErrorDiagnosticField.Sensitivity

    public init(
        message: String,
        fields: [ErrorDiagnosticField] = [],
        messageSensitivity: ErrorDiagnosticField.Sensitivity = .ordinary
    ) {
        self.message = message
        self.fields = fields
        self.messageSensitivity = messageSensitivity
    }
}
