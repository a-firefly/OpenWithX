import SwiftUI
import Combine
import FinderSync
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var extensionEnabled: Bool?
    @State private var transferPending = false
    @State private var authorizationReady = false
    @State private var applicationPath: String?
    @State private var authorizationStatus = AppText.text("Not checked", "未检测")
    @State private var applicationStatus = AppText.text("Not checked", "未检测")
    @StateObject private var verification = FirstRunVerification()
    @ObservedObject var failureInbox: OpenFailureInbox
    @State private var configurationFailure: OpenFailure?
    private var failure: OpenFailure? { failureInbox.current ?? configurationFailure }
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Form {
                    Text("OpenWithX").font(.title2)
                    Text(AppText.text("Open a single local folder from Finder in a new VS Code window.",
                                      "在 Finder 中右击本地单个普通文件夹，使用 VS Code 在新窗口打开。"))
                    if let failure {
                        Section(AppText.text("Resolve an open failure", "处理打开失败")) {
                            Text(failure.message).foregroundStyle(.red)
                            Text(failure.recovery)
                            DisclosureGroup(AppText.text("Original error (may contain local paths)", "原始错误（可能含本机路径）")) {
                                Text(failure.detail).textSelection(.enabled)
                            }
                            .id(failure.id)
                            Button(AppText.text("Dismiss this message", "关闭此提示")) {
                                if failureInbox.current != nil { failureInbox.dismiss() }
                                else { configurationFailure = nil }
                            }
                        }
                        .id("openFailure")
                    }
                    Section(AppText.text("1. Find VS Code", "1. 检测 VS Code")) {
                        LabeledContent("VS Code", value: applicationStatus)
                        HStack {
                            Button(AppText.text("Detect again", "重新检测"), action: refresh)
                            Button(AppText.text("Select stable VS Code…", "手动选择正式版 VS Code"), action: selectApplication)
                            Button(AppText.text("Use automatic discovery", "恢复自动发现")) {
                                do {
                                    try ProbeConfiguration.shared.clearSelection()
                                    verification.invalidate()
                                    configurationFailure = nil
                                    refresh()
                                } catch { reportConfigurationFailure(error) }
                            }
                        }
                        Link(AppText.text("Download stable VS Code (official website)", "下载正式版 VS Code（官方网站）"),
                             destination: URL(string: "https://code.visualstudio.com/download")!)
                        Text(AppText.text("Automatic discovery uses the system's stable version. A manually selected copy is never replaced automatically.",
                                          "未手动选择时使用系统发现的正式版；手动选择后不会自动切换副本。"))
                        LabeledContent(AppText.text("Application authorization", "应用授权"), value: authorizationStatus)
                        if transferPending {
                            Text(AppText.text("Keep this window open while the extension saves VS Code authorization. If it still waits after enabling the extension, select VS Code again.",
                                              "正在等待扩展保存 VS Code 授权。请保持此窗口打开；启用扩展后若仍在等待，请重新选择 VS Code。"))
                        }
                    }
                    Section(AppText.text("2. Enable the Finder extension", "2. 启用 Finder 扩展")) {
                        LabeledContent(AppText.text("System extension status", "系统扩展状态"), value: extensionStatus)
                        Text(AppText.text("In System Settings → General → Login Items & Extensions, find OpenWithX under Extensions and enable it. In category view on macOS 26, it may appear under File Providers. Return here to refresh the status.",
                                          "在“系统设置 → 通用 → 登录项与扩展”的“扩展”中找到 OpenWithX 并手动启用；macOS 26 按类别查看时可能位于“文件提供程序”。再回到这里刷新状态。"))
                        Button(AppText.text("Manage Finder extensions", "管理 Finder 扩展")) {
                            FIFinderSyncController.showExtensionManagementInterface()
                        }
                        Text(AppText.text("If it is missing, install OpenWithX in Applications and open it there. An enabled extension does not prove the menu works.",
                                          "若未找到，请先将 OpenWithX 安装到“应用程序”并从那里打开。系统已启用不代表实际菜单可用。"))
                    }
                    Section(AppText.text("3. Verify manually in Finder", "3. 在 Finder 中手动验证")) {
                        Text(verification.isVerified
                             ? AppText.text("User confirmed: Finder menu and opening worked for this configuration.", "用户已确认：当前配置的 Finder 菜单与打开链路验证通过。")
                             : AppText.text("Not verified: complete a real Finder open before confirming below.", "尚未验证：请完成一次真实 Finder 打开后再确认。"))
                        Text(AppText.text("In Finder, right-click one ordinary folder on a local disk. Choose “Open in VS Code” and check that the correct folder opens in a new window of the intended VS Code copy. Then return here to confirm. No folder selection in this app is needed.",
                                          "请在 Finder 中右击本地磁盘上的单个普通文件夹，选择“使用 VS Code 打开”，确认指定 VS Code 副本在新窗口打开了正确文件夹，再返回这里确认。本应用无需选择项目目录。"))
                        HStack {
                            Button(AppText.text("I verified the Finder open", "我已在 Finder 中验证打开")) { verification.confirm() }
                                .disabled(!verification.canConfirm || failure != nil)
                            Button(AppText.text("Verify again / troubleshoot", "重新验证／排查问题")) { verification.invalidate() }
                        }
                        Text(AppText.text("If the menu is missing, check the extension and folder type. For an open failure, follow the recovery advice in the failure message, fix the cause, and retry manually in Finder.",
                                          "若菜单未出现，请检查扩展状态和文件夹类型；若打开失败，请按失败提示中的恢复指引处理原因，再手动从 Finder 重试。"))
                    }
                    Section(AppText.text("Support and daily use", "支持范围与日常使用")) {
                        Text(AppText.text("Supports one ordinary folder on an internal or mounted local disk. Files, multiple items, app bundles, aliases, and symbolic links are excluded. Network disks, cloud storage, and special Finder locations are not promised.",
                                          "支持内置或已挂载本地磁盘上的单个普通文件夹；不支持文件、多选、应用包、替身和符号链接。云盘、网络卷和特殊 Finder 位置暂不承诺支持。"))
                        Text(AppText.text("After verification, you can quit OpenWithX. No Dock or menu bar app needs to stay running. Reopen this app for configuration or troubleshooting; failed opens may bring it forward. An accepted request does not mean VS Code has finished loading.",
                                          "验证完成后可以退出 OpenWithX，无需常驻 Dock 或菜单栏。需要配置或排障时重新打开；打开失败时可能唤起本应用。系统接受请求不代表 VS Code 已完成加载。"))
                        Button(AppText.text("Quit OpenWithX", "退出 OpenWithX")) { NSApp.terminate(nil) }
                    }

                }
                .formStyle(.grouped)
                .padding(12)
            }
            .frame(minWidth: 720, minHeight: 740)
            .onAppear {
                refresh()
                if failure != nil { verification.invalidate() }
            }
            .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
            .onChange(of: failure?.id) { _, id in
                if id != nil {
                    verification.invalidate()
                    proxy.scrollTo("openFailure", anchor: .top)
                }
            }
            .onOpenURL { url in
                guard OpenFailure(handoffURL: url) != nil else { return }
                verification.invalidate()
                failureInbox.receive(url)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private var extensionStatus: String {
        guard let extensionEnabled else { return AppText.text("Install in Applications to check", "请先安装到“应用程序”后检测") }
        return extensionEnabled ? AppText.text("Enabled", "已启用") : AppText.text("Disabled", "未启用")
    }

    private func refresh() {
        // The native helper reports false for /private/tmp builds on the tested system.
        let installed = Bundle.main.bundleURL.resolvingSymlinksInPath().path.hasPrefix("/Applications/")
        extensionEnabled = installed ? FIFinderSyncController.isExtensionEnabled : nil
        applicationPath = nil
        do {
            let path = try ProbeConfiguration.shared.application().path
            applicationPath = path
            applicationStatus = path
        }
        catch VSCodeSelection.Failure.notFound { applicationStatus = AppText.text("Stable version not found", "未发现正式版") }
        catch VSCodeSelection.Failure.reselect { applicationStatus = AppText.text("Selected copy is invalid; select again", "指定副本失效，请重新选择") }
        catch {
            applicationStatus = AppText.text("Shared configuration unavailable; select VS Code again", "共享配置不可用，请重新选择 VS Code")
        }
        refreshAuthorization()
        verification.refresh(applicationPath: applicationPath, extensionEnabled: extensionEnabled,
                             authorizationReady: authorizationReady)
    }

    private func refreshAuthorization() {
        authorizationReady = false
        transferPending = false
        do {
            switch try ProbeConfiguration.shared.authorizationStatus() {
            case .automatic:
                authorizationReady = true
                authorizationStatus = AppText.text("Automatic discovery (no manual selection)", "自动发现（未手动选择）")
            case .pending:
                transferPending = true
                authorizationStatus = AppText.text("Waiting for extension authorization", "等待扩展保存授权")
            case .synchronized:
                authorizationReady = true
                authorizationStatus = AppText.text("Authorization synchronized (opening not verified)", "授权已同步（不代表打开成功）")
            }
        } catch {
            authorizationStatus = AppText.text("Cannot read authorization; select VS Code again", "读取失败，请重新选择 VS Code")
        }
    }

    private func reportConfigurationFailure(_ error: Error) {
        verification.invalidate()
        configurationFailure = OpenFailure(error: error)
        refresh()
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
            verification.invalidate()
            configurationFailure = nil
            refresh()
        } catch { reportConfigurationFailure(error) }
    }
}
