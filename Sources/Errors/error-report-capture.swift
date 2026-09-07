import Foundation

public extension Error {
    var report: ErrorReport {
        ErrorReport(
            capturing: self
        )
    }

    func report(
        policy: ErrorCapturePolicy
    ) -> ErrorReport {
        ErrorReport(
            capturing: self,
            policy: policy
        )
    }
}

enum ErrorReportCapture {
    private static let standardUserInfoKeys: Set<String> = [
        NSLocalizedDescriptionKey,
        NSLocalizedFailureReasonErrorKey,
        NSLocalizedRecoverySuggestionErrorKey,
        NSHelpAnchorErrorKey,
        "NSErrorFailingURLKey",
        "NSErrorFailingURLStringKey",
        "NSFilePath",
        "NSStringEncoding",
        "_kCFStreamErrorDomainKey",
        "_kCFStreamErrorCodeKey",
        "NSErrorPeerCertificateChainKey",
        "NSURLErrorFailingURLPeerTrustErrorKey",
    ]

    static func capture(
        _ error: any Error,
        policy: ErrorCapturePolicy
    ) -> ErrorReport {
        capture(
            error,
            policy: policy,
            depth: 0,
            activeObjects: []
        )
    }

    private static func capture(
        _ error: any Error,
        policy: ErrorCapturePolicy,
        depth: Int,
        activeObjects: Set<ObjectIdentifier>
    ) -> ErrorReport {
        let nsError =
            error as NSError

        let identity =
            ObjectIdentifier(
                nsError
            )

        let objectCycle =
            activeObjects.contains(
                identity
            )

        var nextActiveObjects =
            activeObjects

        nextActiveObjects.insert(
            identity
        )

        let presentation =
            presentation(
                for: error,
                nsError: nsError
            )

        let fieldCapture =
            fields(
                for: error,
                nsError: nsError,
                policy: policy
            )

        let diagnostic =
            ErrorDiagnostic(
                typeName: String(
                    reflecting: type(
                        of: error
                    )
                ),
                identity:
                    (error as? any ErrorIdentityProviding)?
                        .errorIdentity,
                domain: nsError.domain,
                code: nsError.code,
                fields: fieldCapture.fields
            )

        guard
            !objectCycle,
            depth < policy.maximumDepth
        else {
            return ErrorReport(
                presentation: presentation,
                diagnostic: diagnostic,
                isTruncated: true
            )
        }

        let relationCapture =
            relations(
                for: error,
                nsError: nsError,
                policy: policy
            )

        let capturedRelations =
            relationCapture.relations.map {
                ErrorReport.Relation(
                    kind: $0.kind,
                    report: capture(
                        $0.error,
                        policy: policy,
                        depth: depth + 1,
                        activeObjects: nextActiveObjects
                    )
                )
            }

        return ErrorReport(
            presentation: presentation,
            diagnostic: diagnostic,
            relations: capturedRelations,
            isTruncated:
                fieldCapture.truncated
                || relationCapture.truncated
        )
    }

    private static func presentation(
        for error: any Error,
        nsError: NSError
    ) -> ErrorPresentation {
        let recoverableOptions =
            (error as? any RecoverableError)?
                .recoveryOptions
            ?? []

        if let provided =
            error as? any PresentableError
        {
            let presentation =
                provided.errorPresentation

            guard
                presentation.recoveryOptions.isEmpty,
                !recoverableOptions.isEmpty
            else {
                return presentation
            }

            return ErrorPresentation(
                title: presentation.title,
                message: presentation.message,
                reason: presentation.reason,
                recoverySuggestion:
                    presentation.recoverySuggestion,
                recoveryOptions: recoverableOptions,
                helpAnchor: presentation.helpAnchor
            )
        }

        if let localized =
            error as? any LocalizedError
        {
            return ErrorPresentation(
                message:
                    localized.errorDescription
                    ?? nsError.localizedDescription,
                reason:
                    localized.failureReason
                    ?? nsError.localizedFailureReason,
                recoverySuggestion:
                    localized.recoverySuggestion
                    ?? nsError.localizedRecoverySuggestion,
                recoveryOptions:
                    recoverableOptions,
                helpAnchor:
                    localized.helpAnchor
                    ?? nsError.helpAnchor
            )
        }

        return ErrorPresentation(
            message:
                nsError.localizedDescription,
            reason:
                nsError.localizedFailureReason,
            recoverySuggestion:
                nsError.localizedRecoverySuggestion,
            recoveryOptions:
                recoverableOptions,
            helpAnchor:
                nsError.helpAnchor
        )
    }

