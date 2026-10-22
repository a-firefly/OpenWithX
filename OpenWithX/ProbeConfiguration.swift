import AppKit

// Shared transport is temporary. Persistent app-scope bookmarks belong to their creator.
nonisolated enum ProbeConfiguration {
    private static let selectionKey = "manualApplicationSelection.v2"
    private static let recipientKey = "recipientApplicationSelection.v2"
    private static let receiptKey = "applicationSelectionReceipt.v2"
    static let selectionChanged = Notification.Name("com.point.OpenWithX.applicationSelectionChanged")
    @MainActor private static var activeTransferURL: URL?

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

    private static func manualSelection() throws -> ManualSelection? {
        let defaults = try defaults()
        guard let data = defaults.data(forKey: selectionKey) else {
            // The first prototype stored a sender-owned bookmark for both processes.
            // Require explicit replacement rather than silently switching to discovery.
            if defaults.data(forKey: "selectedVSCodeBookmark") != nil { throw VSCodeSelection.Failure.reselect }
            return nil
        }
        do { return try PropertyListDecoder().decode(ManualSelection.self, from: data) }
        catch { throw VSCodeSelection.Failure.reselect }
    }

    @MainActor static func application() throws -> URL {
        guard let selection = try manualSelection() else {
            return try VSCodeSelection.resolve(bookmark: nil, automaticallyDiscoveredURL:
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode"))
        }
        return try resolve(selection.hostBookmark, originalPath: selection.path)
    }

    @MainActor static func selectApplication(_ application: URL) throws {
        let bookmark = try application.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                                   includingResourceValuesForKeys: nil, relativeTo: nil)
        let ownedURL = try VSCodeSelection.resolve(bookmark: bookmark, automaticallyDiscoveredURL: nil)
        guard ownedURL.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
        do {
            let selection = ManualSelection(id: UUID(), path: ownedURL.path, hostBookmark: bookmark,
                                           transfer: try VSCodeSelection.transfer(ownedURL))
            let data = try PropertyListEncoder().encode(selection)
            try defaults().set(data, forKey: selectionKey)
            activeTransferURL?.stopAccessingSecurityScopedResource()
            activeTransferURL = ownedURL
            DistributedNotificationCenter.default().postNotificationName(selectionChanged, object: nil,
                                                                          userInfo: nil, deliverImmediately: true)
        } catch {
            ownedURL.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    @MainActor static func clearSelection() throws {
        let defaults = try defaults()
        defaults.removeObject(forKey: selectionKey)
        defaults.removeObject(forKey: "selectedVSCodeBookmark")
        defaults.removeObject(forKey: "selectedVSCodePath")
        activeTransferURL?.stopAccessingSecurityScopedResource()
        activeTransferURL = nil
        DistributedNotificationCenter.default().postNotificationName(selectionChanged, object: nil,
                                                                      userInfo: nil, deliverImmediately: true)
    }

    @MainActor static func transferIsPending() throws -> Bool {
        guard let selection = try manualSelection() else { return false }
        let acknowledged = try defaults().string(forKey: receiptKey) == selection.id.uuidString
        if acknowledged {
            activeTransferURL?.stopAccessingSecurityScopedResource()
            activeTransferURL = nil
        }
        return !acknowledged
    }

    // Called on extension startup and on change notification, while the sender is alive.
    static func receiveSelection() throws {
        let local = UserDefaults.standard
        guard let selection = try manualSelection() else {
            local.removeObject(forKey: recipientKey)
            return
        }
        if let data = local.data(forKey: recipientKey),
           let recipient = try? PropertyListDecoder().decode(RecipientSelection.self, from: data),
           recipient.id == selection.id {
            _ = try resolve(recipient.bookmark, originalPath: selection.path)
        } else {
            let bookmark = try VSCodeSelection.adopt(selection.transfer, originalPath: selection.path)
            _ = try resolve(bookmark, originalPath: selection.path)
            let recipient = RecipientSelection(id: selection.id, bookmark: bookmark)
            local.set(try PropertyListEncoder().encode(recipient), forKey: recipientKey)
        }
        try defaults().set(selection.id.uuidString, forKey: receiptKey)
    }

    @MainActor static func extensionApplication() throws -> URL {
        guard let selection = try manualSelection() else { return try application() }
        try receiveSelection()
        guard let data = UserDefaults.standard.data(forKey: recipientKey),
              let recipient = try? PropertyListDecoder().decode(RecipientSelection.self, from: data),
              recipient.id == selection.id else { throw VSCodeSelection.Failure.reselect }
        let selected = try resolve(recipient.bookmark, originalPath: selection.path)
        return try VSCodeSelection.launchURL(for: selected, registeredApplications:
            NSWorkspace.shared.urlsForApplications(withBundleIdentifier: "com.microsoft.VSCode"))
    }

    private static func resolve(_ bookmark: Data, originalPath: String) throws -> URL {
        let application = try VSCodeSelection.resolve(bookmark: bookmark, automaticallyDiscoveredURL: nil)
        guard application.path == originalPath else { throw VSCodeSelection.Failure.reselect }
        return application
    }
}
