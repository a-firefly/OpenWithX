import AppKit
import FinderSync
import OSLog

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.point.OpenWithX.FinderProbe", category: "finder")
    private let opener = TargetFolderOpener()
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
            try ProbeConfiguration.shared.receiveSelection()
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
        let item = NSMenuItem(title: AppText.text("Open in VS Code", "使用 VS Code 打开"),
                              action: #selector(openTarget), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func openTarget() {
        let selection = FIFinderSyncController.default().selectedItemURLs() ?? []
        guard selection.count == 1, let target = selection.first else {
            reportFailure(CocoaError(.fileNoSuchFile))
            return
        }
        opener.open(target) { [self] result in
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
        guard let failureURL = OpenFailure(error: error).handoffURL else { return }
        // Resolve the containing app, never an arbitrary application registered for the scheme.
        let host = Bundle.main.bundleURL.deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        configuration.allowsRunningApplicationSubstitution = false
        NSWorkspace.shared.open([failureURL], withApplicationAt: host,
                                configuration: configuration) { [self] _, error in
            if error != nil { logger.error("Host error handoff failed") }
        }
    }
}
