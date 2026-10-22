import AppKit
import FinderSync
import OSLog

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.point.OpenWithX.FinderProbe", category: "validation")
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        updateCoverage()
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification,
                     NSWorkspace.didRenameVolumeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in self?.updateCoverage() })
        }
        logger.notice("Probe extension started; scope registration is not an access grant")
    }

    deinit {
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    private func updateCoverage() {
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsLocalKey], options: [.skipHiddenVolumes]
        ) ?? []
        let roots = LocalVolumeCoverage.roots(from: volumes.map {
            .init(url: $0, isLocal: try? $0.resourceValues(forKeys: [.volumeIsLocalKey]).volumeIsLocal)
        })
        FIFinderSyncController.default().directoryURLs = roots
        logger.notice("Registered local volume count: \(roots.count)")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems,
              TargetFolderSelection.target(in: FIFinderSyncController.default().selectedItemURLs() ?? []) != nil else {
            return nil
        }
        let menu = NSMenu()
        let chinese = Locale.preferredLanguages.first?.hasPrefix("zh-Hans") == true
            || Locale.preferredLanguages.first?.hasPrefix("zh-CN") == true
        let item = NSMenuItem(title: chinese ? "使用 VS Code 打开" : "Open in VS Code",
                              action: #selector(openTarget), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func openTarget() {
        guard let target = TargetFolderSelection.target(
            in: FIFinderSyncController.default().selectedItemURLs() ?? []
        ) else {
            reportFailure(CocoaError(.fileNoSuchFile))
            return
        }
        do {
            let application = try ProbeConfiguration.application()
            let accessed = application.startAccessingSecurityScopedResource()
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([target], withApplicationAt: application, configuration: configuration) { [self] _, error in
                if accessed { application.stopAccessingSecurityScopedResource() }
                if let error { reportFailure(error) }
                else { logger.notice("NSWorkspace accepted the open request; editor loading is not verified") }
            }
        } catch { reportFailure(error) }
    }

    private func reportFailure(_ error: Error) {
        logger.error("Open request failed; attempting host handoff")
        var url = URLComponents()
        url.scheme = "openwithx-probe"
        url.host = "failure"
        url.queryItems = [URLQueryItem(name: "detail", value: String(describing: error))]
        guard let failureURL = url.url else { return }
        // Resolve the containing app, never an arbitrary application registered for the scheme.
        let host = Bundle.main.bundleURL.deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        NSWorkspace.shared.open([failureURL], withApplicationAt: host,
                                configuration: NSWorkspace.OpenConfiguration()) { [self] _, error in
            if error != nil { logger.error("Host error handoff failed") }
        }
    }
}
