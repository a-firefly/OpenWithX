import Foundation

/// Use the first system language only; unsupported languages deliberately use English.
nonisolated enum AppText {
    static func text(_ english: String, _ simplifiedChinese: String,
                     languages: [String] = Locale.preferredLanguages) -> String {
        guard let identifier = languages.first else { return english }
        let language = Locale.Language(identifier: identifier)
        return language.languageCode?.identifier == "zh" && language.script?.identifier == "Hans"
            ? simplifiedChinese : english
    }
}
