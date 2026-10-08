# 平台能力与同步开发

本项目以 Android、Windows、iOS、macOS、Linux 为原生平台目标；当前强制构建验收范围为 Android arm64 与 Windows x64。工程源集、插件接线、构建、运行、业务验收和发布是不同证据层级。当前结果以[状态](../status.md)为准，内部边界见 [ADR 0019](../decisions/0019-five-platform-foundation.md)。

## 工程与宿主矩阵

| 目标 | 当前工程 | 构建宿主 | 本轮要求与边界 |
| --- | --- | --- | --- |
| Android | Flutter runner、Kotlin 通道、Rust Native Assets | Windows/macOS/Linux + JDK/SDK/NDK | 实际构建 arm64 Debug APK；其他宿主和 ABI 未验证 |
| Windows | Flutter runner、Dart Win32 adapter、Rust Native Assets | Windows + Visual Studio C++ | 实际构建 x64 Debug bundle，运行 Windows 引擎集成 |
| iOS | Flutter runner、插件注册、Native Assets hook | macOS + Xcode | 源集维护；Swift、链接、模拟器、签名均待验证 |
| macOS | Flutter runner、插件注册、网络沙箱 entitlement、品牌图标 | macOS + Xcode | 工程准备；Keychain、Native Assets 和窗口运行待验证 |
| Linux | GTK runner、插件注册、Native Assets bundle 安装规则 | Linux 桌面 + Clang/CMake/Ninja/GTK | 工程准备；依赖、钥匙环、动态链接及运行待验证 |

源集来自锁定 Flutter 模板，并使用项目自己的应用身份、图标与同一 Dart 入口。Android API 24、iOS 15、macOS 12.0 是当前配置值，实际插件、SDK 与部署环境可能提高下限，首次平台构建必须核验。Linux 首先以 x64 GNU/Linux 桌面为验收目标；arm64 和 Windows arm64 不因存在 Rust target 就成为已支持的发布目标。Web 不在本轮范围，当前使用 dart:io、FFI 与原生句柄。

## 已接入能力与明确缺口

| 能力 | Android | Windows | iOS | macOS | Linux |
| --- | --- | --- | --- | --- | --- |
| 共享 UI、SQLite、网络模型协议 | 已接线 | 已接线 | 共享源码，待验证 | 共享源码，待验证 | 共享源码，待验证 |
| 凭据 | SystemSecretStore → Android 安全存储 | WindowsSecretStore → 已有 DPAPI 格式 | SystemSecretStore → Keychain，待验证 | SystemSecretStore → Keychain，待验证 | SystemSecretStore → libsecret，待验证 |
| 文本/模型/扩展文件选择与导出 | runner 平台通道 | Win32 adapter | unsupported | unsupported | unsupported |
| 本地 CPU 推理 | MNN/llama.cpp adapter | MNN/llama.cpp adapter | unsupported | unsupported | unsupported |
| TOOLPKG 脚本执行 | QuickJS-NG adapter | QuickJS-NG adapter | unsupported | unsupported | unsupported |
| 审计正文保护与签名 | Keystore | DPAPI 保护密钥 | unsupported | unsupported | unsupported |
| Android 系统 Toast | 原生通道 | unsupported | unsupported | unsupported | unsupported |
| 文本手柄触觉 | 原生通道 | unsupported | Flutter iOS 调用，待验证 | unsupported | unsupported |

“已接线”不代表全功能或设备验收。系统凭据适配与审计保护是两个端口：Keychain 接入不代表 P-256 签名或历史审计迁移完成。缺失审计后端不能保存明文、伪造签名或删除旧密文，相关操作必须保留失败；首次启动、建会话和迁移仍需目标平台实测。系统文件通道缺失返回 typed unsupported，不能把未实现当作用户取消。

macOS 复用现有 flutter_secure_storage，保持独立 accountName、不同步凭据，并显式使用非共享 Keychain；不为本应用增加 Keychain Sharing/provisioning 要求。Debug/Profile 和 Release 均声明出站网络，入站调试 entitlement 仅留在 Debug/Profile。Linux 需要 libsecret 开发/运行依赖、D-Bus 用户会话及可用钥匙环服务；锁定或缺失钥匙环必须报错，不自动清空或落盘明文。当前测试只能核对 Dart 参数和错误契约。

## 架构与构建不变量

- Flutter 产品行为仍完全参考旧 Kiyori-Android；runner 只装配系统能力，不复制业务数据库或改变 UI。
- Dart 界面依赖类型化端口，Rust Runtime 是业务事实唯一所有者；平台可用性不授予权限，编译成功不证明能力就绪。
- 平台 Dart 工厂和系统存储实现分开；推理、脚本、审计按真实职责组织，不预建空平台 package。
- inference/scripts 复用 build_support/cmake.rs 的工具查找、NDK/ABI 配置与输入追踪。Windows 未接入的架构直接拒绝，不能误链接 x64。
- root/crate-local Rust pin 的 targets 与 toolchains.json 同步；锁定的 Native Assets 依赖强制要求此清单。rustup 可能安装列出的标准库，它们不提供 Xcode/系统 SDK 或 linker，也不等于验收。
- Native Assets hook 登记共用构建源码和重命名后的输入；Cargo dep-info 与显式配置输入共同保证增量失效。
- 当前保留原生缓存名 native-scripts；推理迁移到 target/inference，避免 CMake 复用指向旧源码路径的 cache。环境变量指定的自定义缓存也必须与源码位置匹配。

## 在目标宿主继续验证

所有命令从仓库根执行，使用 toolchains.json 锁定版本及 PowerShell 7。安装工具、申请账号、签名和发布分别按实际授权执行；本轮没有安装或远端操作。

| 目标 | 需要的环境与 target | 构建入口 |
| --- | --- | --- |
| Android | JDK/SDK/NDK；aarch64-linux-android | tools/build.ps1 -Platform android |
| Windows | Visual Studio C++；x86_64-pc-windows-msvc | tools/build.ps1 -Platform windows |
| iOS | Xcode；aarch64-apple-ios，模拟器另加 aarch64-apple-ios-sim | tools/build.ps1 -Platform ios（无签名） |
| macOS | Xcode；匹配主机的 aarch64-apple-darwin 或 x86_64-apple-darwin | tools/build.ps1 -Platform macos |
| Linux | Clang、CMake、Ninja、pkg-config、GTK3、libsecret；x86_64-unknown-linux-gnu | tools/build.ps1 -Platform linux |

在对应宿主先执行 tools/verify.ps1，再构建和运行普通入口；首次真实构建可能暴露未发现的 SDK/插件问题。Apple 插件依赖管理按锁定 Flutter 与插件要求配置。Android/Windows 完整本机命令见[验证策略](../development/testing.md)。

未来浏览器、后台传输、媒体、终端与 MCP 仍复用各自唯一会话/任务所有者。平台底层分别评估 WebView/WebView2/WKWebView/Linux 引擎、SAF/路径/bookmark/portal、后台调度和进程权限；不能把 Android 生命周期直接移植到桌面，也不能提前承诺 iOS 的任意执行能力。

## 官方依据与证据边界

2026-10-07 核对 [Flutter 桌面支持](https://docs.flutter.dev/platform-integration/desktop)、[Linux 构建说明](https://docs.flutter.dev/platform-integration/linux/building)及 [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)；实现参数同时核对本机锁定 11.2.0 源码。官方支持列表不代替本项目验证，实际 Apple 环境要求应在准备时查 [Xcode 系统要求](https://developer.apple.com/xcode/system-requirements/)。商店审核、签名、公证和下载代码规则在发布任务中另行核验。
