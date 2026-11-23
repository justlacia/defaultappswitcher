<img src="assets/icon.svg" width="64" height="64" alt="DefaultAppSwitcher Icon">

# DefaultAppSwitcher

**English** | **[Türkçe](#türkçe)**

A native SwiftUI macOS utility that resets accidentally overridden default file associations (`.mp3`, `.mp4`, `.avi`, `.mkv`, `.flac`, `.ts`, `.ps`, etc.) back to standard macOS apps **in one click**, and lets you inspect and reset any installed app's privacy permissions (`TCC`), code signature, Sandbox/Entitlements, and background items.

> **New in v1.1.0:** Full **English & Turkish** localization! Automatically launches in your Mac's system language (Turkish on `tr*` systems, English on all others) and includes a live **`TR | EN`** toggle switch in the top-right toolbar.

---

## Download

Pre-built **Universal macOS** binaries are available on **GitHub Releases**:

- **[Download Latest Release (v1.1.0)](https://github.com/justlacia/defaultappswitcher/releases/latest)**
  - **`DefaultAppSwitcher-v1.1.0-macOS-Universal.dmg`** — Drag-and-drop installer image (recommended)
  - **`DefaultAppSwitcher-v1.1.0-macOS-Universal.zip`** — Compressed `.app` bundle

> **First Launch (Gatekeeper):** Because this app is ad-hoc signed rather than notarized with a paid Apple Developer ID certificate, macOS may show a warning on first launch. Use **Right-Click → Open** or run:
> ```bash
> xattr -cr /Applications/DefaultAppSwitcher.app
> ```

---

## Supported Versions & Requirements

| Requirement | Support |
|---|---|
| **Operating System** | **macOS 14.0 (Sonoma)** and newer (macOS 14 Sonoma, macOS 15 Sequoia, macOS 26/27 Tahoe+) |
| **Architecture** | **Universal Binary** — native **Apple Silicon (M1–M5 / `arm64`)** and **Intel (`x86_64`)** |
| **Platform** | macOS only (Windows, Linux, and iOS are not supported) |
| **Build from Source** | Xcode 16+ / Swift 6.0+ |

---

## Problem Solved

When installing a media player on macOS (such as **IINA** or **VLC**) and clicking *"Set as default for all supported files"*, several frustrating issues occur:

1. **No Bulk Reset in macOS:** Finder requires fixing `.mp4`, `.mkv`, `.avi`, `.mov`, `.mp3`, `.flac`, `.aac`, etc. one extension at a time via *Get Info → Open with → Change All*.
2. **Non-Media Hijacks (Type Collisions):** Media players sometimes claim developer or document formats such as `.ts` / `.tsx` (TypeScript) or `.ps` (PostScript).
3. **Orphaned Records from Deleted Apps:** Legacy `HandlerPref` / `extension:` entries left behind by uninstalled apps don't appear cleanly in System Settings.
4. **Hidden App Permissions & Entitlements:** Viewing an app's code signing status, App Sandbox, Hardened Runtime, embedded entitlements, and `TCC` privacy permissions—and resetting them cleanly—normally requires multiple terminal commands.

**DefaultAppSwitcher** combines `LaunchServices` (`lsregister -dump HandlerPref`), `NSWorkspace` / `UniformTypeIdentifiers`, `Security.framework`, and `tccutil` into a fast native macOS interface with automatic undo snapshots.

---

## Build & Test from Source

```bash
# Run unit tests (read-only / mocked; does not modify your macOS defaults)
swift test

# Build Universal Binary (.app, .dmg, and .zip)
bash scripts/build_app.sh 1.1.0

# Launch app
open "build/DefaultAppSwitcher.app"
```

---

## Türkçe

macOS üzerinde yanlışlıkla veya toplu şekilde değiştirilmiş varsayılan dosya açma uygulamalarını (`.mp3`, `.mp4`, `.avi`, `.mkv`, `.flac`, `.ts`, `.ps` vb.) **tek tuşla macOS varsayılanlarına sıfırlayan**, ayrıca uygulamaların gizlilik izinlerini (`TCC`), kod imzalarını, Sandbox/Entitlement yetkilerini ve arka plan öğelerini inceleyip sıfırlayabilen yerel (SwiftUI) bir macOS aracıdır.

> **v1.1.0 Yenilikleri:** Tam **İngilizce ve Türkçe** dil desteği! Uygulama bilgisayarınızın sistem diline göre (Türkçe ise Türkçe, değilse İngilizce) otomatik açılır ve sağ üst araç çubuğundaki **`TR | EN`** anahtarıyla anlık dil değiştirilebilir.

### İndirme ve Desteklenen Sürümler

- **[Son Sürümü İndir (GitHub Releases — v1.1.0)](https://github.com/justlacia/defaultappswitcher/releases/latest)**
  - **`DefaultAppSwitcher-v1.1.0-macOS-Universal.dmg`** (önerilen) veya **`DefaultAppSwitcher-v1.1.0-macOS-Universal.zip`**
- **Desteklenen macOS Sürümleri:** **macOS 14.0 (Sonoma)** ve üzeri (macOS 14 Sonoma, macOS 15 Sequoia, macOS 26/27 Tahoe+)
- **İşlemci Desteği:** **Universal Binary** — **Apple Silicon (`arm64`)** ve **Intel (`x86_64`)** Mac'ler

### Özellikler

- **Genel Bakış & Tek Tuşla Sıfırlama:** Medya uzantılarını veya tüm 3. parti özel atamaları akıllı sistem eşleştirmesiyle (`QuickTime Player`, `Müzik`, `TV`, `TextEdit`, `Preview`) geri alır; `.aac`/`.ac3` dosyalarını Apple Books yerine QuickTime Player'a, `.ts` dosyalarını TextEdit'e yönlendirir.
- **Otomatik Yedekleme (Geri Al):** Her işlem öncesi `~/Library/Application Support/DefaultAppSwitcher/snapshots.json` içine geri yükleme noktası kaydeder.
- **Tür Çakışması & Silinmiş Uygulama Tespiti:** Medya oynatıcılara yanlışlıkla bağlanan `.ts`/`.ps` uzantılarını ve sistemden silinmiş uygulamaların hayalet `LaunchServices` kayıtlarını yakalar.
- **İzinler & Güvenlik İnceleyici:** `Info.plist` gizlilik anahtarlarını, `Security.framework` ile imza/Sandbox/Entitlement yetkilerini, canlı `TCC.db` onaylarını (Tam Disk Erişimi verildiğinde) ve `tccutil reset` ile izin sıfırlamayı sunar.

---

## License

[MIT License](LICENSE) © 2026 Haluk (justlacia)
