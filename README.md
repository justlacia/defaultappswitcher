<img src="assets/icon.svg" width="64" height="64" alt="DefaultAppSwitcher Icon">

# DefaultAppSwitcher

macOS üzerinde yanlışlıkla veya toplu şekilde değiştirilmiş varsayılan dosya açma uygulamalarını (`.mp3`, `.mp4`, `.avi`, `.mkv`, `.flac`, `.ts`, `.ps` vb.) **tek tuşla macOS varsayılanlarına sıfırlayan**, ayrıca yüklü uygulamaların gizlilik izinlerini (`TCC`), kod imzalarını, Sandbox/Entitlement yetkilerini ve arka plan servislerini inceleyip sıfırlayabilen yerel (SwiftUI) bir macOS aracıdır.

---

## İndirme (Download)

Hazır derlenmiş Universal uygulamayı **GitHub Releases** üzerinden doğrudan indirebilirsiniz:

- **[Son Sürümü İndir (Releases)](https://github.com/justlacia/defaultappswitcher/releases/latest)**
  - **`DefaultAppSwitcher-v1.0.0-macOS-Universal.dmg`** — Sürükle-bırak kurulum paketi (önerilen)
  - **`DefaultAppSwitcher-v1.0.0-macOS-Universal.zip`** — Doğrudan sıkıştırılmış `.app` paketi

> **İlk Açılış Notu (Gatekeeper):** Uygulama Apple Notarization sertifikası yerine ad-hoc imzalıdır. İlk açılışta macOS *"geliştiricisi doğrulanamıyor"* uyarısı verirse uygulamaya **Sağ Tık → Aç** diyebilir veya Terminal'de şu komutu çalıştırabilirsiniz:
> ```bash
> xattr -cr /Applications/DefaultAppSwitcher.app
> ```

---

## Desteklenen Sürümler & Sistem Gereksinimleri

| Özellik | Desteklenen Değer |
|---|---|
| **İşletim Sistemi** | **macOS 14.0 (Sonoma)** ve üzeri (macOS 14 Sonoma, macOS 15 Sequoia, macOS 26/27 Tahoe+) |
| **İşlemci Mimarisi** | **Universal Binary** — hem **Apple Silicon (M1 / M2 / M3 / M4 / M5 — `arm64`)** hem **Intel (`x86_64`)** Mac'ler |
| **Platform** | Yalnızca macOS (Windows, Linux ve iOS desteklenmez) |
| **Kaynaktan Derleme** | Xcode 16+ / Swift 6.0+ |

---

## Hangi Sorun İçin Yapıldı?

macOS'ta yeni bir medya oynatıcı (örneğin **IINA** veya **VLC**) kurup *"Tüm medya türleri için varsayılan yap"* seçeneğini işaretlediğinizde sık karşılaşılan birkaç ciddi sorun oluşur:

1. **Tek Tuşla Geri Alma Yok:** Finder'da tek tek her uzantı için *"Bilgi Ver → Birlikte Aç → Tümünü Değiştir"* yapmak zorunda kalırsınız. `.mp4`, `.mkv`, `.avi`, `.mov`, `.mp3`, `.flac`, `.aac` gibi onlarca uzantıyı tek tek düzeltmek uzun sürer.
2. **Alakasız Türlerin Ele Geçirilmesi (Tür Çakışmaları):** Bazı medya uygulamaları yazılım geliştirme dosyalarını (`.ts` / `.tsx` — TypeScript) veya belge formatlarını (`.ps` — PostScript, `.cue`) da medya uzantısı sanıp kendine bağlayabilir.
3. **Eski ve Silinmiş Uygulama Kalıntıları:** Sistemden sildiğiniz eski uygulamaların `LaunchServices` veritabanında bıraktığı eski `extension:` veya `HandlerPref` kayıtları macOS Ayarları'nda görünmez.
4. **Gizli Uygulama İzinlerini Görme Zorluğu:** Bir uygulamanın kod imzası, Sandbox durumu, hangi gizli yetkilere (`entitlements`) veya gizlilik izinlerine (`Kamera`, `Mikrofon`, `Klasör Erişimi`, `Otomasyon`) sahip olduğunu tek bir ekranda görmek ve gerektiğinde sıfırlamak zordur.

**DefaultAppSwitcher**, macOS'un `LaunchServices` veritabanını (`lsregister -dump HandlerPref`), `NSWorkspace` ve `UniformTypeIdentifiers` API'lerini, `Security.framework` imza/yetki analizini ve `tccutil` altyapısını tek bir hızlı macOS arayüzünde birleştirerek bu sorunları çözer.

---

## Özellikler

- **Genel Bakış & Tek Tuşla Sıfırlama**
  - **Medya Uzantılarını Sıfırla:** Video, ses ve medya oynatıcılara yanlışlıkla bağlanmış uzantıları akıllı sistem eşleştirmesiyle (`QuickTime Player`, `Müzik`, `TV`, `TextEdit`, `Preview`) geri döndürür. (Örneğin `.aac`/`.ac3` dosyalarını Apple Books yerine QuickTime Player'a, `.mp3`/`.m4a`/`.wav` dosyalarını Müzik'e, `.ts` TypeScript dosyalarını TextEdit'e atar.)
  - **Tüm Özel Varsayılanları Sıfırla:** 3. parti uygulamalara atanmış tüm dosya uzantılarını (ve isteğe bağlı olarak tarayıcı/URL şemalarını) sıfırlar.
  - **Otomatik Yedekleme (Geri Al):** Her sıfırlama veya uygulama değişikliği öncesi `~/Library/Application Support/DefaultAppSwitcher/snapshots.json` içine geri yükleme noktası kaydeder; istediğiniz an tek tıkla önceki hale dönebilirsiniz.
- **Uygulama Bazlı Yönetim**
  - Özel varsayılan ataması bulunan tüm uygulamaları (silinmiş uygulamaların kalıntı kayıtları dahil) üstte sıralar.
  - Her uzantı veya UTI satırını tek tek sıfırlayabilir ya da **Değiştir** menüsüyle istediğiniz başka bir uygulamaya atayabilirsiniz.
  - Yanlışlıkla ele geçirilmiş türleri **Çakışma** etiketiyle vurgular.
- **İzinler & Güvenlik İnceleyici**
  - `Info.plist` gizlilik açıklamaları (`NS*UsageDescription`) ve ilgili Sistem Ayarları kısayolları.
  - `Security.framework` ile kod imzası, Geliştirici/Takım Kimliği, App Sandbox, Hardened Runtime, Gatekeeper karantina durumu ve tüm gömülü `entitlements` açıklamaları.
  - Tam Disk Erişimi verildiğinde canlı `TCC.db` izin durumlarını okuma ve tek tıkla `tccutil reset` ile izin sıfırlama.
  - URL şemaları (`iina://` vb.) ve arka plan öğeleri (`LoginItems`, `LaunchAgents`, yardımcı servisler).

---

## Kaynaktan Derleme ve Test

```bash
# Birim testlerini çalıştır (sistem varsayılanlarını değiştirmez)
swift test

# Universal Binary (.app, .dmg ve .zip) oluştur
bash scripts/build_app.sh

# Uygulamayı çalıştır
open "build/DefaultAppSwitcher.app"
```

---

## Lisans

[MIT License](LICENSE) © 2026 Haluk (justlacia)
