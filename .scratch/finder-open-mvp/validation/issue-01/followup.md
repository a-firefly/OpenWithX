# Issue 01 修复与新窗口验证

日期：2026-10-22。首轮报告是历史失败记录；当前修复结果以本文为准。完整关卡仍未通过，issue 02–07 保持阻塞。

## 修复

- 原生文件 URL 打开在外接盘出现 OSStatus -54。改用 NSWorkspace 将 VS Code 官方项目 URL 交给指定的正式版应用，路径由 URLComponents 编码；没有新增项目目录授权或 shell 调用。
- 主应用的 app-scope 书签不能直接供扩展持久使用。主应用保持访问期间传递隐式书签，扩展创建并保存自己拥有的 app-scope 书签，再回执确认；失效要求重选，不静默回退。手动选择必须匹配系统登记的同路径应用 URL，禁止运行中的其他副本替代。
- 临时构建路径运行时，启用状态 API 与系统开关不一致。安装到 `/Applications/OpenWithX.app` 后实测 off/on 对应 API false/true；临时运行位置显示未知及安装提示，不再错误报告禁用。
- 按用户追加要求，项目 URL 增加 `windowId=_blank`，使用新窗口保留原工作项目。没有强制新进程或修改 VS Code 全局设置。依据见 ADR 0003。

## 实机证据

环境：macOS 26.7（25G229），arm64，Xcode 27.0，正式 VS Code 1.143.0；Debug 开发签名。两端仍保持原沙盒与只读应用选择权限。

- 15:11:56，正式应用重新选择后，两个 FinderProbe 进程记录接收方授权同步成功。此前验证副本选择残留造成用户 `reselect`，已恢复 `/Applications/Visual Studio Code.app`，不再指向测试副本。
- 用户随后确认 `/Volumes/ssd/codes/swift/hello-world` 可由 Finder 菜单成功打开，但替换当前激活窗口。这是本次新窗口改动前的失败信号。
- 新窗口构建部署后，代理在 Finder 对同一个 `hello-world` 目录右击，选择一级菜单 `使用 VS Code 打开`（`executePlugInCommand:`，区别于既有快速操作）。VS Code 显示 `.gitignore — hello-world`，Explorer 根路径为 `/Volumes/ssd/codes/swift/hello-world`。
- 随后 VS Code 的 Window 菜单同时列出 `.gitignore — hello-world` 与 `01-validate-finder-sandbox-chain.md — OpenWithX — Modified`，原项目窗口保留。只检查窗口和路径，没有编辑目标目录中的内容。设置页显示 `window.openFoldersInNewWindow = default`，未修改全局设置。
- 按用户决定，26.7 通过覆盖 26.0 版本关卡；26.0 没有实测。其他验收条件没有豁免。

## 自动检查与限制

完整签名测试套件通过：5 个逻辑测试、2 个现有 UI 测试，0 失败。日志 `/tmp/OpenWithX-followup-new-window-tests.log`。新增的两个逻辑测试属于已确认的应用选择恢复边界，已分别观察到失败再实现通过；用户明确要求项目 URL 只做实机验证，未新增该边界单元测试。UI 模板测试不证明 Finder 打开链路。

新窗口行为已经通过上述真实 Finder 操作验证。系统重启、独立外接盘卸载/重新挂载、受保护位置、干净权限环境及全部对象筛选场景仍需补齐。不得将本次成功当作整个 issue 01 完成。既有首轮报告、evidence.txt 与 review.md 保留其历史含义。

Release 构建通过（`/tmp/OpenWithX-followup-release.log`），主应用及内嵌扩展严格签名核验通过。两路最终审查与已修正项见 [followup-review.md](followup-review.md)。

## 用户后续人工确认（2026-10-22）

用户确认正确目录打开、外接盘重新挂载及系统重启后的验证已通过。证据为用户人工确认，没有追加逐步日志或硬件标识；不据此扩展到全部生命周期分支。前文“外接盘循环、系统重启待验证”是本次确认前的状态，相应子场景现已获得人工通过结论。受保护位置及其他尚未覆盖的验收仍待确认，完整关卡尚未关闭。

## 受保护位置人工确认（2026-10-22）

用户进一步确认：桌面、文稿、下载三个位置下的文件夹均能正确使用 VS Code 在新窗口打开。这三个位置的成功打开场景通过；前文对这些位置的待确认状态被本次结论取代。权限拒绝分支、干净权限环境及其他未覆盖的验收不由此推定通过。
