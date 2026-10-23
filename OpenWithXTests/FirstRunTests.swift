import Foundation
import Testing
@testable import OpenWithX

@MainActor struct FirstRunTests {
    @Test func enablingExtensionDoesNotVerifyFinderAndConfirmationSurvivesRelaunch() throws {
        let name = "FirstRunTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let setup = FirstRunVerification(defaults: defaults)
        setup.refresh(applicationPath: "/Applications/Code.app", extensionEnabled: true, authorizationReady: true)
        #expect(!setup.isVerified)
        setup.confirm()
        #expect(setup.isVerified)
        let relaunched = FirstRunVerification(defaults: defaults)
        relaunched.refresh(applicationPath: "/Applications/Code.app", extensionEnabled: true, authorizationReady: true)
        #expect(relaunched.isVerified)
    }
    @Test func disabledExtensionChangedApplicationAndFailuresRequireFreshConfirmation() throws {
        let name = "FirstRunTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let setup = FirstRunVerification(defaults: defaults)
        setup.refresh(applicationPath: "/A.app", extensionEnabled: true, authorizationReady: true)
        setup.confirm()
        setup.refresh(applicationPath: "/A.app", extensionEnabled: false, authorizationReady: true)
        setup.refresh(applicationPath: "/A.app", extensionEnabled: true, authorizationReady: true)
        #expect(!setup.isVerified)
        setup.confirm()
        setup.refresh(applicationPath: "/B.app", extensionEnabled: true, authorizationReady: true)
        #expect(!setup.isVerified)
        setup.confirm()
        setup.invalidate()
        #expect(!setup.isVerified)
        setup.refresh(applicationPath: "/B.app", extensionEnabled: true, authorizationReady: false)
        setup.confirm()
        #expect(!setup.canConfirm)
        #expect(!setup.isVerified)
    }

}
