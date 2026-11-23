import DefaultAppSwitcherCore
import SwiftUI

struct SnapshotsSheet: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    private var s: AppStrings { state.strings }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: state.language.localeIdentifier)
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.snapshotsTitle)
                        .font(.title3.weight(.bold))
                    Text(s.snapshotsSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(s.closeButton) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            if state.snapshots.isEmpty {
                ContentUnavailableView(
                    s.noSnapshotsTitle,
                    systemImage: "clock.arrow.circlepath",
                    description: Text(s.noSnapshotsDescription)
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(state.snapshots) { snapshot in
                            HStack(spacing: 12) {
                                Image(systemName: "archivebox.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(snapshot.title)
                                        .font(.callout.weight(.semibold))
                                    Text(s.snapshotEntriesMeta(formattedDate(snapshot.createdAt), snapshot.entries.count))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(s.restoreButton) {
                                    Task {
                                        await state.restoreSnapshot(snapshot)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(state.isMutating)

                                Button(role: .destructive) {
                                    Task {
                                        await state.deleteSnapshot(snapshot)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .frame(minHeight: 240, maxHeight: 360)
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}
