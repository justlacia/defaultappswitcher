import AppKit
import Darwin
import Foundation
import Security
import SQLite3

public enum TCCResetError: LocalizedError, Sendable {
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "Gizlilik izni sıfırlanamadı: \(message)"
        }
    }
}

public final class AppPermissionInspector: Sendable {
    private struct PrivacyKeySpec: Sendable {
        let displayName: String
        let symbolName: String
        let tccutilService: String?
        let settingsFragment: String
    }

    private struct TCCServiceSpec: Sendable {
        let displayName: String
        let symbolName: String
        let tccutilName: String?
        let settingsFragment: String
    }

    private struct EntitlementSpec: Sendable {
        let title: String
        let explanation: String
        let isSensitive: Bool
    }

    private static let privacyKeys: [String: PrivacyKeySpec] = [
        "NSCameraUsageDescription": PrivacyKeySpec(
            displayName: "Kamera",
            symbolName: "camera.fill",
            tccutilService: "Camera",
            settingsFragment: "Privacy_Camera"
        ),
        "NSMicrophoneUsageDescription": PrivacyKeySpec(
            displayName: "Mikrofon",
            symbolName: "mic.fill",
            tccutilService: "Microphone",
            settingsFragment: "Privacy_Microphone"
        ),
        "NSAudioCaptureUsageDescription": PrivacyKeySpec(
            displayName: "Sistem Ses Yakalama",
            symbolName: "waveform",
            tccutilService: "AudioCapture",
            settingsFragment: "Privacy_ListenEvent"
        ),
        "NSScreenCaptureUsageDescription": PrivacyKeySpec(
            displayName: "Ekran ve Sistem Ses Kaydı",
            symbolName: "rectangle.dashed.badge.record",
            tccutilService: "ScreenCapture",
            settingsFragment: "Privacy_ScreenCapture"
        ),
        "NSPhotoLibraryUsageDescription": PrivacyKeySpec(
            displayName: "Fotoğraflar (Tam Erişim)",
            symbolName: "photo.on.rectangle",
            tccutilService: "Photos",
            settingsFragment: "Privacy_Photos"
        ),
        "NSPhotoLibraryAddUsageDescription": PrivacyKeySpec(
            displayName: "Fotoğraflar (Yalnızca Ekleme)",
            symbolName: "photo.badge.plus",
            tccutilService: "PhotosAdd",
            settingsFragment: "Privacy_Photos"
        ),
        "NSContactsUsageDescription": PrivacyKeySpec(
            displayName: "Kişiler",
            symbolName: "person.crop.circle",
            tccutilService: "AddressBook",
            settingsFragment: "Privacy_Contacts"
        ),
        "NSCalendarsUsageDescription": PrivacyKeySpec(
            displayName: "Takvimler",
            symbolName: "calendar",
            tccutilService: "Calendar",
            settingsFragment: "Privacy_Calendars"
        ),
        "NSCalendarsFullAccessUsageDescription": PrivacyKeySpec(
            displayName: "Takvimler (Tam Erişim)",
            symbolName: "calendar.badge.checkmark",
            tccutilService: "Calendar",
            settingsFragment: "Privacy_Calendars"
        ),
        "NSCalendarsWriteOnlyAccessUsageDescription": PrivacyKeySpec(
            displayName: "Takvimler (Yalnızca Yazma)",
            symbolName: "calendar.badge.plus",
            tccutilService: "Calendar",
            settingsFragment: "Privacy_Calendars"
        ),
        "NSRemindersUsageDescription": PrivacyKeySpec(
            displayName: "Anımsatıcılar",
            symbolName: "checklist",
            tccutilService: "Reminders",
            settingsFragment: "Privacy_Reminders"
        ),
        "NSRemindersFullAccessUsageDescription": PrivacyKeySpec(
            displayName: "Anımsatıcılar (Tam Erişim)",
            symbolName: "checklist.checked",
            tccutilService: "Reminders",
            settingsFragment: "Privacy_Reminders"
        ),
        "NSLocationUsageDescription": PrivacyKeySpec(
            displayName: "Konum Servisleri",
            symbolName: "location.fill",
            tccutilService: "Location",
            settingsFragment: "Privacy_LocationServices"
        ),
        "NSLocationWhenInUseUsageDescription": PrivacyKeySpec(
            displayName: "Konum (Kullanırken)",
            symbolName: "location",
            tccutilService: "Location",
            settingsFragment: "Privacy_LocationServices"
        ),
        "NSLocationAlwaysUsageDescription": PrivacyKeySpec(
            displayName: "Konum (Her Zaman)",
            symbolName: "location.circle.fill",
            tccutilService: "Location",
            settingsFragment: "Privacy_LocationServices"
        ),
        "NSLocationAlwaysAndWhenInUseUsageDescription": PrivacyKeySpec(
            displayName: "Konum (Her Zaman / Kullanırken)",
            symbolName: "location.circle.fill",
            tccutilService: "Location",
            settingsFragment: "Privacy_LocationServices"
        ),
        "NSBluetoothAlwaysUsageDescription": PrivacyKeySpec(
            displayName: "Bluetooth",
            symbolName: "antenna.radiowaves.left.and.right",
            tccutilService: "BluetoothAlways",
            settingsFragment: "Privacy_Bluetooth"
        ),
        "NSBluetoothPeripheralUsageDescription": PrivacyKeySpec(
            displayName: "Bluetooth Çevre Birimleri",
            symbolName: "antenna.radiowaves.left.and.right",
            tccutilService: "BluetoothAlways",
            settingsFragment: "Privacy_Bluetooth"
        ),
        "NSLocalNetworkUsageDescription": PrivacyKeySpec(
            displayName: "Yerel Ağ",
            symbolName: "network",
            tccutilService: nil,
            settingsFragment: "Privacy_LocalNetwork"
        ),
        "NSAppleEventsUsageDescription": PrivacyKeySpec(
            displayName: "Otomasyon (AppleEvents)",
            symbolName: "gearshape.2.fill",
            tccutilService: "AppleEvents",
            settingsFragment: "Privacy_Automation"
        ),
        "NSDesktopFolderUsageDescription": PrivacyKeySpec(
            displayName: "Masaüstü Klasörü",
            symbolName: "menubar.dock.rectangle",
            tccutilService: "SystemPolicyDesktopFolder",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "NSDocumentsFolderUsageDescription": PrivacyKeySpec(
            displayName: "Belgeler Klasörü",
            symbolName: "doc.text.fill",
            tccutilService: "SystemPolicyDocumentsFolder",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "NSDownloadsFolderUsageDescription": PrivacyKeySpec(
            displayName: "İndirilenler Klasörü",
            symbolName: "arrow.down.circle.fill",
            tccutilService: "SystemPolicyDownloadsFolder",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "NSNetworkVolumesUsageDescription": PrivacyKeySpec(
            displayName: "Ağ Birimleri",
            symbolName: "externaldrive.connected.to.line.below.fill",
            tccutilService: "SystemPolicyNetworkVolumes",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "NSRemovableVolumesUsageDescription": PrivacyKeySpec(
            displayName: "Çıkarılabilir Birimler",
            symbolName: "externaldrive.fill",
            tccutilService: "SystemPolicyRemovableVolumes",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "NSSpeechRecognitionUsageDescription": PrivacyKeySpec(
            displayName: "Konuşma Tanıma",
            symbolName: "waveform.and.mic",
            tccutilService: "SpeechRecognition",
            settingsFragment: "Privacy_SpeechRecognition"
        ),
        "NSSiriUsageDescription": PrivacyKeySpec(
            displayName: "Siri",
            symbolName: "sparkles",
            tccutilService: "Siri",
            settingsFragment: "Privacy"
        ),
        "NSFaceIDUsageDescription": PrivacyKeySpec(
            displayName: "Biyometrik Kimlik Doğrulama",
            symbolName: "faceid",
            tccutilService: nil,
            settingsFragment: "Privacy"
        ),
        "NSHomeKitUsageDescription": PrivacyKeySpec(
            displayName: "Ev (HomeKit)",
            symbolName: "homekit",
            tccutilService: "Willow",
            settingsFragment: "Privacy_HomeKit"
        ),
        "NSMotionUsageDescription": PrivacyKeySpec(
            displayName: "Hareket ve Fitness",
            symbolName: "figure.walk",
            tccutilService: "Motion",
            settingsFragment: "Privacy_Motion"
        )
    ]

    private static let tccServices: [String: TCCServiceSpec] = [
        "kTCCServiceCamera": TCCServiceSpec(displayName: "Kamera", symbolName: "camera.fill", tccutilName: "Camera", settingsFragment: "Privacy_Camera"),
        "kTCCServiceMicrophone": TCCServiceSpec(displayName: "Mikrofon", symbolName: "mic.fill", tccutilName: "Microphone", settingsFragment: "Privacy_Microphone"),
        "kTCCServiceScreenCapture": TCCServiceSpec(displayName: "Ekran Kaydı", symbolName: "rectangle.dashed.badge.record", tccutilName: "ScreenCapture", settingsFragment: "Privacy_ScreenCapture"),
        "kTCCServiceAccessibility": TCCServiceSpec(displayName: "Erişilebilirlik", symbolName: "accessibility", tccutilName: "Accessibility", settingsFragment: "Privacy_Accessibility"),
        "kTCCServiceListenEvent": TCCServiceSpec(displayName: "Giriş İzleme", symbolName: "keyboard", tccutilName: "ListenEvent", settingsFragment: "Privacy_ListenEvent"),
        "kTCCServicePostEvent": TCCServiceSpec(displayName: "Otomatik Girdi Gönderme", symbolName: "cursorarrow.click", tccutilName: "PostEvent", settingsFragment: "Privacy_Accessibility"),
        "kTCCServiceSystemPolicyAllFiles": TCCServiceSpec(displayName: "Tam Disk Erişimi", symbolName: "internaldrive.fill", tccutilName: "SystemPolicyAllFiles", settingsFragment: "Privacy_AllFiles"),
        "kTCCServiceSystemPolicyDesktopFolder": TCCServiceSpec(displayName: "Masaüstü Klasörü", symbolName: "menubar.dock.rectangle", tccutilName: "SystemPolicyDesktopFolder", settingsFragment: "Privacy_FilesAndFolders"),
        "kTCCServiceSystemPolicyDocumentsFolder": TCCServiceSpec(displayName: "Belgeler Klasörü", symbolName: "doc.text.fill", tccutilName: "SystemPolicyDocumentsFolder", settingsFragment: "Privacy_FilesAndFolders"),
        "kTCCServiceSystemPolicyDownloadsFolder": TCCServiceSpec(displayName: "İndirilenler Klasörü", symbolName: "arrow.down.circle.fill", tccutilName: "SystemPolicyDownloadsFolder", settingsFragment: "Privacy_FilesAndFolders"),
        "kTCCServiceSystemPolicyNetworkVolumes": TCCServiceSpec(displayName: "Ağ Birimleri", symbolName: "externaldrive.connected.to.line.below.fill", tccutilName: "SystemPolicyNetworkVolumes", settingsFragment: "Privacy_FilesAndFolders"),
        "kTCCServiceSystemPolicyRemovableVolumes": TCCServiceSpec(displayName: "Çıkarılabilir Birimler", symbolName: "externaldrive.fill", tccutilName: "SystemPolicyRemovableVolumes", settingsFragment: "Privacy_FilesAndFolders"),
        "kTCCServiceSystemPolicyAppBundles": TCCServiceSpec(displayName: "Uygulama Yönetimi", symbolName: "app.badge.checkmark", tccutilName: "SystemPolicyAppBundles", settingsFragment: "Privacy_AppBundles"),
        "kTCCServicePhotos": TCCServiceSpec(displayName: "Fotoğraflar", symbolName: "photo.on.rectangle", tccutilName: "Photos", settingsFragment: "Privacy_Photos"),
        "kTCCServiceAddressBook": TCCServiceSpec(displayName: "Kişiler", symbolName: "person.crop.circle", tccutilName: "AddressBook", settingsFragment: "Privacy_Contacts"),
        "kTCCServiceCalendar": TCCServiceSpec(displayName: "Takvimler", symbolName: "calendar", tccutilName: "Calendar", settingsFragment: "Privacy_Calendars"),
        "kTCCServiceReminders": TCCServiceSpec(displayName: "Anımsatıcılar", symbolName: "checklist", tccutilName: "Reminders", settingsFragment: "Privacy_Reminders"),
        "kTCCServiceAppleEvents": TCCServiceSpec(displayName: "Otomasyon (AppleEvents)", symbolName: "gearshape.2.fill", tccutilName: "AppleEvents", settingsFragment: "Privacy_Automation"),
        "kTCCServiceBluetoothAlways": TCCServiceSpec(displayName: "Bluetooth", symbolName: "antenna.radiowaves.left.and.right", tccutilName: "BluetoothAlways", settingsFragment: "Privacy_Bluetooth"),
        "kTCCServiceSpeechRecognition": TCCServiceSpec(displayName: "Konuşma Tanıma", symbolName: "waveform.and.mic", tccutilName: "SpeechRecognition", settingsFragment: "Privacy_SpeechRecognition"),
        "kTCCServiceMediaLibrary": TCCServiceSpec(displayName: "Medya ve Apple Music", symbolName: "music.note.list", tccutilName: "MediaLibrary", settingsFragment: "Privacy_Media"),
        "kTCCServiceDeveloperTool": TCCServiceSpec(displayName: "Geliştirici Araçları", symbolName: "hammer.fill", tccutilName: "DeveloperTool", settingsFragment: "Privacy_DevTools")
    ]

    private static let entitlementSpecs: [String: EntitlementSpec] = [
        "com.apple.security.app-sandbox": EntitlementSpec(
            title: "App Sandbox",
            explanation: "Uygulama Apple'ın korumalı sanal alanında (sandbox) izole çalışır.",
            isSensitive: false
        ),
        "com.apple.security.network.client": EntitlementSpec(
            title: "Giden Ağ Bağlantıları",
            explanation: "İnternete veya yerel ağa giden bağlantılar başlatabilir.",
            isSensitive: false
        ),
        "com.apple.security.network.server": EntitlementSpec(
            title: "Gelen Ağ Bağlantıları",
            explanation: "Yerel ağdan gelen bağlantıları dinleyebilir (sunucu/yayın modu).",
            isSensitive: true
        ),
        "com.apple.security.files.user-selected.read-write": EntitlementSpec(
            title: "Kullanıcının Seçtiği Dosyalar (Okuma/Yazma)",
            explanation: "Aç/Kaydet penceresiyle kullanıcının seçtiği dosya ve klasörlere erişebilir.",
            isSensitive: false
        ),
        "com.apple.security.files.user-selected.read-only": EntitlementSpec(
            title: "Kullanıcının Seçtiği Dosyalar (Salt Okunur)",
            explanation: "Kullanıcının seçtiği dosyaları yalnızca okuyabilir.",
            isSensitive: false
        ),
        "com.apple.security.files.downloads.read-write": EntitlementSpec(
            title: "İndirilenler Klasörü Erişimi",
            explanation: "Kullanıcının İndirilenler klasörüne doğrudan erişim ister.",
            isSensitive: true
        ),
        "com.apple.security.device.camera": EntitlementSpec(
            title: "Kamera Donanımı",
            explanation: "Sandbox içinde kamera aygıtına erişim yetkisi.",
            isSensitive: true
        ),
        "com.apple.security.device.audio-input": EntitlementSpec(
            title: "Mikrofon / Ses Girişi",
            explanation: "Sandbox içinde mikrofon ve ses girişi yetkisi.",
            isSensitive: true
        ),
        "com.apple.security.device.bluetooth": EntitlementSpec(
            title: "Bluetooth Donanımı",
            explanation: "Bluetooth cihazlarıyla iletişim kurabilir.",
            isSensitive: false
        ),
        "com.apple.security.device.usb": EntitlementSpec(
            title: "USB Donanım Erişimi",
            explanation: "Doğrudan USB aygıtlarıyla iletişim kurabilir.",
            isSensitive: true
        ),
        "com.apple.security.automation.apple-events": EntitlementSpec(
            title: "AppleEvents Otomasyonu",
            explanation: "Diğer uygulamaları AppleScript / AppleEvents ile kontrol edebilir.",
            isSensitive: true
        ),
        "com.apple.security.cs.allow-unsigned-executable-memory": EntitlementSpec(
            title: "İmzasız Çalıştırılabilir Bellek",
            explanation: "JIT/eklenti/dinamik kod üretimi için imzasız çalıştırılabilir bellek sayfalarına izin verir.",
            isSensitive: true
        ),
        "com.apple.security.cs.disable-library-validation": EntitlementSpec(
            title: "Kütüphane Doğrulaması Devre Dışı",
            explanation: "Üçüncü parti veya imzasız dinamik kütüphaneleri (.dylib) ve eklentileri yükleyebilir.",
            isSensitive: true
        ),
        "com.apple.security.cs.allow-jit": EntitlementSpec(
            title: "JIT Kod Derleme (MAP_JIT)",
            explanation: "Çalışma zamanında dinamik makine kodu derlemeye (JIT) izin verir.",
            isSensitive: true
        ),
        "com.apple.security.cs.allow-dyld-environment-variables": EntitlementSpec(
            title: "DYLD Ortam Değişkenleri",
            explanation: "Dinamik bağlayıcı ortam değişkenlerinin kullanılmasına izin verir.",
            isSensitive: true
        ),
        "com.apple.security.cs.debugger": EntitlementSpec(
            title: "Hata Ayıklayıcı (Debugger) Yetkisi",
            explanation: "Diğer işlemlere hata ayıklayıcı (debug) olarak bağlanabilir.",
            isSensitive: true
        )
    ]

    public init() {}

    public func inspect(app: InstalledApp) async -> AppSecurityReport {
        await Task.detached(priority: .userInitiated) {
            let userTCCPath = NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
            let systemTCCPath = "/Library/Application Support/com.apple.TCC/TCC.db"

            let (userTCCState, userEntries) = Self.readTCCDatabase(
                at: userTCCPath,
                bundleID: app.bundleID,
                scope: .user
            )
            let (systemTCCState, systemEntries) = Self.readTCCDatabase(
                at: systemTCCPath,
                bundleID: app.bundleID,
                scope: .system
            )

            guard app.isInstalled else {
                let uninstalledSigning = CodeSigningInfo(
                    isSigned: false,
                    isAppleSigned: false,
                    isAdHoc: false,
                    teamIdentifier: nil,
                    signingAuthority: nil,
                    isSandboxed: false,
                    isHardenedRuntime: false,
                    hasQuarantineAttribute: false,
                    architectures: [],
                    minimumOSVersion: nil
                )
                return AppSecurityReport(
                    codeSigning: uninstalledSigning,
                    entitlements: [],
                    declaredPermissions: [],
                    userTCCState: userTCCState,
                    systemTCCState: systemTCCState,
                    tccEntries: userEntries + systemEntries,
                    urlSchemes: [],
                    backgroundItems: []
                )
            }

            let bundle = Bundle(url: app.url)
            let info = bundle?.infoDictionary ?? [:]

            let (codeSigning, entitlements) = Self.inspectCodeSigning(appURL: app.url, bundle: bundle, info: info)
            let declaredPermissions = Self.extractDeclaredPermissions(from: info)
            let urlSchemes = Self.extractURLSchemes(from: info, targetBundleID: app.bundleID)
            let backgroundItems = Self.scanBackgroundItems(for: app)

            return AppSecurityReport(
                codeSigning: codeSigning,
                entitlements: entitlements,
                declaredPermissions: declaredPermissions,
                userTCCState: userTCCState,
                systemTCCState: systemTCCState,
                tccEntries: userEntries + systemEntries,
                urlSchemes: urlSchemes,
                backgroundItems: backgroundItems
            )
        }.value
    }

    public func resetTCCPermission(service: String, bundleID: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", service, bundleID]

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let outText = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let errText = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if process.terminationStatus != 0 {
                let message = errText.isEmpty ? outText : errText
                throw TCCResetError.commandFailed(message.isEmpty ? "Çıkış kodu \(process.terminationStatus)" : message)
            }

            return outText.isEmpty ? "\(bundleID) için \(service) izni sıfırlandı." : outText
        }.value
    }

    public static func fullDiskAccessSettingsURL() -> URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    // MARK: - Private Inspection Helpers

    private static func inspectCodeSigning(
        appURL: URL,
        bundle: Bundle?,
        info: [String: Any]
    ) -> (CodeSigningInfo, [EntitlementItem]) {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(appURL as CFURL, SecCSFlags(), &staticCode)

        var isSigned = false
        var isAppleSigned = false
        var isAdHoc = false
        var teamIdentifier: String?
        var signingAuthority: String?
        var isHardenedRuntime = false
        var entitlementDict: [String: Any] = [:]

        if createStatus == errSecSuccess, let code = staticCode {
            var infoCF: CFDictionary?
            let flags = SecCSFlags(
                rawValue: kSecCSSigningInformation | kSecCSRequirementInformation | kSecCSDynamicInformation
            )
            let copyStatus = SecCodeCopySigningInformation(code, flags, &infoCF)
            if copyStatus == errSecSuccess, let dict = infoCF as? [String: Any] {
                isSigned = dict[kSecCodeInfoIdentifier as String] != nil || dict[kSecCodeInfoFormat as String] != nil

                if let team = dict[kSecCodeInfoTeamIdentifier as String] as? String, !team.isEmpty {
                    teamIdentifier = team
                }

                if let sigFlagsRaw = dict[kSecCodeInfoFlags as String] as? UInt32 {
                    isHardenedRuntime = (sigFlagsRaw & SecCodeSignatureFlags.runtime.rawValue) != 0
                    isAdHoc = (sigFlagsRaw & SecCodeSignatureFlags.adhoc.rawValue) != 0
                }

                if let platformID = dict[kSecCodeInfoPlatformIdentifier as String] as? Int, platformID != 0 {
                    isAppleSigned = true
                }

                if let certs = dict[kSecCodeInfoCertificates as String] as? [SecCertificate],
                   let leaf = certs.first {
                    var commonName: CFString?
                    if SecCertificateCopyCommonName(leaf, &commonName) == errSecSuccess,
                       let name = commonName as String? {
                        signingAuthority = name
                        if name == "Software Signing"
                            || name == "macOS Software Signing"
                            || name.hasPrefix("Apple ") {
                            isAppleSigned = true
                        }
                    }
                }

                if let ent = dict[kSecCodeInfoEntitlementsDict as String] as? [String: Any] {
                    entitlementDict = ent
                }
            }
        }

        let isSandboxed = (entitlementDict["com.apple.security.app-sandbox"] as? Bool) == true
        let hasQuarantine = getxattr(appURL.path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW) >= 0

        let archs: [String] = (bundle?.executableArchitectures ?? []).map { num in
            switch num.intValue {
            case NSBundleExecutableArchitectureARM64:
                return "arm64 (Apple Silicon)"
            case NSBundleExecutableArchitectureX86_64:
                return "x86_64 (Intel)"
            default:
                return "Mimari #\(num.intValue)"
            }
        }

        let minOS = info["LSMinimumSystemVersion"] as? String

        let mappedEntitlements = entitlementDict.keys.sorted().map { key -> EntitlementItem in
            let rawValue = entitlementDict[key]
            let summary = summarizeEntitlementValue(rawValue)
            if let spec = entitlementSpecs[key] {
                return EntitlementItem(
                    key: key,
                    title: spec.title,
                    explanation: spec.explanation,
                    valueSummary: summary,
                    isSensitive: spec.isSensitive
                )
            }
            return EntitlementItem(
                key: key,
                title: friendlyEntitlementTitle(key),
                explanation: "Uygulama kod imzasına gömülü özel yetki (entitlement).",
                valueSummary: summary,
                isSensitive: key.contains(".cs.") || key.contains("private.")
            )
        }

        let codeSigning = CodeSigningInfo(
            isSigned: isSigned,
            isAppleSigned: isAppleSigned,
            isAdHoc: isAdHoc,
            teamIdentifier: teamIdentifier,
            signingAuthority: signingAuthority,
            isSandboxed: isSandboxed,
            isHardenedRuntime: isHardenedRuntime,
            hasQuarantineAttribute: hasQuarantine,
            architectures: archs,
            minimumOSVersion: minOS
        )

        return (codeSigning, mappedEntitlements)
    }

    private static func extractDeclaredPermissions(from info: [String: Any]) -> [DeclaredPrivacyPermission] {
        var results: [DeclaredPrivacyPermission] = []

        for (key, value) in info where key.hasSuffix("UsageDescription") {
            guard let description = value as? String, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            if let spec = privacyKeys[key] {
                results.append(
                    DeclaredPrivacyPermission(
                        plistKey: key,
                        displayName: spec.displayName,
                        symbolName: spec.symbolName,
                        usageDescription: description,
                        tccutilService: spec.tccutilService,
                        settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?\(spec.settingsFragment)")
                    )
                )
            } else {
                results.append(
                    DeclaredPrivacyPermission(
                        plistKey: key,
                        displayName: friendlyPrivacyTitle(key),
                        symbolName: "hand.raised.fill",
                        usageDescription: description,
                        tccutilService: nil,
                        settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")
                    )
                )
            }
        }

        return results.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func readTCCDatabase(
        at path: String,
        bundleID: String,
        scope: TCCScope
    ) -> (TCCReadState, [TCCPermissionEntry]) {
        var db: OpaquePointer?
        let openCode = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil)
        defer {
            if db != nil {
                sqlite3_close(db)
            }
        }

        guard openCode == SQLITE_OK, let db else {
            if openCode == SQLITE_CANTOPEN || openCode == SQLITE_PERM || openCode == SQLITE_AUTH {
                return (.needsFullDiskAccess, [])
            }
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "SQLite kodu \(openCode)"
            return (.error(message), [])
        }

        let sql = """
        SELECT service, auth_value, indirect_object_identifier, last_modified
        FROM access
        WHERE LOWER(client) = LOWER(?)
        ORDER BY service ASC;
        """

        var stmt: OpaquePointer?
        let prepCode = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer {
            if stmt != nil {
                sqlite3_finalize(stmt)
            }
        }

        guard prepCode == SQLITE_OK, let stmt else {
            let errCode = sqlite3_errcode(db)
            if errCode == SQLITE_AUTH || errCode == SQLITE_PERM || errCode == SQLITE_CANTOPEN {
                return (.needsFullDiskAccess, [])
            }
            let message = String(cString: sqlite3_errmsg(db))
            return (.error(message), [])
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, bundleID, -1, SQLITE_TRANSIENT)

        var entries: [TCCPermissionEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let serviceKey = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? "Bilinmiyor"
            let authVal = Int(sqlite3_column_int(stmt, 1))
            let indirectRaw = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let indirectTarget = (indirectRaw == nil || indirectRaw == "UNUSED") ? nil : indirectRaw

            var lastMod: Date?
            if sqlite3_column_type(stmt, 3) != SQLITE_NULL {
                let ts = sqlite3_column_double(stmt, 3)
                if ts > 0 {
                    lastMod = Date(timeIntervalSince1970: ts)
                }
            }

            let status: TCCAuthStatus
            switch authVal {
            case 2: status = .allowed
            case 0: status = .denied
            case 3: status = .limited
            default: status = .unknown(authVal)
            }

            let spec = tccServices[serviceKey]
            let displayName = spec?.displayName ?? serviceKey.replacingOccurrences(of: "kTCCService", with: "")
            let symbolName = spec?.symbolName ?? "lock.shield"
            let tccutilName = spec?.tccutilName ?? fallbackTCCUtilName(for: serviceKey)
            let settingsURL = spec.flatMap {
                URL(string: "x-apple.systempreferences:com.apple.preference.security?\($0.settingsFragment)")
            } ?? URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")

            entries.append(
                TCCPermissionEntry(
                    serviceKey: serviceKey,
                    displayName: displayName,
                    symbolName: symbolName,
                    tccutilName: tccutilName,
                    status: status,
                    scope: scope,
                    indirectTarget: indirectTarget,
                    lastModified: lastMod,
                    settingsURL: settingsURL
                )
            )
        }

        return (.readable, entries)
    }

    private static func extractURLSchemes(from info: [String: Any], targetBundleID: String) -> [URLSchemeInfo] {
        guard let urlTypes = info["CFBundleURLTypes"] as? [[String: Any]] else {
            return []
        }

        var schemes = Set<String>()
        for entry in urlTypes {
            if let list = entry["CFBundleURLSchemes"] as? [String] {
                for scheme in list where !scheme.isEmpty {
                    schemes.insert(scheme)
                }
            }
        }

        let lowerTarget = targetBundleID.lowercased()
        return schemes.sorted().map { scheme in
            let currentURL = URL(string: "\(scheme)://").flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) }
            let currentBundle = currentURL.flatMap { Bundle(url: $0) }
            let currentID = currentBundle?.bundleIdentifier
            let currentName = currentURL.map {
                DefaultAppResolver.displayName(for: $0, bundle: currentBundle, fallbackBundleID: currentID ?? "")
            }
            return URLSchemeInfo(
                scheme: scheme,
                isCurrentDefault: currentID?.lowercased() == lowerTarget,
                currentDefaultAppName: currentName
            )
        }
    }

    private static func scanBackgroundItems(for app: InstalledApp) -> [BackgroundItem] {
        var items: [BackgroundItem] = []
        let fm = FileManager.default

        let loginItemsDir = app.url.appendingPathComponent("Contents/Library/LoginItems", isDirectory: true)
        if let loginItems = try? fm.contentsOfDirectory(at: loginItemsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for item in loginItems {
                items.append(
                    BackgroundItem(
                        name: item.deletingPathExtension().lastPathComponent,
                        kind: .loginItem,
                        path: item.path
                    )
                )
            }
        }

        let launchServicesDir = app.url.appendingPathComponent("Contents/Library/LaunchServices", isDirectory: true)
        if let helpers = try? fm.contentsOfDirectory(at: launchServicesDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for helper in helpers {
                items.append(
                    BackgroundItem(
                        name: helper.lastPathComponent,
                        kind: .helper,
                        path: helper.path
                    )
                )
            }
        }

        let agentDirs = [
            URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Library/LaunchAgents", isDirectory: true),
            URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true)
        ]

        let lowerID = app.id
        let appPath = app.url.path.lowercased()

        for dir in agentDirs {
            guard let plists = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            for plistURL in plists where plistURL.pathExtension.lowercased() == "plist" {
                let filenameMatches = plistURL.lastPathComponent.lowercased().contains(lowerID)
                var contentMatches = filenameMatches
                var label = plistURL.deletingPathExtension().lastPathComponent

                if let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] {
                    if let plistLabel = dict["Label"] as? String {
                        label = plistLabel
                        if plistLabel.lowercased().contains(lowerID) {
                            contentMatches = true
                        }
                    }
                    if let prog = dict["Program"] as? String, prog.lowercased().contains(appPath) {
                        contentMatches = true
                    }
                    if let args = dict["ProgramArguments"] as? [String],
                       args.contains(where: { $0.lowercased().contains(appPath) }) {
                        contentMatches = true
                    }
                }

                if contentMatches {
                    items.append(
                        BackgroundItem(
                            name: label,
                            kind: .launchAgent,
                            path: plistURL.path
                        )
                    )
                }
            }
        }

        return items
    }

