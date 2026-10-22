import AppKit
import Testing
@testable import OpenWithX

@MainActor
struct TargetFolderOpenerTests {
    @Test func deliversTargetToSelectedVSCodeAndWaitsForSystemAcceptance() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("中文 Project/Nested #?&:42", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let application = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
        var systemReply: ((Error?) -> Void)?
        var outcome: Result<Void, Error>?
        let opener = TargetFolderOpener(application: { application }, runningApplications: { [] }) {
            urls, selectedApplication, configuration, reply in
            #expect(selectedApplication == application)
            #expect(urls.map(\.absoluteString) == [
                "vscode://file\(root.path)/%E4%B8%AD%E6%96%87%20Project/Nested%20%23%3F&:42/?windowId=_blank"
            ])
            #expect(configuration.activates)
            #expect(!configuration.createsNewApplicationInstance)
            #expect(!configuration.allowsRunningApplicationSubstitution)
            systemReply = reply
        }

        opener.open(folder) { outcome = $0 }
        #expect(outcome == nil)
        let reply = try #require(systemReply)
        reply(nil)
        guard case .success? = outcome else {
            Issue.record("System acceptance should complete the open request")
            return
        }
    }
    @Test func rejectsTargetRemovedBeforeDelivery() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.removeItem(at: folder)
        var outcome: Result<Void, Error>?
        let opener = TargetFolderOpener(application: {
            Issue.record("Invalid target should be rejected before application discovery")
            return URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
        }, runningApplications: { [] }) { _, _, _, _ in
            Issue.record("An unavailable target must not be submitted to the system")
        }
        opener.open(folder) { outcome = $0 }
        guard case .failure(let error)? = outcome else {
            Issue.record("An unavailable target should fail")
            return
        }
        #expect((error as NSError).domain == NSCocoaErrorDomain)
        #expect((error as NSError).code == CocoaError.fileNoSuchFile.rawValue)
    }

    @Test func preservesSystemRejection() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let rejection = NSError(domain: NSOSStatusErrorDomain, code: -54)
        var systemReply: ((Error?) -> Void)?
        var outcome: Result<Void, Error>?
        let opener = TargetFolderOpener(application: {
            URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
        }, runningApplications: { [] }) { _, _, _, reply in systemReply = reply }
        opener.open(folder) { outcome = $0 }
        let reply = try #require(systemReply)
        reply(rejection)
        guard case .failure(let error)? = outcome else {
            Issue.record("System rejection must fail the open request")
            return
        }
        #expect((error as NSError) === rejection)
    }

    @Test func reportsMissingVSCodeWithoutSubmitting() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var outcome: Result<Void, Error>?
        let opener = TargetFolderOpener(application: {
            throw VSCodeSelection.Failure.notFound
        }, runningApplications: { [] }) { _, _, _, _ in
            Issue.record("Missing VS Code must not submit an open request")
        }
        opener.open(folder) { outcome = $0 }
        guard case .failure(let error)? = outcome else {
            Issue.record("Missing VS Code should be reported to the caller")
            return
        }
        #expect(error as? VSCodeSelection.Failure == .notFound)
        // Eligibility is independent of application discovery, so the menu remains available.
        #expect(TargetFolderSelection.target(in: [folder]) == folder)
    }

}
