import DefaultAppSwitcherCore
import SwiftUI

enum OverviewFilterMode: String, CaseIterable, Identifiable {
    case thirdParty = "3. Parti"
    case media = "Medya"
    case collisions = "Çakışanlar"
    case schemes = "URL Şemaları"
    case all = "Tümü"

    var id: String { rawValue }
}

struct OverviewView: View {
    @Bindable var state: AppState
    @State private var filterMode: OverviewFilterMode = .thirdParty
    @State private var searchText: String = ""

    private var filteredAssociations: [AppAssociation] {
        let base: [AppAssociation]
        switch filterMode {
        case .thirdParty:
            base = state.thirdPartyOverrideAssociations
        case .media:
            base = state.thirdPartyMediaOverrideAssociations
        case .collisions:
            base = state.allOverrideAssociations.filter { $0.isSuspiciousCollision }
        case .schemes:
            base = state.allOverrideAssociations.filter { $0.kind == .urlScheme }
        case .all:
            base = state.allOverrideAssociations
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter { item in
            item.displayExtensionsText.localizedCaseInsensitiveContains(query)
                || item.identifier.localizedCaseInsensitiveContains(query)
                || item.currentAppName.localizedCaseInsensitiveContains(query)
                || item.localizedDescription.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard

                metricsRow

                overridesSection
            }
            .padding(20)
        }
        .navigationTitle("Genel Bakış")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tek Tuşla Varsayılan Uygulamaları Sıfırla")
                        .font(.title2.weight(.bold))
                    Text("LaunchServices veritabanındaki özel dosya uzantısı ve medya atamalarını güvenle macOS varsayılanlarına (QuickTime Player, Müzik, TextEdit vb.) geri alın. Her işlem öncesi otomatik yedek alınır.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    state.promptMediaReset()
                } label: {
                    Label(
                        "Medya Uzantılarını Sıfırla (\(state.resettableThirdPartyMediaOverrides.count))",
                        systemImage: "play.slash.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(state.isMutating || state.resettableThirdPartyMediaOverrides.isEmpty)

                Button(role: .destructive) {
                    state.promptGlobalResetAll()
                } label: {
                    Label(
                        "Tüm Özel Varsayılanları Sıfırla (\(state.resettableThirdPartyOverrides.count))",
                        systemImage: "trash.slash"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(state.isMutating || state.resettableThirdPartyOverrides.isEmpty)

                Button {
                    state.isShowingSnapshotsSheet = true
                } label: {
                    Label("Yedekler / Geri Al", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.12), Color.indigo.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.22), lineWidth: 1)
        )
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            metricCard(
                title: "3. Parti Özel Atama",
                value: "\(state.thirdPartyOverrideAssociations.count)",
                subtitle: "Toplam \(state.allOverrideAssociations.count) kayıt içinde",
                icon: "doc.badge.gearshape",
                tint: .blue
            )
            metricCard(
                title: "Etkilenen Uygulama",
                value: "\(state.affectedThirdPartyAppCount)",
                subtitle: "Sol listeden detayına inin",
                icon: "square.stack.3d.up.fill",
                tint: .indigo
            )
            metricCard(
                title: "Tür Çakışması",
                value: "\(state.collisionOverrideCount)",
                subtitle: state.collisionOverrideCount > 0 ? "Örn. medya oynatıcıya bağlı .ts / .ps" : "Çakışma tespit edilmedi",
                icon: "exclamationmark.triangle.fill",
                tint: state.collisionOverrideCount > 0 ? .orange : .green
            )
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var overridesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Aktif Varsayılan Atamalar")
                    .font(.headline)

                Picker("Filtre", selection: $filterMode) {
                    ForEach(OverviewFilterMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 460)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField("Uzantı, UTI veya uygulama ara...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .frame(width: 200)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }

            if state.isLoadingInitial && state.allOverrideAssociations.isEmpty {
                ProgressView("LaunchServices kayıtları okunuyor...")
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else if filteredAssociations.isEmpty {
                ContentUnavailableView(
                    "Kayıt Bulunamadı",
                    systemImage: "checkmark.seal",
                    description: Text("Seçili filtre için gösterilecek aktif varsayılan atama yok.")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredAssociations) { assoc in
                        AssociationRowView(
                            association: assoc,
                            showCurrentApp: true,
                            isBusy: state.isMutating,
                            onSelectCurrentApp: {
                                state.selection = .app(assoc.normalizedBundleID)
                            },
                            onReset: {
                                Task {
                                    await state.resetSingleAssociation(assoc)
                                }
                            },
                            onChooseApp: { appURL in
                                Task {
                                    await state.setSingleAssociation(assoc, toAppAt: appURL)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}
