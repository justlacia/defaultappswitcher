import Foundation
import Testing
import UniformTypeIdentifiers
@testable import DefaultAppSwitcherCore

actor MockHandlerMutator: DefaultHandlerMutating {
    struct Call: Sendable, Equatable {
        let bundleID: String
        let kind: HandlerKind
        let identifier: String
    }

    private(set) var calls: [Call] = []
    var failingIdentifiers: Set<String> = []

    func setFailingIdentifiers(_ ids: Set<String>) {
        failingIdentifiers = ids
    }

    func setDefault(appURL: URL, bundleID: String, for kind: HandlerKind, identifier: String) async throws {
        if failingIdentifiers.contains(identifier) {
            throw LaunchServicesError.setDefaultFailed(identifier: identifier, reason: "Mock failure")
        }
        calls.append(Call(bundleID: bundleID, kind: kind, identifier: identifier))
    }
}

@Suite("DefaultAppSwitcherCore Tests")
struct DefaultAppSwitcherTests {
    @Test("HandlerPrefParser parses content types, URL schemes, extensions, and ignores bundle ver")
    func testHandlerPrefParser() {
        let sample = """
        --------------------------------------------------------------------------------
        handlerpref id:             public.mpeg-4 (0xb0)
        content type:               public.mpeg-4 (0xd8b0)
        all roles:                  com.colliderli.iina
        mod date:                   2026-11-23 13:32 (POSIX 1795429978, 𝛥 27min 8sec)

        --------------------------------------------------------------------------------
        handlerpref id:             public.mp3 (0x158)
        content type:               public.mp3 (0xd8ec)
        all roles:                  com.apple.music
        all roles (bundle ver):     1.7.3
        mod date:                   2026-11-23 13:46 (POSIX 1795430795, 𝛥 13min 31sec)

        --------------------------------------------------------------------------------
        handlerpref id:             https (0x50)
        URL scheme:                 https
        all roles:                  com.google.chrome
        mod date:                   2026-09-10 17:26 (POSIX 1789050388, 𝛥 2mths)

        --------------------------------------------------------------------------------
        handlerpref id:             mkv (0x60)
        extension:                  mkv
        all roles:                  com.video.player.converter.fj.mp3
        mod date:                   2026-09-10 21:52 (POSIX 1789066378, 𝛥 2mths)
        """

        let parsed = HandlerPrefParser.parse(sample)
        #expect(parsed.count == 4)

        let mp4 = parsed.first { $0.identifier == "public.mpeg-4" }
        #expect(mp4?.kind == .contentType)
        #expect(mp4?.normalizedBundleID == "com.colliderli.iina")
        #expect(mp4?.modDate == Date(timeIntervalSince1970: 1795429978))

        let mp3 = parsed.first { $0.identifier == "public.mp3" }
        #expect(mp3?.bundleID == "com.apple.music")
        #expect(mp3?.roles == ["all roles"])

        let https = parsed.first { $0.identifier == "https" }
        #expect(https?.kind == .urlScheme)
        #expect(https?.normalizedBundleID == "com.google.chrome")

        let mkv = parsed.first { $0.identifier == "mkv" }
        #expect(mkv?.kind == .extensionOnly)
        #expect(mkv?.normalizedBundleID == "com.video.player.converter.fj.mp3")
    }

