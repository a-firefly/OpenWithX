# Issue 01 首轮验证报告

日期：2026-10-22（Asia/Shanghai）。结论：**关卡未通过，issue 02–07 继续等待 01**。

当前原型已验证一级菜单与失败交接，但未完成成功打开链路。以下失败仅证明本次构建和运行条件下的结果，不能推导 Finder Sync 路线在所有条件下不可行。不得自行扩大目录授权、关闭沙盒、恢复父目录配置或降级菜单。

## 环境与构建

| 项目 | 本次实测 |
| --- | --- |
| 系统 | macOS 26.7，build 25G229，arm64 |
| 最低系统 | 工程 Debug/Release 与测试目标已从 26.7 改为 26.0；**没有 26.0 实机运行证据** |
| 工具链 | Xcode 27.0，build 27A266a，macOS 27.0 SDK |
| 开发工具 | `/Applications/Visual Studio Code.app`，1.143.0，`com.microsoft.VSCode` |
| 构建 | Debug，arm64，Apple Development 签名，TeamIdentifier `RR2LFYZJUK`，Hardened Runtime |
| 运行位置 | `/private/tmp/OpenWithX-issue01-probe/Build/Products/Debug/OpenWithX.app`；不是正式安装或发布构建 |
| 扩展 | `com.point.OpenWithX.FinderProbe`，内嵌 `Contents/PlugIns/FinderProbe.appex` |
| 本地卷 | 扩展启动诊断登记 2 个本地卷；有外接物理 APFS 磁盘；**不等于证明两卷菜单全覆盖** |
| 权限 | 两个已签名产物均含 app-sandbox、user-selected.read-only、bookmarks.app-scope 及同一 App Group；Debug 含 get-task-allow |

本轮未选择项目目录或磁盘根目录，未新增管理员、辅助功能或完全磁盘访问授权；仅在主应用中选择 VS Code 应用包。没有读取项目内容或修改项目。宿主机器既有 TCC 授权未独立审计，不能声称完成干净权限环境验证。UI 自动化由开发工具执行，产品代码不包含自动化或辅助功能逻辑。

最初受代理执行沙盒影响，钥匙串显示 0 个身份、diskutil 不可用，Swift 宏进程无法启动；沙盒外重试后开发签名、磁盘查询、编译和有签名测试均可运行。这些不是产品沙盒能力结论。`CODE_SIGNING_ALLOWED=NO` 的基线完整测试曾因 UI runner 被终止而失败；最终采用有签名构建，未关闭产品沙盒。

## 原型位置与边界

- `FinderProbe/FinderSync.swift`：启动时登记本地卷，监听挂载/卸载/卷重命名；只为 item 菜单提供一级入口，重新检查选中目标，再调用 NSWorkspace。失败用原生打开 API 将 URL 交给包含它的主应用。
- `OpenWithX/ProbePolicy.swift`：普通目标文件夹筛选、本地卷集合、VS Code 选择恢复。
- `OpenWithX/ProbeConfiguration.swift`：共享 App Group 中保存应用书签和所选路径；路径仅用于判定副本移动，**不作为授权**。
- `OpenWithX/ContentView.swift`：应用发现、应用包选择、原生扩展管理入口、API 状态和可展开错误。明确标注验证原型及未实测通过。
- `Validation/`：显式沙盒授权及 host/extension Info.plist。主应用不再启动模板 SwiftData 数据库。

该原型不是 issue 02–06 的正式实现。错误去重、并发合并、完整本地化、生产级配置恢复均不在本轮交付范围。应用书签仍使用 app-scope，尚未证明可跨进程共享；不把 App Group、监控根或路径字符串当作文件授权。未增加第三方依赖。

## 可复现步骤

开发者执行（仅构建/收集证据；普通用户产品流程不需要终端）：

```sh
xcodebuild -project OpenWithX.xcodeproj -scheme OpenWithX -configuration Debug \
  -derivedDataPath /tmp/OpenWithX-issue01-probe build
mkdir -p '/tmp/OpenWithX-FinderProbe/中文 Project/Nested'
touch /tmp/OpenWithX-FinderProbe/file.txt
mkdir -p /tmp/OpenWithX-FinderProbe/Example.app
ln -s '中文 Project' /tmp/OpenWithX-FinderProbe/FolderLink
```

