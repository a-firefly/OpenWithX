# Issue 04：正式版 VS Code 选择与持久化

日期：2026-10-23（Asia/Shanghai）。基线：`02f37bf`。

## 实现

- 保留原生重新检测、手动应用选择及显式恢复自动发现入口。显示完整应用路径，便于区分同名副本；新增用户主动点击的官方下载链接，不自动访问或安装。
- 自动发现结果校验正式版 bundle identifier 和路径存在性；手动选择仅接受 `com.microsoft.VSCode`，拒绝 Insiders 与其他工具。未手动选择时沿用系统发现顺序，不承诺多副本排序。
- 沿用既有 v2 配置和授权协议：App Group 保存选择、主应用自有书签和临时隐式传输；扩展保存自己创建的持久 app-scope 书签并回执 UUID。主应用保留传输访问直到回执到达。没有变更权限、书签归属或配置格式。
- 将配置入口改为可独立构造的实例，生产两端使用各自进程中的 `shared`；测试只替换 UserDefaults 与系统应用发现/注册，不替换书签创建或解析。
- 副本移动或删除后，主应用读取、扩展打开及授权状态均要求重选，不静默回退。修复原先失效后授权状态仍显示“已同步”的问题。
- 原有多副本运行冲突检查保持：所选副本未运行而其他副本运行时提示自行退出其他副本或重新选择，不强制退出、不替换。

## TDD 与检查

用户明确确认两个测试边界：`VSCodeSelection` 与 `ProbeConfiguration` 的选择/读取/接收接口。系统授权与 Finder 行为另做集成实测。

- 基线 13 个逻辑测试通过：`/tmp/OpenWithX-issue04-baseline.log`。
- 自动发现校验先出现 3 个断言失败，再实现通过：`/tmp/OpenWithX-issue04-red1.log`、`/tmp/OpenWithX-issue04-green1.log`。
- 配置重建测试先因缺少实例接口编译失败；实现后路径比较曾受书签规范化目录 URL 影响，改为比较文件系统路径，未更改产品逻辑来迎合测试。最终通过：`/tmp/OpenWithX-issue04-red2.log`、`/tmp/OpenWithX-issue04-green2.log`。
- 移动已同步副本时授权状态仍显示成功的测试先失败，增加状态校验后通过：`/tmp/OpenWithX-issue04-red3.log`、`/tmp/OpenWithX-issue04-green3.log`。
- 追加既有行为回归：拒绝非正式版时保留原选择、重新选择使用新回执、显式清除后恢复发现。删除与移动均验证不回退。配置测试使用独立临时存储和最小应用夹具，不证明真实跨进程沙盒授权。
- 完整套件退出 0：20 个逻辑用例（含参数化用例）、2 个既有 UI 测试通过；UI 模板测试不证明 Finder 链路。日志：`/tmp/OpenWithX-issue04-full-tests.log`。
- Release arm64 构建退出 0，最低 macOS 26.0；严格深层签名核验通过，两端 app-sandbox、app-scope bookmarks、只读应用选择及原有 App Group 保持。日志：`/tmp/OpenWithX-issue04-release.log`。这是开发签名，不是公证发布交付。
- 两路审查后合并重复的最小应用测试夹具，最终完整回归仍为 20 个逻辑用例、2 个 UI 测试通过，退出 0：`/tmp/OpenWithX-issue04-reviewed-tests.log`。无 Swift 编译警告，仅有未依赖 AppIntents 的工具提示。

## 实机证据

环境：macOS 26.7（25G229）、Apple Silicon，沿用已确认的 26.7 代表 26.0 版本关卡安排，不声称 26.0 已实测。沙盒与原有只读应用选择授权保持。

1. 备份旧安装至 `/tmp/OpenWithX-issue04-previous.app`，安装本轮 Debug 构建。界面显示系统发现路径 `/Applications/Visual Studio Code.app`、自动发现状态及官方下载链接。
2. 通过 NSOpenPanel 手动选择该正式版副本，界面实际显示“授权已同步（不代表打开成功）”。09:49:28 两个扩展进程均记录接收方授权同步。
3. 退出主应用，停止旧扩展以验证冷启动。系统没有立即重新启动扩展，首次菜单缺失；刷新已安装 appex 注册后，09:52:14 新进程 58493 启动，登记 2 个本地卷，并读取接收方授权。该人工注册仅用于开发部署验证，不作为产品自动恢复能力的证据；未重启 Finder、未操作磁盘挂载。
4. Finder 在 `/private/tmp/OpenWithX-issue04-fixtures` 右击 `中文 Project`，出现一级“使用 VS Code 打开”（`executePlugInCommand:`）。点击后 09:52:28 系统接受请求，VS Code 新窗口为 `Welcome — 中文 Project`，Explorer 子目录路径明确为 `/private/tmp/OpenWithX-issue04-fixtures/中文 Project/Nested Folder`。
5. 请求后 `pgrep -x OpenWithX` 无进程，扩展进程为 58493；没有启动配置应用、额外授权目录或修改工作区信任。系统日志摘录见 [evidence.txt](evidence.txt)。

## 多副本与剩余验收

既有多副本与路径失效实测证据继续适用：用户于 2026-10-22 确认其他副本运行时提示冲突；退出原副本后手选副本正常打开；改名后要求重选；重选有效副本后恢复打开。详见 [issue 01 后续记录](../issue-01/followup.md) 中“用户确认副本基线与改名失效检测”和“用户确认副本恢复成功”。本轮不把此前确认写成新执行的实测，也不退出用户正在使用的 VS Code。

本轮尚未实际重启系统验证手动授权恢复。Issue 03 的重启豁免明确仅限那一轮，不能据此关闭 issue 04 的系统重启要求；需用户在方便时重启后，通过 Finder 打开普通文件夹并确认无需重选。统一错误恢复最终联验由 issue 06 完成。当前用户环境限制与既有 TCC 授权影响保持，不推广为其他用户可用性承诺。
