import AppKit
import CoreServices
import Foundation
import UniformTypeIdentifiers

public protocol DefaultHandlerMutating: Sendable {
    func setDefault(appURL: URL, bundleID: String, for kind: HandlerKind, identifier: String) async throws
}

public enum LaunchServicesError: LocalizedError, Sendable {
    case lsregisterFailed(String)
    case setDefaultFailed(identifier: String, reason: String)
    case noTargetApp(identifier: String)

    public var errorDescription: String? {
        switch self {
        case .lsregisterFailed(let detail):
            return "LaunchServices veritabanı okunamadı: \(detail)"
        case .setDefaultFailed(let identifier, let reason):
            return "\(identifier) için varsayılan uygulama değiştirilemedi: \(reason)"
        case .noTargetApp(let identifier):
            return "\(identifier) için uygun bir sistem varsayılan uygulaması bulunamadı."
        }
    }
}

public struct SystemDefaultHandlerMutator: DefaultHandlerMutating {
    public init() {}

    public func setDefault(appURL: URL, bundleID: String, for kind: HandlerKind, identifier: String) async throws {
        switch kind {
        case .contentType:
            try await setContentTypeDefault(appURL: appURL, bundleID: bundleID, utiIdentifier: identifier)

        case .urlScheme:
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: identifier)
            } catch {
                let status = LSSetDefaultHandlerForURLScheme(identifier as CFString, bundleID as CFString)
                if status != noErr {
                    throw LaunchServicesError.setDefaultFailed(
                        identifier: identifier,
                        reason: "\(error.localizedDescription) (LSStatus: \(status))"
                    )
                }
            }

        case .extensionOnly:
            var targetUTIs = UTType.types(tag: identifier, tagClass: .filenameExtension, conformingTo: nil)
            if let preferred = UTType(filenameExtension: identifier),
               !targetUTIs.contains(where: { $0.identifier.lowercased() == preferred.identifier.lowercased() }) {
                targetUTIs.append(preferred)
            }
            let extensionBase = UTType(exportedAs: "com.justlacia.defaultappswitcher.extension-override")
            if let dynamicExtUTI = UTType(tag: identifier, tagClass: .filenameExtension, conformingTo: extensionBase),
               !targetUTIs.contains(where: { $0.identifier.lowercased() == dynamicExtUTI.identifier.lowercased() }) {
                targetUTIs.append(dynamicExtUTI)
            }

            if targetUTIs.isEmpty {
                throw LaunchServicesError.setDefaultFailed(
                    identifier: identifier,
                    reason: "'\(identifier)' uzantısı için geçerli bir UTType bulunamadı."
                )
            }
            var lastError: Error?
            var succeededAny = false
            for ut in targetUTIs {
                do {
                    try await setContentTypeDefault(appURL: appURL, bundleID: bundleID, utiIdentifier: ut.identifier)
                    succeededAny = true
                } catch {
                    lastError = error
                }
            }
            if !succeededAny, let lastError {
                throw lastError
            }
        }
    }

    private func setContentTypeDefault(appURL: URL, bundleID: String, utiIdentifier: String) async throws {
        if let utType = UTType(utiIdentifier) {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: utType)
                return
            } catch {
                let status = LSSetDefaultRoleHandlerForContentType(
                    utiIdentifier as CFString,
                    .all,
                    bundleID as CFString
                )
                if status == noErr {
                    return
                }
                throw LaunchServicesError.setDefaultFailed(
                    identifier: utiIdentifier,
                    reason: "\(error.localizedDescription) (LSStatus: \(status))"
                )
            }
        } else {
            let status = LSSetDefaultRoleHandlerForContentType(
                utiIdentifier as CFString,
                .all,
                bundleID as CFString
            )
            if status != noErr {
                throw LaunchServicesError.setDefaultFailed(
                    identifier: utiIdentifier,
                    reason: "Tanımlanmamış UTI ataması başarısız (LSStatus: \(status))"
                )
            }
        }
    }
}

