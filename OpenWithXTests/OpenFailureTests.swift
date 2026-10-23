import Foundation
import Testing
@testable import OpenWithX

@MainActor
struct OpenFailureTests {
    @Test func explainsNativePermissionRejectionWithoutExposingPathsInSummary() {
        let native = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES),
                             userInfo: [NSFilePathErrorKey: "/private/example-project"])
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadUnknown.rawValue,
                              userInfo: [NSUnderlyingErrorKey: native])
        let failure = OpenFailure(error: wrapped)
        #expect(failure.reason == .accessDenied)
        #expect(failure.message.contains("访问被拒绝"))
        #expect(failure.recovery.contains("权限"))
        #expect(!failure.message.contains("/private/example-project"))
        #expect(!failure.recovery.contains("完全磁盘访问"))
        #expect(failure.detail.contains("NSPOSIXErrorDomain"))
    }
    @Test func distinguishesRecoverableFailuresFromUnknownErrors() {
        let cases: [(Error, OpenFailure.Reason, String)] = [
            (VSCodeSelection.Failure.notFound, .applicationMissing, "重新检测"),
            (VSCodeSelection.Failure.reselect, .applicationInvalid, "重新选择"),
            (VSCodeSelection.Failure.anotherCopyIsRunning, .copyConflict, "自行退出"),
            (CocoaError(.fileReadNoSuchFile), .targetUnavailable, "磁盘"),
            (NSError(domain: NSPOSIXErrorDomain, code: Int(ENODEV)), .diskUnavailable, "重新连接"),
            (NSError(domain: NSOSStatusErrorDomain, code: -10826), .accessDenied, "权限"),
            (NSError(domain: NSOSStatusErrorDomain, code: -10664), .systemRejected, "系统"),
            (NSError(domain: NSOSStatusErrorDomain, code: -10810), .systemRejected, "系统"),
            (NSError(domain: NSCocoaErrorDomain, code: CocoaError.executableNotLoadable.rawValue),
             .systemRejected, "系统"),
            (NSError(domain: "Unrecognized", code: 42), .unknown, "原始错误")
        ]
        for (error, reason, recovery) in cases {
            let failure = OpenFailure(error: error)
            #expect(failure.reason == reason)
            #expect(failure.recovery.contains(recovery))
        }
        #expect(OpenFailure(error: NSError(domain: "Unrecognized", code: -54)).reason == .unknown)
    }

    @Test func receivesEachFailureOnceAndKeepsDifferentRequestsUntilDismissed() throws {
        let inbox = OpenFailureInbox()
        let first = OpenFailure(error: CocoaError(.fileReadNoPermission))
        let second = OpenFailure(error: VSCodeSelection.Failure.reselect)
        let url = try #require(first.handoffURL)
        #expect(inbox.receive(url))
        #expect(!inbox.receive(url))
        #expect(inbox.current?.id == first.id)
        #expect(inbox.current?.reason == .accessDenied)
        #expect(inbox.current?.detail == first.detail)
        #expect(inbox.receive(try #require(second.handoffURL)))
        #expect(inbox.current?.id == first.id)
        inbox.dismiss()
        #expect(inbox.current?.id == second.id)
        inbox.dismiss()
        #expect(inbox.current == nil)
        #expect(!inbox.receive(url))
        #expect(!inbox.receive(URL(string: "openwithx-probe://failure?reason=accessDenied")!))
        #expect(!inbox.receive(URL(string: "https://failure")!))
        #expect(inbox.receive(try #require(OpenFailure(error: CocoaError(.fileReadNoPermission)).handoffURL)))
    }

}
