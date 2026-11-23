import DefaultAppSwitcherCore
import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Uygulama ara...", text: $state.sidebarSearchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !state.sidebarSearchText.isEmpty {
                    Button {
                        state.sidebarSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            List(selection: $state.selection) {
                Section("Hızlı Yönetim") {
                    NavigationLink(value: SidebarSelection.overview) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.shield.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 22)
                            Text("Genel Bakış")
                                .fontWeight(.medium)
                            Spacer()
                            if !state.thirdPartyOverrideAssociations.isEmpty {
                                Text("\(state.thirdPartyOverrideAssociations.count)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                if !state.appsWithOverrides.isEmpty {
                    Section("Özel Varsayılanı Olanlar") {
                        ForEach(state.appsWithOverrides) { app in
                            NavigationLink(value: SidebarSelection.app(app.id)) {
                                sidebarAppRow(app: app, highlightCount: true)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Yalnızca 3. Parti Uygulamalar", isOn: $state.showOnlyThirdPartyInAllApps)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(state.filteredAllApps) { app in
                        NavigationLink(value: SidebarSelection.app(app.id)) {
                            sidebarAppRow(app: app, highlightCount: false)
                        }
                    }
                } header: {
                    Text("Tüm Uygulamalar (\(state.filteredAllApps.count))")
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func sidebarAppRow(app: InstalledApp, highlightCount: Bool) -> some View {
        HStack(spacing: 8) {
            AppIconView(url: app.isInstalled ? app.url : nil, size: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .lineLimit(1)
                if !app.isInstalled {
                    Text("Kurulu değil")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else if !highlightCount {
                    Text(app.bundleID)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if app.overrideCount > 0 {
                Text("\(app.overrideCount)")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (app.isAppleApp ? Color.secondary : Color.orange).opacity(0.16),
                        in: Capsule()
                    )
                    .foregroundStyle(app.isAppleApp ? Color.secondary : Color.orange)
            }
        }
    }
}
