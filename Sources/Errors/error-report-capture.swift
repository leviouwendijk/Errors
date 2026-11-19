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
        let state = ErrorCaptureState()

        return capture(
            error,
            policy: policy,
            depth: 0,
            activeObjects: [],
            state: state
        )
    }

    private static func capture(
        _ error: any Error,
        policy: ErrorCapturePolicy,
        depth: Int,
        activeObjects: Set<ObjectIdentifier>,
        state: ErrorCaptureState
    ) -> ErrorReport {
        if let contextual = error as? ContextualError {
            return capture(
                contextual.underlying,
                policy: policy,
                depth: depth,
                activeObjects: activeObjects,
                state: state
            )
            .adding.context(
                contextual.context
            )
        }

        state.reportCount += 1

        var truncations: [ErrorCaptureTruncation] = []

        let nsError =
            error as NSError

        // Swift errors bridge to a box whose domain is the type name and
        // whose code is the case's position: noise that shifts when cases
        // are reordered. Only Foundation errors carry a real domain, code
        // and userInfo.
        let foundationError: NSError? =
            isFoundationError(error)
            ? nsError
            : nil

        let objectIdentity =
            ObjectIdentifier(
                nsError
            )

        let objectCycle =
            activeObjects.contains(
                objectIdentity
            )

        var nextActiveObjects =
            activeObjects

        nextActiveObjects.insert(
            objectIdentity
        )

        let presentation =
            boundedPresentation(
                presentation(
                    for: error,
                    nsError: nsError
                ),
                policy: policy,
                truncations: &truncations
            )

        let fieldCapture =
            fields(
                for: error,
                foundationError: foundationError,
                policy: policy,
                state: state
            )

        truncations.append(
            contentsOf: fieldCapture.truncations
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
                domain: foundationError?.domain,
                code: foundationError?.code,
                disposition:
                    (error as? any ErrorDispositionProviding)?
                        .errorDisposition
                    ?? ErrorDisposition.inferred(
                        from: error
                    ),
                fields: fieldCapture.fields
            )

        if objectCycle {
            record(
                .cycle,
                in: &truncations
            )

            return ErrorReport(
                presentation: presentation,
                diagnostic: diagnostic,
                truncations: truncations
            )
        }

        guard
            depth < policy.maximumDepth
        else {
            record(
                .maximum_depth,
                limit: policy.maximumDepth,
                in: &truncations
            )

            return ErrorReport(
                presentation: presentation,
                diagnostic: diagnostic,
                truncations: truncations
            )
        }

        let relationCapture =
            relations(
                for: error,
                foundationError: foundationError,
                policy: policy
            )

        truncations.append(
            contentsOf: relationCapture.truncations
        )

        var capturedRelations: [ErrorReport.Relation] = []

        for relation in relationCapture.relations {
            guard
                state.reportCount < policy.maximumTotalReports
            else {
                record(
                    .maximum_total_reports,
                    limit: policy.maximumTotalReports,
                    in: &truncations
                )
                break
            }

            capturedRelations.append(
                ErrorReport.Relation(
                    kind: relation.kind,
                    report: capture(
                        relation.error,
                        policy: policy,
                        depth: depth + 1,
                        activeObjects: nextActiveObjects,
                        state: state
                    )
                )
            )
        }

        return ErrorReport(
            presentation: presentation,
            diagnostic: diagnostic,
            relations: capturedRelations,
            truncations: truncations
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

            return presentation.replacingText(
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
        foundationError: NSError?,
        policy: ErrorCapturePolicy,
        state: ErrorCaptureState
    ) -> (
        fields: [ErrorDiagnosticField],
        truncations: [ErrorCaptureTruncation]
    ) {
        var fields: [ErrorDiagnosticField] = []
        var keys: Set<ErrorDiagnosticKey> = []
        var truncations: [ErrorCaptureTruncation] = []

        if let provided =
            error as? any ErrorDiagnosticFieldsProviding
        {
            for field in provided.errorDiagnosticFields {
                guard appendField(
                    field,
                    to: &fields,
                    keys: &keys,
                    policy: policy,
                    state: state,
                    truncations: &truncations
                ) else {
                    break
                }
            }
        }

        if
            fields.count < policy.maximumFieldsPerError,
            state.fieldCount < policy.maximumTotalFields
        {
            for field in foundationFields(
                for: error
            ) {
                guard appendField(
                    field,
                    to: &fields,
                    keys: &keys,
                    policy: policy,
                    state: state,
                    truncations: &truncations
                ) else {
                    break
                }
            }
        }

        guard
            let foundationError,
            fields.count < policy.maximumFieldsPerError,
            state.fieldCount < policy.maximumTotalFields,
            policy.userInfo != .none
        else {
            return (
                fields,
                truncations
            )
        }

        let userInfo =
            foundationError.userInfo
                .sorted {
                    String(
                        describing: $0.key
                    ) < String(
                        describing: $1.key
                    )
                }

        for (rawKey, value) in userInfo {
            let name =
                String(
                    describing: rawKey
                )

            guard
                name != NSUnderlyingErrorKey,
                name != "NSMultipleUnderlyingErrorsKey"
            else {
                continue
            }

            guard
                policy.userInfo == .all
                    || standardUserInfoKeys.contains(
                        name
                    )
            else {
                continue
            }

            let key =
                ErrorDiagnosticKey(
                    rawValue: name
                )

            guard
                !keys.contains(key)
            else {
                continue
            }

            var valueTruncations: [ErrorCaptureTruncation] = []

            let diagnosticValue =
                diagnosticValue(
                    from: value,
                    depth: 0,
                    policy: policy,
                    truncations: &valueTruncations
                )

            truncations.append(
                contentsOf: valueTruncations
            )

            guard appendField(
                ErrorDiagnosticField(
                    key: key,
                    value: diagnosticValue,
                    sensitivity:
                        sensitivity(
                            for: name
                        )
                ),
                to: &fields,
                keys: &keys,
                policy: policy,
                state: state,
                truncations: &truncations
            ) else {
                break
            }
        }

        return (
            fields,
            truncations
        )
    }

    private static func foundationFields(
        for error: any Error
    ) -> [ErrorDiagnosticField] {
        var fields: [ErrorDiagnosticField] = []

        if let urlError = error as? URLError {
            fields.append(
                .init(
                    key: "url_error.code",
                    value: urlError.code.rawValue
                )
            )

            if let url = urlError.failingURL {
                fields.append(
                    .init(
                        key: "url_error.url",
                        value: url.absoluteString,
                        sensitivity: .potentially_sensitive
                    )
                )
            }
        }

        if let cocoaError = error as? CocoaError {
            fields.append(
                .init(
                    key: "cocoa.code",
                    value: cocoaError.code.rawValue
                )
            )
        }

        if let posixError = error as? POSIXError {
            fields.append(
                .init(
                    key: "posix.code",
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
                        kind: "type_mismatch",
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
                        kind: "value_not_found",
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
                        kind: "key_not_found",
                        context: context,
                        key: key.stringValue
                    )
                )

            case .dataCorrupted(
                let context
            ):
                fields.append(
                    contentsOf: decodingFields(
                        kind: "data_corrupted",
                        context: context
                    )
                )

            @unknown default:
                fields.append(
                    .init(
                        key: "decoding.kind",
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
                key: "decoding.kind",
                value: kind
            ),
            .init(
                key: "decoding.coding_path",
                value: .array(
                    context.codingPath.map {
                        .string(
                            $0.stringValue
                        )
                    }
                )
            ),
            .init(
                key: "decoding.debug_description",
                value: context.debugDescription
            ),
        ]

        if let expectedType {
            fields.append(
                .init(
                    key: "decoding.expected_type",
                    value: String(
                        reflecting: expectedType
                    )
                )
            )
        }

        if let key {
            fields.append(
                .init(
                    key: "decoding.key",
                    value: key
                )
            )
        }

        return fields
    }

    private static func relations(
        for error: any Error,
        foundationError: NSError?,
        policy: ErrorCapturePolicy
    ) -> (
        relations: [ErrorRelation],
        truncations: [ErrorCaptureTruncation]
    ) {
        var relations: [ErrorRelation] = []
        var truncations: [ErrorCaptureTruncation] = []

        if let provided =
            error as? any ErrorRelationsProviding
        {
            let providedRelations =
                provided.errorRelations

            relations =
                Array(
                    providedRelations.prefix(
                        policy.maximumRelationsPerError
                    )
                )

            if
                providedRelations.count
                    > policy.maximumRelationsPerError
            {
                record(
                    .maximum_relations,
                    limit: policy.maximumRelationsPerError,
                    in: &truncations
                )
            }
        }

        // An error that names no relations may still hold its cause
        // (`case io(any Error)`, `let underlying: any Error`); find it.
        if relations.isEmpty, foundationError == nil {
            for relation in discoveredRelations(
                in: error
            ) {
                guard
                    relations.count < policy.maximumRelationsPerError
                else {
                    record(
                        .maximum_relations,
                        limit: policy.maximumRelationsPerError,
                        in: &truncations
                    )
                    break
                }

                relations.append(
                    relation
                )
            }
        }

        let alreadyHasUnderlying =
            relations.contains {
                $0.kind == .underlying
            }

        if
            !alreadyHasUnderlying,
            let underlying =
                foundationError?.userInfo[NSUnderlyingErrorKey]
                    as? any Error
        {
            if
                relations.count < policy.maximumRelationsPerError
            {
                relations.append(
                    .underlying(
                        underlying
                    )
                )
            } else {
                record(
                    .maximum_relations,
                    limit: policy.maximumRelationsPerError,
                    in: &truncations
                )
            }
        }

        if let multiple =
            foundationError?.userInfo["NSMultipleUnderlyingErrorsKey"]
                as? [Any]
        {
            for candidate in multiple {
                guard
                    let error = candidate as? any Error
                else {
                    continue
                }

                guard
                    relations.count < policy.maximumRelationsPerError
                else {
                    record(
                        .maximum_relations,
                        limit: policy.maximumRelationsPerError,
                        in: &truncations
                    )
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
            truncations
        )
    }

    private static func diagnosticValue(
        from value: Any,
        depth: Int,
        policy: ErrorCapturePolicy,
        truncations: inout [ErrorCaptureTruncation]
    ) -> ErrorDiagnosticValue {
        guard
            depth < policy.maximumDiagnosticValueDepth
        else {
            record(
                .maximum_diagnostic_value_depth,
                limit: policy.maximumDiagnosticValueDepth,
                in: &truncations
            )

            return .string(
                boundedString(
                    String(
                        reflecting: value
                    ),
                    policy: policy,
                    truncations: &truncations
                )
            )
        }

        switch value {
        case let value as String:
            return .string(
                boundedString(
                    value,
                    policy: policy,
                    truncations: &truncations
                )
            )

        case let value as Bool:
            return .boolean(value)

        case let value as Int:
            return .integer(value)

        case let value as Int8:
            return .integer(Int(value))

        case let value as Int16:
            return .integer(Int(value))

        case let value as Int32:
            return .integer(Int(value))

        case let value as Int64:
            if let exact = Int(exactly: value) {
                return .integer(exact)
            }

            return .string(
                boundedString(
                    String(value),
                    policy: policy,
                    truncations: &truncations
                )
            )

        case let value as UInt:
            if let exact = Int(exactly: value) {
                return .integer(exact)
            }

            return .string(
                boundedString(
                    String(value),
                    policy: policy,
                    truncations: &truncations
                )
            )

        case let value as UInt8:
            return .integer(Int(value))

        case let value as UInt16:
            return .integer(Int(value))

        case let value as UInt32:
            if let exact = Int(exactly: value) {
                return .integer(exact)
            }

            return .string(
                boundedString(
                    String(value),
                    policy: policy,
                    truncations: &truncations
                )
            )

        case let value as UInt64:
            if let exact = Int(exactly: value) {
                return .integer(exact)
            }

            return .string(
                boundedString(
                    String(value),
                    policy: policy,
                    truncations: &truncations
                )
            )

        case let value as Double:
            return .double(value)

        case let value as Float:
            return .double(Double(value))

        case let value as URL:
            return .string(
                boundedString(
                    value.absoluteString,
                    policy: policy,
                    truncations: &truncations
                )
            )

        case let values as [Any]:
            if values.count > policy.maximumCollectionCount {
                record(
                    .maximum_collection_count,
                    limit: policy.maximumCollectionCount,
                    in: &truncations
                )
            }

            var bounded: [ErrorDiagnosticValue] = []

            for value in values.prefix(
                policy.maximumCollectionCount
            ) {
                bounded.append(
                    diagnosticValue(
                        from: value,
                        depth: depth + 1,
                        policy: policy,
                        truncations: &truncations
                    )
                )
            }

            return .array(bounded)

        case let values as [String: Any]:
            let keys = values.keys.sorted()

            if keys.count > policy.maximumCollectionCount {
                record(
                    .maximum_collection_count,
                    limit: policy.maximumCollectionCount,
                    in: &truncations
                )
            }

            var bounded: [String: ErrorDiagnosticValue] = [:]

            for key in keys.prefix(
                policy.maximumCollectionCount
            ) {
                guard let value = values[key] else {
                    continue
                }

                bounded[key] =
                    diagnosticValue(
                        from: value,
                        depth: depth + 1,
                        policy: policy,
                        truncations: &truncations
                    )
            }

            return .object(bounded)

        case _ as NSNull:
            return .null

        default:
            return .string(
                boundedString(
                    String(
                        reflecting: value
                    ),
                    policy: policy,
                    truncations: &truncations
                )
            )
        }
    }

    private static func boundedPresentation(
        _ presentation: ErrorPresentation,
        policy: ErrorCapturePolicy,
        truncations: inout [ErrorCaptureTruncation]
    ) -> ErrorPresentation {
        var recoveryOptions: [String] = []

        if presentation.recoveryOptions.count > policy.maximumCollectionCount {
            record(
                .maximum_collection_count,
                limit: policy.maximumCollectionCount,
                in: &truncations
            )
        }

        for option in presentation.recoveryOptions.prefix(
            policy.maximumCollectionCount
        ) {
            recoveryOptions.append(
                boundedString(
                    option,
                    policy: policy,
                    truncations: &truncations
                )
            )
        }

        return presentation.replacingText(
            title: boundedOptionalString(
                presentation.title,
                policy: policy,
                truncations: &truncations
            ),
            message: boundedString(
                presentation.message,
                policy: policy,
                truncations: &truncations
            ),
            reason: boundedOptionalString(
                presentation.reason,
                policy: policy,
                truncations: &truncations
            ),
            recoverySuggestion: boundedOptionalString(
                presentation.recoverySuggestion,
                policy: policy,
                truncations: &truncations
            ),
            recoveryOptions: recoveryOptions,
            helpAnchor: boundedOptionalString(
                presentation.helpAnchor,
                policy: policy,
                truncations: &truncations
            )
        )
    }

    private static func appendField(
        _ field: ErrorDiagnosticField,
        to fields: inout [ErrorDiagnosticField],
        keys: inout Set<ErrorDiagnosticKey>,
        policy: ErrorCapturePolicy,
        state: ErrorCaptureState,
        truncations: inout [ErrorCaptureTruncation]
    ) -> Bool {
        guard !keys.contains(field.key) else {
            return true
        }

        guard fields.count < policy.maximumFieldsPerError else {
            record(
                .maximum_fields,
                limit: policy.maximumFieldsPerError,
                in: &truncations
            )
            return false
        }

        guard state.fieldCount < policy.maximumTotalFields else {
            record(
                .maximum_total_fields,
                limit: policy.maximumTotalFields,
                in: &truncations
            )
            return false
        }

        keys.insert(field.key)

        let value =
            boundedDiagnosticValue(
                field.value,
                depth: 0,
                policy: policy,
                truncations: &truncations
            )

        fields.append(
            ErrorDiagnosticField(
                key: field.key,
                value: value,
                sensitivity: field.sensitivity
            )
        )

        state.fieldCount += 1

        return true
    }

    private static func boundedDiagnosticValue(
        _ value: ErrorDiagnosticValue,
        depth: Int,
        policy: ErrorCapturePolicy,
        truncations: inout [ErrorCaptureTruncation]
    ) -> ErrorDiagnosticValue {
        guard depth < policy.maximumDiagnosticValueDepth else {
            record(
                .maximum_diagnostic_value_depth,
                limit: policy.maximumDiagnosticValueDepth,
                in: &truncations
            )
            return .redacted
        }

        switch value {
        case .string(let value):
            return .string(
                boundedString(
                    value,
                    policy: policy,
                    truncations: &truncations
                )
            )

        case .array(let values):
            if values.count > policy.maximumCollectionCount {
                record(
                    .maximum_collection_count,
                    limit: policy.maximumCollectionCount,
                    in: &truncations
                )
            }

            var bounded: [ErrorDiagnosticValue] = []

            for value in values.prefix(
                policy.maximumCollectionCount
            ) {
                bounded.append(
                    boundedDiagnosticValue(
                        value,
                        depth: depth + 1,
                        policy: policy,
                        truncations: &truncations
                    )
                )
            }

            return .array(bounded)

        case .object(let values):
            let keys = values.keys.sorted()

            if keys.count > policy.maximumCollectionCount {
                record(
                    .maximum_collection_count,
                    limit: policy.maximumCollectionCount,
                    in: &truncations
                )
            }

            var bounded: [String: ErrorDiagnosticValue] = [:]

            for key in keys.prefix(
                policy.maximumCollectionCount
            ) {
                guard let value = values[key] else {
                    continue
                }

                bounded[key] =
                    boundedDiagnosticValue(
                        value,
                        depth: depth + 1,
                        policy: policy,
                        truncations: &truncations
                    )
            }

            return .object(bounded)

        case .integer,
             .double,
             .boolean,
             .redacted,
             .null:
            return value
        }
    }

    private static func boundedOptionalString(
        _ value: String?,
        policy: ErrorCapturePolicy,
        truncations: inout [ErrorCaptureTruncation]
    ) -> String? {
        guard let value else {
            return nil
        }

        return boundedString(
            value,
            policy: policy,
            truncations: &truncations
        )
    }

    private static func boundedString(
        _ value: String,
        policy: ErrorCapturePolicy,
        truncations: inout [ErrorCaptureTruncation]
    ) -> String {
        guard value.count > policy.maximumStringLength else {
            return value
        }

        record(
            .maximum_string_length,
            limit: policy.maximumStringLength,
            in: &truncations
        )

        return String(
            value.prefix(
                policy.maximumStringLength
            )
        )
    }

    private static func record(
        _ reason: ErrorCaptureTruncation.Reason,
        limit: Int? = nil,
        in truncations: inout [ErrorCaptureTruncation]
    ) {
        let truncation =
            ErrorCaptureTruncation(
                reason: reason,
                limit: limit
            )

        guard !truncations.contains(truncation) else {
            return
        }

        truncations.append(truncation)
    }

    /// Errors held by `error`'s stored properties or enum payload, looking
    /// through tuples (multi-value payloads), optionals and collections (as
    /// aggregates), but not into other structs or classes.
    private static func discoveredRelations(
        in error: any Error
    ) -> [ErrorRelation] {
        var relations: [ErrorRelation] = []

        collectErrors(
            in: error,
            depth: 0,
            aggregate: false,
            into: &relations
        )

        return relations
    }

    private static func collectErrors(
        in value: Any,
        depth: Int,
        aggregate: Bool,
        into relations: inout [ErrorRelation]
    ) {
        for child in Mirror(reflecting: value).children {
            if let error = child.value as? any Error {
                relations.append(
                    aggregate
                    ? .aggregate(error)
                    : .underlying(error)
                )
                continue
            }

            guard depth < 2 else {
                continue
            }

            switch Mirror(reflecting: child.value).displayStyle {
            case .tuple?,
                 .optional?:
                collectErrors(
                    in: child.value,
                    depth: depth + 1,
                    aggregate: aggregate,
                    into: &relations
                )

            case .collection?,
                 .set?:
                collectErrors(
                    in: child.value,
                    depth: depth + 1,
                    aggregate: true,
                    into: &relations
                )

            default:
                continue
            }
        }
    }

    private static func isFoundationError(
        _ error: any Error
    ) -> Bool {
        type(of: error) is NSError.Type
            || error is any CustomNSError
    }

    private static func sensitivity(
        for name: String
    ) -> ErrorSensitivity {
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
            return .potentially_sensitive
        }

        return .ordinary
    }
}
