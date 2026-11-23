import AppKit
import Foundation
import UniformTypeIdentifiers

public enum DefaultAppResolver {
    public enum BundleID {
        public static let quickTime = "com.apple.QuickTimePlayerX"
        public static let music = "com.apple.Music"
        public static let tv = "com.apple.TV"
        public static let preview = "com.apple.Preview"
        public static let textEdit = "com.apple.TextEdit"
        public static let safari = "com.apple.Safari"
        public static let mail = "com.apple.mail"
        public static let photos = "com.apple.Photos"
        public static let archiveUtility = "com.apple.archiveutility"
        public static let diskImageMounter = "com.apple.DiskImageMounter"
        public static let finder = "com.apple.finder"
        public static let books = "com.apple.iBooksX"
    }

    private static let fallbackPaths: [String: String] = [
        BundleID.quickTime.lowercased(): "/System/Applications/QuickTime Player.app",
        BundleID.music.lowercased(): "/System/Applications/Music.app",
        BundleID.tv.lowercased(): "/System/Applications/TV.app",
        BundleID.preview.lowercased(): "/System/Applications/Preview.app",
        BundleID.textEdit.lowercased(): "/System/Applications/TextEdit.app",
        BundleID.safari.lowercased(): "/Applications/Safari.app",
        BundleID.mail.lowercased(): "/System/Applications/Mail.app",
        BundleID.photos.lowercased(): "/System/Applications/Photos.app",
        BundleID.archiveUtility.lowercased(): "/System/Library/CoreServices/Applications/Archive Utility.app",
        BundleID.diskImageMounter.lowercased(): "/System/Library/CoreServices/DiskImageMounter.app",
        BundleID.finder.lowercased(): "/System/Library/CoreServices/Finder.app",
        BundleID.books.lowercased(): "/System/Applications/Books.app"
    ]

    private static let mediaPlayerBundleIDs: Set<String> = [
        "com.colliderli.iina",
        "org.videolan.vlc",
        "com.video.player.converter.fj.mp3",
        "com.movist.movist",
        "com.movist.movistpro",
        "com.elmedia.elmediaplayer",
        "io.mpv"
    ]

    private static let videoExtensions: Set<String> = [
        "mp4", "mpg4", "m4v", "mov", "qt", "avi", "vfw", "mkv", "webm", "wmv",
        "flv", "f4v", "f4p", "asf", "mpg", "mpeg", "mpeg1", "mpeg2", "m1v", "m2v",
        "mpv", "mpe", "m75", "m15", "m2p", "m2t", "m2ts", "mts", "mt2s", "tp",
        "3gp", "3gpp", "3g2", "3gp2", "sdv", "dv", "dif", "divx", "rm", "rmvb",
        "wtv", "amv", "ogv", "ogm", "vob"
    ]

    private static let audioExtensions: Set<String> = [
        "mp3", "mpga", "m4a", "m4b", "m4p", "m4r", "aac", "adts", "ac3", "aiff",
        "aif", "aifc", "wav", "wave", "flac", "opus", "ogg", "oga", "wma", "mka",
        "ape", "wv", "dsf", "dff", "xm", "ra", "m2a", "mp1", "mp2", "mpa", "caf",
        "f4a", "f4b", "m3u", "m3u8", "pls", "aa3", "acm", "dts", "tak", "tta"
    ]

    private static let musicPreferredUTIs: Set<String> = [
        "public.mp3",
        "public.mpeg-4-audio",
        "com.apple.m4a-audio",
        "public.aiff-audio",
        "com.microsoft.waveform-audio",
        "com.apple.music.m3u-playlist",
        "com.apple.music.mp2",
        "public.mp2",
        "com.apple.coreaudio-format"
    ]

    private static let textCodeUTIs: Set<String> = [
        "com.microsoft.typescript",
        "io.iina.cue",
        "com.real.ram",
        "public.plain-text",
        "public.utf8-plain-text",
        "public.text",
        "public.source-code",
        "public.script",
        "public.shell-script",
        "public.json",
        "public.xml",
        "public.yaml",
        "net.daringfireball.markdown",
        "public.comma-separated-values-text"
    ]

