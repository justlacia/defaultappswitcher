import DefaultAppSwitcherCore
import SwiftUI

struct ResetConfirmationSheet: View {
    @Bindable var state: AppState
    let confirmation: PendingResetConfirmation
    @Environment(\.dismiss) private var dismiss

    @State private var includeBrowserAndSchemes: Bool = false

    private var s: AppStrings { state.strings }

    private var activeItems: [AppAssociation] {
        let source = includeBrowserAndSchemes ? confirmation.allThirdPartyItems : confirmation.items
        return source.filter { $0.canResetToSystemDefault }
    }

    private var groupedTargets: [(target: ResetTarget, count: Int, sampleExtensions: [String])] {
        var buckets: [String: (target: ResetTarget, exts: [String])] = [:]
        for item in activeItems {
            guard let target = item.recommendedDefault else { continue }
            let key = target.bundleID.lowercased()
            let label = item.kind == .urlScheme ? "\(item.identifier)://" : item.displayExtensionsText
            if var existing = buckets[key] {
                existing.exts.append(label)
                buckets[key] = existing
            } else {
                buckets[key] = (target, [label])
            }
        }
        return buckets.values
            .map { ($0.target, $0.exts.count, Array($0.exts.prefix(6))) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(confirmation.title)
                        .font(.title3.weight(.bold))
                    Text(confirmation.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if confirmation.includesBrowserAndSchemesToggle {
                Toggle(
                    s.toggleBrowserAndSchemes,
                    isOn: $includeBrowserAndSchemes
                )
                .font(.callout)
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(s.previewResetHeader(activeItems.count))
                    .font(.callout.weight(.semibold))

                if groupedTargets.isEmpty {
                    Text(s.noResettableFound)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(groupedTargets, id: \.target.bundleID) { group in
                                HStack(spacing: 10) {
                                    AppIconView(url: group.target.appURL, size: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.extensionTargetLine(group.count, group.target.appName))
                                            .font(.callout.weight(.medium))
                                        Text(group.sampleExtensions.joined(separator: ", "))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                    .frame(maxHeight: 230)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.green)
                Text(s.snapshotNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button(s.cancelButton) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(s.confirmAndResetButton(activeItems.count)) {
                    let itemsToReset = activeItems
                    let title = confirmation.title
                    dismiss()
                    Task {
                        await state.executePendingReset(items: itemsToReset, title: title)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(activeItems.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
