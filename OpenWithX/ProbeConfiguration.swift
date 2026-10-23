import AppKit

// Shared transport is temporary. Persistent app-scope bookmarks belong to their creator.
nonisolated final class ProbeConfiguration {
    static let shared = ProbeConfiguration()
    private let sharedDefaults: () throws -> UserDefaults
    private let localDefaults: UserDefaults
    private let discover: @MainActor () -> URL?
    private let registeredApplications: @MainActor () -> [URL]

    init(
        sharedDefaults: @escaping () throws -> UserDefaults = { try ProbeConfiguration.defaults() },
        localDefaults: UserDefaults = .standard,
        discover: @escaping @MainActor () -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode")
        },
        registeredApplications: @escaping @MainActor () -> [URL] = {
            NSWorkspace.shared.urlsForApplications(withBundleIdentifier: "com.microsoft.VSCode")
        }
    ) {
        self.sharedDefaults = sharedDefaults
        self.localDefaults = localDefaults
        self.discover = discover
        self.registeredApplications = registeredApplications
    }

    private static let selectionKey = "manualApplicationSelection.v2"
    private static let recipientKey = "recipientApplicationSelection.v2"
    private static let receiptKey = "applicationSelectionReceipt.v2"
    static let selectionChanged = Notification.Name("com.point.OpenWithX.applicationSelectionChanged")
    @MainActor private var activeTransferURL: URL?

    private struct ManualSelection: Codable {
        let id: UUID
        let path: String
        let hostBookmark: Data
        let transfer: Data
    }

    private struct RecipientSelection: Codable {
        let id: UUID
        let bookmark: Data
    }

    static func defaults() throws -> UserDefaults {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "ProbeAppGroup") as? String,
              FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
              let defaults = UserDefaults(suiteName: group) else {
            throw CocoaError(.fileReadNoPermission)
        }
        return defaults
    }

    private func manualSelection() throws -> ManualSelection? {
        let defaults = try sharedDefaults()
        guard let data = defaults.data(forKey: Self.selectionKey) else {
            // The first prototype stored a sender-owned bookmark for both processes.
            // Require explicit replacement rather than silently switching to discovery.
            if defaults.data(forKey: "selectedVSCodeBookmark") != nil { throw VSCodeSelection.Failure.reselect }
            return nil
        }
        do { return try PropertyListDecoder().decode(ManualSelection.self, from: data) }
        catch { throw VSCodeSelection.Failure.reselect }
    }

    @MainActor func application() throws -> URL {
        guard let selection = try manualSelection() else {
            return try VSCodeSelection.resolve(bookmark: nil, automaticallyDiscoveredURL:
                discover())
        }
        return try resolve(selection.hostBookmark, originalPath: selection.path)
    }

    @MainActor func selectApplication(_ application: URL) throws {
        let bookmark = try application.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                                   includingResourceValuesForKeys: nil, relativeTo: nil)
        let ownedURL = try VSCodeSelection.resolve(bookmark: bookmark, automaticallyDiscoveredURL: nil)
        guard ownedURL.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
        do {
            let selection = ManualSelection(id: UUID(), path: ownedURL.path, hostBookmark: bookmark,
                                           transfer: try VSCodeSelection.transfer(ownedURL))
            let data = try PropertyListEncoder().encode(selection)
            try sharedDefaults().set(data, forKey: Self.selectionKey)
            activeTransferURL?.stopAccessingSecurityScopedResource()
            activeTransferURL = ownedURL
            DistributedNotificationCenter.default().postNotificationName(Self.selectionChanged, object: nil,
                                                                          userInfo: nil, deliverImmediately: true)
        } catch {
            ownedURL.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    @MainActor func clearSelection() throws {
        let defaults = try sharedDefaults()
        defaults.removeObject(forKey: Self.selectionKey)
        defaults.removeObject(forKey: "selectedVSCodeBookmark")
        defaults.removeObject(forKey: "selectedVSCodePath")
        activeTransferURL?.stopAccessingSecurityScopedResource()
        activeTransferURL = nil
        DistributedNotificationCenter.default().postNotificationName(Self.selectionChanged, object: nil,
                                                                      userInfo: nil, deliverImmediately: true)
    }

    enum AuthorizationStatus: Equatable {
        case automatic, pending, synchronized
    }

    @MainActor func authorizationStatus() throws -> AuthorizationStatus {
        guard let selection = try manualSelection() else { return .automatic }
        _ = try resolve(selection.hostBookmark, originalPath: selection.path)
        let acknowledged = try sharedDefaults().string(forKey: Self.receiptKey) == selection.id.uuidString
        if acknowledged {
            activeTransferURL?.stopAccessingSecurityScopedResource()
            activeTransferURL = nil
        }
        return acknowledged ? .synchronized : .pending
    }

    // Called on extension startup and on change notification, while the sender is alive.
    func receiveSelection() throws {
        let local = localDefaults
        guard let selection = try manualSelection() else {
            local.removeObject(forKey: Self.recipientKey)
            return
        }
        if let data = local.data(forKey: Self.recipientKey),
           let recipient = try? PropertyListDecoder().decode(RecipientSelection.self, from: data),
           recipient.id == selection.id {
            _ = try resolve(recipient.bookmark, originalPath: selection.path)
        } else {
            let bookmark = try VSCodeSelection.adopt(selection.transfer, originalPath: selection.path)
            _ = try resolve(bookmark, originalPath: selection.path)
            let recipient = RecipientSelection(id: selection.id, bookmark: bookmark)
            local.set(try PropertyListEncoder().encode(recipient), forKey: Self.recipientKey)
        }
        try sharedDefaults().set(selection.id.uuidString, forKey: Self.receiptKey)
    }

    @MainActor func extensionApplication() throws -> URL {
        guard let selection = try manualSelection() else { return try application() }
        try receiveSelection()
        guard let data = localDefaults.data(forKey: Self.recipientKey),
              let recipient = try? PropertyListDecoder().decode(RecipientSelection.self, from: data),
              recipient.id == selection.id else { throw VSCodeSelection.Failure.reselect }
        let selected = try resolve(recipient.bookmark, originalPath: selection.path)
        return try VSCodeSelection.launchURL(for: selected, registeredApplications:
            registeredApplications())
    }

    private func resolve(_ bookmark: Data, originalPath: String) throws -> URL {
        let application = try VSCodeSelection.resolve(bookmark: bookmark, automaticallyDiscoveredURL: nil)
        guard application.path == originalPath else { throw VSCodeSelection.Failure.reselect }
        return application
    }
}