    private static func fields(
        for error: any Error,
        nsError: NSError,
        policy: ErrorCapturePolicy
    ) -> (
        fields: [ErrorDiagnosticField],
        truncated: Bool
    ) {
        var fields: [ErrorDiagnosticField] = []
        var names: Set<String> = []
        var truncated = false

        if let provided =
            error as? any ErrorDiagnosticFieldsProviding
        {
            for field in provided.errorDiagnosticFields {
                guard
                    fields.count < policy.maximumFieldsPerError
                else {
                    truncated = true
                    break
                }

                guard
                    names.insert(
                        field.name
                    ).inserted
                else {
                    continue
                }

                fields.append(
                    field
                )
            }
        }

        for field in foundationFields(
            for: error
        ) {
            guard
                fields.count < policy.maximumFieldsPerError
            else {
                truncated = true
                break
            }

            guard
                names.insert(
                    field.name
                ).inserted
            else {
                continue
            }

            fields.append(
                field
            )
        }

        guard
            fields.count < policy.maximumFieldsPerError,
            policy.userInfo != .none
        else {
            if
                policy.userInfo != .none,
                !nsError.userInfo.isEmpty,
                fields.count >= policy.maximumFieldsPerError
            {
                truncated = true
            }

            return (
                fields,
                truncated
            )
        }

        let userInfo =
            nsError.userInfo
                .sorted {
                    String(
                        describing: $0.key
                    ) < String(
                        describing: $1.key
                    )
                }

        for (rawKey, value) in userInfo {
            let key =
                String(
                    describing: rawKey
                )

            guard
                key != NSUnderlyingErrorKey,
                key != "NSMultipleUnderlyingErrorsKey"
            else {
                continue
            }

            guard
                policy.userInfo == .all
                    || standardUserInfoKeys.contains(
                        key
                    )
            else {
                continue
            }

            guard
                names.insert(
                    key
                ).inserted
            else {
                continue
            }

            guard
                fields.count < policy.maximumFieldsPerError
            else {
                truncated = true
                break
            }

            fields.append(
                ErrorDiagnosticField(
                    name: key,
                    value: diagnosticValue(
                        from: value,
                        depth: 0,
                        maximumDepth:
                            policy.maximumDiagnosticValueDepth
                    ),
                    sensitivity:
                        sensitivity(
                            for: key
                        )
                )
            )
        }

        return (
            fields,
            truncated
        )
    }

