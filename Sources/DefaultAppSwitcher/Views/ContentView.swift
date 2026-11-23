import DefaultAppSwitcherCore
import SwiftUI

struct ContentView: View {
    @Bindable var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(state: state)
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 340)
        } detail: {
            ZStack(alignment: .bottom) {
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let banner = state.statusBanner {
                    statusBannerView(banner)
                        .padding(16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.22), value: state.statusBanner?.id)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if state.isLoadingInitial || state.isMutating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }

                Button {
                    state.isShowingSnapshotsSheet = true
                } label: {
                    Label(
                        state.snapshots.isEmpty ? "Yedekler" : "Yedekler (\(state.snapshots.count))",
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                .help("Sıfırlama yedeklerini görüntüle ve geri al")

                Button {
                    Task {
                        await state.reloadAll()
                    }
                } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
                .disabled(state.isLoadingInitial || state.isMutating)
                .help("LaunchServices ve uygulama verilerini yenile (⌘R)")
            }
        }
        .task {
            await state.loadInitialIfNeeded()
        }
        .onChange(of: state.selection) { _, _ in
            Task {
                await state.loadSelectedAppDetailIfNeeded()
            }
        }
        .sheet(item: $state.pendingResetConfirmation) { confirmation in
            ResetConfirmationSheet(state: state, confirmation: confirmation)
        }
        .sheet(isPresented: $state.isShowingSnapshotsSheet) {
            SnapshotsSheet(state: state)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch state.selection {
        case .overview, .none:
            OverviewView(state: state)
        case .app:
            if let app = state.selectedApp {
                AppDetailView(state: state, app: app)
            } else if state.isLoadingInitial {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Uygulamalar taranıyor...")
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "Uygulama Seçin",
                    systemImage: "app.dashed",
                    description: Text("Sol kenar çubuğundan incelemek veya varsayılanlarını sıfırlamak istediğiniz bir uygulamayı seçin.")
                )
            }
        }
    }

    private func statusBannerView(_ banner: StatusBanner) -> some View {
        HStack(spacing: 10) {
            Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(banner.isError ? .red : .green)

            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.callout.weight(.semibold))
                if let detail = banner.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            Button {
                state.statusBanner = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 620)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(banner.isError ? Color.red.opacity(0.35) : Color.green.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}
