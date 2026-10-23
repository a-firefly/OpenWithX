import AppKit
import FinderSync
import OSLog

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.point.OpenWithX.FinderProbe", category: "finder")
    private var volumeMonitor: LocalVolumeMonitor?
    private var selectionObserver: NSObjectProtocol?

    override init() {
        super.init()
        volumeMonitor = LocalVolumeMonitor { [weak self] roots in
            FIFinderSyncController.default().directoryURLs = roots
            self?.logger.notice("Registered local volume count: \(roots.count)")
        }
        selectionObserver = DistributedNotificationCenter.default().addObserver(
            forName: ProbeConfiguration.selectionChanged, object: nil, queue: .main
        ) { [weak self] _ in self?.receiveSelection() }
        receiveSelection()
        logger.notice("Finder extension started; scope registration is not an access grant")
    }

    deinit {
        if let selectionObserver { DistributedNotificationCenter.default().removeObserver(selectionObserver) }
    }

    private func receiveSelection() {
        do {
            try ProbeConfiguration.receiveSelection()
            logger.notice("Application selection synchronized using recipient-owned authorization")
        } catch {
            // A disabled extension may miss the sender's transfer window. Never auto-fallback.
            logger.error("Application authorization not synchronized; explicit reselection may be required")
        }
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
        TargetFolderOpener().open(target) { [self] result in
            switch result {
            case .success:
                logger.notice("NSWorkspace accepted the open request; editor loading is not verified")
            case .failure(let error):
                reportFailure(error)
            }
        }
    }

    private func reportFailure(_ error: Error) {
        logger.error("Open request failed; attempting host handoff")
        var url = URLComponents()
        url.scheme = "openwithx-probe"
        url.host = "failure"
        url.queryItems = [
            URLQueryItem(name: "detail", value: String(describing: error)),
            URLQueryItem(name: "message", value: (error as? VSCodeSelection.Failure)?.errorDescription
                ?? "打开失败，请检查 VS Code 选择及系统权限。")
        ]
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
