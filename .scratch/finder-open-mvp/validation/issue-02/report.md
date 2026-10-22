# Issue 02：本地目标文件夹打开验收

日期：2026-10-22（Asia/Shanghai）。基线：`e18c55884ef902989f5e58d2a00191ad1635391e`。

## 实现与边界

- `TargetFolderOpener` 是 Finder 打开请求入口：交付前检查普通目标文件夹，恢复或自动发现正式版 VS Code，检查副本冲突，通过 NSWorkspace 交付项目 URL。系统完成回调决定请求结果，不监控编辑器加载。
- Finder 继续通过 `selectedItemURLs()` 获取目标，一级菜单不依赖 VS Code 发现结果；成功只记录不含目标路径的本机日志，不启动主应用。既有失败交接保留，完整恢复与请求合并属于 issue 05。
- 保留 issue 01 已验证的自动本地卷覆盖、App Group、接收方独立应用书签、沙盒和授权策略，以及既有标识符，避免使安装与配置失效。没有新增依赖、目录选择、shell 调用或项目内容访问。
- 按规格及 ADR 0003 的后续用户决定，请求新窗口、保留原项目，不强制新进程。同步了 issue 02 中较早的窗口行为措辞。
- 移除主界面“issue 01 关卡未通过”的过期原型文案；首次配置与完整本地化仍属 issue 06，不在此声称已完成。

## TDD 与自动验证

用户确认三个测试边界：TargetFolderSelection、LocalVolumeCoverage 和打开请求入口（NSWorkspace 系统边界可替换）。前两个边界保留已有行为测试；新增入口先测试再实现。

| 检查 | 结果与本机日志 |
| --- | --- |
| 初始基线 | 6 个逻辑测试通过；`/tmp/OpenWithX-issue02-baseline.log` |
| 请求交付红灯 | 缺少 TargetFolderOpener 导致编译失败；`/tmp/OpenWithX-issue02-red1.log` |
| 请求交付绿灯 | 中文、空格、嵌套与 `#?&:42` 路径编码；激活、指定副本、不强制新进程；回调前不完成、系统接受后成功；`/tmp/OpenWithX-issue02-green1.log` |
| 目标消失红灯/绿灯 | 删除目标后不应交付，先观察失败再增加交付前检查；`/tmp/OpenWithX-issue02-red2.log`、`/tmp/OpenWithX-issue02-green2.log` |
| 请求回归 | 补充原样传播系统错误、未发现 VS Code 时不交付且不影响目标资格；10 个逻辑测试通过；`/tmp/OpenWithX-issue02-core-tests.log` |
| 最终完整套件 | 10 个逻辑测试及 2 个既有 UI 测试全部通过，xcodebuild 退出 0；`/tmp/OpenWithX-issue02-full-tests.log` |
| Release | arm64、最低 macOS 26.0 构建通过；主应用和内嵌扩展严格签名核验通过，两端 app-sandbox 保持 true；`/tmp/OpenWithX-issue02-release.log` |

系统错误测试使用替身，不代表真实访问拒绝已实测。UI 模板测试不证明 Finder 端到端行为。Release 仍为本机开发签名（含开发调试授权），不属于 issue 07 的 Developer ID 公证交付。执行沙盒内的签名核验曾报告信任服务错误，在与签名构建相同的沙盒外环境重试通过；未修改产品沙盒或证书设置。

## Finder 实机回归

macOS 26.7（25G229），Apple Silicon arm64，Xcode 27.0 工具链，正式 VS Code 1.143.0。安装本次 Debug 开发构建到 `/Applications/OpenWithX.app`，保留既有扩展启用状态；旧构建备份在 `/tmp/OpenWithX-issue02-previous.app`。更新构建后刷新了已启用扩展的开发注册，没有重启 Finder、改变 VS Code 设置或新增权限。

夹具位于内置磁盘 `/private/tmp/OpenWithX-issue02-finder-20261022-1836`，包含两个普通目录、嵌套目录、空文件、`.app` 包夹具、符号链接及 Finder 创建的真实替身。没有读取或修改用户项目内容。

| 场景 | 观察 |
| --- | --- |
| 自动发现 | 安装构建界面显示正式版 Visual Studio Code.app；授权状态为“自动发现（未手动选择）”，扩展已启用，无目录配置。随后退出主应用。 |
| 中文与空格目录 | Finder 右击 `中文 Project` 出现一级“使用 VS Code 打开”，命令为 `executePlugInCommand:`；区别于既有快速操作中的“使用 VSCode 打开”。18:39:10 系统接受请求。VS Code 新窗口显示中文项目，Explorer 子目录路径核对为本夹具中的嵌套路径。 |
| 第二个普通目录 | `Another Folder` 同样出现一级菜单；18:40:02 系统接受，VS Code 出现独立 Another Folder 项目窗口。 |
| 嵌套与特殊字符 | `中文 Project/Nested #?&:42` 出现一级菜单；18:40:25 系统接受，VS Code 窗口和 Explorer 根名为完整 `Nested #?&:42`，未被解释为查询参数或行号。Finder 将冒号显示为斜杠，核对 URL 中仍为冒号。 |
| 原项目保留 | VS Code Window 菜单同时列出原 `02-open-local-target-folder.md — OpenWithX`、中文项目与原有权限测试窗口；未替换原项目。新目标处于 VS Code Restricted Mode，没有替用户授予工作区信任。 |
| 文件、包、链接 | 分别右击 `file.txt`、`Example.app`、`FolderLink`，完整上下文菜单中均无本功能入口。 |
| Finder 替身 | Finder 创建的真实替身菜单含“显示原项目”，无本功能入口；没有解析替身。 |
| 多选 | 同时选中两个普通文件夹，状态栏为选择 2 项，菜单含“压缩2个项目”，无本功能入口。 |
| 空白处 | 右击目录列空白区域，菜单含“新建文件夹”，无本功能入口。 |
| 主应用退出与成功静默 | 三次成功请求期间主应用保持退出，无成功弹窗或配置界面；进程核验未发现 `/Applications/OpenWithX.app/Contents/MacOS/OpenWithX`。扩展独立处理请求；回执摘录见 evidence.txt。 |

保留上述临时夹具便于复验。外接磁盘生命周期属于 issue 03；完整手动副本选择属于 issue 04；错误恢复与合并属于 issue 05；首次配置、本地化与最终联验属于 issue 06。本轮没有卸载 VS Code，未发现应用场景的自动检查通过替身验证及菜单与发现分离的代码检查覆盖。

可用性承诺仍仅限当前用户已验证环境。干净权限环境验收已按用户决定取消，既有 TCC 授权影响未排除；26.0 未实测，沿用用户确认的 26.7 版本关卡豁免。
