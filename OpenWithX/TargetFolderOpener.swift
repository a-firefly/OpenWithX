import AppKit

/// Delivers a target folder to VS Code. Success means system acceptance, not editor loading.
@MainActor
final class TargetFolderOpener {
    private var inFlight: [URL: UUID] = [:]
    private let application: @MainActor () throws -> URL
    private let runningApplications: @MainActor () -> [URL]
    private let submit: @MainActor ([URL], URL, NSWorkspace.OpenConfiguration, @escaping (Error?) -> Void) -> Void

    init(
        application: @escaping @MainActor () throws -> URL = { try ProbeConfiguration.shared.extensionApplication() },
        runningApplications: @escaping @MainActor () -> [URL] = {
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.VSCode")
                .compactMap(\.bundleURL)
        },
        submit: @escaping @MainActor ([URL], URL, NSWorkspace.OpenConfiguration, @escaping (Error?) -> Void) -> Void = {
            urls, application, configuration, reply in
            NSWorkspace.shared.open(urls, withApplicationAt: application, configuration: configuration) { _, error in
                Task { @MainActor in reply(error) }
            }
        }
    ) {
        self.application = application
        self.runningApplications = runningApplications
        self.submit = submit
    }

    func open(_ folder: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let key = folder.standardizedFileURL
        guard inFlight[key] == nil else { return }
        let id = UUID()
        inFlight[key] = id
        let finish: (Result<Void, Error>) -> Void = { [self] result in
            guard inFlight[key] == id else { return }
            inFlight.removeValue(forKey: key)
            completion(result)
        }
        do {
            try TargetFolderSelection.validate(folder)
            let selected = try application()
            try VSCodeSelection.checkRunningApplications(for: selected, runningApplications: runningApplications())
            let projectURL = try VSCodeProjectURL.make(for: folder)
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.addsToRecentItems = false
            configuration.allowsRunningApplicationSubstitution = false
            submit([projectURL], selected, configuration) { error in
                if let error { finish(.failure(error)) }
                else { finish(.success(())) }
            }
        } catch { finish(.failure(error)) }
    }
}