    private static func foundationFields(
        for error: any Error
    ) -> [ErrorDiagnosticField] {
        var fields: [ErrorDiagnosticField] = []

        if let urlError = error as? URLError {
            fields.append(
                .init(
                    name: "urlerror.code",
                    value: urlError.code.rawValue
                )
            )

            if let url = urlError.failingURL {
                fields.append(
                    .init(
                        name: "urlerror.url",
                        value: url.absoluteString,
                        sensitivity: .potentiallySensitive
                    )
                )
            }
        }

        if let cocoaError = error as? CocoaError {
            fields.append(
                .init(
                    name: "cocoa.code",
                    value: cocoaError.code.rawValue
                )
            )
        }

        if let posixError = error as? POSIXError {
            fields.append(
                .init(
                    name: "posix.code",
                    value: Int(
                        posixError.code.rawValue
                    )
                )
            )
        }

        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .typeMismatch(
                let type,
                let context
            ):
                fields.append(
                    contentsOf: decodingFields(
                        kind: "typemismatch",
                        context: context,
                        expectedType: type
                    )
                )

            case .valueNotFound(
                let type,
                let context
            ):
                fields.append(
                    contentsOf: decodingFields(
                        kind: "valuenotfound",
                        context: context,
                        expectedType: type
                    )
                )

            case .keyNotFound(
                let key,
                let context
            ):
                fields.append(
                    contentsOf: decodingFields(
                        kind: "keynotfound",
                        context: context,
                        key: key.stringValue
                    )
                )

            case .dataCorrupted(
                let context
            ):
                fields.append(
                    contentsOf: decodingFields(
                        kind: "datacorrupted",
                        context: context
                    )
                )

            @unknown default:
                fields.append(
                    .init(
                        name: "decoding.kind",
                        value: "unknown"
                    )
                )
            }
        }

        return fields
    }

    private static func decodingFields(
        kind: String,
        context: DecodingError.Context,
        expectedType: Any.Type? = nil,
        key: String? = nil
    ) -> [ErrorDiagnosticField] {
        var fields: [ErrorDiagnosticField] = [
            .init(
                name: "decoding.kind",
                value: kind
            ),
            .init(
                name: "decoding.codingpath",
                value: .array(
                    context.codingPath.map {
                        .string(
                            $0.stringValue
                        )
                    }
                )
            ),
            .init(
                name: "decoding.debugdescription",
                value: context.debugDescription
            ),
        ]

        if let expectedType {
            fields.append(
                .init(
                    name: "decoding.expectedtype",
                    value: String(
                        reflecting: expectedType
                    )
                )
            )
        }

        if let key {
            fields.append(
                .init(
                    name: "decoding.key",
                    value: key
                )
            )
        }

        return fields
    }

    private static func relations(
        for error: any Error,
        nsError: NSError,
        policy: ErrorCapturePolicy
    ) -> (
        relations: [ErrorRelation],
        truncated: Bool
    ) {
        var relations: [ErrorRelation] = []
        var truncated = false

        if let provided =
            error as? any ErrorRelationsProviding
        {
            relations =
                Array(
                    provided.errorRelations.prefix(
                        policy.maximumRelationsPerError
                    )
                )

            truncated =
                provided.errorRelations.count
                > policy.maximumRelationsPerError
        }

        let alreadyHasUnderlying =
            relations.contains {
                $0.kind == .underlying
            }

        if
            !alreadyHasUnderlying,
            let underlying =
                nsError.userInfo[NSUnderlyingErrorKey]
                    as? any Error
        {
            if
                relations.count
                    < policy.maximumRelationsPerError
            {
                relations.append(
                    .underlying(
                        underlying
                    )
                )
            } else {
                truncated = true
            }
        }

        if let multiple =
            nsError.userInfo["NSMultipleUnderlyingErrorsKey"]
                as? [Any]
        {
            for candidate in multiple {
                guard
                    let error = candidate as? any Error
                else {
                    continue
                }

                guard
                    relations.count
                        < policy.maximumRelationsPerError
                else {
                    truncated = true
                    break
                }

                relations.append(
                    .aggregate(
                        error
                    )
                )
            }
        }

        return (
            relations,
            truncated
        )
    }

    private static func diagnosticValue(
        from value: Any,
        depth: Int,
        maximumDepth: Int
    ) -> ErrorDiagnosticValue {
        guard
            depth < maximumDepth
        else {
            return .string(
                String(
                    reflecting: value
                )
            )
        }

        switch value {
        case let value as String:
            return .string(
                value
            )

        case let value as Bool:
            return .boolean(
                value
            )

        case let value as Int:
            return .integer(
                value
            )

        case let value as Int8:
            return .integer(
                Int(value)
            )

        case let value as Int16:
            return .integer(
                Int(value)
            )

        case let value as Int32:
            return .integer(
                Int(value)
            )

        case let value as Int64:
            if let exact = Int(
                exactly: value
            ) {
                return .integer(
                    exact
                )
            }

            return .string(
                String(value)
            )

        case let value as UInt:
            if let exact = Int(
                exactly: value
            ) {
                return .integer(
                    exact
                )
            }

            return .string(
                String(value)
            )

        case let value as UInt8:
            return .integer(
                Int(value)
            )

        case let value as UInt16:
            return .integer(
                Int(value)
            )

        case let value as UInt32:
            if let exact = Int(
                exactly: value
            ) {
                return .integer(
                    exact
                )
            }

            return .string(
                String(value)
            )

        case let value as UInt64:
            if let exact = Int(
                exactly: value
            ) {
                return .integer(
                    exact
                )
            }

            return .string(
                String(value)
            )

        case let value as Double:
            return .double(
                value
            )

        case let value as Float:
            return .double(
                Double(value)
            )

        case let value as URL:
            return .string(
                value.absoluteString
            )

        case let value as [Any]:
            return .array(
                value.map {
                    diagnosticValue(
                        from: $0,
                        depth: depth + 1,
                        maximumDepth: maximumDepth
                    )
                }
            )

        case let value as [String: Any]:
            return .object(
                value.mapValues {
                    diagnosticValue(
                        from: $0,
                        depth: depth + 1,
                        maximumDepth: maximumDepth
                    )
                }
            )

        case _ as NSNull:
            return .null

        default:
            return .string(
                String(
                    reflecting: value
                )
            )
        }
    }

    private static func sensitivity(
        for name: String
    ) -> ErrorDiagnosticField.Sensitivity {
        let normalized =
            name.lowercased()

        let secretFragments = [
            "password",
            "passwd",
            "token",
            "secret",
            "authorization",
            "cookie",
            "credential",
            "api_key",
            "apikey",
            "private_key",
            "privatekey",
        ]

        if secretFragments.contains(
            where: normalized.contains
        ) {
            return .secret
        }

        let sensitiveFragments = [
            "url",
            "path",
            "host",
            "address",
            "email",
            "request",
            "response",
            "user",
            "file",
        ]

        if sensitiveFragments.contains(
            where: normalized.contains
        ) {
            return .potentiallySensitive
        }

        return .ordinary
    }
}
