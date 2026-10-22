# 选择 Finder Sync 集成

OpenWithX 的 MVP 要求在 Finder 一级右键菜单打开单个目标文件夹；“服务”和“快速操作”子菜单无法满足核心体验。选择 Finder Sync 作为首选集成路线，由应用自动维护本地磁盘的菜单覆盖范围，具体支持边界见 [ADR 0004](0004-automatic-local-folder-coverage.md)。

Apple 将 Finder Sync 定位于文件同步应用而非通用 Finder UI 修改，因此这条集成路线必须通过 macOS 26 系列 Apple Silicon 上的端到端验证，包括一级菜单、自动目录覆盖、主应用退出后可用和跨重启恢复。若不能满足核心要求，应携实测证据重新讨论，不自动降级菜单入口。当前验证结论见 [Issue 01](../../.scratch/finder-open-mvp/issues/01-validate-finder-sandbox-chain.md)。

参考：[Apple Finder Sync 指南](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)。