    private static func summarizeEntitlementValue(_ value: Any?) -> String {
        switch value {
        case let bool as Bool:
            return bool ? "Açık (true)" : "Kapalı (false)"
        case let str as String:
            return str
        case let num as NSNumber:
            return num.stringValue
        case let arr as [Any]:
            if arr.isEmpty { return "Boş liste" }
            let preview = arr.prefix(3).map { "\($0)" }.joined(separator: ", ")
            return arr.count > 3 ? "\(preview) (+\(arr.count - 3))" : preview
        case let dict as [String: Any]:
            return "\(dict.count) anahtar"
        default:
            return "Tanımlı"
        }
    }

    private static func friendlyEntitlementTitle(_ key: String) -> String {
        key.replacingOccurrences(of: "com.apple.security.", with: "")
            .replacingOccurrences(of: "com.apple.developer.", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " / ")
    }

    private static func friendlyPrivacyTitle(_ key: String) -> String {
        var cleaned = key
        if cleaned.hasPrefix("NS") { cleaned.removeFirst(2) }
        if cleaned.hasSuffix("UsageDescription") {
            cleaned = String(cleaned.dropLast("UsageDescription".count))
        }
        return cleaned
    }

    private static func fallbackTCCUtilName(for serviceKey: String) -> String? {
        guard serviceKey.hasPrefix("kTCCService") else { return nil }
        return String(serviceKey.dropFirst("kTCCService".count))
    }
}
