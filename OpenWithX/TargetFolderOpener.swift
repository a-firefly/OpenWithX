import AppKit

/// Delivers a target folder to VS Code. Success means system acceptance, not editor loading.
@MainActor
struct TargetFolderOpener {
    private let application: @MainActor () throws -> URL
    private let runningApplications: @MainActor () -> [URL]
    private let submit: @MainActor ([URL], URL, NSWorkspace.OpenConfiguration, @escaping (Error?) -> Void) -> Void

    init(
        application: @escaping @MainActor () throws -> URL = { try ProbeConfiguration.extensionApplication() },
        runningApplications: @escaping @MainActor () -> [URL] = {
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.VSCode")
                .compactMap(\.bundleURL)
        },
        submit: @escaping @MainActor ([URL], URL, NSWorkspace.OpenConfiguration, @escaping (Error?) -> Void) -> Void = {
            urls, application, configuration, reply in
            NSWorkspace.shared.open(urls, withApplicationAt: application, configuration: configuration) { _, error in
                reply(error)
            }
        }
    ) {
        self.application = application
        self.runningApplications = runningApplications
        self.submit = submit
    }

    func open(_ folder: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            guard TargetFolderSelection.target(in: [folder]) != nil else {
                throw CocoaError(.fileNoSuchFile)
            }
            let selected = try application()
            try VSCodeSelection.checkRunningApplications(for: selected, runningApplications: runningApplications())
            let projectURL = try VSCodeProjectURL.make(for: folder)
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.allowsRunningApplicationSubstitution = false
            submit([projectURL], selected, configuration) { error in
                if let error { completion(.failure(error)) }
                else { completion(.success(())) }
            }
        } catch { completion(.failure(error)) }
    }
}
