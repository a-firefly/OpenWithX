# Issue 07：长期自用构建（2026-10-23）

交付流程、真实签名公证、安装及用户反馈的重启后使用验收已完成。用户于 2026-10-23 决定整个 App 实现到此为止，Issue 07 按决定结束；完整回归与强制终止扩展后的恢复问题不再推进，不记为通过。

## 实现

新增 `scripts/self_use.py` 的 `build`、`finish`、`verify` 命令，使用 Xcode 原生 archive / developer-id export / developer-id upload / exportNotarizedApp，最后生成带票据应用的 ZIP 和 SHA-256。不发布、不上架，不依赖额外 notarytool 密码配置；支持已有 Xcode 账号的云端托管 Developer ID 签名。

`build` 拒绝已有目录，`finish` 拒绝覆盖已有备份。Apple 尚在处理时退出并给出继续命令，保留归档，不把上传成功当作公证成功。最终验证要求两端 Developer ID、同团队、安全时间戳、Hardened Runtime、无调试授权、arm64、macOS 26.0、现有沙盒/书签/只读选择/App Group，以及无任何嵌入 Provisioning Profile、有效附加票据与 Gatekeeper 接受。

## 自动与真实验证

用户确认 CLI 为测试边界；替代 codesign、xcodebuild、stapler、Gatekeeper 和 lipo 的系统结果，文件系统使用真实临时目录。11 项行为测试通过，覆盖拒绝开发签名、开发签名扩展、缺失时间戳、嵌入描述文件、缺失票据、团队/架构/权限错误、缺失扩展、构建失败不生成备份、拒绝覆盖和成功备份。红绿证据 `red1.log`–`green7.log`；这类测试不证明真实 Apple 服务或 Finder 行为。

真实执行：`python3 scripts/self_use.py build artifacts/self-use/2026-10-23`。归档、导出、上传成功；首次获取公证结果尚在处理时按预期退出，随后 `finish` 成功。原生日志在上述输出目录，已忽略于 Git。最终归档分发记录：`E343B4E9-0759-4D5D-BCAC-E470493A2F3B`。

安装到 `/Applications/OpenWithX.app`，旧安装保存在 `/tmp/OpenWithX-before-issue07.app`。严格深层签名、主应用和扩展签名、公证票据及 Gatekeeper 检查见 [signature.txt](signature.txt)。双方同属 `RR2LFYZJUK`，Developer ID Application: Zhentao Tang，保持沙盒、只读应用选择、app-scope 书签及 `RR2LFYZJUK.com.point.OpenWithX.validation`；未嵌入描述文件。最低 26.0，仅 arm64；26.0 未实机测试，沿用已确认的版本验收豁免。

ZIP 经 `ditto -x -k` 解压到独立临时目录后再次通过完整 `verify`，证明备份保留了签名与公证票据。

最终备份：`artifacts/self-use/2026-10-23/OpenWithX-self-use.zip`，`shasum -a 256 -c SHA256SUMS` 通过：

```text
f76d2d17bbc874a62f478b62e8ef25713de9e74829fd42bff69e6caf90995922  OpenWithX-self-use.zip
```

## 本轮现场使用

- 已安装公证版正常启动，自动发现 `/Applications/Visual Studio Code.app`，扩展状态显示已启用；无新增目录配置或权限要求。
- Finder 在 `/private/tmp/OpenWithX-self-use-check/中文 项目` 显示一级“使用 VS Code 打开”，点击后 VS Code 的窗口和 Explorer 显示“中文 项目”。使用的是 `/Applications` 下的扩展（首次 PID 6677），不是临时归档副本。
- 冷启动压力步骤：退出主应用，向已确认的扩展 PID 6677 发送 TERM。原窗口重复打开菜单及新 Finder 窗口均未立即唤回扩展；只登记了 `/Applications` 的一个插件，启用状态仍为 `+`。尚不能断言是系统暂停还是冷启动缺陷，不记为无干预冷启动通过。
- 随后重开主应用，已观察到新扩展 PID 6814；再重新登记同一安装扩展，之后扩展 PID 6821。再次退出主应用，Finder 一级菜单恢复，并成功打开另一个临时目标“退出后 打开”；VS Code 的新窗口及 Explorer 已核对，主应用未被成功请求唤起。此结果证明退出主应用后的日常打开，恢复经过干预，不能替代无干预冷启动证据。未重启 Finder、未操作系统扩展开关。

## 用户重启验收反馈（2026-10-23）

用户按上一轮重启验收步骤反馈：登录后未启动 OpenWithX，第一次 Finder 菜单存在，打开目录正确；第二个目录在新窗口打开，原项目保留。该反馈作为当前已安装公证版在用户环境下系统重启恢复、登录后无需主应用的正常扩展启动和新窗口语义验收通过的人工证据。用户随后补充本次验收系统版本为 macOS 26.7，作为此次重启验收的环境记录。

此结果不等同于强制 TERM 后自动恢复已修复，也不代表其他回归项已全部重跑。

## 收尾时未完成的边界

本轮公证安装版在正常系统重启后、无需主应用的启动已由用户反馈通过；强制 TERM 后的扩展自动恢复尚未确认，完整 Issue 07 回归（失效副本、外接盘变化、错误恢复、中英文与回退等）未全部完成。用户决定停止后续验证与实现，这些项目不再推进，也不记为通过。既有 Issue 02–06 的证据保留，未伪称在新签名安装包全部重跑。未重置用户偏好或清理 TCC，未撤销证书，未修改产品沙盒或业务代码，也没有模拟账号到期或更改系统时间。

会员自然到期后的既有版本使用依据 Apple 的 Developer ID / 安全时间戳规则，不冒充未来到期实测；证书撤销及未来系统兼容性仍有边界。使用与手动重装说明见 [长期自用安装](../../../../docs/delivery/self-use.md)。

## 2026-10-23 — 加入 App Logo 后重新交付

按用户要求，使用已有 AppIcon 资源重新执行相同的 Developer ID 签名、公证及附加票据流程，产物位于 `artifacts/self-use/2026-10-23-logo-release/`。确认最终应用包含 `AppIcon.icns`，Info.plist 配置 `CFBundleIconName=AppIcon`。11 项打包工具测试通过；最终 ZIP 独立解压后和 `/Applications/OpenWithX.app` 安装副本均通过完整 `verify`（签名、权限、架构、票据和 Gatekeeper）。

已替换 `/Applications/OpenWithX.app`，重新登记 Finder 扩展并启动新版；已替换 `docs/app/OpenWithX-self-use.zip` 和 `docs/app/SHA256SUMS`，校验通过：

```text
6b93a823aa5a9b0febc78cd1689b94ce303e7c09ab28e46150873613b7a53572  OpenWithX-self-use.zip
```

旧安装备份为上述产物目录中的 `previous-installed-app.zip`，旧交付 ZIP 和校验值保存为 `previous-OpenWithX-self-use.zip` 与 `previous-SHA256SUMS`。本次仅重新打包与替换，不表示新包已重跑 Finder 功能或重启人工验收，既有未完成边界和 Issue 收尾状态保持。
