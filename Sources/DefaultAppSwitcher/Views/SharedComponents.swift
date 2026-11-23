import AppKit
import DefaultAppSwitcherCore
import SwiftUI

struct AppIconView: View {
    let url: URL?
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let url, FileManager.default.fileExists(atPath: url.path) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

struct PillBadge: View {
    let text: String
    var color: Color = .secondary
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct AssociationRowView: View {
    let association: AppAssociation
    let showCurrentApp: Bool
    let isBusy: Bool
    var onSelectCurrentApp: (() -> Void)? = nil
    let onReset: () -> Void
    let onChooseApp: (URL) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: association.category.symbolName)
                .font(.title3)
                .foregroundStyle(association.isSuspiciousCollision ? .orange : .accentColor)
                .frame(width: 28, height: 28)
                .background(
                    (association.isSuspiciousCollision ? Color.orange : Color.accentColor).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(association.displayExtensionsText)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .lineLimit(1)

                    if association.isSuspiciousCollision {
                        PillBadge(text: "Çakışma", color: .orange, icon: "exclamationmark.triangle.fill")
                    } else if association.isExplicitOverride {
                        PillBadge(text: "Özel Atama", color: .blue)
                    } else {
                        PillBadge(text: "Varsayılan", color: .secondary)
                    }

                    PillBadge(text: association.category.displayName, color: .secondary)
                }

                HStack(spacing: 6) {
                    Text(association.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.quaternary)

                    Text(association.identifier)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if let reason = association.collisionReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 8)

            if showCurrentApp {
                Button {
                    onSelectCurrentApp?()
                } label: {
                    HStack(spacing: 6) {
                        AppIconView(url: association.currentAppURL, size: 18)
                        Text(association.currentAppName)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("\(association.currentAppName) detayını aç")
            }

            if let target = association.recommendedDefault, association.canResetToSystemDefault {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    AppIconView(url: target.appURL, size: 16)
                    Text(target.appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(minWidth: 130, alignment: .trailing)
            } else if association.isSystemDefault {
                HStack(spacing: 4) {
                    PillBadge(text: "macOS Varsayılanı", color: .green, icon: "checkmark.circle.fill")
                }
                .frame(minWidth: 130, alignment: .trailing)
            } else {
                Text("Sistem alternatifi yok")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 130, alignment: .trailing)
            }

            Menu {
                if association.candidateAppURLs.isEmpty {
                    Text("Kayıtlı başka uygulama bulunamadı")
                } else {
                    ForEach(association.candidateAppURLs, id: \.self) { appURL in
                        let name = DefaultAppResolver.displayName(for: appURL)
                        let isCurrent = Bundle(url: appURL)?.bundleIdentifier?.lowercased() == association.normalizedBundleID
                        Button {
                            onChooseApp(appURL)
                        } label: {
                            HStack {
                                Text(name)
                                if isCurrent {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .disabled(isCurrent)
                    }
                }
            } label: {
                Text("Değiştir")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(isBusy || association.candidateAppURLs.isEmpty)

            Button("Sıfırla") {
                onReset()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isBusy || !association.canResetToSystemDefault)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    association.isSuspiciousCollision ? Color.orange.opacity(0.45) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
    }
}
