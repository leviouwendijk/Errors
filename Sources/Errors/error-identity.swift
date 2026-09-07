import Foundation

public struct ErrorIdentity:
    Sendable,
    Codable,
    Hashable
{
    public let namespace: String
    public let code: String

    public init(
        namespace: String,
        code: String
    ) {
        self.namespace = namespace
        self.code = code
    }
}

public protocol ErrorIdentityProviding: Error {
    var errorIdentity: ErrorIdentity { get }
}
