# 无需目录配置的自动 Finder 覆盖

OpenWithX 自动覆盖本地普通文件夹，首次使用无需目录配置，让用户可以从不同本地位置直接打开目标文件夹。集成路线采用 [Finder Sync](0001-finder-sync-integration.md)，权限边界遵循[最小权限与沙盒优先策略](0002-minimal-permissions-and-sandbox.md)。

首选 Finder Sync，由应用自动维护内置磁盘与已挂载本地外接磁盘的菜单范围，并响应磁盘挂载变化。仅支持单选普通文件夹，文件、多选、应用包、替身和符号链接均排除；网络卷、云盘和特殊虚拟位置暂不承诺支持。首次使用只需完成 VS Code 检测或选择、扩展启用引导和手动 Finder 打开验证。

OpenInTerminal 的自动登记已挂载卷实现说明这条路线有先例，但不保证本项目在 macOS 26 上可行。登记菜单范围不等于全盘访问权限；无需目录配置时，沙盒下的对象分类、原生 NSWorkspace 打开、扩展共存、主应用退出与重启后的完整链路仍须实测。若必须新增目录授权、改变沙盒策略或缩小核心覆盖才能实现，应基于证据重新讨论，不静默新增目录配置，不默认要求完全磁盘访问权限。

参考：[Apple directoryURLs](https://developer.apple.com/documentation/findersync/fifindersynccontroller/directoryurls)、[OpenInTerminal 实现](https://github.com/Ji4n1ng/OpenInTerminal/blob/master/OpenInTerminalFinderExtension/FinderSync.swift)、[Apple DTS 对重叠扩展菜单问题的说明](https://developer.apple.com/forums/thread/731680)。
