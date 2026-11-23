import DefaultAppSwitcherCore
import SwiftUI

struct AppPermissionsTab: View {
    @Bindable var state: AppState
    let app: InstalledApp

    @State private var confirmResetAllTCC: Bool = false

    var body: some View {
        ScrollView {
            if let report = state.selectedAppReport {
                VStack(alignment: .leading, spacing: 18) {
                    if !app.isInstalled {
                        uninstalledNoticeBanner
                    }

                    liveTCCSection(report: report)

                    if app.isInstalled {
                        declaredPrivacySection(report: report)

                        codeSigningSection(report: report)

                        entitlementsSection(report: report)

                        if !report.urlSchemes.isEmpty || !report.backgroundItems.isEmpty {
                            schemesAndBackgroundSection(report: report)
                        }
                    }
                }
                .padding(20)
            } else {
                ProgressView("İzin ve güvenlik raporu hazırlanıyor...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .confirmationDialog(
            "\(app.name) için tüm gizlilik (TCC) izinleri sıfırlansın mı?",
            isPresented: $confirmResetAllTCC,
            titleVisibility: .visible
        ) {
            Button("Tüm İzinleri Sıfırla (tccutil reset All)", role: .destructive) {
                Task {
                    await state.resetTCCPermission(service: "All", for: app)
                }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Kamera, Mikrofon, Klasör Erişimi ve Otomasyon gibi verilmiş tüm gizlilik onayları temizlenir. Uygulama tekrar istediğinde macOS yeniden onay sorar.")
        }
    }

    private var uninstalledNoticeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Uygulama Diskte Bulunamadı")
                    .font(.callout.weight(.semibold))
                Text("Bu uygulama silinmiş veya taşınmış görünüyor; yalnızca LaunchServices varsayılan kaydı ve olası TCC gizlilik kayıtları mevcut.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - 1. Live TCC Section

    private func liveTCCSection(report: AppSecurityReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Verilmiş Sistem Gizlilik İzinleri (TCC Veritabanı)", systemImage: "hand.raised.shield.fill")
                    .font(.headline)
                Spacer()
                Button("Gizlilik Ayarlarını Aç") {
                    state.openSystemSettings(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy"))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    confirmResetAllTCC = true
                } label: {
                    Label("Tüm TCC İzinlerini Sıfırla", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(state.isMutating)
            }

            if report.needsFullDiskAccessForTCC {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Canlı Onay Durumları İçin Tam Disk Erişimi Gerekli")
                            .font(.callout.weight(.semibold))
                        Text("macOS, diğer uygulamaların verilmiş/reddedilmiş canlı TCC veritabanı kayıtlarını (TCC.db) yalnızca Tam Disk Erişimi verilen uygulamaların okumasına izin verir. Yine de aşağıdaki 'Beyan Edilen İzinler' ve 'Yetkiler' her zaman görünür ve 'tccutil' ile sıfırlanabilir.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        Button("Tam Disk Erişimi Ver") {
                            state.openFullDiskAccessSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Tekrar Kontrol Et") {
                            Task {
                                await state.loadDetail(for: app)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
                )
            }

            if !report.tccEntries.isEmpty {
                VStack(spacing: 8) {
                    ForEach(report.tccEntries) { entry in
                        HStack(spacing: 10) {
                            Image(systemName: entry.symbolName)
                                .foregroundStyle(.blue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(entry.displayName)
                                        .font(.callout.weight(.semibold))
                                    PillBadge(
                                        text: entry.status.displayName,
                                        color: tccColor(entry.status)
                                    )
                                    PillBadge(text: entry.scope.rawValue, color: .secondary)
                                }
                                if let target = entry.indirectTarget {
                                    Text("Hedef: \(target)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if let settingsURL = entry.settingsURL {
                                Button("Sistem Ayarları") {
                                    state.openSystemSettings(settingsURL)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if let svc = entry.tccutilName {
                                Button("Sıfırla") {
                                    Task {
                                        await state.resetTCCPermission(service: svc, for: app)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(state.isMutating)
                            }
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            } else if !report.needsFullDiskAccessForTCC {
                Text("Bu uygulama için TCC veritabanında kayıtlı verilmiş veya reddedilmiş gizlilik izni bulunamadı.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func tccColor(_ status: TCCAuthStatus) -> Color {
        switch status {
        case .allowed: return .green
        case .denied: return .red
        case .limited: return .orange
        case .unknown: return .secondary
        }
    }

    // MARK: - 2. Info.plist Declared Permissions

    private func declaredPrivacySection(report: AppSecurityReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Beyan Edilen Gizlilik İzinleri (Info.plist)", systemImage: "doc.text.magnifyingglass")
                .font(.headline)

            if report.declaredPermissions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bu uygulama Info.plist içinde kamera, mikrofon, konum veya klasör erişimi gibi özel bir gizlilik açıklaması (NS*UsageDescription) beyan etmiyor.")
                        .font(.callout)
                    Text(report.codeSigning.isSandboxed ? "Uygulama App Sandbox içinde çalıştığı için ek izinleri kısıtlıdır." : "Not: Uygulama App Sandbox dışında çalıştığı için kullanıcının normal dosya izinleriyle dosya okuyabilir; ekstra TCC izinleri yalnızca ihtiyaç duyulduğunda sistem tarafından istenir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(report.declaredPermissions) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.symbolName)
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 26)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(item.displayName)
                                        .font(.callout.weight(.semibold))
                                    Text(item.plistKey)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                                Text("“\(item.usageDescription)”")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            HStack(spacing: 6) {
                                if let settingsURL = item.settingsURL {
                                    Button("Ayarları Aç") {
                                        state.openSystemSettings(settingsURL)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                if let svc = item.tccutilService {
                                    Button("Sıfırla") {
                                        Task {
                                            await state.resetTCCPermission(service: svc, for: app)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(state.isMutating)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - 3. Code Signing Summary

    private func codeSigningSection(report: AppSecurityReport) -> some View {
        let cs = report.codeSigning
        return VStack(alignment: .leading, spacing: 10) {
            Label("Kod İmzalama & Güvenlik Profili", systemImage: "checkmark.seal.fill")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                infoGridCell(
                    title: "İmza Durumu",
                    value: cs.isSigned ? (cs.isAdHoc ? "Ad-Hoc İmzalı" : "Geçerli Kod İmzası") : "İmzasız",
                    color: cs.isSigned && !cs.isAdHoc ? .green : .orange
                )
                infoGridCell(
                    title: "İmza Otoritesi",
                    value: cs.signingAuthority ?? (cs.isAppleSigned ? "Apple" : "Bilinmiyor")
                )
                infoGridCell(
                    title: "Takım Kimliği (Team ID)",
                    value: cs.teamIdentifier ?? (cs.isAppleSigned ? "Apple Sistem" : "Yok")
                )
                infoGridCell(
                    title: "App Sandbox",
                    value: cs.isSandboxed ? "Etkin (İzole)" : "Devre Dışı",
                    color: cs.isSandboxed ? .green : .orange
                )
                infoGridCell(
                    title: "Hardened Runtime",
                    value: cs.isHardenedRuntime ? "Etkin" : "Devre Dışı",
                    color: cs.isHardenedRuntime ? .green : .secondary
                )
                infoGridCell(
                    title: "Karantina Özelliği",
                    value: cs.hasQuarantineAttribute ? "Mevcut (com.apple.quarantine)" : "Temiz",
                    color: cs.hasQuarantineAttribute ? .orange : .green
                )
                infoGridCell(
                    title: "Mimari",
                    value: cs.architectures.isEmpty ? "Bilinmiyor" : cs.architectures.joined(separator: ", ")
                )
                infoGridCell(
                    title: "Min. macOS Sürümü",
                    value: cs.minimumOSVersion ?? "-"
                )
            }
        }
    }

    private func infoGridCell(title: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - 4. Entitlements

    private func entitlementsSection(report: AppSecurityReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Gömülü Yetkiler / Entitlements (\(report.entitlements.count))", systemImage: "key.fill")
                .font(.headline)

            if report.entitlements.isEmpty {
                Text("Uygulama imzasında gömülü ek entitlement bulunmuyor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(report.entitlements) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.isSensitive ? "exclamationmark.shield.fill" : "checkmark.shield")
                                .foregroundStyle(item.isSensitive ? .orange : .green)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.title)
                                        .font(.callout.weight(.semibold))
                                    if item.isSensitive {
                                        PillBadge(text: "Hassas Yetki", color: .orange)
                                    }
                                }
                                Text(item.explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.key)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                            }

                            Spacer(minLength: 8)

                            PillBadge(text: item.valueSummary, color: .secondary)
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - 5. URL Schemes & Background Items

    private func schemesAndBackgroundSection(report: AppSecurityReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("URL Şemaları & Arka Plan Öğeleri", systemImage: "link.badge.plus")
                .font(.headline)

            if !report.urlSchemes.isEmpty {
                VStack(spacing: 6) {
                    ForEach(report.urlSchemes) { scheme in
                        HStack {
                            Text("\(scheme.scheme)://")
                                .font(.system(.callout, design: .monospaced).weight(.semibold))
                            Spacer()
                            if scheme.isCurrentDefault {
                                PillBadge(text: "Varsayılan Handler", color: .blue)
                            } else if let owner = scheme.currentDefaultAppName {
                                Text("Mevcut varsayılan: \(owner)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            if !report.backgroundItems.isEmpty {
                VStack(spacing: 6) {
                    ForEach(report.backgroundItems) { bg in
                        HStack {
                            Image(systemName: "gear.badge")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(bg.name)
                                        .font(.callout.weight(.medium))
                                    PillBadge(text: bg.kind.rawValue, color: .indigo)
                                }
                                Text(bg.path)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
}
