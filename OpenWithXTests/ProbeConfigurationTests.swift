import AppKit
import Testing
@testable import OpenWithX

@MainActor
struct ProbeConfigurationTests {
    @Test func manualCopyPersistsForHostAndRecipientAfterRecreation() throws {
        let fixture = try SelectionFixture()
        defer { fixture.remove() }
        let host = fixture.configuration()
        defer { try? host.clearSelection() }
        try host.selectApplication(fixture.selected)
        #expect(try host.application().path == fixture.selected.path)
        #expect(try host.authorizationStatus() == .pending)

        let recipient = fixture.configuration()
        try recipient.receiveSelection()
        #expect(try host.authorizationStatus() == .synchronized)
        #expect(try fixture.configuration().application().path == fixture.selected.path)
        #expect(try fixture.configuration().extensionApplication().path == fixture.selected.path)
    }
    @Test(arguments: ["com.microsoft.VSCodeInsiders", "com.example.Editor"])
    func rejectedToolDoesNotReplaceSavedOfficialCopy(identifier: String) throws {
        let fixture = try SelectionFixture()
        let unsupported = try SelectionFixture(identifier: identifier)
        defer { fixture.remove(); unsupported.remove() }
        let host = fixture.configuration()
        defer { try? host.clearSelection() }
        try host.selectApplication(fixture.selected)
        #expect(throws: VSCodeSelection.Failure.reselect) { try host.selectApplication(unsupported.selected) }
        #expect(try host.application().path == fixture.selected.path)
    }

    @Test func replacementNeedsNewAcknowledgementAndExplicitResetRestoresDiscovery() throws {
        let fixture = try SelectionFixture()
        defer { fixture.remove() }
        let host = fixture.configuration()
        defer { try? host.clearSelection() }
        try host.selectApplication(fixture.selected)
        try fixture.configuration().receiveSelection()
        #expect(try host.authorizationStatus() == .synchronized)
        try host.selectApplication(fixture.selected)
        #expect(try host.authorizationStatus() == .pending)
        try fixture.configuration().receiveSelection()
        #expect(try host.authorizationStatus() == .synchronized)
        try host.clearSelection()
        let restarted = fixture.configuration()
        try restarted.receiveSelection()
        #expect(try restarted.authorizationStatus() == .automatic)
        #expect(try restarted.extensionApplication().path == fixture.selected.path)
    }

    @Test(arguments: [false, true])
    func unavailableManualCopyRequiresReselectionEvenAfterAcknowledgement(deleted: Bool) throws {
        let fixture = try SelectionFixture()
        defer { fixture.remove() }
        let host = fixture.configuration()
        defer { try? host.clearSelection() }
        try host.selectApplication(fixture.selected)
        try fixture.configuration().receiveSelection()
        #expect(try host.authorizationStatus() == .synchronized)
        if deleted {
            try FileManager.default.removeItem(at: fixture.selected)
        } else {
            try FileManager.default.moveItem(at: fixture.selected,
                                            to: fixture.root.appendingPathComponent("Moved Code.app"))
        }
        #expect(throws: VSCodeSelection.Failure.reselect) { try host.application() }
        #expect(throws: VSCodeSelection.Failure.reselect) { try fixture.configuration().extensionApplication() }
        #expect(throws: VSCodeSelection.Failure.reselect) { try host.authorizationStatus() }
    }
}

private struct SelectionFixture {
    let root: URL
    let selected: URL
    let sharedName = "OpenWithX-selection-" + UUID().uuidString
    let recipientName = "OpenWithX-recipient-" + UUID().uuidString

    init(identifier: String = "com.microsoft.VSCode") throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        selected = root.appendingPathComponent("Selected Code.app")
        try TestApplication.create(at: selected, identifier: identifier)
    }

    func configuration() -> ProbeConfiguration {
        ProbeConfiguration(sharedDefaults: { UserDefaults(suiteName: sharedName)! },
                           localDefaults: UserDefaults(suiteName: recipientName)!,
                           discover: { selected }, registeredApplications: { [selected] })
    }

    func remove() {
        UserDefaults(suiteName: sharedName)?.removePersistentDomain(forName: sharedName)
        UserDefaults(suiteName: recipientName)?.removePersistentDomain(forName: recipientName)
        try? FileManager.default.removeItem(at: root)
    }
}
