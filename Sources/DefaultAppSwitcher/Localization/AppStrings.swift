import DefaultAppSwitcherCore
import Foundation

struct AppStrings: Sendable {
    let language: AppLanguage

    private func pick(tr: String, en: String) -> String {
        language == .turkish ? tr : en
    }

    // MARK: - App & Toolbar

    var windowTitle: String { "DefaultAppSwitcher" }
    var refresh: String { pick(tr: "Yenile", en: "Refresh") }
    var refreshTooltip: String {
        pick(
            tr: "LaunchServices ve uygulama verilerini yenile (⌘R)",
            en: "Refresh LaunchServices and application data (⌘R)"
        )
    }
    var snapshots: String { pick(tr: "Yedekler", en: "Snapshots") }
    func snapshotsCount(_ count: Int) -> String {
        pick(tr: "Yedekler (\(count))", en: "Snapshots (\(count))")
    }
    var snapshotsTooltip: String {
        pick(
            tr: "Sıfırlama yedeklerini görüntüle ve geri al",
            en: "View and restore reset snapshots"
        )
    }
    var languageSwitchTooltip: String {
        pick(
            tr: "Arayüz dilini değiştir (Türkçe / English)",
            en: "Switch interface language (Türkçe / English)"
        )
    }

    // MARK: - Detail Empty / Loading

    var scanningApps: String {
        pick(tr: "Uygulamalar taranıyor...", en: "Scanning applications...")
    }
    var selectAppTitle: String {
        pick(tr: "Uygulama Seçin", en: "Select an Application")
    }
    var selectAppDescription: String {
        pick(
            tr: "Sol kenar çubuğundan incelemek veya varsayılanlarını sıfırlamak istediğiniz bir uygulamayı seçin.",
            en: "Choose an application from the sidebar to inspect its permissions or reset its default file associations."
        )
    }

    // MARK: - Sidebar

    var searchAppsPlaceholder: String {
        pick(tr: "Uygulama ara...", en: "Search apps...")
    }
    var quickManagementSection: String {
        pick(tr: "Hızlı Yönetim", en: "Quick Actions")
    }
    var overviewTitle: String {
        pick(tr: "Genel Bakış", en: "Overview")
    }
    var appsWithOverridesSection: String {
        pick(tr: "Özel Varsayılanı Olanlar", en: "Apps with Overrides")
    }
    var onlyThirdPartyApps: String {
        pick(tr: "Yalnızca 3. Parti Uygulamalar", en: "Third-Party Apps Only")
    }
    func allAppsSection(_ count: Int) -> String {
        pick(tr: "Tüm Uygulamalar (\(count))", en: "All Applications (\(count))")
    }
    var notInstalledShort: String {
        pick(tr: "Kurulu değil", en: "Not installed")
    }

    // MARK: - Overview

    var heroTitle: String {
        pick(
            tr: "Tek Tuşla Varsayılan Uygulamaları Sıfırla",
            en: "Reset Default Apps in One Click"
        )
    }
    var heroSubtitle: String {
        pick(
            tr: "LaunchServices veritabanındaki özel dosya uzantısı ve medya atamalarını güvenle macOS varsayılanlarına (QuickTime Player, Müzik, TextEdit vb.) geri alın. Her işlem öncesi otomatik yedek alınır.",
            en: "Safely revert custom file extension and media overrides in LaunchServices back to standard macOS defaults (QuickTime Player, Music, TextEdit, etc.). A snapshot is automatically saved before every change."
        )
    }
    func resetMediaButton(_ count: Int) -> String {
        pick(tr: "Medya Uzantılarını Sıfırla (\(count))", en: "Reset Media Extensions (\(count))")
    }
    func resetAllOverridesButton(_ count: Int) -> String {
        pick(tr: "Tüm Özel Varsayılanları Sıfırla (\(count))", en: "Reset All Overrides (\(count))")
    }
    var backupsRestoreButton: String {
        pick(tr: "Yedekler / Geri Al", en: "Snapshots / Undo")
    }

