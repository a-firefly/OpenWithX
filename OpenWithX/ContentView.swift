import SwiftUI
import FinderSync
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var extensionEnabled = false
    @State private var applicationStatus = "未检测"
    @State private var failure: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Text("OpenWithX · Issue 01 验证原型").font(.title2)
            Text("本构建仅用于可行性实测，验证关卡尚未通过。")
            Text("VS Code：\(applicationStatus)")
            HStack {
                Button("重新检测", action: refresh)
                Button("手动选择正式版 VS Code", action: selectApplication)
                Button("恢复自动发现") {
                    do {
                        let defaults = try ProbeConfiguration.defaults()
                        defaults.removeObject(forKey: ProbeConfiguration.bookmarkKey)
                        defaults.removeObject(forKey: ProbeConfiguration.pathKey)
                        refresh()
                    } catch { failure = error.localizedDescription }
                }
            }
            Text("系统扩展状态：\(extensionEnabled ? "已启用" : "未启用")")
            Button("管理 Finder 扩展") {
                FIFinderSyncController.showExtensionManagementInterface()
            }
            Text("Finder 菜单与打开链路：尚未记录实测通过。系统已启用不代表实际菜单可用。")
            Text("无需选择项目目录。仅验证本地单个普通文件夹；云盘、网络卷和特殊位置尚未验证。")
            if let failure {
                Text("打开或配置失败，请检查 VS Code 选择及系统权限。").foregroundStyle(.red)
                DisclosureGroup("原始错误（可能含本机路径）") {
                    Text(failure).textSelection(.enabled)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 360)
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onOpenURL { url in
            guard url.scheme == "openwithx-probe", url.host == "failure" else { return }
            failure = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "detail" })?.value ?? "未知打开失败"
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func refresh() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
        do { applicationStatus = try ProbeConfiguration.application().lastPathComponent }
        catch VSCodeSelection.Failure.notFound { applicationStatus = "未发现正式版" }
        catch VSCodeSelection.Failure.reselect { applicationStatus = "指定副本失效，请重新选择" }
        catch { applicationStatus = "共享配置不可用"; failure = error.localizedDescription }
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
            let bookmark = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                                includingResourceValuesForKeys: nil, relativeTo: nil)
            let defaults = try ProbeConfiguration.defaults()
            defaults.set(bookmark, forKey: ProbeConfiguration.bookmarkKey)
            defaults.set(url.path, forKey: ProbeConfiguration.pathKey)
            failure = nil
            refresh()
        } catch { failure = String(describing: error) }
    }
}
