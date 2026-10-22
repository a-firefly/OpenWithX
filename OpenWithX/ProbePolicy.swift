import Foundation

// Validation-only policies. Finder callbacks and sandbox grants require real-system evidence.
nonisolated enum TargetFolderSelection {
    static func target(in urls: [URL]) -> URL? {
        guard urls.count == 1, let url = urls.first, url.isFileURL,
              let values = try? url.resourceValues(forKeys: [
                .isDirectoryKey, .isPackageKey, .isAliasFileKey, .isSymbolicLinkKey
              ]), values.isDirectory == true, values.isPackage == false,
              values.isAliasFile == false, values.isSymbolicLink == false else { return nil }
        return url
    }
}

nonisolated enum LocalVolumeCoverage {
    struct Volume {
        let url: URL
        let isLocal: Bool?
    }

    static func roots(from volumes: [Volume]) -> Set<URL> {
        Set(volumes.filter { $0.isLocal == true }.map(\.url))
    }
}

nonisolated enum VSCodeSelection {
    enum Failure: Error, Equatable {
        case notFound
        case reselect
    }

    static func launchURL(for selected: URL, registeredApplications: [URL]) throws -> URL {
        guard let application = registeredApplications.first(where: {
            $0.standardizedFileURL.path == selected.standardizedFileURL.path
        }) else { throw Failure.reselect }
        return application
    }

    // An implicit transfer is consumed while the sending app still holds access.
    // The recipient then persists its OWN app-scope bookmark, never the sender's.
    static func transfer(_ application: URL) throws -> Data {
        try application.bookmarkData(options: .minimalBookmark,
                                     includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func adopt(_ transfer: Data, originalPath: String) throws -> Data {
        do {
            var stale = false
            let application = try URL(resolvingBookmarkData: transfer, options: .withoutUI,
                                      relativeTo: nil, bookmarkDataIsStale: &stale)
            guard !stale, application.path == originalPath,
                  Bundle(url: application)?.bundleIdentifier == "com.microsoft.VSCode" else {
                throw Failure.reselect
            }
            return try application.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                                includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch { throw Failure.reselect }
    }

    static func resolve(bookmark: Data?, automaticallyDiscoveredURL: URL?) throws -> URL {
        guard let bookmark else {
            guard let automaticallyDiscoveredURL else { throw Failure.notFound }
            return automaticallyDiscoveredURL
        }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let matchesVSCode = Bundle(url: url)?.bundleIdentifier == "com.microsoft.VSCode"
            let exists = FileManager.default.fileExists(atPath: url.path)
            guard !stale, matchesVSCode, exists else { throw Failure.reselect }
            return url
        } catch {
            throw Failure.reselect
        }
    }
}

nonisolated enum VSCodeProjectURL {
    static func make(for folder: URL) throws -> URL {
        guard folder.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        var components = URLComponents()
        components.scheme = "vscode"
        components.host = "file"
        // A trailing slash requests a project, including names ending with :digits.
        components.path = folder.path.hasSuffix("/") ? folder.path : folder.path + "/"
        // Preserve the active project by requesting a separate VS Code window.
        components.queryItems = [URLQueryItem(name: "windowId", value: "_blank")]
        guard let url = components.url else { throw CocoaError(.fileReadInvalidFileName) }
        return url
    }
}
