import Foundation

public enum HandlerKind: String, Codable, Sendable, CaseIterable, Hashable {
    case contentType
    case urlScheme
    case extensionOnly

    public var displayName: String {
        switch self {
        case .contentType:
            return "İçerik Türü (UTI)"
        case .urlScheme:
            return "URL Şeması"
        case .extensionOnly:
            return "Dosya Uzantısı"
        }
    }
}

public struct HandlerOverride: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let kind: HandlerKind
    public let identifier: String
    public let bundleID: String
    public let roles: [String]
    public let modDate: Date?

    public init(
        kind: HandlerKind,
        identifier: String,
        bundleID: String,
        roles: [String] = ["all roles"],
        modDate: Date? = nil
    ) {
        self.id = "\(kind.rawValue):\(identifier.lowercased())"
        self.kind = kind
        self.identifier = identifier
        self.bundleID = bundleID
        self.roles = roles
        self.modDate = modDate
    }

    public var normalizedBundleID: String {
        bundleID.lowercased()
    }
}

public enum AssociationCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case video
    case audio
    case image
    case web
    case textCode
    case archive
    case scheme
    case other

    public var displayName: String {
        switch self {
        case .video: return "Video"
        case .audio: return "Ses"
        case .image: return "Görsel / PDF"
        case .web: return "Web"
        case .textCode: return "Metin / Kod"
        case .archive: return "Arşiv"
        case .scheme: return "URL Şeması"
        case .other: return "Diğer"
        }
    }

    public var symbolName: String {
        switch self {
        case .video: return "film"
        case .audio: return "music.note"
        case .image: return "photo"
        case .web: return "globe"
        case .textCode: return "chevron.left.forwardslash.chevron.right"
        case .archive: return "archivebox"
        case .scheme: return "link"
        case .other: return "doc"
        }
    }

    public var isMedia: Bool {
        self == .video || self == .audio
    }
}

public struct ResetTarget: Codable, Sendable, Hashable {
    public let bundleID: String
    public let appName: String
    public let appURL: URL

    public init(bundleID: String, appName: String, appURL: URL) {
        self.bundleID = bundleID
        self.appName = appName
        self.appURL = appURL
    }
}

public struct AppAssociation: Identifiable, Sendable, Hashable {
    public let id: String
    public let kind: HandlerKind
    public let identifier: String
    public let extensions: [String]
    public let localizedDescription: String
    public let category: AssociationCategory
    public let currentBundleID: String
    public let currentAppURL: URL?
    public let currentAppName: String
    public let isExplicitOverride: Bool
    public let overrideModDate: Date?
    public let isSuspiciousCollision: Bool
    public let collisionReason: String?
    public let recommendedDefault: ResetTarget?
    public let candidateAppURLs: [URL]

    public init(
        kind: HandlerKind,
        identifier: String,
        extensions: [String],
        localizedDescription: String,
        category: AssociationCategory,
        currentBundleID: String,
        currentAppURL: URL?,
        currentAppName: String,
        isExplicitOverride: Bool,
        overrideModDate: Date?,
        isSuspiciousCollision: Bool,
        collisionReason: String?,
        recommendedDefault: ResetTarget?,
        candidateAppURLs: [URL]
    ) {
        self.id = "\(kind.rawValue):\(identifier.lowercased())"
        self.kind = kind
        self.identifier = identifier
        self.extensions = extensions
        self.localizedDescription = localizedDescription
        self.category = category
        self.currentBundleID = currentBundleID
        self.currentAppURL = currentAppURL
        self.currentAppName = currentAppName
        self.isExplicitOverride = isExplicitOverride
        self.overrideModDate = overrideModDate
        self.isSuspiciousCollision = isSuspiciousCollision
        self.collisionReason = collisionReason
        self.recommendedDefault = recommendedDefault
        self.candidateAppURLs = candidateAppURLs
    }

    public var normalizedBundleID: String {
        currentBundleID.lowercased()
    }