夹具路径应使用新的空目录；重复执行时跳过已存在的符号链接。随后：

1. 打开上述构建产物；确认能发现正式版 VS Code。不要选择项目父目录。
2. 点击“管理 Finder 扩展”。本机原生入口定位到系统设置 → 通用 → 登录项与扩展 → 文件提供程序，显示 OpenWithX 开关。开启 OpenWithX；本机 WPS Office 与微信输入法开关原本为 on，未关闭它们。
3. Finder 前往 `/tmp/OpenWithX-FinderProbe`，右击“中文 Project”。预期出现一级“使用 VS Code 打开”；实际出现，另有既存“快速操作”中的“使用 VSCode 打开”，两者不可混淆。
4. 点击**一级**入口。预期 NSWorkspace 接受请求并激活正确 VS Code，主应用不显示成功提示；实际失败并激活主应用。
5. 展开主应用错误；记录下述 Cocoa/OSStatus 错误。点击“手动选择正式版 VS Code”，选择上述应用包并保存。再次从 Finder 点击一级入口；实际为 `reselect`。
6. 退出主应用，再次在 Finder 操作。菜单仍出现；失败后主应用自动启动并显示错误。
7. 分别右击 `file.txt`、`Example.app`、`FolderLink`。通过 Finder 对“中文 Project”执行“制作替身”，再右击新替身；本次这些菜单均无一级“使用 VS Code 打开”。

本次通过系统设置启用了验证扩展，并保留该状态以供复现。恢复时在同一系统设置页面关闭 OpenWithX；主应用中“恢复自动发现”会移除验证用手动应用选择。主应用可以直接退出。未卸载磁盘或重启系统。

## 实测证据

以下为 UI 与原型自身日志的转录；完整本机日志不包含在产品中。日志摘录见 [evidence.txt](evidence.txt)。

| 时间（本地） | 预期 | 实际与判定 |
| --- | --- | --- |
| 12:25–12:26 | 原生入口可管理扩展 | 系统设置列出 OpenWithX，开关 off → on；pluginkit 登记为 `+`；入口在本机有效 |
| 12:26:10 | 无目录配置登记范围 | `Registered local volume count: 2`；只证明登记发生，不证明授权/全范围覆盖 |
| 12:27 | 本地普通文件夹一级菜单 | Finder 的 `executePlugInCommand:` 为“使用 VS Code 打开”；**此夹具菜单通过** |
| 12:27:28 | 自动发现后原生成功打开 | 主应用展示 `NSCocoaErrorDomain Code=256`，底层 `NSOSStatusErrorDomain Code=-54`（permErr）；**失败** |
| 12:28 | 手动应用授权在扩展中可用 | 主应用选择/保存成功，扩展点击后显示 `reselect`；**失败** |
| 12:29:36、12:31:54 | 主应用可恢复手动选择 | 主应用日志 `stale=false, scopedAccess=true, matchesVSCode=true, exists=true`；只证明主应用可用 |
| 12:31:53 | 主应用退出后扩展恢复选择并打开 | 新扩展进程解析手动书签失败：`NSCocoaErrorDomain code=259`；错误交给新主应用进程 78120；**打开失败，启动交接通过** |
| 12:30–12:31 | 非支持对象隐藏入口 | 普通文件、空 `.app` 包、符号链接、Finder 创建的真实替身均隐藏；不把伪包夹具当作所有包类型的穷尽验证 |
| 开启后多次刷新 | 启用状态可靠 | 主应用 `isExtensionEnabled` 报告 false，系统开关 on 且实际菜单出现；**不一致，可靠检测未通过** |

12:29 前后构建/测试导致扩展进程发生重建，日志记录新的初始化与 2 个卷登记。但没有可控冷启动全流程、跨系统重启或首次安装证据，不能把它们算作生命周期通过。

## 验收矩阵与剩余关卡

