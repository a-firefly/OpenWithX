# 通过 NSWorkspace 交付打开请求

OpenWithX 使用原生 NSWorkspace 发现正式版 VS Code，并将目标文件夹 URL 交给指定应用；不依赖 `code` 命令、PATH、shell 脚本或第三方依赖。用户未手动指定时采用系统发现结果，手动指定后失效则要求重新选择，不静默切换副本。

不通过强制新进程或命令行参数控制窗口，窗口行为遵循 VS Code 自身设置。OpenWithX 的成功边界为系统接受打开请求，而非编辑器加载完成；成功不显示提示，失败时启动或激活主应用提供恢复入口。沙盒扩展在主应用退出后打开与传递错误的完整链路仍需实测；若验证失败，重新讨论，不静默改为命令行方案。

参考：[NSWorkspace 应用发现](https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication(withbundleidentifier:))、[打开 URL](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:))。
