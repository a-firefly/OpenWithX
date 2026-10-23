import Foundation

/// Use the first system language only; unsupported languages deliberately use English.
nonisolated enum AppText {
    static func supportedLanguage(languages: [String] = Locale.preferredLanguages) -> String {
        guard let identifier = languages.first else { return "en" }
        let language = Locale.Language(identifier: identifier)
        return language.languageCode?.identifier == "zh" && language.script?.identifier == "Hans"
            ? "zh-Hans" : "en"
    }

    static func text(_ english: String, _ simplifiedChinese: String,
                     languages: [String] = Locale.preferredLanguages) -> String {
        supportedLanguage(languages: languages) == "zh-Hans" ? simplifiedChinese : english
    }

    /// Keep AppKit/SwiftUI's generated menus consistent without storing a language preference.
    static func configureSystemLocalization() {
        let language = supportedLanguage()
        var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments["AppleLanguages"] = [language]
        UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }
}
