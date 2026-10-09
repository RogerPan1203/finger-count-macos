import Foundation

/// The user's language choice. System language is the default until a choice is saved.
enum AppLanguage: String, CaseIterable {
    case system
    case english
    case chinese

    static let preferenceKey = "appLanguage"

    static var saved: AppLanguage {
        guard let value = UserDefaults.standard.string(forKey: preferenceKey) else { return .system }
        return AppLanguage(rawValue: value) ?? .system
    }

    var usesChinese: Bool {
        switch self {
        case .chinese: return true
        case .english: return false
        case .system:
            return (Locale.preferredLanguages.first ?? "en")
                .lowercased().hasPrefix("zh")
        }
    }

    func text(_ chinese: String, _ english: String) -> String {
        usesChinese ? chinese : english
    }
}
