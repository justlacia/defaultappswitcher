import Foundation

public enum TCCAuthStatus: Sendable, Hashable {
    case allowed
    case denied
    case limited
    case unknown(Int)

    public var displayName: String {
        switch self {
        case .allowed: return "İzin Verildi"
        case .denied: return "Reddedildi"
        case .limited: return "Sınırlı"
        case .unknown(let code): return "Bilinmiyor (\(code))"
        }
    }
}

public enum TCCScope: String, Sendable, Hashable {
    case user = "Kullanıcı"
    case system = "Sistem"
}

public enum TCCReadState: Sendable, Hashable {
    case readable
    case needsFullDiskAccess
    case notFound
    case error(String)
}

public struct TCCPermissionEntry: Identifiable, Sendable, Hashable {
    public let id: String
    public let serviceKey: String
    public let displayName: String
    public let symbolName: String
    public let tccutilName: String?
    public let status: TCCAuthStatus
    public let scope: TCCScope
    public let indirectTarget: String?
    public let lastModified: Date?
    public let settingsURL: URL?

    public init(
        serviceKey: String,
        displayName: String,
        symbolName: String,
        tccutilName: String?,
        status: TCCAuthStatus,
        scope: TCCScope,
        indirectTarget: String?,
        lastModified: Date?,
        settingsURL: URL?
    ) {
        self.id = "\(scope.rawValue):\(serviceKey):\(indirectTarget ?? "")"
        self.serviceKey = serviceKey
        self.displayName = displayName
        self.symbolName = symbolName
        self.tccutilName = tccutilName
        self.status = status
        self.scope = scope
        self.indirectTarget = indirectTarget
        self.lastModified = lastModified
        self.settingsURL = settingsURL
    }
}

public struct DeclaredPrivacyPermission: Identifiable, Sendable, Hashable {
    public let id: String
    public let plistKey: String
    public let displayName: String
    public let symbolName: String
    public let usageDescription: String
    public let tccutilService: String?
    public let settingsURL: URL?

    public init(
        plistKey: String,
        displayName: String,
        symbolName: String,
        usageDescription: String,
        tccutilService: String?,
        settingsURL: URL?
    ) {
        self.id = plistKey
        self.plistKey = plistKey
        self.displayName = displayName
        self.symbolName = symbolName
        self.usageDescription = usageDescription
        self.tccutilService = tccutilService
        self.settingsURL = settingsURL
    }
}

public struct EntitlementItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let key: String
    public let title: String
    public let explanation: String
    public let valueSummary: String
    public let isSensitive: Bool

    public init(
        key: String,
        title: String,
        explanation: String,
        valueSummary: String,
        isSensitive: Bool
    ) {
        self.id = key
        self.key = key
        self.title = title
        self.explanation = explanation
        self.valueSummary = valueSummary
        self.isSensitive = isSensitive
    }
}

public struct CodeSigningInfo: Sendable, Hashable {
    public let isSigned: Bool
    public let isAppleSigned: Bool
    public let isAdHoc: Bool
    public let teamIdentifier: String?
    public let signingAuthority: String?
    public let isSandboxed: Bool
    public let isHardenedRuntime: Bool
    public let hasQuarantineAttribute: Bool
    public let architectures: [String]
    public let minimumOSVersion: String?

    public init(
        isSigned: Bool,
        isAppleSigned: Bool,
        isAdHoc: Bool,
        teamIdentifier: String?,
        signingAuthority: String?,
        isSandboxed: Bool,
        isHardenedRuntime: Bool,
        hasQuarantineAttribute: Bool,
        architectures: [String],
        minimumOSVersion: String?
    ) {
        self.isSigned = isSigned
        self.isAppleSigned = isAppleSigned
        self.isAdHoc = isAdHoc
        self.teamIdentifier = teamIdentifier
        self.signingAuthority = signingAuthority
        self.isSandboxed = isSandboxed
        self.isHardenedRuntime = isHardenedRuntime
        self.hasQuarantineAttribute = hasQuarantineAttribute
        self.architectures = architectures
        self.minimumOSVersion = minimumOSVersion
    }
}

public enum BackgroundItemKind: String, Sendable, Hashable {
    case loginItem = "Oturum Açma Öğesi"
    case launchAgent = "LaunchAgent"
    case helper = "Yardımcı Servis"
}

public struct BackgroundItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let kind: BackgroundItemKind
    public let path: String

    public init(name: String, kind: BackgroundItemKind, path: String) {
        self.id = "\(kind.rawValue):\(path)"
        self.name = name
        self.kind = kind
        self.path = path
    }
}

public struct URLSchemeInfo: Identifiable, Sendable, Hashable {
    public let id: String
    public let scheme: String
    public let isCurrentDefault: Bool
    public let currentDefaultAppName: String?

    public init(scheme: String, isCurrentDefault: Bool, currentDefaultAppName: String?) {
        self.id = scheme.lowercased()
        self.scheme = scheme
        self.isCurrentDefault = isCurrentDefault
        self.currentDefaultAppName = currentDefaultAppName
    }
}

public struct AppSecurityReport: Sendable {
    public let codeSigning: CodeSigningInfo
    public let entitlements: [EntitlementItem]
    public let declaredPermissions: [DeclaredPrivacyPermission]
    public let userTCCState: TCCReadState
    public let systemTCCState: TCCReadState
    public let tccEntries: [TCCPermissionEntry]
    public let urlSchemes: [URLSchemeInfo]
    public let backgroundItems: [BackgroundItem]

    public init(
        codeSigning: CodeSigningInfo,
        entitlements: [EntitlementItem],
        declaredPermissions: [DeclaredPrivacyPermission],
        userTCCState: TCCReadState,
        systemTCCState: TCCReadState,
        tccEntries: [TCCPermissionEntry],
        urlSchemes: [URLSchemeInfo],
        backgroundItems: [BackgroundItem]
    ) {
        self.codeSigning = codeSigning
        self.entitlements = entitlements
        self.declaredPermissions = declaredPermissions
        self.userTCCState = userTCCState
        self.systemTCCState = systemTCCState
        self.tccEntries = tccEntries
        self.urlSchemes = urlSchemes
        self.backgroundItems = backgroundItems
    }

    public var needsFullDiskAccessForTCC: Bool {
        userTCCState == .needsFullDiskAccess || systemTCCState == .needsFullDiskAccess
    }
}
