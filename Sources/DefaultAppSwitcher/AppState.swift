import AppKit
import DefaultAppSwitcherCore
import Foundation
import Observation

enum SidebarSelection: Hashable {
    case overview
    case app(String) // lowercased bundleID
}

enum AppDetailTab: String, CaseIterable, Identifiable {
    case associations
    case permissions

    var id: String { rawValue }
}

struct PendingResetConfirmation: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let items: [AppAssociation]
    let includesBrowserAndSchemesToggle: Bool
    let allThirdPartyItems: [AppAssociation]
}

struct StatusBanner: Identifiable {
    let id = UUID()
    let title: String
    let detail: String?
    let isError: Bool
}

@MainActor
@Observable
final class AppState {
    static let languageDefaultsKey = "DefaultAppSwitcher.appLanguage"

    private let lsManager = LaunchServicesManager()
    private let permissionInspector = AppPermissionInspector()
    private let snapshotStore = SnapshotStore()

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageDefaultsKey)
        }
    }

    var strings: AppStrings {
        AppStrings(language: language)
    }

    var selection: SidebarSelection? = .overview
    var sidebarSearchText: String = ""
    var showOnlyThirdPartyInAllApps: Bool = false

    var installedApps: [InstalledApp] = []
    var overrides: [HandlerOverride] = []
    var allOverrideAssociations: [AppAssociation] = []
    var snapshots: [ResetSnapshot] = []

    var selectedAppTab: AppDetailTab = .associations
    var selectedAppAssociations: [AppAssociation] = []
    var selectedAppOtherExtensions: [DeclaredExtensionStatus] = []
    var selectedAppReport: AppSecurityReport?

    var isLoadingInitial: Bool = false
    var isLoadingAppDetail: Bool = false
    var isMutating: Bool = false

    private var loadedDetailAppID: String?
    private var activeDetailRequestID: UUID?

    var pendingResetConfirmation: PendingResetConfirmation?
    var isShowingSnapshotsSheet: Bool = false
    var statusBanner: StatusBanner?

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.languageDefaultsKey)
        self.language = AppLanguage.resolveInitial(storedCode: stored)
    }

    var appsWithOverrides: [InstalledApp] {
        installedApps
            .filter { $0.overrideCount > 0 && !$0.isAppleApp }
            .sorted { lhs, rhs in
                if lhs.overrideCount != rhs.overrideCount {
                    return lhs.overrideCount > rhs.overrideCount
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    var filteredAllApps: [InstalledApp] {
        installedApps.filter { app in
            if showOnlyThirdPartyInAllApps && app.isAppleApp {
                return false
            }
            let query = sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            return app.name.localizedCaseInsensitiveContains(query)
                || app.bundleID.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedApp: InstalledApp? {
        guard case .app(let bundleID) = selection else { return nil }
        return installedApps.first { $0.id == bundleID }
    }

    var thirdPartyOverrideAssociations: [AppAssociation] {
        allOverrideAssociations.filter { !DefaultAppResolver.isAppleBundleID($0.currentBundleID) }
    }

    var resettableThirdPartyOverrides: [AppAssociation] {
        thirdPartyOverrideAssociations.filter { $0.canResetToSystemDefault }
    }

    var thirdPartyFileOverrideAssociations: [AppAssociation] {
        thirdPartyOverrideAssociations.filter { $0.kind != .urlScheme && $0.category != .web }
    }

    var resettableThirdPartyFileOverrides: [AppAssociation] {
        thirdPartyFileOverrideAssociations.filter { $0.canResetToSystemDefault }
    }

    var thirdPartyMediaOverrideAssociations: [AppAssociation] {
        thirdPartyOverrideAssociations.filter { $0.category.isMedia || $0.isSuspiciousCollision }
    }

    var resettableThirdPartyMediaOverrides: [AppAssociation] {
        thirdPartyMediaOverrideAssociations.filter { $0.canResetToSystemDefault }
    }

    var affectedThirdPartyAppCount: Int {
        Set(thirdPartyOverrideAssociations.map { $0.normalizedBundleID }).count
    }

    var collisionOverrideCount: Int {
        allOverrideAssociations.filter { $0.isSuspiciousCollision }.count
    }

    func loadInitialIfNeeded() async {
        guard installedApps.isEmpty && !isLoadingInitial else { return }
        await reloadAll()
    }

    func reloadAll() async {
        isLoadingInitial = true
        defer { isLoadingInitial = false }

        do {
            let fetchedOverrides = try await lsManager.fetchHandlerOverrides()
            async let appsTask = lsManager.scanInstalledApps(overrides: fetchedOverrides)
            async let allAssocTask = lsManager.allOverrideAssociations(from: fetchedOverrides)
            async let snapshotsTask = snapshotStore.loadAll()

            self.overrides = fetchedOverrides
            self.installedApps = await appsTask
            self.allOverrideAssociations = await allAssocTask
            self.snapshots = await snapshotsTask

            if let app = selectedApp {
                await loadDetail(for: app)
            }
        } catch {
            let detail = (error as? LaunchServicesError)?.message(in: language) ?? error.localizedDescription
            statusBanner = StatusBanner(
                title: strings.loadFailedTitle,
                detail: detail,
                isError: true
            )
        }
    }

    func selectApp(_ app: InstalledApp) {
        selection = .app(app.id)
    }

    func loadSelectedAppDetailIfNeeded() async {
        guard let app = selectedApp else {
            loadedDetailAppID = nil
            activeDetailRequestID = nil
            selectedAppAssociations = []
            selectedAppOtherExtensions = []
            selectedAppReport = nil
            return
        }
        await loadDetail(for: app)
    }

    func loadDetail(for app: InstalledApp) async {
        let requestID = UUID()
        activeDetailRequestID = requestID

        if loadedDetailAppID != app.id {
            loadedDetailAppID = app.id
            selectedAppAssociations = []
            selectedAppOtherExtensions = []
            selectedAppReport = nil
        }

        isLoadingAppDetail = true

        async let assocTask = lsManager.associations(for: app, overrides: overrides)
        async let reportTask = permissionInspector.inspect(app: app)

        let assocs = await assocTask
        let others = await lsManager.declaredOtherExtensions(for: app, activeAssociations: assocs)
        let report = await reportTask

        guard activeDetailRequestID == requestID, selectedApp?.id == app.id else {
            return
        }

        self.selectedAppAssociations = assocs
        self.selectedAppOtherExtensions = others
        self.selectedAppReport = report
        self.isLoadingAppDetail = false
    }

    // MARK: - Reset Actions

    func promptGlobalResetAll() {
        let thirdParty = resettableThirdPartyOverrides
        let fileOnly = resettableThirdPartyFileOverrides
        pendingResetConfirmation = PendingResetConfirmation(
            title: strings.globalResetTitle,
            subtitle: strings.globalResetSubtitle,
            items: fileOnly,
            includesBrowserAndSchemesToggle: true,
            allThirdPartyItems: thirdParty
        )
    }

    func promptMediaReset() {
        let mediaItems = resettableThirdPartyMediaOverrides
        pendingResetConfirmation = PendingResetConfirmation(
            title: strings.mediaResetTitle,
            subtitle: strings.mediaResetSubtitle,
            items: mediaItems,
            includesBrowserAndSchemesToggle: false,
            allThirdPartyItems: mediaItems
        )
    }

    var resettableSelectedAppAssociations: [AppAssociation] {
        let explicitResettable = selectedAppAssociations.filter { $0.isExplicitOverride && $0.canResetToSystemDefault }
        if !explicitResettable.isEmpty {
            return explicitResettable
        }
        return selectedAppAssociations.filter { $0.canResetToSystemDefault }
    }

    func promptResetForSelectedApp() {
        guard let app = selectedApp else { return }
        let resettable = resettableSelectedAppAssociations
        pendingResetConfirmation = PendingResetConfirmation(
            title: strings.appResetTitle(app.name),
            subtitle: strings.appResetSubtitle(app.name),
            items: resettable,
            includesBrowserAndSchemesToggle: false,
            allThirdPartyItems: resettable
        )
    }

    func executePendingReset(items: [AppAssociation], title: String) async {
        pendingResetConfirmation = nil
        await performBulkReset(items: items, snapshotTitle: title)
    }

    func resetSingleAssociation(_ item: AppAssociation) async {
        await performBulkReset(
            items: [item],
            snapshotTitle: strings.singleResetSnapshotTitle(item.displayExtensionsText)
        )
    }

    func setSingleAssociation(_ item: AppAssociation, toAppAt appURL: URL) async {
        guard let targetBundleID = Bundle(url: appURL)?.bundleIdentifier else { return }
        isMutating = true
        defer { isMutating = false }

        do {
            try await lsManager.setAssociation(item, to: appURL, bundleID: targetBundleID, snapshotStore: snapshotStore)
            let targetName = DefaultAppResolver.displayName(for: appURL)
            statusBanner = StatusBanner(
                title: strings.updatedTitle(item.displayExtensionsText),
                detail: strings.newDefaultDetail(targetName),
                isError: false
            )
            await reloadAll()
        } catch {
            let detail = (error as? LaunchServicesError)?.message(in: language) ?? error.localizedDescription
            statusBanner = StatusBanner(
                title: strings.changeFailedTitle,
                detail: detail,
                isError: true
            )
        }
    }

    func performBulkReset(items: [AppAssociation], snapshotTitle: String) async {
        isMutating = true
        defer { isMutating = false }

        let result = await lsManager.resetAssociations(
            items,
            snapshotTitle: snapshotTitle,
            snapshotStore: snapshotStore
        )

        if result.failed.isEmpty {
            statusBanner = StatusBanner(
                title: strings.resetSuccessTitle(result.succeeded),
                detail: strings.resetSuccessDetail(skipped: result.skipped),
                isError: false
            )
        } else {
            let firstErr = result.failed.first?.reason ?? ""
            statusBanner = StatusBanner(
                title: strings.resetPartialTitle(succeeded: result.succeeded, failed: result.failed.count),
                detail: firstErr,
                isError: result.succeeded == 0
            )
        }

        await reloadAll()
    }

    // MARK: - Snapshots

    func restoreSnapshot(_ snapshot: ResetSnapshot) async {
        isMutating = true
        defer { isMutating = false }
        isShowingSnapshotsSheet = false

        let result = await lsManager.restoreSnapshot(snapshot, language: language)
        if result.failed.isEmpty {
            statusBanner = StatusBanner(
                title: strings.restoreSuccessTitle,
                detail: strings.restoreSuccessDetail(result.succeeded),
                isError: false
            )
        } else {
            statusBanner = StatusBanner(
                title: strings.restorePartialTitle(succeeded: result.succeeded, failed: result.failed.count),
                detail: result.failed.first?.reason,
                isError: result.succeeded == 0
            )
        }
        await reloadAll()
    }

    func deleteSnapshot(_ snapshot: ResetSnapshot) async {
        try? await snapshotStore.delete(id: snapshot.id)
        snapshots = await snapshotStore.loadAll()
    }

    // MARK: - TCC / Permissions Actions

    func resetTCCPermission(service: String, for app: InstalledApp) async {
        isMutating = true
        defer { isMutating = false }

        do {
            let output = try await permissionInspector.resetTCCPermission(
                service: service,
                bundleID: app.bundleID,
                language: language
            )
            statusBanner = StatusBanner(
                title: strings.tccResetSuccessTitle(app.name),
                detail: output,
                isError: false
            )
            await loadDetail(for: app)
        } catch {
            let detail = (error as? TCCResetError)?.message(in: language) ?? error.localizedDescription
            statusBanner = StatusBanner(
                title: strings.tccResetFailedTitle,
                detail: detail,
                isError: true
            )
        }
    }

    func openSystemSettings(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    func openFullDiskAccessSettings() {
        if let url = AppPermissionInspector.fullDiskAccessSettingsURL() {
            NSWorkspace.shared.open(url)
        }
    }

    func revealAppInFinder(_ app: InstalledApp) {
        NSWorkspace.shared.activateFileViewerSelecting([app.url])
    }
}
