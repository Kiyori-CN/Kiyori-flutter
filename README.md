# Kiyori

Kiyori 是开发中的跨平台 AI 工作台，面向 Android、Windows 与 iOS，计划连接 AI 助手、网页浏览、文件与下载、音视频和可授权的扩展工具。项目尚未正式发布。

**产品完整复刻旧 Kiyori Android；跨平台重构改变内部实现，不重新设计 UI 与交互。** 旧项目为 `D:\10_Project\Kiyori-Android`，新旧应用独立安装、独立保存数据。

## 当前能力

| 范围 | 已接入 | 主要限制 |
| --- | --- | --- |
| AI 与模型 | 四种网络协议文字聊天、模型配置、密钥池、角色、历史、总结及独立标题 | 完整工具与文件附件闭环仍待实施 |
| 本地与扩展模型 | 托管模型下载、GGUF 导入、CPU 推理、TOOLPKG 提供方安装与调用 | GPU、媒体及完整旧包宿主能力尚未接入 |
| 本机数据 | 记忆/知识/日记/关系、工作流定义、基础会话审计与导出 | 工作流执行、全量备份恢复与云嵌入尚未接入 |
| 产品界面 | 三页首页、五图标底栏、设置及 AI 抽屉等旧源界面 | 部分页面仅展示与草稿，空点击不代表业务可用 |
| 平台 | Android 与 Windows 本机构建已有历史证据；维护 iOS 源集 | Apple 编译、设备体验与 Profile 验收另行记录 |

首次使用：在“设置 → AI 助手 → 模型与 API”配置端点、协议、模型和密钥，保存后测试模型，再回到 AI 对话选择模型并发送。配置、会话与原文由本机 Rust 存储持有；网络请求仅在相应操作触发。详细操作、凭据导出风险与功能限制见[当前能力指南](docs/user-guide/current-capabilities.md)。

## 阅读入口

- [文档中心](docs/README.md)：用户指南、架构、设计、ADR 和开发入口。
- [当前状态](docs/status.md) / [路线图](docs/roadmap.md)：实际进度与长期完成条件。
- [仓库布局](docs/architecture/repository-layout.md) / [核心语义](CONTEXT.md)：实际代码边界与状态所有权。
- [工具链](docs/development/toolchains.md) / [验证策略](docs/development/testing.md)：准备环境、执行检查与理解证据。
- [协作规则](AGENTS.md) / [复刻流程](docs/development/ui-replication-workflow.md)：修改代码前必读。

## 本机准备检查

在已配置受管理环境的 Windows PowerShell 中执行：

```powershell
Set-Location D:\10_Project\Kiyori
. .\tools\activate.ps1
flutter --version
rustc --version
.\tools\check-foundation.ps1
```

其他机器的安装要求见工具链文档。当前支持的本机构建与运行入口：

```powershell
flutter pub get
.\tools\test-ui.ps1 -Test home_shell_test.dart,primary_pages_test.dart
.\tools\verify.ps1
.\tools\build.ps1 -Platform android
.\tools\build.ps1 -Platform windows
.\tools\build.ps1 -Platform android -Mode profile
Set-Location apps\kiyori
flutter run -d windows
```

Android Debug 产物在 `apps/kiyori/build/app/outputs/flutter-apk/app-debug.apk`；Windows 在 `apps/kiyori/build/windows/x64/runner/Debug/`，运行时需保留整个目录及其 DLL/data。安装到设备另行进行。

性能排查使用 `-Mode profile`（Android 产物为同目录 `app-profile.apk`），不要据 Debug 判断
真机手感。三页往返基准、真实触摸验收与高刷帧预算见[性能契约](docs/development/performance.md)。
`build/verify` 会检查实际 Flutter/Dart/Rust 版本，当前 pin 为 Flutter 3.47.6 / Dart 3.13.5。
每个新 PowerShell 会话都先运行 `tools/activate.ps1`。同一批验证中，依赖已经解析且
manifest/lock 未变化时，`tools/test-ui.ps1` 与 `tools/build.ps1` 可追加 `-NoPub`，避免重复
解析依赖；首次运行或依赖变化后仍使用默认入口。

修改 Rust 公共 API 后运行 `tools/generate-bridge.ps1`。生成器安装、真实桥接测试和 iOS 限制见 [M1 开发指南](docs/development/m1-foundation.md)。

开发时可在 `apps/kiyori` 执行 `flutter run -d windows --dart-define=KIYORI_DIAGNOSTICS=true` 进入独立运行检查。正常启动保持复刻界面，设置按钮不跳转到开发诊断页。UI 的源码依据和验证范围见 [UI 复刻契约](docs/design/ui-parity.md)。

## 项目身份

产品和新仓库均命名为 **Kiyori**，内部包使用 `kiyori` 前缀。新 Android 应用使用 `com.kiyori`，与独立维护的旧 Android 应用并存。详细标识见[命名规范](docs/architecture/naming.md)。