    private static let documentImageUTIs: Set<String> = [
        "com.adobe.postscript",
        "com.adobe.encapsulated-postscript",
        "com.adobe.pdf",
        "public.image",
        "public.jpeg",
        "public.png",
        "com.compuserve.gif",
        "public.tiff",
        "public.heic",
        "org.webmproject.webp",
        "com.microsoft.bmp"
    ]

    private static let webUTIs: Set<String> = [
        "public.html",
        "public.xhtml",
        "com.apple.default-app.web-browser",
        "com.apple.webarchive"
    ]

    private static let webSchemes: Set<String> = [
        "http",
        "https"
    ]

    public static func resolveApp(bundleID: String) -> ResetTarget? {
        let lower = bundleID.lowercased()
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) ?? fallbackURL(for: lower) {
            return makeTarget(from: url, fallbackBundleID: bundleID)
        }
        if let fallback = fallbackURL(for: lower) {
            return makeTarget(from: fallback, fallbackBundleID: bundleID)
        }
        return nil
    }

    public static func makeTarget(from appURL: URL, fallbackBundleID: String? = nil) -> ResetTarget? {
        let bundle = Bundle(url: appURL)
        guard let resolvedID = bundle?.bundleIdentifier ?? fallbackBundleID else {
            return nil
        }
        let name = displayName(for: appURL, bundle: bundle, fallbackBundleID: resolvedID)
        return ResetTarget(bundleID: resolvedID, appName: name, appURL: appURL)
    }

    public static func displayName(for appURL: URL, bundle: Bundle? = nil, fallbackBundleID: String = "") -> String {
        let loadedBundle = bundle ?? Bundle(url: appURL)
        if let localized = loadedBundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String, !localized.isEmpty {
            return localized
        }
        if let display = loadedBundle?.infoDictionary?["CFBundleDisplayName"] as? String, !display.isEmpty {
            return display
        }
        if let name = loadedBundle?.infoDictionary?["CFBundleName"] as? String, !name.isEmpty {
            return name
        }
        let filename = appURL.deletingPathExtension().lastPathComponent
        if !filename.isEmpty {
            return filename
        }
        return fallbackBundleID
    }

    public static func isAppleBundleID(_ bundleID: String) -> Bool {
        bundleID.lowercased().hasPrefix("com.apple.")
    }

    public static func categorize(
        kind: HandlerKind,
        identifier: String,
        extensions: [String],
        utType: UTType?
    ) -> AssociationCategory {
        let lowerID = identifier.lowercased()
        let lowerExts = Set(extensions.map { $0.lowercased() })

        if kind == .urlScheme {
            if webSchemes.contains(lowerID) {
                return .web
            }
            return .scheme
        }

        if textCodeUTIs.contains(lowerID) {
            return .textCode
        }
        if documentImageUTIs.contains(lowerID) {
            return .image
        }
        if webUTIs.contains(lowerID) {
            return .web
        }
        if lowerID == "public.mpeg-2-transport-stream" && lowerExts == ["ts"] {
            // Note: .ts as MPEG-2 TS is video, whereas com.microsoft.typescript was caught above.
            return .video
        }

        if let utType {
            if utType.conforms(to: .movie) || utType.conforms(to: .video) || utType.conforms(to: .audiovisualContent) && !utType.conforms(to: .audio) {
                return .video
            }
            if utType.conforms(to: .audio) || utType.conforms(to: .playlist) {
                return .audio
            }
            if utType.conforms(to: .image) || utType.conforms(to: .pdf) {
                return .image
            }
            if utType.conforms(to: .html) || utType.conforms(to: .webArchive) {
                return .web
            }
            if utType.conforms(to: .sourceCode) || utType.conforms(to: .text) || utType.conforms(to: .json) || utType.conforms(to: .xml) {
                return .textCode
            }
            if utType.conforms(to: .archive) || utType.conforms(to: .diskImage) {
                return .archive
            }
        }

        if !lowerExts.isDisjoint(with: videoExtensions) || lowerID.contains("video") || lowerID.contains("movie") || lowerID.contains("divx") || lowerID.contains("mkv") || lowerID.contains("webm") {
            return .video
        }
        if !lowerExts.isDisjoint(with: audioExtensions) || lowerID.contains("audio") || lowerID.contains("playlist") || lowerID.contains("flac") || lowerID.contains("opus") || lowerID.contains("ogg") {
            return .audio
        }
        if lowerExts.contains("cue") || lowerExts.contains("ram") || lowerExts.contains("tsx") {
            return .textCode
        }
        if lowerExts.contains("ps") || lowerExts.contains("eps") || lowerExts.contains("pdf") {
            return .image
        }
        if lowerExts.contains("zip") || lowerExts.contains("gz") || lowerExts.contains("tar") || lowerExts.contains("dmg") {
            return .archive
        }

        return .other
    }

    public static func detectCollision(
        kind: HandlerKind,
        identifier: String,
        extensions: [String],
        category: AssociationCategory,
        currentBundleID: String
    ) -> (isCollision: Bool, reason: String?) {
        let lowerApp = currentBundleID.lowercased()
        let lowerID = identifier.lowercased()

        if isAppleBundleID(lowerApp) {
            return (false, nil)
        }

        if mediaPlayerBundleIDs.contains(lowerApp) {
            if lowerID == "com.microsoft.typescript" {
                return (true, "Medya oynatıcı TypeScript kod dosyasına (.ts/.tsx) varsayılan atanmış")
            }
            if lowerID == "com.adobe.postscript" || lowerID == "com.adobe.encapsulated-postscript" {
                return (true, "Medya oynatıcı PostScript belgesine (.ps) varsayılan atanmış")
            }
            if lowerID == "io.iina.cue" || lowerID == "com.real.ram" {
                return (true, "Metin/playlist metadata dosyası (\(extensions.map { ".\($0)" }.joined(separator: ", "))) medya oynatıcıya bağlı")
            }
            if category == .textCode || category == .image || category == .web || category == .archive {
                return (true, "Medya oynatıcı medya dışı türe (\(category.displayName)) varsayılan atanmış")
            }
        }

        if kind == .extensionOnly {
            return (true, "Eski uzantı tabanlı (extension) özel atama kaydı")
        }

        return (false, nil)
    }

    public static func isPrivatePluginOrPackageUTI(_ utiIdentifier: String) -> Bool {
        let lower = utiIdentifier.lowercased()
        guard !isAppleBundleID(lower) else { return false }
        if lower == "io.iina.iinaplgz" || lower == "io.iina.iinaplugin" {
            return true
        }
        if lower.hasSuffix(".plugin") || lower.hasSuffix(".iinaplgz") || lower.hasSuffix(".iinaplugin") {
            return true
        }
        if let ut = UTType(utiIdentifier), ut.conforms(to: .package), !ut.conforms(to: .audiovisualContent) {
            return true
        }
        return false
    }

    public static func recommendedSystemDefault(
        for kind: HandlerKind,
        identifier: String,
        extensions: [String],
        category: AssociationCategory,
        excludingBundleID: String?,
        candidateAppURLs: [URL]
    ) -> ResetTarget? {
        let lowerID = identifier.lowercased()
        let excluded = excludingBundleID?.lowercased()

        if kind == .contentType && isPrivatePluginOrPackageUTI(lowerID) {
            return nil
        }

        let preferredBundleIDs = orderedPreferredAppleBundleIDs(
            kind: kind,
            lowerIdentifier: lowerID,
            extensions: extensions,
            category: category
        )

        for candidateID in preferredBundleIDs {
            if candidateID.lowercased() == excluded {
                continue
            }
            if let resolved = resolveApp(bundleID: candidateID) {
                return resolved
            }
        }

        // Fall back to Apple apps in candidateAppURLs, avoiding Books unless explicitly ebook/audiobook.
        let nonExcludedAppleCandidates = candidateAppURLs.compactMap { makeTarget(from: $0) }
            .filter { target in
                let lower = target.bundleID.lowercased()
                guard lower != excluded else { return false }
                guard isAppleBundleID(lower) else { return false }
                if lower == BundleID.books.lowercased() && !isBookOrAudioBookType(lowerID, extensions: extensions) {
                    return false
                }
                return true
            }

        if let firstApple = nonExcludedAppleCandidates.first {
            return firstApple
        }

        return nil
    }

    public static func isStandardAppleDefault(
        bundleID: String,
        for kind: HandlerKind,
        identifier: String,
        extensions: [String],
        category: AssociationCategory
    ) -> Bool {
        let lower = bundleID.lowercased()
        guard isAppleBundleID(lower) else { return false }
        let preferred = orderedPreferredAppleBundleIDs(
            kind: kind,
            lowerIdentifier: identifier.lowercased(),
            extensions: extensions,
            category: category
        ).map { $0.lowercased() }
        if preferred.contains(lower) {
            return true
        }
        return lower != BundleID.books.lowercased()
    }

    private static func orderedPreferredAppleBundleIDs(
        kind: HandlerKind,
        lowerIdentifier: String,
        extensions: [String],
        category: AssociationCategory
    ) -> [String] {
        if kind == .urlScheme {
            if webSchemes.contains(lowerIdentifier) {
                return [BundleID.safari]
            }
            if lowerIdentifier == "mailto" {
                return [BundleID.mail]
            }
            // Custom app-owned URL schemes (e.g. iina://, codex://, xcode://, t3code://) have no Apple fallback.
            return []
        }

        if lowerIdentifier == "com.apple.m4v-video" {
            return [BundleID.tv, BundleID.quickTime]
        }

        if webUTIs.contains(lowerIdentifier) {
            return [BundleID.safari]
        }

        if textCodeUTIs.contains(lowerIdentifier) {
            return [BundleID.textEdit]
        }

        if lowerIdentifier == "com.adobe.postscript" || lowerIdentifier == "com.adobe.encapsulated-postscript" {
            return [BundleID.preview, BundleID.textEdit]
        }

        if musicPreferredUTIs.contains(lowerIdentifier) {
            return [BundleID.music, BundleID.quickTime]
        }

        if lowerIdentifier == "com.apple.disk-image-udif" || lowerIdentifier == "com.apple.disk-image" {
            return [BundleID.diskImageMounter]
        }

        let lowerExts = Set(extensions.map { $0.lowercased() })

        switch category {
        case .video:
            return [BundleID.quickTime, BundleID.tv]
        case .audio:
            let musicExts: Set<String> = ["mp3", "mpga", "m4a", "wav", "wave", "aif", "aiff", "m3u", "m3u8", "mp2", "caf"]
            if !lowerExts.isDisjoint(with: musicExts) {
                return [BundleID.music, BundleID.quickTime]
            }
            return [BundleID.quickTime, BundleID.music]
        case .image:
            return [BundleID.preview, BundleID.textEdit]
        case .web:
            return [BundleID.safari]
        case .textCode:
            return [BundleID.textEdit]
        case .archive:
            if lowerExts.contains("dmg") || lowerExts.contains("iso") {
                return [BundleID.diskImageMounter, BundleID.archiveUtility]
            }
            return [BundleID.archiveUtility]
        case .scheme:
            return []
        case .other:
            if lowerIdentifier.contains("typescript") || lowerExts.contains("ts") || lowerExts.contains("tsx") {
                return [BundleID.textEdit]
            }
            return []
        }
    }

    private static func isBookOrAudioBookType(_ lowerID: String, extensions: [String]) -> Bool {
        let bookExts: Set<String> = ["epub", "ibooks", "pdf", "m4b"]
        let lowerExts = Set(extensions.map { $0.lowercased() })
        return lowerID.contains("epub") || lowerID.contains("ibook") || !lowerExts.isDisjoint(with: bookExts)
    }

    private static func fallbackURL(for lowerBundleID: String) -> URL? {
        guard let path = fallbackPaths[lowerBundleID] else { return nil }
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }
}
