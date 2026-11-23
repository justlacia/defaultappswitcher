import Foundation

public enum HandlerPrefParser {
    private static let blockSeparator = "--------------------------------------------------------------------------------"
    private static let rolePrefixes = ["all roles:", "viewer:", "editor:", "shell:", "none:"]

    /// Parses the textual output of `lsregister -dump HandlerPref`.
    public static func parse(_ output: String) -> [HandlerOverride] {
        let blocks = output.components(separatedBy: blockSeparator)
        var results: [HandlerOverride] = []
        var seenIDs = Set<String>()

        for block in blocks {
            var kind: HandlerKind?
            var identifier: String?
            var bundleID: String?
            var roles: [String] = []
            var modDate: Date?

            let lines = block.components(separatedBy: .newlines)
            for rawLine in lines {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty else { continue }

                if line.hasPrefix("content type:") {
                    let value = valueAfterColon(line)
                    if let firstToken = value.split(whereSeparator: { $0.isWhitespace }).first {
                        kind = .contentType
                        identifier = String(firstToken)
                    }
                } else if line.hasPrefix("URL scheme:") {
                    let value = valueAfterColon(line)
                    if let firstToken = value.split(whereSeparator: { $0.isWhitespace }).first {
                        kind = .urlScheme
                        identifier = String(firstToken)
                    }
                } else if line.hasPrefix("extension:") {
                    let value = valueAfterColon(line)
                    if let firstToken = value.split(whereSeparator: { $0.isWhitespace }).first {
                        kind = .extensionOnly
                        identifier = String(firstToken)
                    }
                } else if line.hasPrefix("mod date:") {
                    modDate = parseModDate(from: line)
                } else if !line.contains("(bundle ver)"), let matchedPrefix = rolePrefixes.first(where: { line.hasPrefix($0) }) {
                    let roleName = String(matchedPrefix.dropLast())
                    let value = valueAfterColon(line)
                    guard !value.isEmpty, value != "-", value != "(none)", value != "none" else {
                        continue
                    }
                    // Keep the first valid bundle identifier encountered in role entries.
                    if bundleID == nil {
                        bundleID = value
                    }
                    roles.append(roleName)
                }
            }

            if let kind, let identifier, let bundleID {
                let item = HandlerOverride(
                    kind: kind,
                    identifier: identifier,
                    bundleID: bundleID,
                    roles: roles,
                    modDate: modDate
                )
                if seenIDs.insert(item.id).inserted {
                    results.append(item)
                }
            }
        }

        return results
    }

    private static func valueAfterColon(_ line: String) -> String {
        guard let idx = line.firstIndex(of: ":") else { return "" }
        return line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
    }

    private static func parseModDate(from line: String) -> Date? {
        guard let range = line.range(of: #"POSIX\s+(\d+)"#, options: .regularExpression) else {
            return nil
        }
        let match = String(line[range])
        let digits = match.replacingOccurrences(of: "POSIX", with: "").trimmingCharacters(in: .whitespaces)
        guard let seconds = TimeInterval(digits) else {
            return nil
        }
        return Date(timeIntervalSince1970: seconds)
    }
}
