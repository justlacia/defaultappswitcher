import DefaultAppSwitcherCore
import SwiftUI

enum OverviewFilterMode: String, CaseIterable, Identifiable {
    case thirdParty
    case media
    case collisions
    case schemes
    case all

    var id: String { rawValue }
}

struct OverviewView: View {
    @Bindable var state: AppState
    @State private var filterMode: OverviewFilterMode = .thirdParty
    @State private var searchText: String = ""

    private var s: AppStrings { state.strings }

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
                || item.descriptionText(in: state.language).localizedCaseInsensitiveContains(query)
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
        .navigationTitle(s.overviewTitle)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(s.heroTitle)
                        .font(.title2.weight(.bold))
                    Text(s.heroSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    state.promptMediaReset()
                } label: {
                    Label(
                        s.resetMediaButton(state.resettableThirdPartyMediaOverrides.count),
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
                        s.resetAllOverridesButton(state.resettableThirdPartyOverrides.count),
                        systemImage: "trash.slash"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(state.isMutating || state.resettableThirdPartyOverrides.isEmpty)

                Button {
                    state.isShowingSnapshotsSheet = true
                } label: {
                    Label(s.backupsRestoreButton, systemImage: "clock.arrow.circlepath")
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
                title: s.metricThirdPartyTitle,
                value: "\(state.thirdPartyOverrideAssociations.count)",
                subtitle: s.metricThirdPartySubtitle(state.allOverrideAssociations.count),
                icon: "doc.badge.gearshape",
                tint: .blue
            )
            metricCard(
                title: s.metricAffectedAppsTitle,
                value: "\(state.affectedThirdPartyAppCount)",
                subtitle: s.metricAffectedAppsSubtitle,
                icon: "square.stack.3d.up.fill",
                tint: .indigo
            )
            metricCard(
                title: s.metricCollisionsTitle,
                value: "\(state.collisionOverrideCount)",
                subtitle: state.collisionOverrideCount > 0 ? s.metricCollisionsSubtitleSome : s.metricCollisionsSubtitleNone,
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
                Text(s.activeOverridesTitle)
                    .font(.headline)

                Picker(s.filterLabel, selection: $filterMode) {
                    ForEach(OverviewFilterMode.allCases) { mode in
                        Text(s.overviewFilterTitle(mode)).tag(mode)
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
                    TextField(s.searchOverridesPlaceholder, text: $searchText)
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
                ProgressView(s.readingLaunchServices)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else if filteredAssociations.isEmpty {
                ContentUnavailableView(
                    s.noRecordsTitle,
                    systemImage: "checkmark.seal",
                    description: Text(s.noRecordsDescription)
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredAssociations) { assoc in
                        AssociationRowView(
                            association: assoc,
                            showCurrentApp: true,
                            isBusy: state.isMutating,
                            strings: s,
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
