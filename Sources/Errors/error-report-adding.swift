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
        _ value: String,
        sensitivity: ErrorDiagnosticField.Sensitivity = .ordinary
    ) -> ErrorReport {
        let values: [ErrorDiagnosticValue]

        switch report.diagnostic[
            field: .context
        ]?.value {
        case .array(let existing):
            values = existing + [
                .string(value),
            ]

        case .string(let existing):
            values = [
                .string(existing),
                .string(value),
            ]

        case .none:
            values = [
                .string(value),
            ]

        default:
            values = [
                .string(value),
            ]
        }

        return field(
            .context,
            value: .array(values),
            sensitivity: sensitivity
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
            relations: report.relations,
            isTruncated: report.isTruncated
        )
    }
}
