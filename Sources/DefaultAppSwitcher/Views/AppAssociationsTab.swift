import DefaultAppSwitcherCore
import SwiftUI

struct AppAssociationsTab: View {
    @Bindable var state: AppState
    let app: InstalledApp

    @State private var searchText: String = ""
    @State private var selectedCategory: AssociationCategory? = nil
    @State private var showOtherExtensions: Bool = false

    private var s: AppStrings { state.strings }

    private var collisionItems: [AppAssociation] {
        state.selectedAppAssociations.filter { $0.isSuspiciousCollision }
    }

    private var filteredAssociations: [AppAssociation] {
        state.selectedAppAssociations.filter { item in
            if let selectedCategory, item.category != selectedCategory {
                return false
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            return item.displayExtensionsText.localizedCaseInsensitiveContains(query)
                || item.identifier.localizedCaseInsensitiveContains(query)
                || item.descriptionText(in: state.language).localizedCaseInsensitiveContains(query)
        }
    }

    private var availableCategories: [AssociationCategory] {
        let present = Set(state.selectedAppAssociations.map { $0.category })
        return AssociationCategory.allCases.filter { present.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !collisionItems.isEmpty {
                    collisionBanner
                }

                filterBar

                if filteredAssociations.isEmpty {
                    ContentUnavailableView(
                        s.noAssociationsTitle,
                        systemImage: "checkmark.circle",
                        description: Text(s.noAssociationsDescription(app.name))
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredAssociations) { assoc in
                            AssociationRowView(
                                association: assoc,
                                showCurrentApp: false,
                                isBusy: state.isMutating,
                                strings: s,
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

                if !state.selectedAppOtherExtensions.isEmpty {
                    otherExtensionsDisclosure
                }
            }
            .padding(20)
        }
    }

    private var collisionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(s.collisionWarningTitle(collisionItems.count))
                    .font(.callout.weight(.semibold))
                Text(s.collisionWarningDetail(collisionItems.map { $0.displayExtensionsText }.joined(separator: ", ")))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(s.resetCollisionsButton) {
                Task {
                    await state.performBulkReset(
                        items: collisionItems,
                        snapshotTitle: s.collisionsResetSnapshotTitle(app.name)
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
            .disabled(state.isMutating)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryButton(title: s.allCategoryCount(state.selectedAppAssociations.count), category: nil)
                    ForEach(availableCategories, id: \.self) { category in
                        let count = state.selectedAppAssociations.filter { $0.category == category }.count
                        categoryButton(title: "\(category.displayName(in: state.language)) (\(count))", category: category)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField(s.searchExtensionPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .frame(width: 180)
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
    }

    private func categoryButton(title: String, category: AssociationCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var otherExtensionsDisclosure: some View {
        DisclosureGroup(
            s.otherExtensionsTitle(state.selectedAppOtherExtensions.count),
            isExpanded: $showOtherExtensions
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
                ForEach(state.selectedAppOtherExtensions) { item in
                    HStack {
                        Text(".\(item.ext)")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                        Spacer()
                        Text(item.currentAppName ?? s.noneText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.top, 8)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
