import Common

func parseWorkspaceToMonitorAssignment(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [String: [MonitorDescription]] {
    guard let rawTable = raw.asDictOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: [MonitorDescription]] = [:]
    for (workspaceName, rawMonitorDescription) in rawTable {
        result[workspaceName] = parseMonitorDescriptions(rawMonitorDescription, backtrace + .key(workspaceName), &c)
    }
    return result
}

func parseWorkspaceToMonitorAssignmentOnConnect(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [String: WorkspaceToMonitorAssignmentOnConnect] {
    guard let rawTable = raw.asDictOrNil else {
        c.errors += [expectedActualTypeDiagnostic(expected: .table, actual: raw.tomlType, backtrace)]
        return [:]
    }
    var result: [String: WorkspaceToMonitorAssignmentOnConnect] = [:]
    for (workspaceName, rawAssignment) in rawTable {
        result[workspaceName] = parseWorkspaceToMonitorAssignmentOnConnectEntry(rawAssignment, backtrace + .key(workspaceName), &c)
    }
    return result
}

private func parseWorkspaceToMonitorAssignmentOnConnectEntry(
    _ raw: OrderedJson,
    _ backtrace: ConfigBacktrace,
    _ c: inout ConfigParserContext,
) -> WorkspaceToMonitorAssignmentOnConnect? {
    if let rawTable = raw.asDictOrNil {
        var unknownKeys = Set(rawTable.keys)
        let targetRaw = rawTable["if"]
        unknownKeys.remove("if")
        let largerThanRaw = rawTable["larger-than"]
        unknownKeys.remove("larger-than")
        let smallerThanRaw = rawTable["smaller-than"]
        unknownKeys.remove("smaller-than")

        for key in unknownKeys.sorted() {
            c.errors.append(unknownKeyDiagnostic(backtrace + .key(key)))
        }
        guard let targetRaw else {
            c.errors.append(ConfigParseDiagnostic(backtrace, "Mandatory key is not specified ('if')"))
            return nil
        }
        return WorkspaceToMonitorAssignmentOnConnect(
            target: parseMonitorDescriptions(targetRaw, backtrace + .key("if"), &c),
            largerThan: largerThanRaw.map { parseMonitorDescriptions($0, backtrace + .key("larger-than"), &c) },
            smallerThan: smallerThanRaw.map { parseMonitorDescriptions($0, backtrace + .key("smaller-than"), &c) },
        )
    } else {
        return WorkspaceToMonitorAssignmentOnConnect(
            target: parseMonitorDescriptions(raw, backtrace, &c),
            largerThan: nil,
            smallerThan: nil,
        )
    }
}

func parseMonitorDescriptions(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> [MonitorDescription] {
    if let array = raw.asArrayOrNil {
        return array.enumerated()
            .map { (index, rawDesc) in parseMonitorDescription(rawDesc, backtrace + .index(index)).getOrNil(appendErrorTo: &c.errors) }
            .filterNotNil()
    } else {
        return parseMonitorDescription(raw, backtrace).getOrNil(appendErrorTo: &c.errors).asList()
    }
}

func parseMonitorDescription(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<MonitorDescription> {
    let rawString: String
    if let string = raw.asStringOrNil {
        rawString = string
    } else if let int = raw.asIntOrNil {
        rawString = String(int)
    } else {
        return .failure(expectedActualTypeDiagnostic(expected: [.string, .int], actual: raw.tomlType, backtrace))
    }

    return parseMonitorDescription(rawString).toParsedConfig(backtrace)
}
