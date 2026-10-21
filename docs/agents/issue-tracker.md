# Issue tracker: Local Markdown

本仓库的 Issue 和规格文档以 Markdown 文件保存在 `.scratch/` 下。

## Conventions

- 每个功能使用一个目录：`.scratch/<feature-slug>/`。
- 规格文档位于 `.scratch/<feature-slug>/spec.md`。
- 每个实施任务单独保存为 `.scratch/<feature-slug>/issues/<NN>-<slug>.md`，从 `01` 开始编号，不合并为一个任务文件。
- 在每个 Issue 文件顶部附近用 `Status:` 行记录分诊状态。角色字符串参见同目录的 `triage-labels.md`。
- 评论和对话历史追加到文件底部的 `## Comments` 标题下。

## When a skill says "publish to the issue tracker"

在 `.scratch/<feature-slug>/` 下创建文件，按需创建目录。

## When a skill says "fetch the relevant ticket"

读取所引用路径的文件。用户通常会直接提供文件路径或任务编号。

## Wayfinding operations

供 `/wayfinder` 使用。路线图（map）保存为一个文件，每个子任务（child ticket）各保存为一个文件。

- 路线图：`.scratch/<effort>/map.md`，包含 `Notes`、`Decisions-so-far` 和 `Fog`。
- 子任务：`.scratch/<effort>/issues/NN-<slug>.md`，从 `01` 开始编号，正文记录问题。
- `Type:` 行记录 `research`、`prototype`、`grilling` 或 `task`。
- Wayfinding 生命周期使用 `Status: open`、`Status: claimed` 和 `Status: resolved`。
- 依赖：在文件顶部附近以 `Blocked by: NN, NN` 记录。所有列出的任务均为 `resolved` 时，该任务解除阻塞。
- 前沿任务：扫描当前工作的 issues 目录，选择处于 open、未阻塞且未认领的任务；优先选择编号最小的任务。
- 认领：开始工作前，先设置 `Status: claimed` 并保存。
- 解决：在 `## Answer` 标题下追加答案，设置 `Status: resolved`，再将上下文指针（摘要和链接）追加到路线图的 `Decisions-so-far` 中。

Wayfinding 状态用于描述其生命周期；五个分诊角色用于执行 triage 时的分诊状态。
