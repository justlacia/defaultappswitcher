import DefaultAppSwitcherCore
import SwiftUI

struct AppDetailView: View {
    @Bindable var state: AppState
    let app: InstalledApp

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

            Picker("Görünüm", selection: $state.selectedAppTab) {
                Text("Varsayılan Uzantılar (\(state.selectedAppAssociations.count))")
                    .tag(AppDetailTab.associations)
                Text("İzinler & Güvenlik")
                    .tag(AppDetailTab.permissions)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            Group {
                if state.isLoadingAppDetail && state.selectedAppReport == nil {
                    ProgressView("\(app.name) inceleniyor...")
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
                        PillBadge(text: "Kurulu Değil", color: .orange, icon: "exclamationmark.triangle")
                    }
                    if app.isAppleApp {
                        PillBadge(text: "Apple Uygulaması", color: .blue, icon: "apple.logo")
                    }
                    if app.isInstalled, let report = state.selectedAppReport {
                        PillBadge(
                            text: report.codeSigning.isSandboxed ? "Sandbox" : "Sandbox Dışı",
                            color: report.codeSigning.isSandboxed ? .green : .orange,
                            icon: report.codeSigning.isSandboxed ? "lock.shield" : "lock.open"
                        )
                        if report.codeSigning.isHardenedRuntime {
                            PillBadge(text: "Hardened Runtime", color: .indigo)
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

                    Text("Sürüm \(app.version) (\(app.buildNumber))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(app.isInstalled ? app.url.path : "Sistemde kurulu değil (yalnızca LaunchServices kaydı)")
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
                        "Bu Uygulamanın Varsayılanlarını Sıfırla (\(resettableCount))",
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
                        Label("Finder'da Göster", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}