    public var displayExtensionsText: String {
        if kind == .urlScheme {
            return "\(identifier)://"
        }
        if extensions.isEmpty {
            return identifier
        }
        return extensions.map { ".\($0)" }.joined(separator: ", ")
    }

    public var canResetToSystemDefault: Bool {
        guard let recommendedDefault else { return false }
        return recommendedDefault.bundleID.lowercased() != currentBundleID.lowercased()
    }

    public var isSystemDefault: Bool {
        DefaultAppResolver.isStandardAppleDefault(
            bundleID: currentBundleID,
            for: kind,
            identifier: identifier,
            extensions: extensions,
            category: category
        )
    }
}

public struct InstalledApp: Identifiable, Sendable, Hashable {
    public let id: String // lowercased bundleID
    public let bundleID: String // exact bundleID
    public let name: String
    public let url: URL
    public let version: String
    public let buildNumber: String
    public let isAppleApp: Bool
    public let isInstalled: Bool
    public let overrideCount: Int
    public let defaultAssociationCount: Int
    public let declaredExtensions: [String]
    public let declaredUTIs: [String]
    public let declaredSchemes: [String]

    public init(
        bundleID: String,
        name: String,
        url: URL,
        version: String,
        buildNumber: String,
        isAppleApp: Bool,
        isInstalled: Bool = true,
        overrideCount: Int,
        defaultAssociationCount: Int,
        declaredExtensions: [String],
        declaredUTIs: [String],
        declaredSchemes: [String]
    ) {
        self.id = bundleID.lowercased()
        self.bundleID = bundleID
        self.name = name
        self.url = url
        self.version = version
        self.buildNumber = buildNumber
        self.isAppleApp = isAppleApp
        self.isInstalled = isInstalled
        self.overrideCount = overrideCount
        self.defaultAssociationCount = defaultAssociationCount
        self.declaredExtensions = declaredExtensions
        self.declaredUTIs = declaredUTIs
        self.declaredSchemes = declaredSchemes
    }
}

public struct DeclaredExtensionStatus: Identifiable, Sendable, Hashable {
    public let id: String
    public let ext: String
    public let uti: String?
    public let currentAppName: String?
    public let currentBundleID: String?

    public init(ext: String, uti: String?, currentAppName: String?, currentBundleID: String?) {
        self.id = ext.lowercased()
        self.ext = ext
        self.uti = uti
        self.currentAppName = currentAppName
        self.currentBundleID = currentBundleID
    }
}

public struct ResetFailure: Identifiable, Sendable, Hashable {
    public let id: String
    public let identifier: String
    public let reason: String

    public init(identifier: String, reason: String) {
        self.id = identifier
        self.identifier = identifier
        self.reason = reason
    }
}

public struct ResetResult: Sendable {
    public let succeeded: Int
    public let failed: [ResetFailure]
    public let skipped: Int
    public let snapshotID: UUID?

    public init(succeeded: Int, failed: [ResetFailure], skipped: Int, snapshotID: UUID?) {
        self.succeeded = succeeded
        self.failed = failed
        self.skipped = skipped
        self.snapshotID = snapshotID
    }
}

public struct SnapshotEntry: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let kind: HandlerKind
    public let identifier: String
    public let previousBundleID: String
    public let previousAppPath: String?
    public let targetBundleID: String?

    public init(
        kind: HandlerKind,
        identifier: String,
        previousBundleID: String,
        previousAppPath: String?,
        targetBundleID: String?
    ) {
        self.id = "\(kind.rawValue):\(identifier.lowercased())"
        self.kind = kind
        self.identifier = identifier
        self.previousBundleID = previousBundleID
        self.previousAppPath = previousAppPath
        self.targetBundleID = targetBundleID
    }
}

public struct ResetSnapshot: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let createdAt: Date
    public let title: String
    public let entries: [SnapshotEntry]

    public init(id: UUID = UUID(), createdAt: Date = Date(), title: String, entries: [SnapshotEntry]) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.entries = entries
    }
}
