import AppKit

/// Rebuilds Finder coverage from the current mount table, never from saved volume paths.
@MainActor
final class LocalVolumeMonitor {
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        mountedVolumes: @escaping @MainActor () -> [LocalVolumeCoverage.Volume] = LocalVolumeMonitor.mountedVolumes,
        register: @escaping @MainActor (Set<URL>) -> Void
    ) {
        self.notificationCenter = notificationCenter
        // Subscribe before the initial snapshot so a mount during startup is not missed.
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification,
                     NSWorkspace.didRenameVolumeNotification] {
            observers.append(notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                // NotificationCenter delivers this observer on the main operation queue.
                MainActor.assumeIsolated {
                    register(LocalVolumeCoverage.roots(from: mountedVolumes()))
                }
            })
        }
        register(LocalVolumeCoverage.roots(from: mountedVolumes()))
    }

    deinit {
        for observer in observers { notificationCenter.removeObserver(observer) }
    }

    private static func mountedVolumes() -> [LocalVolumeCoverage.Volume] {
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsLocalKey], options: [.skipHiddenVolumes]
        ) ?? []
        return urls.map {
            .init(url: $0, isLocal: try? $0.resourceValues(forKeys: [.volumeIsLocalKey]).volumeIsLocal)
        }
    }
}