    var metricThirdPartyTitle: String {
        pick(tr: "3. Parti Özel Atama", en: "Third-Party Overrides")
    }
    func metricThirdPartySubtitle(_ total: Int) -> String {
        pick(tr: "Toplam \(total) kayıt içinde", en: "Out of \(total) total overrides")
    }
    var metricAffectedAppsTitle: String {
        pick(tr: "Etkilenen Uygulama", en: "Affected Apps")
    }
    var metricAffectedAppsSubtitle: String {
        pick(tr: "Sol listeden detayına inin", en: "Select an app in the sidebar")
    }
    var metricCollisionsTitle: String {
        pick(tr: "Tür Çakışması", en: "Type Collisions")
    }
    var metricCollisionsSubtitleSome: String {
        pick(tr: "Örn. medya oynatıcıya bağlı .ts / .ps", en: "e.g. .ts / .ps linked to a media player")
    }
    var metricCollisionsSubtitleNone: String {
        pick(tr: "Çakışma tespit edilmedi", en: "No collisions detected")
    }

    var activeOverridesTitle: String {
        pick(tr: "Aktif Varsayılan Atamalar", en: "Active Default Overrides")
    }
    var filterLabel: String { pick(tr: "Filtre", en: "Filter") }
    func overviewFilterTitle(_ mode: OverviewFilterMode) -> String {
        switch mode {
        case .thirdParty: return pick(tr: "3. Parti", en: "3rd Party")
        case .media: return pick(tr: "Medya", en: "Media")
        case .collisions: return pick(tr: "Çakışanlar", en: "Collisions")
        case .schemes: return pick(tr: "URL Şemaları", en: "URL Schemes")
        case .all: return pick(tr: "Tümü", en: "All")
        }
    }
    var searchOverridesPlaceholder: String {
        pick(tr: "Uzantı, UTI veya uygulama ara...", en: "Search extension, UTI, or app...")
    }
    var readingLaunchServices: String {
        pick(tr: "LaunchServices kayıtları okunuyor...", en: "Reading LaunchServices database...")
    }
    var noRecordsTitle: String {
        pick(tr: "Kayıt Bulunamadı", en: "No Records Found")
    }
    var noRecordsDescription: String {
        pick(
            tr: "Seçili filtre için gösterilecek aktif varsayılan atama yok.",
            en: "No active default overrides match the selected filter."
        )
    }

    // MARK: - Association Row

    var collisionBadge: String { pick(tr: "Çakışma", en: "Collision") }
    var explicitOverrideBadge: String { pick(tr: "Özel Atama", en: "Override") }
    var defaultBadge: String { pick(tr: "Varsayılan", en: "Default") }
    func openAppDetailsTooltip(_ name: String) -> String {
        pick(tr: "\(name) detayını aç", en: "Open \(name) details")
    }
    var macOSDefaultBadge: String { pick(tr: "macOS Varsayılanı", en: "macOS Default") }
    var noSystemAlternative: String { pick(tr: "Sistem alternatifi yok", en: "No system alternative") }
    var noOtherAppsRegistered: String {
        pick(tr: "Kayıtlı başka uygulama bulunamadı", en: "No other compatible apps found")
    }
    var changeButton: String { pick(tr: "Değiştir", en: "Change") }
    var resetButton: String { pick(tr: "Sıfırla", en: "Reset") }

    // MARK: - App Detail Header & Tabs

    func tabAssociationsTitle(_ count: Int) -> String {
        pick(tr: "Varsayılan Uzantılar (\(count))", en: "Default Extensions (\(count))")
    }
    var tabPermissionsTitle: String {
        pick(tr: "İzinler & Güvenlik", en: "Permissions & Security")
    }
    func analyzingApp(_ name: String) -> String {
        pick(tr: "\(name) inceleniyor...", en: "Inspecting \(name)...")
    }
    var notInstalledBadge: String { pick(tr: "Kurulu Değil", en: "Not Installed") }
    var appleAppBadge: String { pick(tr: "Apple Uygulaması", en: "Apple App") }
    var sandboxBadge: String { pick(tr: "Sandbox", en: "Sandboxed") }
    var nonSandboxBadge: String { pick(tr: "Sandbox Dışı", en: "Unsandboxed") }
    var hardenedRuntimeBadge: String { "Hardened Runtime" }
    func versionBuild(_ version: String, _ build: String) -> String {
        pick(tr: "Sürüm \(version) (\(build))", en: "Version \(version) (\(build))")
    }
    var uninstalledPathHint: String {
        pick(
            tr: "Sistemde kurulu değil (yalnızca LaunchServices kaydı)",
            en: "Not installed on disk (LaunchServices record only)"
        )
    }
    func resetAppDefaultsButton(_ count: Int) -> String {
        pick(
            tr: "Bu Uygulamanın Varsayılanlarını Sıfırla (\(count))",
            en: "Reset Defaults for This App (\(count))"
        )
    }
    var revealInFinder: String { pick(tr: "Finder'da Göster", en: "Show in Finder") }

