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
        let discovered = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
        #expect(try VSCodeSelection.resolve(bookmark: nil, automaticallyDiscoveredURL: discovered) == discovered)
        #expect(throws: VSCodeSelection.Failure.reselect) {
            try VSCodeSelection.resolve(bookmark: Data([0, 1, 2]), automaticallyDiscoveredURL: discovered)
        }
        #expect(throws: VSCodeSelection.Failure.notFound) {
            try VSCodeSelection.resolve(bookmark: nil, automaticallyDiscoveredURL: nil)
        }
    }
}
