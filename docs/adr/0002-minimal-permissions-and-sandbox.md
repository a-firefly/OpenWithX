# 采用最小权限与沙盒优先策略

OpenWithX 的首次使用无需选择目录或预先授予目录访问权限；菜单范围由应用自动维护，具体覆盖边界见 [ADR 0004](0004-automatic-local-folder-coverage.md)。菜单范围登记与文件访问授权分别处理，路径字符串、App Group 或登记范围本身均不代表访问授权。

主应用和 Finder Sync 扩展优先保持沙盒，不读取项目文件内容、不修改项目，也不要求管理员、辅助功能或完全磁盘访问权限。在本机保存 VS Code 选择及必要的应用授权；手动指定副本的授权失效时引导重新选择应用。

直接分发允许其他沙盒组合，但不以关闭主应用沙盒作为默认解决方案。无预先目录授权时的目标识别与原生打开、应用选择授权的跨进程使用、跨重启恢复及主应用退出后的完整链路均需实测；如不能满足需求，应基于证据重新讨论，不静默扩大权限。当前验证结论见 [Issue 01](../../.scratch/finder-open-mvp/issues/01-validate-finder-sandbox-chain.md)。

参考：[Apple 沙盒文件访问](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)、[Apple DTS 对直接分发沙盒组合的说明](https://developer.apple.com/forums/thread/776568)。

2026-10-22 验收范围调整：用户决定取消干净权限环境验收，可用性承诺仅限当前用户已验证的环境，不保证其他用户正常使用。既有 TCC 授权影响未排除，此决定不记为干净环境实测通过，也不改变沙盒、无预先目录授权或不要求额外高权限的约束。OpenWithX 可识别访问拒绝时的提示与恢复仍待实测，用户同意移交 issue 05 验证，不再阻塞 issue 01 核心可行性关卡关闭与 issue 02 开始；不将未触发分支记为通过。

2026-10-23 手动应用授权落地：维持双方各自拥有持久 app-scope 书签；App Group 中的临时隐式书签只供主应用保持访问期间接收，扩展保存自己的书签后回执选择 UUID。主应用显示等待与已同步状态，已同步不代表打开成功；副本路径或授权失效后要求重选。选择配置格式保持 v2。配置重建与失效规则由公开接口测试，当前构建真实跨进程同步与扩展冷启动已实测，系统重启后的手动授权验收仍待确认，见 [issue 04 验证记录](../../.scratch/finder-open-mvp/validation/issue-04/report.md)。
