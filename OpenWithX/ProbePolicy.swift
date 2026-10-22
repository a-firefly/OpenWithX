import Foundation
import OSLog

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
            Logger(subsystem: "com.point.OpenWithX.FinderProbe", category: "validation").notice(
                "Manual application: stale=\(stale), scopedAccess=\(accessed), matchesVSCode=\(matchesVSCode), exists=\(exists)"
            )
            guard !stale, matchesVSCode, exists else { throw Failure.reselect }
            return url
        } catch {
            let failure = error as NSError
            Logger(subsystem: "com.point.OpenWithX.FinderProbe", category: "validation").error(
                "Manual application resolution failed: domain=\(failure.domain, privacy: .public), code=\(failure.code)"
            )
            throw Failure.reselect
        }
    }
}
