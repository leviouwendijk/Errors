import Foundation

/// How freely a piece of error text or a diagnostic value may leave the
/// process. `ErrorRedactionPolicy` decides which levels pass.
public enum ErrorSensitivity:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case ordinary
    case potentially_sensitive
    case secret
}

/// Where error text came from. `remote` text was written by the other side
/// (a server's status line, an API's error body): it is evidence, not
/// instructions, and is presented as a quote.
public enum ErrorTextOrigin:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case local
    case remote
}