public final class LaunchServicesManager: Sendable {
    public static let lsregisterPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    private let mutator: any DefaultHandlerMutating

    public init(mutator: any DefaultHandlerMutating = SystemDefaultHandlerMutator()) {
        self.mutator = mutator
    }

    public func fetchHandlerOverrides() async throws -> [HandlerOverride] {
        let output = try await runProcess(
            executablePath: Self.lsregisterPath,
            arguments: ["-dump", "HandlerPref"]
        )
        return HandlerPrefParser.parse(output)
    }

    public func scanInstalledApps(overrides: [HandlerOverride]) async -> [InstalledApp] {
        await Task.detached(priority: .userInitiated) {
            var overrideCounts: [String: Int] = [:]
            for item in overrides {
                overrideCounts[item.normalizedBundleID, default: 0] += 1
            }

            var candidateURLs: [URL] = []
            let fm = FileManager.default
            let searchRoots: [URL] = [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
                URL(fileURLWithPath: "/System/Applications", isDirectory: true),
                URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
                URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Applications", isDirectory: true)
            ]

            for root in searchRoots {
                guard let items = try? fm.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    continue
                }
                for item in items where item.pathExtension.lowercased() == "app" {
                    candidateURLs.append(item)
                }
            }

            // Ensure every app referenced in active overrides is also included even if outside standard dirs.
            for bundleID in overrideCounts.keys {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    candidateURLs.append(url)
                }
            }

            var appsByBundleID: [String: InstalledApp] = [:]

            for url in candidateURLs {
                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      !bundleID.isEmpty else {
                    continue
                }

                let key = bundleID.lowercased()
                let priority = Self.appLocationPriority(url)
                if let existing = appsByBundleID[key], Self.appLocationPriority(existing.url) <= priority {
                    continue
                }

                let info = bundle.infoDictionary ?? [:]
                let name = DefaultAppResolver.displayName(for: url, bundle: bundle, fallbackBundleID: bundleID)
                let version = (info["CFBundleShortVersionString"] as? String) ?? "-"
                let buildNumber = (info["CFBundleVersion"] as? String) ?? "-"

                let (declaredUTIs, declaredExts) = Self.extractDeclaredTypes(from: info)
                let declaredSchemes = Self.extractDeclaredSchemes(from: info)

                let ovCount = overrideCounts[key, default: 0]

                let app = InstalledApp(
                    bundleID: bundleID,
                    name: name,
                    url: url,
                    version: version,
                    buildNumber: buildNumber,
                    isAppleApp: DefaultAppResolver.isAppleBundleID(bundleID),
                    overrideCount: ovCount,
                    defaultAssociationCount: ovCount,
                    declaredExtensions: declaredExts,
                    declaredUTIs: declaredUTIs,
                    declaredSchemes: declaredSchemes
                )
                appsByBundleID[key] = app
            }

            // Also synthesize fallback entries for overrides whose bundle isn't installed anymore.
            for (lowerBundleID, count) in overrideCounts where appsByBundleID[lowerBundleID] == nil {
                let app = InstalledApp(
                    bundleID: lowerBundleID,
                    name: lowerBundleID,
                    url: URL(fileURLWithPath: "/Applications/\(lowerBundleID).app"),
                    version: "-",
                    buildNumber: "-",
                    isAppleApp: DefaultAppResolver.isAppleBundleID(lowerBundleID),
                    isInstalled: false,
                    overrideCount: count,
                    defaultAssociationCount: count,
                    declaredExtensions: [],
                    declaredUTIs: [],
                    declaredSchemes: []
                )
                appsByBundleID[lowerBundleID] = app
            }

            return appsByBundleID.values.sorted { lhs, rhs in
                if lhs.overrideCount != rhs.overrideCount {
                    return lhs.overrideCount > rhs.overrideCount
                }
                if lhs.isAppleApp != rhs.isAppleApp {
                    return !lhs.isAppleApp
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }.value
    }

