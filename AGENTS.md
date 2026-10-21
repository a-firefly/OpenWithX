## 项目与开发约定

- 本项目是使用 Swift 和 SwiftUI 开发的 macOS 应用。
- 最低 macOS 版本以 `OpenWithX.xcodeproj/project.pbxproj` 中适用构建配置的 `MACOSX_DEPLOYMENT_TARGET` 为准。
- 优先使用苹果原生 API。
- 业务逻辑尽量保持可测试。
- 仅在必要时引入第三方依赖。
- 功能开发遵循 TDD：先编写失败的测试，再实现功能，最后重构。
- 功能或架构决策发生变化时，同步更新相关文档。

## Agent skills

### Issue tracker

Issue 和规格文档以本地 Markdown 文件保存在 `.scratch/<feature>/` 下。读写任务时，参见 `docs/agents/issue-tracker.md`。

### Triage labels

使用五个默认分诊角色，在每个 Issue 的 `Status:` 行中记录。进行分诊时，参见 `docs/agents/triage-labels.md`。

### Domain docs

采用 single-context 布局：根目录的 `GLOSSARY.md` 和 `docs/adr/`。探索代码库前，参见 `docs/agents/domain.md`。
