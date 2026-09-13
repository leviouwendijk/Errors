import Primitives

/// Error relation kinds are open string identifiers rather than a closed enum.
///
/// The existing raw-value, string-literal, and Codable implementation is
/// already wire-compatible with StringIdentifier. This conformance gives the
/// type the shared identifier semantics without changing its representation.
extension ErrorRelation.Kind: StringIdentifier {}
