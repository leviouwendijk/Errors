import Foundation

public extension ErrorReport {
    var adding: ErrorReportAdding {
        .init(
            report: self
        )
    }
}

public struct ErrorReportAdding {
    let report: ErrorReport

    init(
        report: ErrorReport
    ) {
        self.report = report
    }

    public func field(
        _ key: ErrorDiagnosticKey,
        value: ErrorDiagnosticValue,
        sensitivity: ErrorDiagnosticField.Sensitivity = .ordinary
    ) -> ErrorReport {
        var fields =
            report.diagnostic.fields

        let field = ErrorDiagnosticField(
            key: key,
            value: value,
            sensitivity: sensitivity
        )

        if let index = fields.firstIndex(
            where: {
                $0.key == key
            }
        ) {
            fields[index] = field
        } else {
            fields.append(
                field
            )
        }

        return replacingFields(
            fields
        )
    }

    public func field(
        _ key: ErrorDiagnosticKey,
        value: String,
        sensitivity: ErrorDiagnosticField.Sensitivity = .ordinary
    ) -> ErrorReport {
        field(
            key,
            value: .string(value),
            sensitivity: sensitivity
        )
    }

    public func field(
        _ key: ErrorDiagnosticKey,
        value: Int,
        sensitivity: ErrorDiagnosticField.Sensitivity = .ordinary
    ) -> ErrorReport {
        field(
            key,
            value: .integer(value),
            sensitivity: sensitivity
        )
    }

    public func field(
        _ key: ErrorDiagnosticKey,
        value: Double,
        sensitivity: ErrorDiagnosticField.Sensitivity = .ordinary
    ) -> ErrorReport {
        field(
            key,
            value: .double(value),
            sensitivity: sensitivity
        )
    }

    public func field(
        _ key: ErrorDiagnosticKey,
        value: Bool,
        sensitivity: ErrorDiagnosticField.Sensitivity = .ordinary
    ) -> ErrorReport {
        field(
            key,
            value: .boolean(value),
            sensitivity: sensitivity
        )
    }

    public func context(
        _ message: String,
        fields: [ErrorDiagnosticField] = [],
        sensitivity: ErrorDiagnosticField.Sensitivity = .ordinary
    ) -> ErrorReport {
        context(
            ErrorContext(
                message: message,
                fields: fields,
                messageSensitivity: sensitivity
            )
        )
    }

    public func context(
        _ context: ErrorContext
    ) -> ErrorReport {
        ErrorReport(
            presentation: report.presentation,
            diagnostic: report.diagnostic,
            contexts:
                report.contexts
                + [context],
            relations: report.relations,
            truncations: report.truncations
        )
    }
}

private extension ErrorReportAdding {
    func replacingFields(
        _ fields: [ErrorDiagnosticField]
    ) -> ErrorReport {
        ErrorReport(
            presentation: report.presentation,
            diagnostic: ErrorDiagnostic(
                typeName: report.diagnostic.typeName,
                identity: report.diagnostic.identity,
                domain: report.diagnostic.domain,
                code: report.diagnostic.code,
                fields: fields
            ),
            contexts: report.contexts,
            relations: report.relations,
            truncations: report.truncations
        )
    }
}