    @Test("DefaultAppResolver picks smart Apple defaults, avoids private plugins and false Apple collisions")
    func testDefaultAppResolverTargetsAndCollisions() {
        let aacTarget = DefaultAppResolver.recommendedSystemDefault(
            for: .contentType,
            identifier: "public.aac-audio",
            extensions: ["aac", "adts"],
            category: .audio,
            excludingBundleID: "com.colliderli.iina",
            candidateAppURLs: []
        )
        #expect(aacTarget?.bundleID.lowercased() == DefaultAppResolver.BundleID.quickTime.lowercased())

        let mp3Target = DefaultAppResolver.recommendedSystemDefault(
            for: .contentType,
            identifier: "public.mp3",
            extensions: ["mp3"],
            category: .audio,
            excludingBundleID: "com.colliderli.iina",
            candidateAppURLs: []
        )
        #expect(mp3Target?.bundleID.lowercased() == DefaultAppResolver.BundleID.music.lowercased())

        let mp4Target = DefaultAppResolver.recommendedSystemDefault(
            for: .contentType,
            identifier: "public.mpeg-4",
            extensions: ["mp4"],
            category: .video,
            excludingBundleID: "com.colliderli.iina",
            candidateAppURLs: []
        )
        #expect(mp4Target?.bundleID.lowercased() == DefaultAppResolver.BundleID.quickTime.lowercased())

        let tsCategory = DefaultAppResolver.categorize(
            kind: .contentType,
            identifier: "com.microsoft.typescript",
            extensions: ["ts", "tsx"],
            utType: UTType("com.microsoft.typescript")
        )
        #expect(tsCategory == .textCode)

        let tsTarget = DefaultAppResolver.recommendedSystemDefault(
            for: .contentType,
            identifier: "com.microsoft.typescript",
            extensions: ["ts", "tsx"],
            category: tsCategory,
            excludingBundleID: "com.colliderli.iina",
            candidateAppURLs: []
        )
        #expect(tsTarget?.bundleID.lowercased() == DefaultAppResolver.BundleID.textEdit.lowercased())

        let tsCollision = DefaultAppResolver.detectCollision(
            kind: .contentType,
            identifier: "com.microsoft.typescript",
            extensions: ["ts", "tsx"],
            category: tsCategory,
            currentBundleID: "com.colliderli.iina"
        )
        #expect(tsCollision.isCollision == true)

        let psCategory = DefaultAppResolver.categorize(
            kind: .contentType,
            identifier: "com.adobe.postscript",
            extensions: ["ps"],
            utType: UTType("com.adobe.postscript")
        )
        #expect(psCategory == .image)

        let psCollision = DefaultAppResolver.detectCollision(
            kind: .contentType,
            identifier: "com.adobe.postscript",
            extensions: ["ps"],
            category: psCategory,
            currentBundleID: "com.colliderli.iina"
        )
        #expect(psCollision.isCollision == true)

        let httpsTarget = DefaultAppResolver.recommendedSystemDefault(
            for: .urlScheme,
            identifier: "https",
            extensions: [],
            category: .web,
            excludingBundleID: "com.google.Chrome",
            candidateAppURLs: []
        )
        #expect(httpsTarget?.bundleID.lowercased() == DefaultAppResolver.BundleID.safari.lowercased())

        // Apple apps on extensionOnly must NOT be flagged as collisions
        let appleExtCollision = DefaultAppResolver.detectCollision(
            kind: .extensionOnly,
            identifier: "aa3",
            extensions: ["aa3"],
            category: .audio,
            currentBundleID: "com.apple.quicktimeplayerx"
        )
        #expect(appleExtCollision.isCollision == false)

        // Private app plugin UTIs must not be redirected to Archive Utility or other system apps
        let privatePluginTarget = DefaultAppResolver.recommendedSystemDefault(
            for: .contentType,
            identifier: "io.iina.iinaplgz",
            extensions: ["iinaplgz"],
            category: .archive,
            excludingBundleID: "com.colliderli.iina",
            candidateAppURLs: []
        )
        #expect(privatePluginTarget == nil)

        let privatePluginTarget2 = DefaultAppResolver.recommendedSystemDefault(
            for: .contentType,
            identifier: "io.iina.iinaplugin",
            extensions: ["iinaplugin"],
            category: .other,
            excludingBundleID: "com.colliderli.iina",
            candidateAppURLs: []
        )
        #expect(privatePluginTarget2 == nil)

        // Standard Apple default recognition
        #expect(DefaultAppResolver.isStandardAppleDefault(
            bundleID: DefaultAppResolver.BundleID.quickTime,
            for: .contentType,
            identifier: "public.mpeg-4",
            extensions: ["mp4"],
            category: .video
        ) == true)
        #expect(DefaultAppResolver.isStandardAppleDefault(
            bundleID: DefaultAppResolver.BundleID.music,
            for: .contentType,
            identifier: "public.mp3",
            extensions: ["mp3"],
            category: .audio
        ) == true)
        #expect(DefaultAppResolver.isStandardAppleDefault(
            bundleID: DefaultAppResolver.BundleID.textEdit,
            for: .contentType,
            identifier: "com.microsoft.typescript",
            extensions: ["ts"],
            category: .textCode
        ) == true)
        #expect(DefaultAppResolver.isStandardAppleDefault(
            bundleID: DefaultAppResolver.BundleID.safari,
            for: .urlScheme,
            identifier: "https",
            extensions: [],
            category: .web
        ) == true)
        #expect(DefaultAppResolver.isStandardAppleDefault(
            bundleID: DefaultAppResolver.BundleID.preview,
            for: .contentType,
            identifier: "com.adobe.postscript",
            extensions: ["ps"],
            category: .image
        ) == true)
        #expect(DefaultAppResolver.isStandardAppleDefault(
            bundleID: "com.apple.dt.xcode",
            for: .urlScheme,
            identifier: "xcode",
            extensions: [],
            category: .scheme
        ) == true)
    }

    @Test("SnapshotStore persists, prunes, and deletes snapshots in a temporary folder")
    func testSnapshotStoreLifecycle() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot_tests_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = SnapshotStore(directoryURL: tempDir)
        for index in 0..<28 {
            let snap = ResetSnapshot(
                createdAt: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + index)),
                title: "Yedek \(index)",
                entries: [
                    SnapshotEntry(
                        kind: .contentType,
                        identifier: "public.mpeg-4",
                        previousBundleID: "com.colliderli.iina",
                        previousAppPath: "/Applications/IINA.app",
                        targetBundleID: "com.apple.QuickTimePlayerX"
                    )
                ]
            )
            try await store.save(snap)
        }

        let loaded = await store.loadAll()
        #expect(loaded.count == 25)
        #expect(loaded.first?.title == "Yedek 27")

        if let firstID = loaded.first?.id {
            try await store.delete(id: firstID)
            let afterDelete = await store.loadAll()
            #expect(afterDelete.count == 24)
        }
    }

    @Test("LaunchServicesManager bulk reset (including extensionOnly) and snapshot restore use mock mutator")
    func testMockBulkResetAndRestore() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ls_manager_tests_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = SnapshotStore(directoryURL: tempDir)
        let mutator = MockHandlerMutator()
        let manager = LaunchServicesManager(mutator: mutator)

        let qtTarget = ResetTarget(
            bundleID: DefaultAppResolver.BundleID.quickTime,
            appName: "QuickTime Player",
            appURL: URL(fileURLWithPath: "/System/Applications/QuickTime Player.app")
        )

        let assoc1 = AppAssociation(
            kind: .contentType,
            identifier: "public.mpeg-4",
            extensions: ["mp4"],
            localizedDescription: "MPEG-4 Movie",
            category: .video,
            currentBundleID: "com.colliderli.iina",
            currentAppURL: URL(fileURLWithPath: "/Applications/IINA.app"),
            currentAppName: "IINA",
            isExplicitOverride: true,
            overrideModDate: nil,
            isSuspiciousCollision: false,
            collisionReason: nil,
            recommendedDefault: qtTarget,
            candidateAppURLs: []
        )

        let assocExt = AppAssociation(
            kind: .extensionOnly,
            identifier: "mkv",
            extensions: ["mkv"],
            localizedDescription: "Matroska Video",
            category: .video,
            currentBundleID: "com.video.player.converter.fj.mp3",
            currentAppURL: nil,
            currentAppName: "com.video.player.converter.fj.mp3",
            isExplicitOverride: true,
            overrideModDate: nil,
            isSuspiciousCollision: true,
            collisionReason: "Eski uzantı tabanlı kayıt",
            recommendedDefault: qtTarget,
            candidateAppURLs: []
        )

        let customSchemeNoTarget = AppAssociation(
            kind: .urlScheme,
            identifier: "iina",
            extensions: [],
            localizedDescription: "iina:// URL Şeması",
            category: .scheme,
            currentBundleID: "com.colliderli.iina",
            currentAppURL: URL(fileURLWithPath: "/Applications/IINA.app"),
            currentAppName: "IINA",
            isExplicitOverride: false,
            overrideModDate: nil,
            isSuspiciousCollision: false,
            collisionReason: nil,
            recommendedDefault: nil,
            candidateAppURLs: []
        )

        let resetResult = await manager.resetAssociations(
            [assoc1, assocExt, customSchemeNoTarget],
            snapshotTitle: "Test Sıfırlama",
            snapshotStore: store
        )
        #expect(resetResult.succeeded == 2)
        #expect(resetResult.skipped == 1)
        #expect(resetResult.failed.isEmpty)

        let mutatorCalls = await mutator.calls
        #expect(mutatorCalls.count == 2)
        #expect(mutatorCalls[0].bundleID == DefaultAppResolver.BundleID.quickTime)
        #expect(mutatorCalls[0].identifier == "public.mpeg-4")
        #expect(mutatorCalls[1].kind == .extensionOnly)
        #expect(mutatorCalls[1].identifier == "mkv")

        let snapshots = await store.loadAll()
        #expect(snapshots.count == 1)

        if let saved = snapshots.first {
            let restoreResult = await manager.restoreSnapshot(saved)
            #expect(restoreResult.succeeded == 1)
            #expect(restoreResult.skipped == 1)
            #expect(restoreResult.failed.count == 1)
        }
    }

    @Test("AppPermissionInspector safely inspects TextEdit, IINA, and uninstalled apps read-only")
    func testAppPermissionInspectorReadOnly() async {
        let inspector = AppPermissionInspector()
        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        let textEditApp = InstalledApp(
            bundleID: "com.apple.TextEdit",
            name: "TextEdit",
            url: textEditURL,
            version: "1.0",
            buildNumber: "1",
            isAppleApp: true,
            isInstalled: true,
            overrideCount: 0,
            defaultAssociationCount: 0,
            declaredExtensions: [],
            declaredUTIs: [],
            declaredSchemes: []
        )

        let report = await inspector.inspect(app: textEditApp)
        #expect(report.codeSigning.isSigned == true)
        #expect(report.codeSigning.isAppleSigned == true)
        #expect(report.codeSigning.isSandboxed == true)

        let iinaURL = URL(fileURLWithPath: "/Applications/IINA.app")
        if FileManager.default.fileExists(atPath: iinaURL.path) {
            let iinaApp = InstalledApp(
                bundleID: "com.colliderli.iina",
                name: "IINA",
                url: iinaURL,
                version: "1.5.1",
                buildNumber: "183",
                isAppleApp: false,
                isInstalled: true,
                overrideCount: 0,
                defaultAssociationCount: 0,
                declaredExtensions: [],
                declaredUTIs: [],
                declaredSchemes: ["iina"]
            )
            let iinaReport = await inspector.inspect(app: iinaApp)
            #expect(iinaReport.codeSigning.isSigned == true)
            #expect(iinaReport.codeSigning.isAppleSigned == false)
            #expect(iinaReport.entitlements.contains { $0.key == "com.apple.security.cs.disable-library-validation" })
            #expect(iinaReport.urlSchemes.contains { $0.scheme == "iina" })
        }

        // Uninstalled orphaned app must not inspect /Applications or return bogus signing info
        let orphanedApp = InstalledApp(
            bundleID: "com.video.player.converter.fj.mp3",
            name: "com.video.player.converter.fj.mp3",
            url: URL(fileURLWithPath: "/Applications"),
            version: "-",
            buildNumber: "-",
            isAppleApp: false,
            isInstalled: false,
            overrideCount: 1,
            defaultAssociationCount: 1,
            declaredExtensions: [],
            declaredUTIs: [],
            declaredSchemes: []
        )
        let orphanReport = await inspector.inspect(app: orphanedApp)
        #expect(orphanReport.codeSigning.isSigned == false)
        #expect(orphanReport.codeSigning.isSandboxed == false)
        #expect(orphanReport.entitlements.isEmpty)
        #expect(orphanReport.declaredPermissions.isEmpty)
        #expect(orphanReport.urlSchemes.isEmpty)
    }
}