    // MARK: - App Associations Tab

    var noAssociationsTitle: String {
        pick(tr: "Varsayılan Atama Yok", en: "No Default Associations")
    }
    func noAssociationsDescription(_ appName: String) -> String {
        pick(
            tr: "\(appName) şu anda seçili filtreye göre hiçbir uzantının varsayılan uygulaması değil.",
            en: "\(appName) is not currently set as the default app for any file type matching this filter."
        )
    }
    func collisionWarningTitle(_ count: Int) -> String {
        pick(
            tr: "Dikkat: \(count) Tür Çakışması Tespit Edildi",
            en: "Warning: \(count) Type Collision(s) Detected"
        )
    }
    func collisionWarningDetail(_ list: String) -> String {
        pick(
            tr: "\(list) türleri yanlışlıkla bu uygulamaya atanmış görünüyor.",
            en: "\(list) appear(s) to be mistakenly assigned to this app."
        )
    }
    var resetCollisionsButton: String {
        pick(tr: "Çakışanları Sıfırla", en: "Reset Collisions")
    }
    func allCategoryCount(_ count: Int) -> String {
        pick(tr: "Tümü (\(count))", en: "All (\(count))")
    }
    var searchExtensionPlaceholder: String {
        pick(tr: "Uzantı veya UTI ara...", en: "Search extension or UTI...")
    }
    func otherExtensionsTitle(_ count: Int) -> String {
        pick(
            tr: "Desteklediği Ancak Varsayılan Olmadığı Uzantılar (\(count))",
            en: "Supported Non-Default Extensions (\(count))"
        )
    }
    var noneText: String { pick(tr: "Yok", en: "None") }

    // MARK: - App Permissions Tab

