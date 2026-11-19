import Foundation

/// What a caller should do about an error, said by the library that knows:
/// whether trying again can help, or what has to change first. It says
/// nothing about whether a retry is safe given side effects; that is the
/// caller's own knowledge.
public enum ErrorDisposition:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    /// Trying again unchanged may succeed: a timeout, a dropped
    /// connection, a busy server.
    case transient
    /// The input is wrong; change it before trying again.
    case invalid_input
    /// Permission or approval is missing; ask for it.
    case requires_access
    /// A setting or credential is missing; it has to be configured.
    case requires_configuration
    /// It will not succeed; stop.
    case permanent
}

public protocol ErrorDispositionProviding: Error {
    var errorDisposition: ErrorDisposition? { get }
}

extension ErrorDisposition {
    /// The disposition Foundation errors imply, for the codes where it is
    /// unambiguous.
    static func inferred(
        from error: any Error
    ) -> ErrorDisposition? {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .resourceUnavailable:
                return .transient

            case .userAuthenticationRequired,
                 .userCancelledAuthentication:
                return .requires_access

            case .badURL,
                 .unsupportedURL:
                return .invalid_input

            default:
                return nil
            }
        }

        if let posixError = error as? POSIXError {
            switch posixError.code {
            case .ETIMEDOUT,
                 .ECONNRESET,
                 .ECONNREFUSED,
                 .EAGAIN,
                 .EINTR,
                 .EBUSY:
                return .transient

            case .EACCES,
                 .EPERM:
                return .requires_access

            case .ENOENT,
                 .ENOTDIR,
                 .EISDIR,
                 .EINVAL:
                return .invalid_input

            default:
                return nil
            }
        }

        return nil
    }
}
