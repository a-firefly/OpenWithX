# 通过 NSWorkspace 交付打开请求

OpenWithX 使用原生 NSWorkspace 发现正式版 VS Code，并通过 VS Code 项目 URL 将目标文件夹交给指定应用；不依赖 `code` 命令、PATH、shell 脚本或第三方依赖。用户未手动指定时采用系统发现结果，手动指定后失效则要求重新选择，不静默切换副本。

按 2026-10-22 用户追加要求，打开目标文件夹必须使用新窗口，保留当前激活窗口中的项目。通过项目 URL 的 `windowId=_blank` 参数请求新窗口，不强制新进程，不使用命令行参数或修改 VS Code 全局设置。项目路径由 URLComponents 编码，与查询参数分开构造。OpenWithX 的成功边界为系统接受打开请求，而非编辑器加载完成；成功不显示提示，失败时启动或激活主应用提供恢复入口。沙盒扩展在主应用退出后打开与传递错误的完整链路仍需实测；若验证失败，重新讨论，不静默改为命令行方案。

VS Code 协议依据：[官方 URL 打开说明](https://code.visualstudio.com/docs/configure/command-line#_opening-vs-code-with-urls)、[官方协议处理实现](https://github.com/microsoft/vscode/blob/main/src/vs/code/electron-main/app.ts)（`windowId=_blank`）。

参考：[NSWorkspace 应用发现](https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication(withbundleidentifier:))、[打开 URL](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:))。