    var preparingSecurityReport: String {
        pick(tr: "İzin ve güvenlik raporu hazırlanıyor...", en: "Preparing permissions & security report...")
    }
    func resetAllTCCDialogTitle(_ name: String) -> String {
        pick(
            tr: "\(name) için tüm gizlilik (TCC) izinleri sıfırlansın mı?",
            en: "Reset all privacy (TCC) permissions for \(name)?"
        )
    }
    var resetAllTCCDialogConfirm: String {
        pick(tr: "Tüm İzinleri Sıfırla (tccutil reset All)", en: "Reset All Permissions (tccutil reset All)")
    }
    var cancelButton: String { pick(tr: "Vazgeç", en: "Cancel") }
    var resetAllTCCDialogMessage: String {
        pick(
            tr: "Kamera, Mikrofon, Klasör Erişimi ve Otomasyon gibi verilmiş tüm gizlilik onayları temizlenir. Uygulama tekrar istediğinde macOS yeniden onay sorar.",
            en: "Clears all granted privacy approvals such as Camera, Microphone, Folder Access, and Automation. macOS will prompt again when the app requests access."
        )
    }
    var uninstalledBannerTitle: String {
        pick(tr: "Uygulama Diskte Bulunamadı", en: "Application Not Found on Disk")
    }
    var uninstalledBannerBody: String {
        pick(
            tr: "Bu uygulama silinmiş veya taşınmış görünüyor; yalnızca LaunchServices varsayılan kaydı ve olası TCC gizlilik kayıtları mevcut.",
            en: "This app appears to have been deleted or moved; only its LaunchServices record and any leftover TCC privacy entries remain."
        )
    }
    var tccSectionTitle: String {
        pick(
            tr: "Verilmiş Sistem Gizlilik İzinleri (TCC Veritabanı)",
            en: "Granted System Privacy Permissions (TCC Database)"
        )
    }
    var openPrivacySettings: String {
        pick(tr: "Gizlilik Ayarlarını Aç", en: "Open Privacy Settings")
    }
    var resetAllTCCButton: String {
        pick(tr: "Tüm TCC İzinlerini Sıfırla", en: "Reset All TCC Permissions")
    }
    var fdaRequiredTitle: String {
        pick(
            tr: "Canlı Onay Durumları İçin Tam Disk Erişimi Gerekli",
            en: "Full Disk Access Required for Live Approval Status"
        )
    }
    var fdaRequiredBody: String {
        pick(
            tr: "macOS, diğer uygulamaların verilmiş/reddedilmiş canlı TCC veritabanı kayıtlarını (TCC.db) yalnızca Tam Disk Erişimi verilen uygulamaların okumasına izin verir. Yine de aşağıdaki 'Beyan Edilen İzinler' ve 'Yetkiler' her zaman görünür ve 'tccutil' ile sıfırlanabilir.",
            en: "macOS restricts reading other apps' live granted/denied TCC database entries (TCC.db) unless Full Disk Access is granted. Declared Permissions and Entitlements below are always visible and can still be reset with 'tccutil'."
        )
    }
    var grantFDAButton: String {
        pick(tr: "Tam Disk Erişimi Ver", en: "Grant Full Disk Access")
    }
    var recheckButton: String {
        pick(tr: "Tekrar Kontrol Et", en: "Check Again")
    }
    func targetPrefix(_ target: String) -> String {
        pick(tr: "Hedef: \(target)", en: "Target: \(target)")
    }
    var systemSettingsButton: String {
        pick(tr: "Sistem Ayarları", en: "System Settings")
    }
    var noTCCEntriesMessage: String {
        pick(
            tr: "Bu uygulama için TCC veritabanında kayıtlı verilmiş veya reddedilmiş gizlilik izni bulunamadı.",
            en: "No granted or denied TCC privacy entries were found for this app."
        )
    }
    var declaredPrivacyTitle: String {
        pick(
            tr: "Beyan Edilen Gizlilik İzinleri (Info.plist)",
            en: "Declared Privacy Permissions (Info.plist)"
        )
    }
    var noDeclaredPrivacyMain: String {
        pick(
            tr: "Bu uygulama Info.plist içinde kamera, mikrofon, konum veya klasör erişimi gibi özel bir gizlilik açıklaması (NS*UsageDescription) beyan etmiyor.",
            en: "This app does not declare any privacy usage descriptions (NS*UsageDescription) such as Camera, Microphone, Location, or Folder access in its Info.plist."
        )
    }
    var noDeclaredPrivacySandboxed: String {
        pick(
            tr: "Uygulama App Sandbox içinde çalıştığı için ek izinleri kısıtlıdır.",
            en: "Because this app runs inside App Sandbox, additional system permissions are restricted."
        )
    }
    var noDeclaredPrivacyUnsandboxed: String {
        pick(
            tr: "Not: Uygulama App Sandbox dışında çalıştığı için kullanıcının normal dosya izinleriyle dosya okuyabilir; ekstra TCC izinleri yalnızca ihtiyaç duyulduğunda sistem tarafından istenir.",
            en: "Note: Because this app runs outside App Sandbox, it inherits your standard user file permissions; protected TCC resources are prompted by macOS on demand."
        )
    }
    var openSettingsShort: String { pick(tr: "Ayarları Aç", en: "Open Settings") }
    var codeSigningTitle: String {
        pick(tr: "Kod İmzalama & Güvenlik Profili", en: "Code Signing & Security Profile")
    }
    var signingStatusLabel: String { pick(tr: "İmza Durumu", en: "Signing Status") }
    var signingAdHoc: String { pick(tr: "Ad-Hoc İmzalı", en: "Ad-Hoc Signed") }
    var signingValid: String { pick(tr: "Geçerli Kod İmzası", en: "Valid Code Signature") }
    var signingUnsigned: String { pick(tr: "İmzasız", en: "Unsigned") }
    var signingAuthorityLabel: String { pick(tr: "İmza Otoritesi", en: "Signing Authority") }
    var unknownText: String { pick(tr: "Bilinmiyor", en: "Unknown") }
    var teamIDLabel: String { pick(tr: "Takım Kimliği (Team ID)", en: "Team Identifier") }
    var appleSystemText: String { pick(tr: "Apple Sistem", en: "Apple System") }
    var appSandboxLabel: String { "App Sandbox" }
    var enabledIsolated: String { pick(tr: "Etkin (İzole)", en: "Enabled (Isolated)") }
    var disabledText: String { pick(tr: "Devre Dışı", en: "Disabled") }
    var hardenedRuntimeLabel: String { "Hardened Runtime" }
    var enabledText: String { pick(tr: "Etkin", en: "Enabled") }
    var quarantineLabel: String { pick(tr: "Karantina Özelliği", en: "Quarantine Attribute") }
    var quarantinePresent: String {
        pick(tr: "Mevcut (com.apple.quarantine)", en: "Present (com.apple.quarantine)")
    }
    var cleanText: String { pick(tr: "Temiz", en: "Clean") }
    var architectureLabel: String { pick(tr: "Mimari", en: "Architecture") }
    var minOSLabel: String { pick(tr: "Min. macOS Sürümü", en: "Minimum macOS") }
    func entitlementsTitle(_ count: Int) -> String {
        pick(tr: "Gömülü Yetkiler / Entitlements (\(count))", en: "Embedded Entitlements (\(count))")
    }
    var noEntitlements: String {
        pick(
            tr: "Uygulama imzasında gömülü ek entitlement bulunmuyor.",
            en: "No embedded entitlements found in this app's code signature."
        )
    }
    var sensitivePermissionBadge: String { pick(tr: "Hassas Yetki", en: "Sensitive") }
    var schemesAndBackgroundTitle: String {
        pick(tr: "URL Şemaları & Arka Plan Öğeleri", en: "URL Schemes & Background Items")
    }
    var defaultHandlerBadge: String { pick(tr: "Varsayılan Handler", en: "Default Handler") }
    func currentDefaultOwner(_ owner: String) -> String {
        pick(tr: "Mevcut varsayılan: \(owner)", en: "Current default: \(owner)")
    }

