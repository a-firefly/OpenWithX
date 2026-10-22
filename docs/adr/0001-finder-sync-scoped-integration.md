# 选择配置目录内的 Finder Sync 集成

当前状态：2026-10-22 已由 [ADR 0004](0004-automatic-local-folder-coverage.md) 取代。用户确认无需项目父目录配置，自动覆盖本地普通文件夹；不再采用下述配置范围限制。以下保留原决策及其理由。

OpenWithX 的 MVP 要求在 Finder 一级右键菜单打开单个项目文件夹；“服务”和“快速操作”子菜单无法满足已确认的核心体验。选择 Finder Sync 作为首选集成路线，覆盖用户明确配置的项目父目录中的普通子文件夹，不承诺任意 Finder 位置或从外侧右击父目录自身的菜单，也不为此扩大范围。

Apple 将 Finder Sync 定位于文件同步应用而非通用 Finder UI 修改，因此此决策确定的是优先验证路线，不代表已证明可行。正式实现前必须验证 macOS 26 系列 Apple Silicon 上的一级菜单、目录覆盖、主应用退出后可用和跨重启授权；失败时重新讨论，不自动降级菜单入口。本次需求澄清不授权立即编写验证或业务代码。

参考：[Apple Finder Sync 指南](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)。
