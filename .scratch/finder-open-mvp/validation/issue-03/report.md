# Issue 03：外接磁盘与生命周期验收

日期：2026-10-23（Asia/Shanghai）。基线：`062c67c51dd6e9c1b9b4cafd9a6d165ba7542d02`。

## 实现

- 将既有的本地卷枚举和 NSWorkspace 挂载、卸载、改名通知整合为 `LocalVolumeMonitor`。扩展持有监控器，主应用无需常驻。
- 每次使用当前卷快照整体替换 Finder `directoryURLs`，只登记明确为本地的可见卷；不持久化卷路径，不累加已断开的卷。登记范围不代表目录授权。
- 启动时先订阅通知，再登记初始快照，消除先枚举后订阅的空档。释放监控器时移除观察者；新实例从当前快照恢复。
- 沿用现有启动时恢复 VS Code 配置、接收方自有书签、普通文件夹单选筛选和打开错误交接；本次不改变配置格式或沙盒，也未新增权限、目录配置、依赖或常驻组件。完整错误恢复属于 issue 05。
- 网络卷和未知类型不登记为覆盖根。云盘及特殊虚拟位置仍不承诺支持；根目录登记不代表所有子路径均已验证。

## TDD 与自动检查

沿用 issue 02 已确认的目标筛选与打开入口测试边界；提出卷覆盖生命周期边界后，用户要求跳过真实外部存储卸载、重挂载实测。测试仅替换系统卷枚举和通知，不操作真实卷。

| 检查 | 结果 | 本机日志 |
| --- | --- | --- |
| 基线 | 10 个逻辑测试通过 | `/tmp/OpenWithX-issue03-baseline.log` |
| 冷启动红灯 | 缺少 LocalVolumeMonitor，编译失败 | `/tmp/OpenWithX-issue03-red1.log` |
| 冷启动绿灯 | 本地内置/外接卷登记，网络及未知类型排除 | `/tmp/OpenWithX-issue03-green1.log` |
| 卷变化红灯 | 新增卷尚未更新，3 处预期失败 | `/tmp/OpenWithX-issue03-red2.log` |
| 卷变化绿灯 | 模拟挂载、卸载、重挂载及改名后整体替换范围 | `/tmp/OpenWithX-issue03-green2.log` |
| 生命周期回归 | 3 个测试通过，覆盖释放与重新建立监控 | `/tmp/OpenWithX-issue03-lifecycle-tests.log` |
| 最终完整套件 | 13 个逻辑测试、2 个既有 UI 测试通过，退出 0 | `/tmp/OpenWithX-issue03-full-tests.log` |
| Release | arm64、macOS 26.0 最低目标构建通过，退出 0；严格签名核验通过，主应用与扩展 app-sandbox 为 true | `/tmp/OpenWithX-issue03-release.log` |

最终完整套件无 Swift 编译警告；仅有未使用 AppIntents 的工具提示。UI 模板测试不证明 Finder 链路。模拟通知不证明真实硬件事件；逻辑重建不证明系统重启。

## 冷启动实机验证

环境：macOS 26.7（25G229），Apple Silicon。沿用规格已确认的 26.7 版本关卡豁免，不声称已实测 26.0。

1. 备份旧安装到 `/tmp/OpenWithX-issue03-previous.app`，停止旧扩展进程 31082，安装此次 Debug 构建到 `/Applications/OpenWithX.app` 并刷新其注册。保留既有启用与配置状态，没有重启 Finder，也未卸载磁盘。
2. 新扩展进程 55206 于 09:33:55 启动，记录当前本地卷数 2，并完成配置同步。此环境为自动发现 VS Code；未另外建立手动副本书签跨重启基线，完整手动配置验收由 issue 04 跟进。
3. 在 Finder 进入内置磁盘 `/private/tmp/OpenWithX-issue03-cold`，右击 `中文 Project`，出现一级“使用 VS Code 打开”（`executePlugInCommand:`），区别于已有快速操作。
4. 点击后 09:34:18 系统接受请求。VS Code 新窗口为 `Welcome — 中文 Project`，Explorer 子目录路径显示 `/private/tmp/OpenWithX-issue03-cold/中文 Project/Nested Folder`。未改变工作区信任。
5. 操作后 `pgrep -x OpenWithX` 无进程，扩展独立处理请求，成功未启动主应用或显示提示。已安装 Debug 构建严格签名核验通过。本轮为开发构建，非公证发布交付。

系统回执见 [evidence.txt](evidence.txt)。冷启动在主应用退出时成功；主应用已退出期间重新建立覆盖与自动配置读取已实测。

## 验收边界与剩余项

- 用户明确跳过外部存储的卸载、重挂载实测：仓库本身位于 SSD，不弹出、不卸载、不重挂载它。真实新盘挂载、断开、重挂载及断开过程中错误反馈未记为通过。
- 已挂载 SSD 的普通及嵌套目录已补验收，见下文；没有改变该盘挂载状态。真实挂载、卸载、重挂载仍按用户要求跳过。
- 用户随后明确豁免本轮系统重启实测；不记为已实际重启。issue 03 按调整后的验收范围 resolved，不保留重启为本轮阻塞项。
- 既有目标消失和系统拒绝传播测试继续通过，真实磁盘断开错误与完整恢复交互仍由 issue 05 验证。
- 保持当前用户环境的可用性边界；既有 TCC 授权影响未排除，不推广为其他用户可用性承诺。

## 已挂载 SSD 补充验证

规格审查提出“已挂载外接盘普通及嵌套目录打开”尚未有本轮样本。保持 SSD 挂载状态，在仓库 `validation/issue-03/fixtures/中文 Project/Nested Folder` 创建空目录夹具，没有读取或修改用户项目内容，没有目录授权操作。

- Finder 在 `fixtures` 下右击 `中文 Project`，出现一级“使用 VS Code 打开”（`executePlugInCommand:`）；点击后 VS Code 新窗口为 `Welcome — 中文 Project`，Explorer 的子目录路径明确为 `/Volumes/ssd/codes/swift/OpenWithX/.scratch/finder-open-mvp/validation/issue-03/fixtures/中文 Project/Nested Folder`。
- Finder 在该目录中右击 `Nested Folder`，同样出现一级菜单；点击后 VS Code 新窗口为 `Welcome — Nested Folder`，Explorer 根名相符。两次系统接受回执已摘录至 evidence.txt，主应用持续未运行。
- 全程未操作 SSD 的挂载状态。空目录留在本机便于复验，Git 不追踪空目录；这是当前已挂载 SSD 的样本，不扩展为所有外接介质已验证的承诺。
