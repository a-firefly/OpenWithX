import Foundation
import Testing
@testable import OpenWithX

struct OpenWithXTests {
    @Test func onlySingleOrdinaryTargetFolderIsEligible() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("中文 Project")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let file = root.appendingPathComponent("file.txt")
        try Data().write(to: file)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)
        let package = root.appendingPathComponent("Example.app")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: false)
        let alias = root.appendingPathComponent("Alias")
        try URL.writeBookmarkData(folder.bookmarkData(options: .suitableForBookmarkFile), to: alias)

        #expect(TargetFolderSelection.target(in: [folder]) == folder)
        for selection in [[], [file], [link], [package], [alias], [folder, root], [root.appendingPathComponent("missing")]] {
            #expect(TargetFolderSelection.target(in: selection) == nil)
        }
    }
    @Test func coverageIncludesOnlyKnownLocalVolumes() {
        let internalDisk = URL(fileURLWithPath: "/")
        let externalDisk = URL(fileURLWithPath: "/Volumes/本地 Disk")
        let network = URL(fileURLWithPath: "/Volumes/Network")
        let unknown = URL(fileURLWithPath: "/Volumes/Unknown")
        #expect(LocalVolumeCoverage.roots(from: [
            .init(url: internalDisk, isLocal: true),
            .init(url: externalDisk, isLocal: true),
            .init(url: network, isLocal: false),
            .init(url: unknown, isLocal: nil)
        ]) == Set([internalDisk, externalDisk]))
        #expect(LocalVolumeCoverage.roots(from: []) == [])
    }
    @Test func invalidManualVSCodeSelectionDoesNotFallBackToDiscovery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let discovered = root.appendingPathComponent("Code.app")
        defer { try? FileManager.default.removeItem(at: root) }
        try TestApplication.create(at: discovered)
        #expect(try VSCodeSelection.resolve(bookmark: nil, automaticallyDiscoveredURL: discovered) == discovered)
        #expect(throws: VSCodeSelection.Failure.reselect) {
            try VSCodeSelection.resolve(bookmark: Data([0, 1, 2]), automaticallyDiscoveredURL: discovered)
        }
        #expect(throws: VSCodeSelection.Failure.notFound) {
            try VSCodeSelection.resolve(bookmark: nil, automaticallyDiscoveredURL: nil)
        }
    }
    @Test func discoveryRejectsUnavailableOrUnsupportedApplications() throws {
        #expect(throws: VSCodeSelection.Failure.notFound) {
            try VSCodeSelection.resolve(bookmark: nil, automaticallyDiscoveredURL:
                URL(fileURLWithPath: "/missing/Visual Studio Code.app"))
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for identifier in ["com.microsoft.VSCodeInsiders", "com.example.Editor"] {
            let application = root.appendingPathComponent(identifier + ".app")
            try TestApplication.create(at: application, identifier: identifier)
            #expect(throws: VSCodeSelection.Failure.notFound) {
                try VSCodeSelection.resolve(bookmark: nil, automaticallyDiscoveredURL: application)
            }
        }
    }

    @Test func transferredApplicationGetsARecipientOwnedBookmark() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let application = root.appendingPathComponent("Selected Code.app", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try TestApplication.create(at: application)
        let transfer = try VSCodeSelection.transfer(application)
        let recipientBookmark = try VSCodeSelection.adopt(transfer, originalPath: application.path)
        #expect(try VSCodeSelection.resolve(bookmark: recipientBookmark, automaticallyDiscoveredURL: nil) == application)
        #expect(throws: VSCodeSelection.Failure.reselect) {
            try VSCodeSelection.adopt(transfer, originalPath: "/a/different/Selected Code.app")
        }
    }
    @Test func manualSelectionUsesOnlyItsMatchingSystemApplicationURL() throws {
        let chosen = URL(fileURLWithPath: "/Applications/Selected/Visual Studio Code.app", isDirectory: true)
        let other = URL(fileURLWithPath: "/Applications/Other/Visual Studio Code.app", isDirectory: true)
        #expect(try VSCodeSelection.launchURL(for: chosen, registeredApplications: [other, chosen]) == chosen)
        #expect(throws: VSCodeSelection.Failure.reselect) {
            try VSCodeSelection.launchURL(for: chosen, registeredApplications: [other])
        }
    }
    @Test func selectedCopyMustNotBeSilentlyReplacedByAnotherRunningCopy() throws {
        let selected = URL(fileURLWithPath: "/Users/test/Selected Code.app", isDirectory: true)
        let other = URL(fileURLWithPath: "/Applications/Visual Studio Code.app", isDirectory: true)
        try VSCodeSelection.checkRunningApplications(for: selected, runningApplications: [])
        try VSCodeSelection.checkRunningApplications(for: selected, runningApplications: [selected])
        try VSCodeSelection.checkRunningApplications(for: selected, runningApplications: [other, selected])
        #expect(throws: VSCodeSelection.Failure.anotherCopyIsRunning) {
            try VSCodeSelection.checkRunningApplications(for: selected, runningApplications: [other])
        }
    }

}
