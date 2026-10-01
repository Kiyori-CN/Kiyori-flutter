# Kiyori

Kiyori 是正在从零构建的个人跨平台 AI 工作台，面向 Android、Windows 与 iOS。它计划把 AI 助手、网页浏览、文件与下载、音视频和可授权的扩展工具统一到一个应用中。

**界面沿用旧 Kiyori：中央首页、左侧负一屏、右侧 AI 对话和五图标底栏。** 重构主要改善目录与内部实现，并支持多平台；未接入业务的按钮保留外观与空点击。真实 Rust 核心及开发用运行检查已建立。Android 与 Windows 优先实现和验证；iOS 已维护源集，Apple 平台构建和设备验收需要后续补齐 Mac 与测试设备。

## 阅读入口

- [文档导航](docs/README.md)：按产品、架构、专项设计和开发指南阅读。
- [技术选型](docs/decisions/0001-technology-stack.md)：Flutter / Dart、Rust 和必要的原生适配。
- [仓库布局](docs/architecture/repository-layout.md)：目标目录、依赖方向和何时创建模块。
- [开发工具链](docs/development/toolchains.md)：版本基线、环境启用与验证方式。
- [当前状态](docs/status.md)与[路线图](docs/roadmap.md)：实际进度、验收条件和下一步。

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

修改 Rust 公共 API 后运行 `tools/generate-bridge.ps1`。生成器安装、真实桥接测试和 iOS 限制见 [M1 开发指南](docs/development/m1-foundation.md)。

开发时可在 `apps/kiyori` 执行 `flutter run -d windows --dart-define=KIYORI_DIAGNOSTICS=true` 进入独立运行检查。正常启动保持复刻界面，设置按钮不跳转到开发诊断页。UI 的源码依据和验证范围见 [UI 复刻契约](docs/design/ui-parity.md)。

## 项目身份

产品和新仓库均命名为 **Kiyori**，内部包使用 `kiyori` 前缀。新 Android 应用使用 `com.kiyori`，与独立维护的旧 Android 应用并存。详细标识见[命名规范](docs/architecture/naming.md)。