    // MARK: - Confirmation Sheet

    var toggleBrowserAndSchemes: String {
        pick(
            tr: "Tarayıcı (http/https/html) ve diğer URL şemalarını da Safari'ye sıfırla",
            en: "Also reset browser (http/https/html) and URL schemes to Safari"
        )
    }
    func previewResetHeader(_ count: Int) -> String {
        pick(
            tr: "Önizleme — Toplam \(count) atama sıfırlanacak:",
            en: "Preview — \(count) association(s) will be reset:"
        )
    }
    var noResettableFound: String {
        pick(tr: "Sıfırlanabilecek uygun bir atama bulunamadı.", en: "No eligible associations found to reset.")
    }
    func extensionTargetLine(_ count: Int, _ appName: String) -> String {
        pick(tr: "\(count) uzantı → \(appName)", en: "\(count) extension(s) → \(appName)")
    }
    var snapshotNotice: String {
        pick(
            tr: "İşlem öncesi mevcut tüm varsayılanlarınız otomatik yedeklenir; istediğiniz an Yedekler menüsünden geri alabilirsiniz.",
            en: "A snapshot of your current defaults is saved automatically before applying changes; you can undo anytime from Snapshots."
        )
    }
    func confirmAndResetButton(_ count: Int) -> String {
        pick(tr: "Onayla ve Sıfırla (\(count))", en: "Confirm & Reset (\(count))")
    }

    // MARK: - Snapshots Sheet

    var snapshotsTitle: String {
        pick(tr: "Sıfırlama Yedekleri (Geri Al)", en: "Reset Snapshots (Undo)")
    }
    var snapshotsSubtitle: String {
        pick(
            tr: "Her sıfırlama işleminden önce mevcut uzantı eşleştirmeleriniz otomatik kaydedilir.",
            en: "Your current default associations are automatically saved before every reset or change."
        )
    }
    var closeButton: String { pick(tr: "Kapat", en: "Close") }
    var noSnapshotsTitle: String { pick(tr: "Henüz Yedek Yok", en: "No Snapshots Yet") }
    var noSnapshotsDescription: String {
        pick(
            tr: "Bir varsayılan sıfırlama veya değiştirme işlemi yaptığınızda otomatik geri yükleme noktası burada görünür.",
            en: "An automatic restore point will appear here whenever you reset or change a default app."
        )
    }
    func snapshotEntriesMeta(_ dateText: String, _ count: Int) -> String {
        pick(tr: "\(dateText) • \(count) atama", en: "\(dateText) • \(count) association(s)")
    }
    var restoreButton: String { pick(tr: "Geri Yükle", en: "Restore") }

    // MARK: - Prompts & Status Banners

