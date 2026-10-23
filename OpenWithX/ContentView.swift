import SwiftUI
import Combine
import FinderSync
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var extensionEnabled: Bool?
    @State private var transferPending = false
    @State private var authorizationStatus = "未检测"
    @State private var applicationStatus = "未检测"
    private struct FailurePresentation {
        let message: String
        let detail: String

        init(message: String, detail: String) {
            self.message = message
            self.detail = detail
        }

        init(error: Error) {
            message = (error as? VSCodeSelection.Failure)?.errorDescription
                ?? "打开或配置失败，请检查 VS Code 选择及系统权限。"
            detail = String(describing: error)
        }
    }

    @State private var failure: FailurePresentation?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Text("OpenWithX").font(.title2)
            Text("在 Finder 中右击本地单个普通文件夹，使用 VS Code 在新窗口打开。")
            Text("VS Code：\(applicationStatus)")
            HStack {
                Button("重新检测", action: refresh)
                Button("手动选择正式版 VS Code", action: selectApplication)
                Button("恢复自动发现") {
                    do {
                        try ProbeConfiguration.shared.clearSelection()
                        failure = nil
                        refresh()
                    } catch { failure = FailurePresentation(error: error) }
                }
            }
            Link("下载正式版 VS Code（官方网站）", destination: URL(string: "https://code.visualstudio.com/download")!)
            Text("未手动选择时使用系统发现的正式版；手动选择后不会自动切换副本。")
            Text("系统扩展状态：\(extensionStatus)")
            Text("授权状态：\(authorizationStatus)")
            if transferPending {
                Text("正在等待扩展保存 VS Code 授权。请保持此窗口打开；启用扩展后若仍在等待，请重新选择 VS Code。")
            }
            Button("管理 Finder 扩展") {
                FIFinderSyncController.showExtensionManagementInterface()
            }
            Text("Finder 菜单与打开链路：尚未记录实测通过。系统已启用不代表实际菜单可用。")
            Text("无需选择项目目录。支持本地单个普通文件夹；云盘、网络卷和特殊位置尚未验证。")
            if let failure {
                Text(failure.message).foregroundStyle(.red)
                DisclosureGroup("原始错误（可能含本机路径）") {
                    Text(failure.detail).textSelection(.enabled)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 360)
        .onAppear(perform: refresh)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            refreshAuthorization()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onOpenURL { url in
            guard url.scheme == "openwithx-probe", url.host == "failure" else { return }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            failure = FailurePresentation(
                message: items?.first(where: { $0.name == "message" })?.value
                    ?? "打开失败，请检查 VS Code 选择及系统权限。",
                detail: items?.first(where: { $0.name == "detail" })?.value ?? "未知打开失败"
            )
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var extensionStatus: String {
        guard let extensionEnabled else { return "请先安装到“应用程序”后检测" }
        return extensionEnabled ? "已启用" : "未启用"
    }

    private func refresh() {
        // On the tested system, the native helper reports false for /private/tmp builds.
        // Do not turn an unsupported run location into a claim that the user disabled it.
        let installed = Bundle.main.bundleURL.resolvingSymlinksInPath().path.hasPrefix("/Applications/")
        extensionEnabled = installed ? FIFinderSyncController.isExtensionEnabled : nil
        refreshAuthorization()
        do { applicationStatus = try ProbeConfiguration.shared.application().path }
        catch VSCodeSelection.Failure.notFound { applicationStatus = "未发现正式版" }
        catch VSCodeSelection.Failure.reselect { applicationStatus = "指定副本失效，请重新选择" }
        catch { applicationStatus = "共享配置不可用"; failure = FailurePresentation(error: error) }
    }

    private func refreshAuthorization() {
        do {
            switch try ProbeConfiguration.shared.authorizationStatus() {
            case .automatic:
                transferPending = false
                authorizationStatus = "自动发现（未手动选择）"
            case .pending:
                transferPending = true
                authorizationStatus = "等待扩展保存授权"
            case .synchronized:
                transferPending = false
                authorizationStatus = "授权已同步（不代表打开成功）"
            }
        } catch {
            transferPending = false
            authorizationStatus = "读取失败，请重新选择 VS Code"
            failure = FailurePresentation(error: error)
        }
    }

    private func selectApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard Bundle(url: url)?.bundleIdentifier == "com.microsoft.VSCode" else {
                throw VSCodeSelection.Failure.reselect
            }
            try ProbeConfiguration.shared.selectApplication(url)
            failure = nil
            refresh()
        } catch { failure = FailurePresentation(error: error) }
    }
}
