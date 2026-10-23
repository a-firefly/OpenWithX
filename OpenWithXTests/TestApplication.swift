import Foundation

/// Minimal application metadata for selection tests; not a launchable or signed application.
enum TestApplication {
    static func create(at url: URL, identifier: String = "com.microsoft.VSCode") throws {
        let contents = url.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleIdentifier": identifier], format: .xml, options: 0)
        try info.write(to: contents.appendingPathComponent("Info.plist"))
    }
}