    public func allOverrideAssociations(from overrides: [HandlerOverride]) async -> [AppAssociation] {
        await Task.detached(priority: .userInitiated) {
            overrides.map { override in
                Self.buildAssociation(
                    kind: override.kind,
                    identifier: override.identifier,
                    currentBundleID: override.bundleID,
                    isExplicitOverride: true,
                    overrideModDate: override.modDate
                )
            }
            .sorted { lhs, rhs in
                if lhs.isSuspiciousCollision != rhs.isSuspiciousCollision {
                    return lhs.isSuspiciousCollision
                }
                if lhs.currentAppName != rhs.currentAppName {
                    return lhs.currentAppName.localizedCaseInsensitiveCompare(rhs.currentAppName) == .orderedAscending
                }
                return lhs.displayExtensionsText.localizedCaseInsensitiveCompare(rhs.displayExtensionsText) == .orderedAscending
            }
        }.value
    }

    public func associations(for app: InstalledApp, overrides: [HandlerOverride]) async -> [AppAssociation] {
        await Task.detached(priority: .userInitiated) {
            let targetLower = app.id
            var resultByID: [String: AppAssociation] = [:]

            // 1. All active LaunchServices HandlerPref overrides pointing to this app.
            for override in overrides where override.normalizedBundleID == targetLower {
                let assoc = Self.buildAssociation(
                    kind: override.kind,
                    identifier: override.identifier,
                    currentBundleID: app.bundleID,
                    isExplicitOverride: true,
                    overrideModDate: override.modDate
                )
                resultByID[assoc.id] = assoc
            }

            // 2. Also inspect UTI/extensions/URL schemes declared in the app's Info.plist
            // to detect default associations not captured in HandlerPref (skipping uninstalled or dynamic/private UTIs).
            if app.isInstalled {
                for uti in app.declaredUTIs {
                    guard !DefaultAppResolver.isPrivatePluginOrPackageUTI(uti) else { continue }
                    let id = "\(HandlerKind.contentType.rawValue):\(uti.lowercased())"
                    guard resultByID[id] == nil, let ut = UTType(uti), !ut.isDynamic else { continue }
                    if let currentURL = NSWorkspace.shared.urlForApplication(toOpen: ut),
                       let currentBundleID = Bundle(url: currentURL)?.bundleIdentifier,
                       currentBundleID.lowercased() == targetLower {
                        let assoc = Self.buildAssociation(
                            kind: .contentType,
                            identifier: uti,
                            currentBundleID: currentBundleID,
                            isExplicitOverride: false,
                            overrideModDate: nil
                        )
                        resultByID[assoc.id] = assoc
                    }
                }

                for ext in app.declaredExtensions where ext != "*" {
                    if let ut = UTType(filenameExtension: ext), !ut.isDynamic {
                        let id = "\(HandlerKind.contentType.rawValue):\(ut.identifier.lowercased())"
                        guard resultByID[id] == nil else { continue }
                        if let currentURL = NSWorkspace.shared.urlForApplication(toOpen: ut),
                           let currentBundleID = Bundle(url: currentURL)?.bundleIdentifier,
                           currentBundleID.lowercased() == targetLower {
                            let assoc = Self.buildAssociation(
                                kind: .contentType,
                                identifier: ut.identifier,
                                currentBundleID: currentBundleID,
                                isExplicitOverride: false,
                                overrideModDate: nil
                            )
                            resultByID[assoc.id] = assoc
                        }
                    }
                }

                for scheme in app.declaredSchemes {
                    let id = "\(HandlerKind.urlScheme.rawValue):\(scheme.lowercased())"
                    guard resultByID[id] == nil, let url = URL(string: "\(scheme)://") else { continue }
                    if let currentURL = NSWorkspace.shared.urlForApplication(toOpen: url),
                       let currentBundleID = Bundle(url: currentURL)?.bundleIdentifier,
                       currentBundleID.lowercased() == targetLower {
                        let assoc = Self.buildAssociation(
                            kind: .urlScheme,
                            identifier: scheme,
                            currentBundleID: currentBundleID,
                            isExplicitOverride: false,
                            overrideModDate: nil
                        )
                        resultByID[assoc.id] = assoc
                    }
                }
            }

            return resultByID.values.sorted { lhs, rhs in
                if lhs.isSuspiciousCollision != rhs.isSuspiciousCollision {
                    return lhs.isSuspiciousCollision
                }
                if lhs.isExplicitOverride != rhs.isExplicitOverride {
                    return lhs.isExplicitOverride
                }
                return lhs.displayExtensionsText.localizedCaseInsensitiveCompare(rhs.displayExtensionsText) == .orderedAscending
            }
        }.value
    }

