# Issue 05：打开失败恢复与在途请求合并

日期：2026-10-23（Asia/Shanghai）。实施基线：`aee51acc01315b6db6b4c14e7e49ade5767580f2`。

## 实现

- Finder 扩展实例复用打开器；同一标准化文件 URL 的在途请求只交付和回调一次，不同目标独立处理，完成后允许新请求。旧请求的重复回调不能结束新请求。系统回调回到主执行器；不跨 Finder Sync 进程协调，也不阻止系统接受后的重复打开。
- 菜单规则保持；执行打开时重新检查目标元数据，保留原生错误，不将访问拒绝改写为不存在。资格数据不足时不交付目标，也不推断一定是权限错误。
- `OpenFailure` 映射选择错误、Cocoa、POSIX、Launch Services 和有限层级底层错误，给出原因及恢复指引；未知原因如实说明。指定副本失效要求重选，不静默回退，不自动循环重试。
- 通过显式指定包含应用的 NSWorkspace URL 交接 UUID、原因和原始错误，唤起或激活主应用。唯一配置窗口使用应用级内存队列；同 ID 只接收一次，不同失败依次展示。关闭当前提示后展示下一条，每条原始错误默认折叠。被动状态刷新不反复制造错误提示。
- 重新检测、手动选择、显式恢复自动发现及主动官方下载入口保留；目标、磁盘和权限问题给出检查与 Finder 重试指引。成功仅指系统接受，不启动主应用，不冒充编辑器加载完成。
- 不持久保存错误、去重 ID 或打开历史；日志只记录阶段与计数。原始错误可能含路径，仅在本机交接供用户展开。打开及错误交接关闭系统最近项目登记；VS Code 自身的历史由编辑器管理。未变更沙盒、应用授权和 App Group，未增加依赖、通知或高权限要求。

## TDD

用户已确认两处边界：`TargetFolderOpener` 的打开行为，以及主应用失败接收/展示入口。文件系统、错误编码和队列使用真实实现，NSWorkspace 在已有系统注入边界控制返回。

日志前缀均为 `/tmp/OpenWithX-issue05-`：

| 切片 | 失败证据 | 通过证据 |
| --- | --- | --- |
| 在途合并、不同目标、完成后重试、重复回调 | `red1.log` 断言失败 | `green1.log` |
| 权限错误映射与无路径摘要 | `red2.log` 接口不存在 | `green2.log` |
| 其他原因与恢复 | `red3.log` 接口不存在 | `green3.log` |
| 真实元数据权限错误及修复后恢复 | `red4.log` 断言失败 | `green4.log` |
| URL 交接、展示队列、ID 去重、非法 URL | `red5.log` 接口不存在 | `green5.log` |
| 启动权限及不兼容应用错误 | `red6.log` 断言失败 | `green6.log` |
| 不登记系统最近项目 | `red7.log` 断言失败 | `green7.log` |
| 同路径显式有无末尾斜杠合并 | `red8-explicit.log` 断言失败 | `green8.log` |

真实元数据用例只对自建临时父目录设置 000，打开其子目标得到原生访问拒绝；恢复 700 后新请求可交付。此测试不证明 Finder 或 NSWorkspace 收到了同样错误，NSWorkspace 提交仍由测试控制。每轮 xcodebuild 同时编译主应用及扩展。

末尾斜杠回归首次使用自动推断目录类型的 URL 时已通过（`red8.log`），不能作为 red 证据；改为显式不同目录标记后才观察到失败，再统一目录 URL key 修复。双轴审查及修复复核无未解决问题，见 [review.md](review.md)。最终 Release arm64 构建退出 0（`final-release.log`）；严格深层签名核验通过，双方 app-sandbox、app-scope bookmarks、只读应用选择和 App Group 保持（`final-signature.log`）。这是开发签名构建，不是公证交付。无 Swift 编译警告，仅有未依赖 AppIntents 的工具提示。

完整套件已执行一次（`full-tests.log`）：25 个逻辑用例运行通过，UI 运行器在测试执行前因“Timed out while enabling automation mode”初始化超时，整体退出 65，不能称为完整套件通过。系统日志明确显示“Writer daemon requires authentication to enable automation mode”及“Enable UI Automation”本机认证请求（`ui-diagnostics.log`）；尚待用户完成本机身份验证，UI 单独重试结果待补充。未绕过认证或更改系统安全设置。最低部署目标保持 macOS 26.0、arm64。

## 实机证据

环境沿用 macOS 26.7（25G229）、Apple Silicon 和既有用户授权，不代表干净权限环境或其他用户。未操作 SSD 挂载，未退出用户现有 VS Code 会话。

1. 备份旧安装到 `/tmp/OpenWithX-issue05-previous.app`，更新为本轮开发签名 Debug 构建，严格深层签名核验通过。刷新安装 appex 的开发注册；这是部署操作，不是产品自动恢复证据。扩展登记 2 个本地卷。
2. `pgrep -x OpenWithX` 未找到进程时，在 Finder 的 `/private/tmp/OpenWithX-issue05-fixtures` 对 `Project` 右击，出现一级“使用 VS Code 打开”（`executePlugInCommand:`）。菜单出现后暂时移除自建夹具父目录权限，再点击入口。
3. 10:14:40 扩展记录失败交接，主应用 PID 61793 启动。主窗口只有一条未知失败提示、恢复指引和默认折叠的原始错误；展开为 Cocoa 262。此错误由资格检查失败产生，不能记为原生权限错误、NSWorkspace 拒绝或访问拒绝端到端通过；Finder 同时退回上级目录。见 [failure.log](failure.log)。
4. 随后恢复夹具父目录为 700，关闭提示并退出主应用，从 Finder 重进目录右击 `Project`。10:16:49 系统接受请求；VS Code 新窗口为 `Welcome — Project`，Explorer 子目录为 `/private/tmp/OpenWithX-issue05-fixtures/Project/Nested`，主应用无进程。见 [recovery.log](recovery.log)。未改变工作区信任。
5. 用本机模拟 URL 独立验证分类 UI：退出状态启动后显示访问拒绝及实际权限检查指引，原始错误默认折叠；关闭窗口后新交接仍可唤起。再交付指定副本失效的新 ID，关闭第一条后出现重选指引；重复第二条 ID，关闭后没有额外提示。detail 标记 `Simulated`，不当作真实系统拒绝。

## 适用边界

- Finder 端原生访问拒绝仍未触发。真实元数据测试、模拟映射与 UI 验证不能替代此端到端证据；按 Issue 允许的安排保留缺口，不以 VS Code 内部错误替代。以后能触发时补充真实拒绝、主应用提示及权限修复后的恢复证据。
- 真实磁盘断开未实测；ENODEV/ENXIO 和目标消失有逻辑覆盖，不声称断盘链路实测通过。
- 选择与统一错误恢复的最终联验由 issue 06 完成；issue 04 系统重启授权验收仍待确认。
- 去重 ID 只在本进程存活期间保留，退出后不保存，避免持久诊断/历史。跨多个扩展进程未做全局合并。
- 上述实机验收在最后补充错误常量与关闭系统最近项目登记前执行；最终构建单独测试和签名检查，不将先前实测扩大到未执行范围。
