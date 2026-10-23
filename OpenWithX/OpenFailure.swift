import Foundation
import CoreServices

/// Transient, local error data. Never persisted as an opening history or logged with paths.
nonisolated struct OpenFailure: Identifiable {
    enum Reason: String {
        case accessDenied, applicationMissing, applicationInvalid, copyConflict
        case targetUnavailable, diskUnavailable, systemRejected, unknown
    }

    let id: UUID
    let reason: Reason
    let detail: String

    init(error: Error, id: UUID = UUID()) {
        self.id = id
        if let selection = error as? VSCodeSelection.Failure {
            reason = switch selection {
            case .notFound: .applicationMissing
            case .reselect: .applicationInvalid
            case .anotherCopyIsRunning: .copyConflict
            }
        } else {
            reason = Self.classify(error as NSError)
        }
        detail = String(describing: error as NSError)
    }

    var handoffURL: URL? {
        var components = URLComponents()
        components.scheme = "openwithx-probe"
        components.host = "failure"
        components.queryItems = [
            URLQueryItem(name: "id", value: id.uuidString),
            URLQueryItem(name: "reason", value: reason.rawValue),
            URLQueryItem(name: "detail", value: detail)
        ]
        return components.url
    }

    init?(handoffURL url: URL) {
        guard url.scheme == "openwithx-probe", url.host == "failure",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let identifier = items.first(where: { $0.name == "id" })?.value,
              let id = UUID(uuidString: identifier),
              let rawReason = items.first(where: { $0.name == "reason" })?.value,
              let reason = Reason(rawValue: rawReason),
              let detail = items.first(where: { $0.name == "detail" })?.value else { return nil }
        self.id = id
        self.reason = reason
        self.detail = detail
    }

    private static func classify(_ error: NSError, depth: Int = 0) -> Reason {
        guard depth < 8 else { return .unknown }
        if (error.domain == NSCocoaErrorDomain &&
            [CocoaError.fileReadNoPermission.rawValue, CocoaError.fileWriteNoPermission.rawValue].contains(error.code))
            || (error.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains(error.code))
            || (error.domain == NSOSStatusErrorDomain && [Int(permErr), Int(kLSNoLaunchPermissionErr)].contains(error.code)) {
            return .accessDenied
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            let reason = classify(underlying, depth: depth + 1)
            if reason != .unknown { return reason }
        }
        if error.domain == NSPOSIXErrorDomain {
            if [Int(ENODEV), Int(ENXIO)].contains(error.code) { return .diskUnavailable }
            if [Int(ENOENT), Int(ENOTDIR)].contains(error.code) { return .targetUnavailable }
        }
        if error.domain == NSCocoaErrorDomain {
            if [CocoaError.fileNoSuchFile.rawValue, CocoaError.fileReadNoSuchFile.rawValue].contains(error.code) {
                return .targetUnavailable
            }
            if (3584...3839).contains(error.code) { return .systemRejected }
        }
        // Launch Services errors; unrelated OSStatus codes remain unknown.
        if error.domain == NSOSStatusErrorDomain && [
            kLSUnknownErr, kLSNotAnApplicationErr, kLSApplicationNotFoundErr,
            kLSLaunchInProgressErr, kLSAppDoesNotClaimTypeErr, kLSServerCommunicationErr,
            kLSIncompatibleSystemVersionErr, kLSNoExecutableErr, kLSMultipleSessionsNotSupportedErr,
            kLSAppInTrashErr, kLSIncompatibleApplicationVersionErr, kLSNo32BitEnvironmentErr
        ].map({ Int($0) }).contains(error.code) { return .systemRejected }
        return .unknown
    }

    var message: String {
        switch reason {
        case .accessDenied: "访问被拒绝，未能完成打开请求。"
        case .applicationMissing: "未发现正式版 VS Code。"
        case .applicationInvalid: "所选 VS Code 副本或授权已失效。"
        case .copyConflict: "另一个 VS Code 副本正在运行，无法可靠地交给所选副本。"
        case .targetUnavailable: "目标文件夹不可用，可能已移动、删除或磁盘已断开。"
        case .diskUnavailable: "目标所在磁盘不可用或已断开。"
        case .systemRejected: "系统拒绝启动应用或打开请求。"
        case .unknown: "打开失败，暂时无法识别原因。"
        }
    }

    var recovery: String {
        switch reason {
        case .accessDenied: "请检查目标文件夹和所选 VS Code 的实际访问权限及系统隐私设置；应用授权失效时重新选择 VS Code，解决后在 Finder 中重试。"
        case .applicationMissing: "请重新检测、手动选择正式版 VS Code，或主动访问下方官方网站下载。"
        case .applicationInvalid: "请重新选择正式版 VS Code；不会自动切换到其他副本。"
        case .copyConflict: "请重新选择正在使用的副本，或自行退出其他副本后在 Finder 中重试。"
        case .targetUnavailable: "请在 Finder 中检查目标是否存在及磁盘是否已连接，再从当前位置重试。"
        case .diskUnavailable: "请检查并重新连接目标磁盘，确认目标文件夹可用后在 Finder 中重试。"
        case .systemRejected: "请检查所选 VS Code 能否由系统正常启动，展开原始错误排查系统限制；必要时重新选择应用后在 Finder 中重试。"
        case .unknown: "请展开原始错误，检查目标文件夹、磁盘及 VS Code 选择，解决后在 Finder 中重试。"
        }
    }
}
