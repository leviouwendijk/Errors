import Foundation

public extension ErrorReport {
    var flattened: [ErrorReport] {
        [self]
            + relations.flatMap {
                $0.report.flattened
            }
    }

    var deepest_underlying: ErrorReport {
        underlying?.deepest_underlying
        ?? self
    }

    func first(
        where predicate: (ErrorReport) -> Bool
    ) -> ErrorReport? {
        guard !predicate(self) else {
            return self
        }

        for relation in relations {
            if let match = relation.report.first(
                where: predicate
            ) {
                return match
            }
        }

        return nil
    }

    func contains(
        identity: ErrorIdentity
    ) -> Bool {
        first {
            $0.diagnostic.identity
                == identity
        } != nil
    }

    /// Whether any report in the tree has an identity within `namespace`
    /// (`mail` matches `mail.imap.command_failed`).
    func contains(
        namespace: String
    ) -> Bool {
        first {
            $0.diagnostic.identity?.isWithin(
                namespace
            ) == true
        } != nil
    }

    func contains(
        domain: String,
        code: Int? = nil
    ) -> Bool {
        first {
            guard
                $0.diagnostic.domain == domain
            else {
                return false
            }

            guard let code else {
                return true
            }

            return $0.diagnostic.code
                == code
        } != nil
    }

    func values(
        for key: ErrorDiagnosticKey
    ) -> [ErrorDiagnosticValue] {
        flattened.compactMap {
            $0.diagnostic[
                field: key
            ]?.value
        }
    }
}
