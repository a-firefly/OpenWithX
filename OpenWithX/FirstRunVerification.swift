import Foundation
import Combine

/// A user attestation, separate from the system's extension-enabled flag.
@MainActor final class FirstRunVerification: ObservableObject {
    private let defaults: UserDefaults
    private let key = "finderManualVerification.applicationPath.v1"
    private var applicationPath: String?
    @Published private(set) var canConfirm = false
    @Published private(set) var isVerified = false

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func refresh(applicationPath: String?, extensionEnabled: Bool?, authorizationReady: Bool) {
        self.applicationPath = applicationPath
        canConfirm = applicationPath != nil && extensionEnabled == true && authorizationReady
        if !canConfirm || defaults.string(forKey: key) != applicationPath { invalidate() }
        isVerified = canConfirm && defaults.string(forKey: key) == applicationPath
    }

    func invalidate() {
        defaults.removeObject(forKey: key)
        isVerified = false
    }

    func confirm() {
        guard canConfirm, let applicationPath else { return }
        defaults.set(applicationPath, forKey: key)
        isVerified = true
    }
}
