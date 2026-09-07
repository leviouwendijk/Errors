import Foundation

public extension ErrorReport {
    var flattened: [ErrorReport] {
        [self]
            + relations.flatMap {
                $0.report.flattened
            }
    }

    var deepestunderlying: ErrorReport {
        underlying?.deepestunderlying
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
