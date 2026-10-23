import Foundation

// Finder callbacks and sandbox grants require real-system evidence in addition to policy tests.
nonisolated enum TargetFolderSelection {
    static func target(in urls: [URL]) -> URL? {
        guard urls.count == 1, let url = urls.first,
              (try? validate(url)) != nil else { return nil }
        return url
    }

    static func validate(_ url: URL) throws {
        guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        let values = try url.resourceValues(forKeys: [
            .isDirectoryKey, .isPackageKey, .isAliasFileKey, .isSymbolicLinkKey
        ])
        guard values.isDirectory == true, values.isPackage == false,
              values.isAliasFile == false, values.isSymbolicLink == false else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
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
    enum Failure: Error, Equatable, LocalizedError {
        case notFound
        case reselect
        case anotherCopyIsRunning

        var errorDescription: String? {
            switch self {
            case .notFound: AppText.text("The stable version of VS Code was not found. Select the application.", "未发现正式版 VS Code，请手动选择应用。")
            case .reselect: AppText.text("The selected VS Code copy or authorization is invalid. Select it again.", "所选 VS Code 副本或授权已失效，请重新选择。")
            case .anotherCopyIsRunning:
                AppText.text("Another VS Code copy is running. Select the copy you are using, or quit the other copy yourself and retry.", "另一个 VS Code 副本正在运行，无法可靠地将文件夹交给所选副本。请手动选择正在使用的副本，或自行退出其他副本后重试。")
            }
        }
    }

    static func checkRunningApplications(for selected: URL, runningApplications: [URL]) throws {
        guard !runningApplications.isEmpty else { return }
        guard runningApplications.contains(where: {
            $0.standardizedFileURL.path == selected.standardizedFileURL.path
        }) else { throw Failure.anotherCopyIsRunning }
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
            guard let automaticallyDiscoveredURL, automaticallyDiscoveredURL.isFileURL,
                  Bundle(url: automaticallyDiscoveredURL)?.bundleIdentifier == "com.microsoft.VSCode",
                  FileManager.default.fileExists(atPath: automaticallyDiscoveredURL.path) else {
                throw Failure.notFound
            }
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
