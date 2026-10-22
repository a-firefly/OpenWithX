import AppKit

// Shared by the host and extension; this is a feasibility probe, not production configuration.
nonisolated enum ProbeConfiguration {
    static let bookmarkKey = "selectedVSCodeBookmark"
    static let pathKey = "selectedVSCodePath"

    static func defaults() throws -> UserDefaults {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "ProbeAppGroup") as? String,
              FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
              let defaults = UserDefaults(suiteName: group) else {
            throw CocoaError(.fileReadNoPermission)
        }
        return defaults
    }

    @MainActor static func application() throws -> URL {
        let defaults = try defaults()
        let bookmark = defaults.data(forKey: bookmarkKey)
        let url = try VSCodeSelection.resolve(
            bookmark: bookmark,
            automaticallyDiscoveredURL: NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode")
        )
        if bookmark != nil, defaults.string(forKey: pathKey) != url.path {
            throw VSCodeSelection.Failure.reselect
        }
        return url
    }
}
