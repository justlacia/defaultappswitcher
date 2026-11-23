import AppKit
import Darwin
import Foundation
import Security
import SQLite3

public enum TCCResetError: LocalizedError, Sendable {
    case commandFailed(String)

    public func message(in language: AppLanguage) -> String {
        switch (self, language) {
        case (.commandFailed(let detail), .turkish):
            return "Gizlilik izni sıfırlanamadı: \(detail)"
        case (.commandFailed(let detail), .english):
            return "Failed to reset privacy permission: \(detail)"
        }
    }

    public var errorDescription: String? {
        message(in: AppLanguage.detectSystemLanguage())
    }
}

public final class AppPermissionInspector: Sendable {
    private struct PrivacyKeySpec: Sendable {
        let displayName: LocalizedText
        let symbolName: String
        let tccutilService: String?
        let settingsFragment: String
    }

    private struct TCCServiceSpec: Sendable {
        let displayName: LocalizedText
        let symbolName: String
        let tccutilName: String?
        let settingsFragment: String
    }

    private struct EntitlementSpec: Sendable {
        let title: LocalizedText
        let explanation: LocalizedText
        let isSensitive: Bool
    }

    private static let privacyKeys: [String: PrivacyKeySpec] = [
        "NSCameraUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Kamera", en: "Camera"),
            symbolName: "camera.fill",
            tccutilService: "Camera",
            settingsFragment: "Privacy_Camera"
        ),
        "NSMicrophoneUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Mikrofon", en: "Microphone"),
            symbolName: "mic.fill",
            tccutilService: "Microphone",
            settingsFragment: "Privacy_Microphone"
        ),
        "NSAudioCaptureUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Sistem Ses Yakalama", en: "System Audio Capture"),
            symbolName: "waveform",
            tccutilService: "AudioCapture",
            settingsFragment: "Privacy_ListenEvent"
        ),
        "NSScreenCaptureUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Ekran ve Sistem Ses Kaydı", en: "Screen & System Audio Recording"),
            symbolName: "rectangle.dashed.badge.record",
            tccutilService: "ScreenCapture",
            settingsFragment: "Privacy_ScreenCapture"
        ),
        "NSPhotoLibraryUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Fotoğraflar (Tam Erişim)", en: "Photos (Full Access)"),
            symbolName: "photo.on.rectangle",
            tccutilService: "Photos",
            settingsFragment: "Privacy_Photos"
        ),
        "NSPhotoLibraryAddUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Fotoğraflar (Yalnızca Ekleme)", en: "Photos (Add Only)"),
            symbolName: "photo.badge.plus",
            tccutilService: "PhotosAdd",
            settingsFragment: "Privacy_Photos"
        ),
        "NSContactsUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Kişiler", en: "Contacts"),
            symbolName: "person.crop.circle",
            tccutilService: "AddressBook",
            settingsFragment: "Privacy_Contacts"
        ),
        "NSCalendarsUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Takvimler", en: "Calendars"),
            symbolName: "calendar",
            tccutilService: "Calendar",
            settingsFragment: "Privacy_Calendars"
        ),
        "NSCalendarsFullAccessUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Takvimler (Tam Erişim)", en: "Calendars (Full Access)"),
            symbolName: "calendar.badge.checkmark",
            tccutilService: "Calendar",
            settingsFragment: "Privacy_Calendars"
        ),
        "NSCalendarsWriteOnlyAccessUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Takvimler (Yalnızca Yazma)", en: "Calendars (Write Only)"),
            symbolName: "calendar.badge.plus",
            tccutilService: "Calendar",
            settingsFragment: "Privacy_Calendars"
        ),
        "NSRemindersUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Anımsatıcılar", en: "Reminders"),
            symbolName: "checklist",
            tccutilService: "Reminders",
            settingsFragment: "Privacy_Reminders"
        ),
        "NSRemindersFullAccessUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Anımsatıcılar (Tam Erişim)", en: "Reminders (Full Access)"),
            symbolName: "checklist.checked",
            tccutilService: "Reminders",
            settingsFragment: "Privacy_Reminders"
        ),
        "NSLocationUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Konum Servisleri", en: "Location Services"),
            symbolName: "location.fill",
            tccutilService: "Location",
            settingsFragment: "Privacy_LocationServices"
        ),
        "NSLocationWhenInUseUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Konum (Kullanırken)", en: "Location (When In Use)"),
            symbolName: "location",
            tccutilService: "Location",
            settingsFragment: "Privacy_LocationServices"
        ),
        "NSLocationAlwaysUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Konum (Her Zaman)", en: "Location (Always)"),
            symbolName: "location.circle.fill",
            tccutilService: "Location",
            settingsFragment: "Privacy_LocationServices"
        ),
        "NSLocationAlwaysAndWhenInUseUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Konum (Her Zaman / Kullanırken)", en: "Location (Always & When In Use)"),
            symbolName: "location.circle.fill",
            tccutilService: "Location",
            settingsFragment: "Privacy_LocationServices"
        ),
        "NSBluetoothAlwaysUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Bluetooth", en: "Bluetooth"),
            symbolName: "antenna.radiowaves.left.and.right",
            tccutilService: "BluetoothAlways",
            settingsFragment: "Privacy_Bluetooth"
        ),
        "NSBluetoothPeripheralUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Bluetooth Çevre Birimleri", en: "Bluetooth Peripherals"),
            symbolName: "antenna.radiowaves.left.and.right",
            tccutilService: "BluetoothAlways",
            settingsFragment: "Privacy_Bluetooth"
        ),
        "NSLocalNetworkUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Yerel Ağ", en: "Local Network"),
            symbolName: "network",
            tccutilService: nil,
            settingsFragment: "Privacy_LocalNetwork"
        ),
        "NSAppleEventsUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Otomasyon (AppleEvents)", en: "Automation (AppleEvents)"),
            symbolName: "gearshape.2.fill",
            tccutilService: "AppleEvents",
            settingsFragment: "Privacy_Automation"
        ),
        "NSDesktopFolderUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Masaüstü Klasörü", en: "Desktop Folder"),
            symbolName: "menubar.dock.rectangle",
            tccutilService: "SystemPolicyDesktopFolder",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "NSDocumentsFolderUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Belgeler Klasörü", en: "Documents Folder"),
            symbolName: "doc.text.fill",
            tccutilService: "SystemPolicyDocumentsFolder",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "NSDownloadsFolderUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "İndirilenler Klasörü", en: "Downloads Folder"),
            symbolName: "arrow.down.circle.fill",
            tccutilService: "SystemPolicyDownloadsFolder",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "NSNetworkVolumesUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Ağ Birimleri", en: "Network Volumes"),
            symbolName: "externaldrive.connected.to.line.below.fill",
            tccutilService: "SystemPolicyNetworkVolumes",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "NSRemovableVolumesUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Çıkarılabilir Birimler", en: "Removable Volumes"),
            symbolName: "externaldrive.fill",
            tccutilService: "SystemPolicyRemovableVolumes",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "NSSpeechRecognitionUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Konuşma Tanıma", en: "Speech Recognition"),
            symbolName: "waveform.and.mic",
            tccutilService: "SpeechRecognition",
            settingsFragment: "Privacy_SpeechRecognition"
        ),
        "NSSiriUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(same: "Siri"),
            symbolName: "sparkles",
            tccutilService: "Siri",
            settingsFragment: "Privacy"
        ),
        "NSFaceIDUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Biyometrik Kimlik Doğrulama", en: "Biometric Authentication (Face ID / Touch ID)"),
            symbolName: "faceid",
            tccutilService: nil,
            settingsFragment: "Privacy"
        ),
        "NSHomeKitUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Ev (HomeKit)", en: "HomeKit"),
            symbolName: "homekit",
            tccutilService: "Willow",
            settingsFragment: "Privacy_HomeKit"
        ),
        "NSMotionUsageDescription": PrivacyKeySpec(
            displayName: LocalizedText(tr: "Hareket ve Fitness", en: "Motion & Fitness"),
            symbolName: "figure.walk",
            tccutilService: "Motion",
            settingsFragment: "Privacy_Motion"
        )
    ]

    private static let tccServices: [String: TCCServiceSpec] = [
        "kTCCServiceCamera": TCCServiceSpec(
            displayName: LocalizedText(tr: "Kamera", en: "Camera"),
            symbolName: "camera.fill",
            tccutilName: "Camera",
            settingsFragment: "Privacy_Camera"
        ),
        "kTCCServiceMicrophone": TCCServiceSpec(
            displayName: LocalizedText(tr: "Mikrofon", en: "Microphone"),
            symbolName: "mic.fill",
            tccutilName: "Microphone",
            settingsFragment: "Privacy_Microphone"
        ),
        "kTCCServiceScreenCapture": TCCServiceSpec(
            displayName: LocalizedText(tr: "Ekran Kaydı", en: "Screen Recording"),
            symbolName: "rectangle.dashed.badge.record",
            tccutilName: "ScreenCapture",
            settingsFragment: "Privacy_ScreenCapture"
        ),
        "kTCCServiceAccessibility": TCCServiceSpec(
            displayName: LocalizedText(tr: "Erişilebilirlik", en: "Accessibility"),
            symbolName: "accessibility",
            tccutilName: "Accessibility",
            settingsFragment: "Privacy_Accessibility"
        ),
        "kTCCServiceListenEvent": TCCServiceSpec(
            displayName: LocalizedText(tr: "Giriş İzleme", en: "Input Monitoring"),
            symbolName: "keyboard",
            tccutilName: "ListenEvent",
            settingsFragment: "Privacy_ListenEvent"
        ),
        "kTCCServicePostEvent": TCCServiceSpec(
            displayName: LocalizedText(tr: "Otomatik Girdi Gönderme", en: "Synthetic Input Events"),
            symbolName: "cursorarrow.click",
            tccutilName: "PostEvent",
            settingsFragment: "Privacy_Accessibility"
        ),
        "kTCCServiceSystemPolicyAllFiles": TCCServiceSpec(
            displayName: LocalizedText(tr: "Tam Disk Erişimi", en: "Full Disk Access"),
            symbolName: "internaldrive.fill",
            tccutilName: "SystemPolicyAllFiles",
            settingsFragment: "Privacy_AllFiles"
        ),
        "kTCCServiceSystemPolicyDesktopFolder": TCCServiceSpec(
            displayName: LocalizedText(tr: "Masaüstü Klasörü", en: "Desktop Folder"),
            symbolName: "menubar.dock.rectangle",
            tccutilName: "SystemPolicyDesktopFolder",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "kTCCServiceSystemPolicyDocumentsFolder": TCCServiceSpec(
            displayName: LocalizedText(tr: "Belgeler Klasörü", en: "Documents Folder"),
            symbolName: "doc.text.fill",
            tccutilName: "SystemPolicyDocumentsFolder",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "kTCCServiceSystemPolicyDownloadsFolder": TCCServiceSpec(
            displayName: LocalizedText(tr: "İndirilenler Klasörü", en: "Downloads Folder"),
            symbolName: "arrow.down.circle.fill",
            tccutilName: "SystemPolicyDownloadsFolder",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "kTCCServiceSystemPolicyNetworkVolumes": TCCServiceSpec(
            displayName: LocalizedText(tr: "Ağ Birimleri", en: "Network Volumes"),
            symbolName: "externaldrive.connected.to.line.below.fill",
            tccutilName: "SystemPolicyNetworkVolumes",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "kTCCServiceSystemPolicyRemovableVolumes": TCCServiceSpec(
            displayName: LocalizedText(tr: "Çıkarılabilir Birimler", en: "Removable Volumes"),
            symbolName: "externaldrive.fill",
            tccutilName: "SystemPolicyRemovableVolumes",
            settingsFragment: "Privacy_FilesAndFolders"
        ),
        "kTCCServiceSystemPolicyAppBundles": TCCServiceSpec(
            displayName: LocalizedText(tr: "Uygulama Yönetimi", en: "App Management"),
            symbolName: "app.badge.checkmark",
            tccutilName: "SystemPolicyAppBundles",
            settingsFragment: "Privacy_AppBundles"
        ),
        "kTCCServicePhotos": TCCServiceSpec(
            displayName: LocalizedText(tr: "Fotoğraflar", en: "Photos"),
            symbolName: "photo.on.rectangle",
            tccutilName: "Photos",
            settingsFragment: "Privacy_Photos"
        ),
        "kTCCServiceAddressBook": TCCServiceSpec(
            displayName: LocalizedText(tr: "Kişiler", en: "Contacts"),
            symbolName: "person.crop.circle",
            tccutilName: "AddressBook",
            settingsFragment: "Privacy_Contacts"
        ),
        "kTCCServiceCalendar": TCCServiceSpec(
            displayName: LocalizedText(tr: "Takvimler", en: "Calendars"),
            symbolName: "calendar",
            tccutilName: "Calendar",
            settingsFragment: "Privacy_Calendars"
        ),
        "kTCCServiceReminders": TCCServiceSpec(
            displayName: LocalizedText(tr: "Anımsatıcılar", en: "Reminders"),
            symbolName: "checklist",
            tccutilName: "Reminders",
            settingsFragment: "Privacy_Reminders"
        ),
        "kTCCServiceAppleEvents": TCCServiceSpec(
            displayName: LocalizedText(tr: "Otomasyon (AppleEvents)", en: "Automation (AppleEvents)"),
            symbolName: "gearshape.2.fill",
            tccutilName: "AppleEvents",
            settingsFragment: "Privacy_Automation"
        ),
        "kTCCServiceBluetoothAlways": TCCServiceSpec(
            displayName: LocalizedText(same: "Bluetooth"),
            symbolName: "antenna.radiowaves.left.and.right",
            tccutilName: "BluetoothAlways",
            settingsFragment: "Privacy_Bluetooth"
        ),
        "kTCCServiceSpeechRecognition": TCCServiceSpec(
            displayName: LocalizedText(tr: "Konuşma Tanıma", en: "Speech Recognition"),
            symbolName: "waveform.and.mic",
            tccutilName: "SpeechRecognition",
            settingsFragment: "Privacy_SpeechRecognition"
        ),
        "kTCCServiceMediaLibrary": TCCServiceSpec(
            displayName: LocalizedText(tr: "Medya ve Apple Music", en: "Media & Apple Music"),
            symbolName: "music.note.list",
            tccutilName: "MediaLibrary",
            settingsFragment: "Privacy_Media"
        ),
        "kTCCServiceDeveloperTool": TCCServiceSpec(
            displayName: LocalizedText(tr: "Geliştirici Araçları", en: "Developer Tools"),
            symbolName: "hammer.fill",
            tccutilName: "DeveloperTool",
            settingsFragment: "Privacy_DevTools"
        )
    ]

    private static let entitlementSpecs: [String: EntitlementSpec] = [
        "com.apple.security.app-sandbox": EntitlementSpec(
            title: LocalizedText(same: "App Sandbox"),
            explanation: LocalizedText(
                tr: "Uygulama Apple'ın korumalı sanal alanında (sandbox) izole çalışır.",
                en: "The app runs isolated inside Apple's App Sandbox container."
            ),
            isSensitive: false
        ),
        "com.apple.security.network.client": EntitlementSpec(
            title: LocalizedText(tr: "Giden Ağ Bağlantıları", en: "Outbound Network Access"),
            explanation: LocalizedText(
                tr: "İnternete veya yerel ağa giden bağlantılar başlatabilir.",
                en: "Can initiate outbound network connections to the internet or LAN."
            ),
            isSensitive: false
        ),
        "com.apple.security.network.server": EntitlementSpec(
            title: LocalizedText(tr: "Gelen Ağ Bağlantıları", en: "Inbound Network Connections"),
            explanation: LocalizedText(
                tr: "Yerel ağdan gelen bağlantıları dinleyebilir (sunucu/yayın modu).",
                en: "Can listen for incoming network connections (server/listener mode)."
            ),
            isSensitive: true
        ),
        "com.apple.security.files.user-selected.read-write": EntitlementSpec(
            title: LocalizedText(tr: "Kullanıcının Seçtiği Dosyalar (Okuma/Yazma)", en: "User-Selected Files (Read/Write)"),
            explanation: LocalizedText(
                tr: "Aç/Kaydet penceresiyle kullanıcının seçtiği dosya ve klasörlere erişebilir.",
                en: "Can read and write files or folders explicitly chosen by the user via Open/Save dialogs."
            ),
            isSensitive: false
        ),
        "com.apple.security.files.user-selected.read-only": EntitlementSpec(
            title: LocalizedText(tr: "Kullanıcının Seçtiği Dosyalar (Salt Okunur)", en: "User-Selected Files (Read-Only)"),
            explanation: LocalizedText(
                tr: "Kullanıcının seçtiği dosyaları yalnızca okuyabilir.",
                en: "Can only read files explicitly chosen by the user."
            ),
            isSensitive: false
        ),
        "com.apple.security.files.downloads.read-write": EntitlementSpec(
            title: LocalizedText(tr: "İndirilenler Klasörü Erişimi", en: "Downloads Folder Access"),
            explanation: LocalizedText(
                tr: "Kullanıcının İndirilenler klasörüne doğrudan erişim ister.",
                en: "Allows direct read/write access to the user's Downloads folder."
            ),
            isSensitive: true
        ),
        "com.apple.security.device.camera": EntitlementSpec(
            title: LocalizedText(tr: "Kamera Donanımı", en: "Camera Hardware"),
            explanation: LocalizedText(
                tr: "Sandbox içinde kamera aygıtına erişim yetkisi.",
                en: "Allows access to camera capture devices inside App Sandbox."
            ),
            isSensitive: true
        ),
        "com.apple.security.device.audio-input": EntitlementSpec(
            title: LocalizedText(tr: "Mikrofon / Ses Girişi", en: "Microphone / Audio Input"),
            explanation: LocalizedText(
                tr: "Sandbox içinde mikrofon ve ses girişi yetkisi.",
                en: "Allows microphone and audio input recording inside App Sandbox."
            ),
            isSensitive: true
        ),
        "com.apple.security.device.bluetooth": EntitlementSpec(
            title: LocalizedText(tr: "Bluetooth Donanımı", en: "Bluetooth Hardware"),
            explanation: LocalizedText(
                tr: "Bluetooth cihazlarıyla iletişim kurabilir.",
                en: "Allows communication with paired Bluetooth devices."
            ),
            isSensitive: false
        ),
        "com.apple.security.device.usb": EntitlementSpec(
            title: LocalizedText(tr: "USB Donanım Erişimi", en: "USB Hardware Access"),
            explanation: LocalizedText(
                tr: "Doğrudan USB aygıtlarıyla iletişim kurabilir.",
                en: "Allows direct communication with connected USB devices."
            ),
            isSensitive: true
        ),
        "com.apple.security.automation.apple-events": EntitlementSpec(
            title: LocalizedText(tr: "AppleEvents Otomasyonu", en: "AppleEvents Automation"),
            explanation: LocalizedText(
                tr: "Diğer uygulamaları AppleScript / AppleEvents ile kontrol edebilir.",
                en: "Can send AppleEvents / AppleScript commands to control other applications."
            ),
            isSensitive: true
        ),
        "com.apple.security.cs.allow-unsigned-executable-memory": EntitlementSpec(
            title: LocalizedText(tr: "İmzasız Çalıştırılabilir Bellek", en: "Allow Unsigned Executable Memory"),
            explanation: LocalizedText(
                tr: "JIT/eklenti/dinamik kod üretimi için imzasız çalıştırılabilir bellek sayfalarına izin verir.",
                en: "Allows writable/executable unsigned memory pages for plugins or dynamic code generation."
            ),
            isSensitive: true
        ),
        "com.apple.security.cs.disable-library-validation": EntitlementSpec(
            title: LocalizedText(tr: "Kütüphane Doğrulaması Devre Dışı", en: "Disable Library Validation"),
            explanation: LocalizedText(
                tr: "Üçüncü parti veya imzasız dinamik kütüphaneleri (.dylib) ve eklentileri yükleyebilir.",
                en: "Allows loading third-party or differently signed dynamic libraries (.dylib) and plugins."
            ),
            isSensitive: true
        ),
        "com.apple.security.cs.allow-jit": EntitlementSpec(
            title: LocalizedText(tr: "JIT Kod Derleme (MAP_JIT)", en: "Allow JIT Compilation (MAP_JIT)"),
            explanation: LocalizedText(
                tr: "Çalışma zamanında dinamik makine kodu derlemeye (JIT) izin verir.",
                en: "Allows Just-In-Time (JIT) executable code compilation at runtime."
            ),
            isSensitive: true
        ),
        "com.apple.security.cs.allow-dyld-environment-variables": EntitlementSpec(
            title: LocalizedText(tr: "DYLD Ortam Değişkenleri", en: "Allow DYLD Environment Variables"),
            explanation: LocalizedText(
                tr: "Dinamik bağlayıcı ortam değişkenlerinin kullanılmasına izin verir.",
                en: "Permits dynamic linker (DYLD) environment variables to affect execution."
            ),
            isSensitive: true
        ),
        "com.apple.security.cs.debugger": EntitlementSpec(
            title: LocalizedText(tr: "Hata Ayıklayıcı (Debugger) Yetkisi", en: "Debugger Tool Entitlement"),
            explanation: LocalizedText(
                tr: "Diğer işlemlere hata ayıklayıcı (debug) olarak bağlanabilir.",
                en: "Allows attaching as a debugger to other processes."
            ),
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

    public func resetTCCPermission(
        service: String,
        bundleID: String,
        language: AppLanguage = .english
    ) async throws -> String {
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
                let fallbackMsg = language == .turkish
                    ? "Çıkış kodu \(process.terminationStatus)"
                    : "Exit code \(process.terminationStatus)"
                let message = errText.isEmpty ? outText : errText
                throw TCCResetError.commandFailed(message.isEmpty ? fallbackMsg : message)
            }

            if outText.isEmpty {
                return language == .turkish
                    ? "\(bundleID) için \(service) izni sıfırlandı."
                    : "Reset \(service) permission for \(bundleID)."
            }
            return outText
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
                return "Arch #\(num.intValue)"
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
                title: LocalizedText(same: friendlyEntitlementTitle(key)),
                explanation: LocalizedText(
                    tr: "Uygulama kod imzasına gömülü özel yetki (entitlement).",
                    en: "Custom entitlement embedded in the app's code signature."
                ),
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
                        displayName: LocalizedText(same: friendlyPrivacyTitle(key)),
                        symbolName: "hand.raised.fill",
                        usageDescription: description,
                        tccutilService: nil,
                        settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")
                    )
                )
            }
        }

        return results.sorted { $0.plistKey.localizedCaseInsensitiveCompare($1.plistKey) == .orderedAscending }
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
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "SQLite code \(openCode)"
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
            let serviceKey = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? "Unknown"
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
            let displayName = spec?.displayName ?? LocalizedText(same: serviceKey.replacingOccurrences(of: "kTCCService", with: ""))
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

    private static func summarizeEntitlementValue(_ value: Any?) -> LocalizedText {
        switch value {
        case let bool as Bool:
            return bool
                ? LocalizedText(tr: "Açık (true)", en: "Enabled (true)")
                : LocalizedText(tr: "Kapalı (false)", en: "Disabled (false)")
        case let str as String:
            return LocalizedText(same: str)
        case let num as NSNumber:
            return LocalizedText(same: num.stringValue)
        case let arr as [Any]:
            if arr.isEmpty {
                return LocalizedText(tr: "Boş liste", en: "Empty list")
            }
            let preview = arr.prefix(3).map { "\($0)" }.joined(separator: ", ")
            let text = arr.count > 3 ? "\(preview) (+\(arr.count - 3))" : preview
            return LocalizedText(same: text)
        case let dict as [String: Any]:
            return LocalizedText(tr: "\(dict.count) anahtar", en: "\(dict.count) keys")
        default:
            return LocalizedText(tr: "Tanımlı", en: "Defined")
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
