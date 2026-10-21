# Domain Docs

本仓库采用 single-context 领域文档布局。

## Before exploring, read these

- 根目录的 `GLOSSARY.md`。
- `docs/adr/` 中与当前探索范围相关的架构决策记录。

如果这些文件不存在，静默继续。`/domain-modeling` 技能会在术语或决策得到明确结论后按需创建它们。

## File structure

- `GLOSSARY.md`：共享领域词汇。
- `docs/adr/`：架构决策记录。
- `OpenWithX/`：应用源码。

## Use the glossary's vocabulary

在 Issue 标题、重构提案、假设或测试名称中命名领域概念时，使用 `GLOSSARY.md` 定义的术语。

如果所需概念尚未收录，重新考虑它是否符合项目用语，或记录该缺口供 `/domain-modeling` 处理。

## Flag ADR conflicts

如果提案与已有 ADR 冲突，明确指出对应 ADR，并解释为何需要重新讨论该决策。
