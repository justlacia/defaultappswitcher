import DefaultAppSwitcherCore
import SwiftUI

struct SnapshotsSheet: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sıfırlama Yedekleri (Geri Al)")
                        .font(.title3.weight(.bold))
                    Text("Her sıfırlama işleminden önce mevcut uzantı eşleştirmeleriniz otomatik kaydedilir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Kapat") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            if state.snapshots.isEmpty {
                ContentUnavailableView(
                    "Henüz Yedek Yok",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Bir varsayılan sıfırlama veya değiştirme işlemi yaptığınızda otomatik geri yükleme noktası burada görünür.")
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
                                    Text("\(dateFormatter.string(from: snapshot.createdAt)) • \(snapshot.entries.count) atama")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Geri Yükle") {
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