    var loadFailedTitle: String { pick(tr: "Veriler yüklenemedi", en: "Failed to load data") }
    var globalResetTitle: String {
        pick(tr: "Tüm Özel Varsayılanları Sıfırla", en: "Reset All Custom Defaults")
    }
    var globalResetSubtitle: String {
        pick(
            tr: "Sistem dışı uygulamalara atanmış tüm dosya uzantılarını macOS varsayılanlarına (QuickTime, Müzik, TextEdit vb.) döndürür.",
            en: "Reverts all file extensions assigned to third-party apps back to macOS defaults (QuickTime Player, Music, TextEdit, etc.)."
        )
    }
    var mediaResetTitle: String {
        pick(tr: "Medya Uzantılarını Sıfırla", en: "Reset Media Extensions")
    }
    var mediaResetSubtitle: String {
        pick(
            tr: "Video, ses ve yanlışlıkla medya oynatıcılara bağlanmış (.ts, .ps vb.) uzantıları tek tuşla Apple uygulamalarına döndürür.",
            en: "Reverts video, audio, and hijacked extensions (.ts, .ps, etc.) assigned to media players back to Apple apps in one click."
        )
    }
    func appResetTitle(_ name: String) -> String {
        pick(tr: "\(name) Varsayılanlarını Sıfırla", en: "Reset \(name) Defaults")
    }
    func appResetSubtitle(_ name: String) -> String {
        pick(
            tr: "\(name) uygulamasına bağlı varsayılan dosya uzantıları önerilen sistem uygulamalarına geri alınacaktır.",
            en: "Default file extensions currently assigned to \(name) will be restored to recommended macOS system apps."
        )
    }
    func singleResetSnapshotTitle(_ extText: String) -> String {
        pick(tr: "\(extText) sıfırlandı", en: "Reset \(extText)")
    }
    func collisionsResetSnapshotTitle(_ appName: String) -> String {
        pick(tr: "\(appName) çakışan uzantıları sıfırlandı", en: "Reset \(appName) colliding extensions")
    }
    func updatedTitle(_ extText: String) -> String {
        pick(tr: "\(extText) güncellendi", en: "Updated \(extText)")
    }
    func newDefaultDetail(_ targetName: String) -> String {
        pick(tr: "Yeni varsayılan uygulama: \(targetName)", en: "New default app: \(targetName)")
    }
    var changeFailedTitle: String {
        pick(tr: "Varsayılan değiştirilemedi", en: "Failed to change default app")
    }
    func resetSuccessTitle(_ count: Int) -> String {
        pick(tr: "\(count) uzantı varsayılana sıfırlandı", en: "Reset \(count) association(s) to default")
    }
    func resetSuccessDetail(skipped: Int) -> String {
        if skipped > 0 {
            return pick(
                tr: "\(skipped) öğe atlandı (sistem alternatifi yok). Yedek kaydedildi.",
                en: "\(skipped) item(s) skipped (no system alternative). Snapshot saved."
            )
        }
        return pick(
            tr: "Otomatik yedek oluşturuldu; istediğiniz zaman Yedekler menüsünden geri alabilirsiniz.",
            en: "Automatic snapshot saved; you can undo anytime from Snapshots."
        )
    }
    func resetPartialTitle(succeeded: Int, failed: Int) -> String {
        pick(
            tr: "\(succeeded) sıfırlandı, \(failed) başarısız",
            en: "\(succeeded) reset, \(failed) failed"
        )
    }
    var restoreSuccessTitle: String {
        pick(tr: "Yedek geri yüklendi", en: "Snapshot restored")
    }
    func restoreSuccessDetail(_ count: Int) -> String {
        pick(
            tr: "\(count) varsayılan atama önceki haline döndürüldü.",
            en: "\(count) default association(s) restored to their previous apps."
        )
    }
    func restorePartialTitle(succeeded: Int, failed: Int) -> String {
        pick(
            tr: "Kısmi geri yükleme: \(succeeded) başarılı, \(failed) hata",
            en: "Partial restore: \(succeeded) succeeded, \(failed) failed"
        )
    }
    func tccResetSuccessTitle(_ appName: String) -> String {
        pick(tr: "\(appName) gizlilik izni sıfırlandı", en: "Reset privacy permission for \(appName)")
    }
    var tccResetFailedTitle: String {
        pick(tr: "Gizlilik izni sıfırlanamadı", en: "Failed to reset privacy permission")
    }
}
