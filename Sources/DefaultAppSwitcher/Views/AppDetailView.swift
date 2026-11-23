import DefaultAppSwitcherCore
import SwiftUI

struct AppDetailView: View {
    @Bindable var state: AppState
    let app: InstalledApp

    private var s: AppStrings { state.strings }

    private var resettableCount: Int {
        state.resettableSelectedAppAssociations.count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            Picker("", selection: $state.selectedAppTab) {
                Text(s.tabAssociationsTitle(state.selectedAppAssociations.count))
                    .tag(AppDetailTab.associations)
                Text(s.tabPermissionsTitle)
                    .tag(AppDetailTab.permissions)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            Group {
                if state.isLoadingAppDetail && state.selectedAppReport == nil {
                    ProgressView(s.analyzingApp(app.name))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch state.selectedAppTab {
                    case .associations:
                        AppAssociationsTab(state: state, app: app)
                    case .permissions:
                        AppPermissionsTab(state: state, app: app)
                    }
                }
            }
        }
        .navigationTitle(app.name)
    }

    private var headerView: some View {
        HStack(spacing: 14) {
            AppIconView(url: app.isInstalled ? app.url : nil, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(app.name)
                        .font(.title2.weight(.bold))

                    if !app.isInstalled {
                        PillBadge(text: s.notInstalledBadge, color: .orange, icon: "exclamationmark.triangle")
                    }
                    if app.isAppleApp {
                        PillBadge(text: s.appleAppBadge, color: .blue, icon: "apple.logo")
                    }
                    if app.isInstalled, let report = state.selectedAppReport {
                        PillBadge(
                            text: report.codeSigning.isSandboxed ? s.sandboxBadge : s.nonSandboxBadge,
                            color: report.codeSigning.isSandboxed ? .green : .orange,
                            icon: report.codeSigning.isSandboxed ? "lock.shield" : "lock.open"
                        )
                        if report.codeSigning.isHardenedRuntime {
                            PillBadge(text: s.hardenedRuntimeBadge, color: .indigo)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Text(app.bundleID)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(s.versionBuild(app.version, app.buildNumber))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(app.isInstalled ? app.url.path : s.uninstalledPathHint)
                    .font(.caption2)
                    .foregroundStyle(app.isInstalled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.orange))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    state.promptResetForSelectedApp()
                } label: {
                    Label(
                        s.resetAppDefaultsButton(resettableCount),
                        systemImage: "arrow.counterclockwise"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(resettableCount > 0 ? .red : .accentColor)
                .disabled(state.isMutating || resettableCount == 0)

                if app.isInstalled {
                    Button {
                        state.revealAppInFinder(app)
                    } label: {
                        Label(s.revealInFinder, systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}
