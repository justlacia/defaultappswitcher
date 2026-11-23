import DefaultAppSwitcherCore
import SwiftUI

struct AppPermissionsTab: View {
    @Bindable var state: AppState
    let app: InstalledApp

    @State private var confirmResetAllTCC: Bool = false

    private var s: AppStrings { state.strings }
    private var lang: AppLanguage { state.language }

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
                ProgressView(s.preparingSecurityReport)
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .confirmationDialog(
            s.resetAllTCCDialogTitle(app.name),
            isPresented: $confirmResetAllTCC,
            titleVisibility: .visible
        ) {
            Button(s.resetAllTCCDialogConfirm, role: .destructive) {
                Task {
                    await state.resetTCCPermission(service: "All", for: app)
                }
            }
            Button(s.cancelButton, role: .cancel) {}
        } message: {
            Text(s.resetAllTCCDialogMessage)
        }
    }

    private var uninstalledNoticeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(s.uninstalledBannerTitle)
                    .font(.callout.weight(.semibold))
                Text(s.uninstalledBannerBody)
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
                Label(s.tccSectionTitle, systemImage: "hand.raised.shield.fill")
                    .font(.headline)
                Spacer()
                Button(s.openPrivacySettings) {
                    state.openSystemSettings(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy"))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    confirmResetAllTCC = true
                } label: {
                    Label(s.resetAllTCCButton, systemImage: "arrow.counterclockwise")
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
                        Text(s.fdaRequiredTitle)
                            .font(.callout.weight(.semibold))
                        Text(s.fdaRequiredBody)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        Button(s.grantFDAButton) {
                            state.openFullDiskAccessSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button(s.recheckButton) {
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
                                    Text(entry.displayName.text(for: lang))
                                        .font(.callout.weight(.semibold))
                                    PillBadge(
                                        text: entry.status.displayName(in: lang),
                                        color: tccColor(entry.status)
                                    )
                                    PillBadge(text: entry.scope.displayName(in: lang), color: .secondary)
                                }
                                if let target = entry.indirectTarget {
                                    Text(s.targetPrefix(target))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if let settingsURL = entry.settingsURL {
                                Button(s.systemSettingsButton) {
                                    state.openSystemSettings(settingsURL)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if let svc = entry.tccutilName {
                                Button(s.resetButton) {
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
                Text(s.noTCCEntriesMessage)
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
        let sortedDeclared = report.declaredPermissions.sorted {
            $0.displayName.text(for: lang).localizedCaseInsensitiveCompare($1.displayName.text(for: lang)) == .orderedAscending
        }
        return VStack(alignment: .leading, spacing: 10) {
            Label(s.declaredPrivacyTitle, systemImage: "doc.text.magnifyingglass")
                .font(.headline)

            if sortedDeclared.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.noDeclaredPrivacyMain)
                        .font(.callout)
                    Text(report.codeSigning.isSandboxed ? s.noDeclaredPrivacySandboxed : s.noDeclaredPrivacyUnsandboxed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedDeclared) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.symbolName)
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 26)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(item.displayName.text(for: lang))
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
                                    Button(s.openSettingsShort) {
                                        state.openSystemSettings(settingsURL)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                if let svc = item.tccutilService {
                                    Button(s.resetButton) {
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
            Label(s.codeSigningTitle, systemImage: "checkmark.seal.fill")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                infoGridCell(
                    title: s.signingStatusLabel,
                    value: cs.isSigned ? (cs.isAdHoc ? s.signingAdHoc : s.signingValid) : s.signingUnsigned,
                    color: cs.isSigned && !cs.isAdHoc ? .green : .orange
                )
                infoGridCell(
                    title: s.signingAuthorityLabel,
                    value: cs.signingAuthority ?? (cs.isAppleSigned ? "Apple" : s.unknownText)
                )
                infoGridCell(
                    title: s.teamIDLabel,
                    value: cs.teamIdentifier ?? (cs.isAppleSigned ? s.appleSystemText : s.noneText)
                )
                infoGridCell(
                    title: s.appSandboxLabel,
                    value: cs.isSandboxed ? s.enabledIsolated : s.disabledText,
                    color: cs.isSandboxed ? .green : .orange
                )
                infoGridCell(
                    title: s.hardenedRuntimeLabel,
                    value: cs.isHardenedRuntime ? s.enabledText : s.disabledText,
                    color: cs.isHardenedRuntime ? .green : .secondary
                )
                infoGridCell(
                    title: s.quarantineLabel,
                    value: cs.hasQuarantineAttribute ? s.quarantinePresent : s.cleanText,
                    color: cs.hasQuarantineAttribute ? .orange : .green
                )
                infoGridCell(
                    title: s.architectureLabel,
                    value: cs.architectures.isEmpty ? s.unknownText : cs.architectures.joined(separator: ", ")
                )
                infoGridCell(
                    title: s.minOSLabel,
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
            Label(s.entitlementsTitle(report.entitlements.count), systemImage: "key.fill")
                .font(.headline)

            if report.entitlements.isEmpty {
                Text(s.noEntitlements)
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
                                    Text(item.title.text(for: lang))
                                        .font(.callout.weight(.semibold))
                                    if item.isSensitive {
                                        PillBadge(text: s.sensitivePermissionBadge, color: .orange)
                                    }
                                }
                                Text(item.explanation.text(for: lang))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.key)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                            }

                            Spacer(minLength: 8)

                            PillBadge(text: item.valueSummary.text(for: lang), color: .secondary)
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
            Label(s.schemesAndBackgroundTitle, systemImage: "link.badge.plus")
                .font(.headline)

            if !report.urlSchemes.isEmpty {
                VStack(spacing: 6) {
                    ForEach(report.urlSchemes) { scheme in
                        HStack {
                            Text("\(scheme.scheme)://")
                                .font(.system(.callout, design: .monospaced).weight(.semibold))
                            Spacer()
                            if scheme.isCurrentDefault {
                                PillBadge(text: s.defaultHandlerBadge, color: .blue)
                            } else if let owner = scheme.currentDefaultAppName {
                                Text(s.currentDefaultOwner(owner))
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
                                    PillBadge(text: bg.kind.displayName(in: lang), color: .indigo)
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