| Issue 01 条件 | 本次结论 |
| --- | --- |
| 两端沙盒、无项目目录授权 | 签名产物核验通过；干净 TCC 环境待测 |
| 26 系列一级菜单、正确 URL、成功原生打开 | 26.7 夹具一级菜单通过；正确目标交付未证明，成功打开失败；26.0 未测 |
| 不同内置位置、嵌套、中文空格 | 中文空格夹具菜单已测，打开失败；其他位置与嵌套未完成 UI 实测 |
| 外接卷挂载/卸载/重新挂载 | 有设备且原型登记本地卷；循环未测。工作仓库就在外接磁盘上，不在活动会话中卸载它 |
| 文件/多选/包/替身/链接/空白处 | 真实 Finder 已测文件、包、替身、链接；多选和空白处仅代码限制，UI 未验证 |
| 主应用退出、扩展冷启动、系统重启 | 主应用退出后菜单与失败启动交接已测；冷启动、重启及成功路径未通过 |
| 应用授权持久化、跨进程使用、副本失效恢复 | 主应用跨重启恢复可用；扩展解析失败；实际移动/删除副本未测，不移动用户的 VS Code 来模拟 |
| 失败自动启动/激活主应用 | 两种状态均观察到错误界面；未穷尽错误/重复事件；没有让扩展弹窗 |
| 可靠启用检测与引导 | 原生入口有效；API 状态不一致，可靠检测失败；实际菜单状态保持未通过 |
| 桌面/文稿、扩展共存 | 既有其他扩展开启时本夹具菜单可见；未穷尽重叠范围、受保护位置或拒绝权限行为 |
| 云盘/网络卷/虚拟位置 | 未测，不承诺支持 |
| 完整通过结论 | **不通过**。没有任何完整核心成功打开证据 |

## 自动验证

用户确认的三个公开测试边界各完成先编译失败、再最小实现通过：

1. `onlySingleOrdinaryTargetFolderIsEligible`：真实临时文件系统与 Finder bookmark-file 替身。通过筛选函数验证对象排除；不证明扩展沙盒有相同元数据权限。
2. `coverageIncludesOnlyKnownLocalVolumes`：固定已知本地、远程与未知卷事实，未知和远程排除；空集合不保留已卸载卷。不证明系统挂载通知或 Finder 覆盖。
3. `invalidManualVSCodeSelectionDoesNotFallBackToDiscovery`：损坏的手动书签必须要求重选，发现缺失时报未发现；不证明真实应用授权的跨进程能力。

最终有签名完整套件通过：3 个 Swift Testing 测试 + 2 个现有 UI 模板测试，0 失败。现有 UI 测试只检查启动和启动性能，不覆盖 Finder。

```sh
xcodebuild -project OpenWithX.xcodeproj -scheme OpenWithX -configuration Debug \
  -derivedDataPath /tmp/OpenWithX-issue01-probe \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 30 test
```

本机结果包：`/tmp/OpenWithX-issue01-probe/Logs/Test/Test-OpenWithX-2026.10.22_12-32-17-+0800.xcresult`（临时文件，非仓库交付）。构建会执行 Swift 类型检查。部署目标 26.0 与 arm64 的工程设置只证明构建配置，不证明 26.0 可运行。Release 单独构建结果在 evidence.txt 记录。

## 继续条件

需要先审查并修正当前原型的应用授权交付方式、自动发现后的权限错误，以及启用状态 API 不一致的原因，再重复同一实验。当前错误不能简单归因于目标目录权限，更不能据此添加父目录授权。临时构建运行位置、SDK/系统版本、签名与登记状态均需作为变量核查。

即使这些问题解决，也必须补齐 26.0 Apple Silicon、独立外接盘循环、受保护位置、干净权限、可控冷启动及重启后的端到端证据，才能解除后续 issue 阻塞。若必须改变已确认权限或集成策略，应带本报告重新讨论并同步规格/ADR；本轮未改变这些决策。

## 审查

已按用户确认的基线执行两路独立 code-review，见 [审查记录](review.md)。Standards 无可操作问题；Spec 保留 1 项验收覆盖缺口，未解除关卡。