    public func declaredOtherExtensions(
        for app: InstalledApp,
        activeAssociations: [AppAssociation]
    ) async -> [DeclaredExtensionStatus] {
        guard app.isInstalled else { return [] }
        return await Task.detached(priority: .userInitiated) {
            let activeExts = Set(activeAssociations.flatMap { $0.extensions.map { $0.lowercased() } })
            var results: [DeclaredExtensionStatus] = []
            for ext in app.declaredExtensions where ext != "*" && !activeExts.contains(ext.lowercased()) {
                let ut = UTType(filenameExtension: ext)
                let currentURL = ut.flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) }
                let currentBundle = currentURL.flatMap { Bundle(url: $0) }
                let currentName = currentURL.map { DefaultAppResolver.displayName(for: $0, bundle: currentBundle) }
                results.append(
                    DeclaredExtensionStatus(
                        ext: ext,
                        uti: ut?.identifier,
                        currentAppName: currentName,
                        currentBundleID: currentBundle?.bundleIdentifier
                    )
                )
            }
            return results.sorted { $0.ext.localizedCaseInsensitiveCompare($1.ext) == .orderedAscending }
        }.value
    }

    public func resetAssociations(
        _ items: [AppAssociation],
        snapshotTitle: String,
        snapshotStore: SnapshotStore
    ) async -> ResetResult {
        var entries: [SnapshotEntry] = []
        for item in items where item.canResetToSystemDefault {
            entries.append(
                SnapshotEntry(
                    kind: item.kind,
                    identifier: item.identifier,
                    previousBundleID: item.currentBundleID,
                    previousAppPath: item.currentAppURL?.path,
                    targetBundleID: item.recommendedDefault?.bundleID
                )
            )
        }

        var snapshotID: UUID?
        if !entries.isEmpty {
            let snapshot = ResetSnapshot(title: snapshotTitle, entries: entries)
            try? await snapshotStore.save(snapshot)
            snapshotID = snapshot.id
        }

        var succeeded = 0
        var skipped = 0
        var failures: [ResetFailure] = []

        for item in items {
            guard item.canResetToSystemDefault, let target = item.recommendedDefault else {
                skipped += 1
                continue
            }
            do {
                try await mutator.setDefault(
                    appURL: target.appURL,
                    bundleID: target.bundleID,
                    for: item.kind,
                    identifier: item.identifier
                )
                succeeded += 1
            } catch {
                // Special fallback for PostScript (.ps) when Preview refuses on newer macOS: try TextEdit.
                if item.identifier.lowercased() == "com.adobe.postscript",
                   target.bundleID.lowercased() != DefaultAppResolver.BundleID.textEdit.lowercased(),
                   let textEdit = DefaultAppResolver.resolveApp(bundleID: DefaultAppResolver.BundleID.textEdit) {
                    do {
                        try await mutator.setDefault(
                            appURL: textEdit.appURL,
                            bundleID: textEdit.bundleID,
                            for: item.kind,
                            identifier: item.identifier
                        )
                        succeeded += 1
                        continue
                    } catch {
                        failures.append(ResetFailure(identifier: item.identifier, reason: error.localizedDescription))
                        continue
                    }
                }
                failures.append(ResetFailure(identifier: item.identifier, reason: error.localizedDescription))
            }
        }

        return ResetResult(
            succeeded: succeeded,
            failed: failures,
            skipped: skipped,
            snapshotID: snapshotID
        )
    }

    public func setAssociation(
        _ item: AppAssociation,
        to targetURL: URL,
        bundleID: String,
        snapshotStore: SnapshotStore
    ) async throws {
        let snapshot = ResetSnapshot(
            title: "\(item.displayExtensionsText) → \(DefaultAppResolver.displayName(for: targetURL))",
            entries: [
                SnapshotEntry(
                    kind: item.kind,
                    identifier: item.identifier,
                    previousBundleID: item.currentBundleID,
                    previousAppPath: item.currentAppURL?.path,
                    targetBundleID: bundleID
                )
            ]
        )
        try? await snapshotStore.save(snapshot)
        try await mutator.setDefault(appURL: targetURL, bundleID: bundleID, for: item.kind, identifier: item.identifier)
    }

    public func restoreSnapshot(_ snapshot: ResetSnapshot) async -> ResetResult {
        var succeeded = 0
        var skipped = 0
        var failures: [ResetFailure] = []

        for entry in snapshot.entries {
            let resolvedURL: URL? = {
                if let path = entry.previousAppPath, FileManager.default.fileExists(atPath: path) {
                    return URL(fileURLWithPath: path)
                }
                return NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.previousBundleID)
                    ?? DefaultAppResolver.resolveApp(bundleID: entry.previousBundleID)?.appURL
            }()

            guard let appURL = resolvedURL else {
                skipped += 1
                failures.append(
                    ResetFailure(
                        identifier: entry.identifier,
                        reason: "Önceki uygulama (\(entry.previousBundleID)) artık sistemde bulunamadı."
                    )
                )
                continue
            }

            do {
                try await mutator.setDefault(
                    appURL: appURL,
                    bundleID: entry.previousBundleID,
                    for: entry.kind,
                    identifier: entry.identifier
                )
                succeeded += 1
            } catch {
                failures.append(ResetFailure(identifier: entry.identifier, reason: error.localizedDescription))
            }
        }

        return ResetResult(succeeded: succeeded, failed: failures, skipped: skipped, snapshotID: snapshot.id)
    }

    // MARK: - Helpers

    private static func buildAssociation(
        kind: HandlerKind,
        identifier: String,
        currentBundleID: String,
        isExplicitOverride: Bool,
        overrideModDate: Date?
    ) -> AppAssociation {
        let currentURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: currentBundleID)
            ?? DefaultAppResolver.resolveApp(bundleID: currentBundleID)?.appURL
        let currentBundle = currentURL.flatMap { Bundle(url: $0) }
        let resolvedBundleID = currentBundle?.bundleIdentifier ?? currentBundleID
        let currentName = currentURL.map {
            DefaultAppResolver.displayName(for: $0, bundle: currentBundle, fallbackBundleID: resolvedBundleID)
        } ?? resolvedBundleID

        let utType: UTType? = (kind == .contentType) ? UTType(identifier) : (kind == .extensionOnly ? UTType(filenameExtension: identifier) : nil)

        var exts: [String] = []
        switch kind {
        case .contentType:
            exts = utType?.tags[.filenameExtension] ?? []
            if exts.isEmpty, identifier.lowercased().hasPrefix("io.iina.") {
                let suffix = identifier.split(separator: ".").last.map(String.init) ?? ""
                if !suffix.isEmpty && !suffix.contains("-") {
                    exts = [suffix]
                }
            }
        case .extensionOnly:
            exts = [identifier]
        case .urlScheme:
            exts = []
        }

        let localizedDescription: String
        if kind == .urlScheme {
            localizedDescription = "\(identifier):// URL Şeması"
        } else if let desc = utType?.localizedDescription, !desc.isEmpty {
            localizedDescription = desc
        } else {
            localizedDescription = identifier
        }

        let category = DefaultAppResolver.categorize(
            kind: kind,
            identifier: identifier,
            extensions: exts,
            utType: utType
        )

        let candidateURLs: [URL] = {
            switch kind {
            case .contentType, .extensionOnly:
                if let utType {
                    return deduplicateAppURLs(NSWorkspace.shared.urlsForApplications(toOpen: utType))
                }
                if let firstExt = exts.first, let fallbackUT = UTType(filenameExtension: firstExt) {
                    return deduplicateAppURLs(NSWorkspace.shared.urlsForApplications(toOpen: fallbackUT))
                }
                return []
            case .urlScheme:
                if let url = URL(string: "\(identifier)://") {
                    return deduplicateAppURLs(NSWorkspace.shared.urlsForApplications(toOpen: url))
                }
                return []
            }
        }()

        let collision = DefaultAppResolver.detectCollision(
            kind: kind,
            identifier: identifier,
            extensions: exts,
            category: category,
            currentBundleID: resolvedBundleID
        )

        let recommended = DefaultAppResolver.recommendedSystemDefault(
            for: kind,
            identifier: identifier,
            extensions: exts,
            category: category,
            excludingBundleID: resolvedBundleID,
            candidateAppURLs: candidateURLs
        )

        return AppAssociation(
            kind: kind,
            identifier: identifier,
            extensions: exts,
            localizedDescription: localizedDescription,
            category: category,
            currentBundleID: resolvedBundleID,
            currentAppURL: currentURL,
            currentAppName: currentName,
            isExplicitOverride: isExplicitOverride,
            overrideModDate: overrideModDate,
            isSuspiciousCollision: collision.isCollision,
            collisionReason: collision.reason,
            recommendedDefault: recommended,
            candidateAppURLs: candidateURLs
        )
    }

    private static func deduplicateAppURLs(_ urls: [URL]) -> [URL] {
        var seenBundleIDs = Set<String>()
        var unique: [URL] = []
        for url in urls {
            let bundleID = Bundle(url: url)?.bundleIdentifier?.lowercased() ?? url.path.lowercased()
            if seenBundleIDs.insert(bundleID).inserted {
                unique.append(url)
            }
        }
        return unique
    }

    private static func extractDeclaredTypes(from info: [String: Any]) -> (utis: [String], extensions: [String]) {
        var utis = Set<String>()
        var exts = Set<String>()
        if let docTypes = info["CFBundleDocumentTypes"] as? [[String: Any]] {
            for doc in docTypes {
                if let contentTypes = doc["LSItemContentTypes"] as? [String] {
                    for uti in contentTypes where !uti.isEmpty {
                        utis.insert(uti)
                    }
                }
                if let typeExts = doc["CFBundleTypeExtensions"] as? [String] {
                    for ext in typeExts where !ext.isEmpty {
                        exts.insert(ext.lowercased())
                    }
                }
            }
        }
        return (utis.sorted(), exts.sorted())
    }

    private static func extractDeclaredSchemes(from info: [String: Any]) -> [String] {
        var schemes = Set<String>()
        if let urlTypes = info["CFBundleURLTypes"] as? [[String: Any]] {
            for item in urlTypes {
                if let urlSchemes = item["CFBundleURLSchemes"] as? [String] {
                    for scheme in urlSchemes where !scheme.isEmpty {
                        schemes.insert(scheme)
                    }
                }
            }
        }
        return schemes.sorted()
    }

    private static func appLocationPriority(_ url: URL) -> Int {
        let path = url.path
        if path.hasPrefix("/Applications/") { return 0 }
        if path.hasPrefix("/System/Applications/") { return 1 }
        if path.hasPrefix(NSHomeDirectory() + "/Applications/") { return 2 }
        return 3
    }

    private func runProcess(executablePath: String, arguments: [String]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errText = String(data: errData, encoding: .utf8) ?? "Bilinmeyen hata"
                throw LaunchServicesError.lsregisterFailed(errText)
            }
            return String(data: data, encoding: .utf8) ?? ""
        }.value
    }
}
