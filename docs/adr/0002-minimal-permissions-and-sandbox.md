# 采用最小权限与沙盒优先策略

OpenWithX 的首次使用无需选择目录或预先授予目录访问权限；菜单范围由应用自动维护，具体覆盖边界见 [ADR 0004](0004-automatic-local-folder-coverage.md)。菜单范围登记与文件访问授权分别处理，路径字符串、App Group 或登记范围本身均不代表访问授权。

主应用和 Finder Sync 扩展优先保持沙盒，不读取项目文件内容、不修改项目，也不要求管理员、辅助功能或完全磁盘访问权限。在本机保存 VS Code 选择及必要的应用授权；手动指定副本的授权失效时引导重新选择应用。

直接分发允许其他沙盒组合，但不以关闭主应用沙盒作为默认解决方案。无预先目录授权时的目标识别与原生打开、应用选择授权的跨进程使用、跨重启恢复及主应用退出后的完整链路均需实测；如不能满足需求，应基于证据重新讨论，不静默扩大权限。当前验证结论见 [Issue 01](../../.scratch/finder-open-mvp/issues/01-validate-finder-sandbox-chain.md)。

参考：[Apple 沙盒文件访问](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)、[Apple DTS 对直接分发沙盒组合的说明](https://developer.apple.com/forums/thread/776568)。
