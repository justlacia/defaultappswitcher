import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case turkish = "tr"
    case english = "en"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .turkish: return "TR"
        case .english: return "EN"
        }
    }

    public var localeIdentifier: String {
        switch self {
        case .turkish: return "tr_TR"
        case .english: return "en_US"
        }
    }

    /// Detects the initial UI language from the system's preferred language list.
    /// Defaults to Turkish when the primary system language is Turkish, and English otherwise.
    public static func detectSystemLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard let first = preferredLanguages.first?.lowercased() else {
            return .english
        }
        return first.hasPrefix("tr") ? .turkish : .english
    }

    /// Resolves the active language from an optional persisted selection or falls back to system language.
    public static func resolveInitial(
        storedCode: String?,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        if let storedCode, let parsed = AppLanguage(rawValue: storedCode.lowercased()) {
            return parsed
        }
        return detectSystemLanguage(preferredLanguages: preferredLanguages)
    }
}

public struct LocalizedText: Sendable, Hashable, Codable {
    public let tr: String
    public let en: String

    public init(tr: String, en: String) {
        self.tr = tr
        self.en = en
    }

    public init(same text: String) {
        self.tr = text
        self.en = text
    }

    public func text(for language: AppLanguage) -> String {
        switch language {
        case .turkish: return tr
        case .english: return en
        }
    }
}
