# 长期自用安装

OpenWithX 仅供当前用户自用，不上架 Mac App Store，不提供公开下载。自用备份采用 Developer ID Application 签名、安全时间戳、公证和附加票据，以便会员自然到期后继续安装和使用既有版本。Debug 与日常开发继续使用原来的自动开发签名。

## 准备条件

- 当前团队为 `RR2LFYZJUK`，最低 macOS 26.0，仅 arm64。
- 需要该团队的 Developer ID Application 签名能力：可以是本机证书及私钥，也可以是 Xcode 已登录账号可用的云端托管签名。本轮已验证 Xcode 自动导出可以使用该团队的托管 Developer ID；仅查看本机 `security find-identity` 的结果不能判断最终能否导出。
- 如自动导出无法获得签名能力，可在 Xcode → Settings → Apple Accounts → 选择付费账号 → Manage Certificates 中创建 Developer ID Application 证书。不要撤销现有证书。
- 公证优先复用 Xcode 已登录账号（见下文）；也可使用 `notarytool` 钥匙串配置。密码不要写入仓库、脚本参数文件或聊天。若采用后者，通过终端交互保存，例如：

```sh
xcrun notarytool store-credentials OpenWithX-notary --apple-id '<Apple ID>' --team-id RR2LFYZJUK
```

按提示在本机输入 app 专用密码。也可用已存在的 App Store Connect API 凭证配置该工具。

## 一条命令构建

在仓库根目录运行，输出目录必须尚不存在（避免覆盖旧备份）：

```sh
python3 scripts/self_use.py build artifacts/self-use/2026-10-23
```

工具依次归档、Developer ID 导出、检查签名和权限、通过 Xcode 账号上传公证、导出带票据的应用、检查票据与 Gatekeeper，再生成 `OpenWithX-self-use.zip` 和 `SHA256SUMS`。全程只上传 Apple 公证服务，不公开发布，不改变 `/Applications` 中的现有安装。

如果 Apple 仍在处理，工具退出并保留归档和日志。稍后继续，不要重新构建或重复上传：

```sh
python3 scripts/self_use.py finish artifacts/self-use/2026-10-23
```

最终应用位于输出目录的 `Notarized/OpenWithX.app`；`Export` 中的包尚未公证，不用于安装。独立复核最终包：

```sh
python3 scripts/self_use.py verify artifacts/self-use/2026-10-23/Notarized/OpenWithX.app
cd artifacts/self-use/2026-10-23
shasum -a 256 -c SHA256SUMS
```

`build` 拒绝已有输出目录，`finish` 拒绝覆盖已有 ZIP。核验失败不会打印交付成功。`artifacts/` 已在 Git 中忽略；请另行备份最终 ZIP 和校验值，不能只留临时文件或本机唯一副本。

工具要求 Python 3（可用 Xcode 命令行工具提供的版本）和 Xcode，无第三方 Python 依赖。测试命令：`python3 -m unittest discover -s scripts/tests -v`。测试仅替代系统命令结果；实际证书、公证及 Finder 仍以实机记录为准。

## 原生归档与导出

仓库的 `Validation/SelfUseExportOptions.plist` 固定使用 `developer-id`、当前 Team ID 和本地导出，不上传到 App Store，也不改变 Debug 的签名方式。以下路径仅为示例，每次交付应使用新的输出目录：

```sh
xcodebuild archive -project OpenWithX.xcodeproj -scheme OpenWithX \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath /tmp/OpenWithX-self-use/OpenWithX.xcarchive \
  -derivedDataPath /tmp/OpenWithX-self-use/DerivedData \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

xcodebuild -exportArchive \
  -archivePath /tmp/OpenWithX-self-use/OpenWithX.xcarchive \
  -exportPath /tmp/OpenWithX-self-use/Export \
  -exportOptionsPlist Validation/SelfUseExportOptions.plist \
  -allowProvisioningUpdates
```

公证上传采用 `Validation/SelfUseNotarizationOptions.plist`（`developer-id`、`destination=upload`）。随后调用 `xcodebuild -exportNotarizedApp`，获取公证状态并导出带票据的应用，复用 Xcode 的已登录账号，无需额外 notarytool 密码配置。

归档本身仍可能是 Apple Development 签名；只有导出后再通过签名与公证检查的包才是长期自用产物。自动导出允许 Xcode 使用已登录账号更新签名资源，失败时保留日志，不降级到开发签名。

## 验收边界

主应用与 Finder Sync 扩展必须保持同一团队、App Sandbox、只读应用选择及 app-scope 书签；App Group 保持 `RR2LFYZJUK.com.point.OpenWithX.validation`。此 Team ID 前缀格式在 macOS 上无需 Provisioning Profile；交付检查采用更严格的策略，拒绝嵌入任何 Provisioning Profile，避免既有版本依赖它的到期日。

每个可执行 bundle 必须使用 Developer ID Application 签名、Hardened Runtime 及安全时间戳，禁止 `get-task-allow`。公证成功后把票据附加至 app，验证 Gatekeeper 接受，再生成最终备份；公证前的上传包不作为完成产物。

安装时先退出主应用，解压最终 ZIP，将其中的 OpenWithX.app 安装到“应用程序”；保留旧版本备份。手动确认扩展状态，验证 Finder 打开、主应用退出后打开、扩展冷启动及重启后的表现。新签名构建的功能验证不能由旧开发构建的证据替代。手动替换构建更新，不自动检查更新。

## 有效期与保存

会员自然到期不使既有 Developer ID 应用失效。安全时间戳让系统检查签名时证书是否有效；证书自然到期不等于撤销。证书撤销可能阻止既有应用运行；未来 macOS 兼容性仍需验证。此方案不承诺会员到期后仍可持续签署、公证新版本。

保存最终带票据的应用备份、SHA-256、构建日志、签名校验及公证结果。私钥另外安全备份，不放进应用备份或仓库。

依据：[Developer ID 有效期](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)、[安全时间戳](https://developer.apple.com/documentation/technotes/tn3161-inside-code-signing-certificates)、[App Group 容器](https://developer.apple.com/documentation/xcode/accessing-app-group-containers)、[公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)。

## 当前验收状态

2026-10-23 已完成真实公证安装、中文/空格目录打开和主应用退出后打开。强制终止扩展后，Finder 未立即自行恢复；重开主应用后扩展重新运行，随后重新登记并退出主应用，菜单及打开恢复。用户随后确认：重启登录后未启动 OpenWithX，Finder 菜单存在且打开目录正确，第二个目录在新窗口打开并保留原项目。macOS 26.7 正常重启与登录后无需主应用的扩展启动验收通过。用户已决定整个 App 实现到此为止，强制终止扩展后的恢复问题及剩余回归不再推进，未验证项保留为已知边界。详见 [Issue 07 验证记录](../../.scratch/finder-open-mvp/validation/issue-07/report.md)。
