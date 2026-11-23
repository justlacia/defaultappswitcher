import AppKit
import DefaultAppSwitcherCore
import Foundation
import Observation

enum SidebarSelection: Hashable {
    case overview
    case app(String) // lowercased bundleID
}

enum AppDetailTab: String, CaseIterable, Identifiable {
    case associations = "Varsayılan Uzantılar"
    case permissions = "İzinler & Güvenlik"

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
    private let lsManager = LaunchServicesManager()
    private let permissionInspector = AppPermissionInspector()
    private let snapshotStore = SnapshotStore()

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
            statusBanner = StatusBanner(
                title: "Veriler yüklenemedi",
                detail: error.localizedDescription,
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
            title: "Tüm Özel Varsayılanları Sıfırla",
            subtitle: "Sistem dışı uygulamalara atanmış tüm dosya uzantılarını macOS varsayılanlarına (QuickTime, Müzik, TextEdit vb.) döndürür.",
            items: fileOnly,
            includesBrowserAndSchemesToggle: true,
            allThirdPartyItems: thirdParty
        )
    }

    func promptMediaReset() {
        let mediaItems = resettableThirdPartyMediaOverrides
        pendingResetConfirmation = PendingResetConfirmation(
            title: "Medya Uzantılarını Sıfırla",
            subtitle: "Video, ses ve yanlışlıkla medya oynatıcılara bağlanmış (.ts, .ps vb.) uzantıları tek tuşla Apple uygulamalarına döndürür.",
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
            title: "\(app.name) Varsayılanlarını Sıfırla",
            subtitle: "\(app.name) uygulamasına bağlı varsayılan dosya uzantıları önerilen sistem uygulamalarına geri alınacaktır.",
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
            snapshotTitle: "\(item.displayExtensionsText) sıfırlandı"
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
                title: "\(item.displayExtensionsText) güncellendi",
                detail: "Yeni varsayılan uygulama: \(targetName)",
                isError: false
            )
            await reloadAll()
        } catch {
            statusBanner = StatusBanner(
                title: "Varsayılan değiştirilemedi",
                detail: error.localizedDescription,
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
                title: "\(result.succeeded) uzantı varsayılana sıfırlandı",
                detail: result.skipped > 0 ? "\(result.skipped) öğe atlandı (sistem alternatifi yok). Yedek kaydedildi." : "Otomatik yedek oluşturuldu; istediğiniz zaman Geri Al ile dönebilirsiniz.",
                isError: false
            )
        } else {
            let firstErr = result.failed.first?.reason ?? ""
            statusBanner = StatusBanner(
                title: "\(result.succeeded) sıfırlandı, \(result.failed.count) başarısız",
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

        let result = await lsManager.restoreSnapshot(snapshot)
        if result.failed.isEmpty {
            statusBanner = StatusBanner(
                title: "Yedek geri yüklendi",
                detail: "\(result.succeeded) varsayılan atama önceki haline döndürüldü.",
                isError: false
            )
        } else {
            statusBanner = StatusBanner(
                title: "Kısmi geri yükleme: \(result.succeeded) başarılı, \(result.failed.count) hata",
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
            let output = try await permissionInspector.resetTCCPermission(service: service, bundleID: app.bundleID)
            statusBanner = StatusBanner(
                title: "\(app.name) gizlilik izni sıfırlandı",
                detail: output,
                isError: false
            )
            await loadDetail(for: app)
        } catch {
            statusBanner = StatusBanner(
                title: "Gizlilik izni sıfırlanamadı",
                detail: error.localizedDescription,
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
