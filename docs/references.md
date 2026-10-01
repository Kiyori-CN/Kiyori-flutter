# 官方资料与核验记录

核验日期：2026-10-02。版本会变化，升级时重新读取官方接口；“最新”只针对本次观察。官方页面与接口不一致时记录差异，优先以实际发行 manifest 和安装工具返回值交叉验证。

## UI 与候选框架

- [Flutter SDK archive](https://docs.flutter.dev/install/archive)与[Windows release manifest](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json)：稳定 Flutter、Dart、archive、摘要。
- [Flutter 支持平台](https://docs.flutter.dev/reference/supported-platforms)：平台和最低系统基线。
- [Flutter Windows 环境](https://docs.flutter.dev/platform-integration/windows/setup)、[Android 环境](https://docs.flutter.dev/platform-integration/android/setup)、[iOS 环境](https://docs.flutter.dev/platform-integration/ios/setup)：主机与系统工具要求。
- [Flutter 架构](https://docs.flutter.dev/resources/architectural-overview)、[平台通道](https://docs.flutter.dev/platform-integration/platform-channels)、[Android 原生视图](https://docs.flutter.dev/platform-integration/android/platform-views)：UI/系统能力边界。
- [Dart Pub workspaces](https://dart.dev/tools/pub/workspaces)：原生 monorepo 依赖管理。
- [Flutter Profile 分析](https://docs.flutter.dev/perf/ui-performance)、[性能实践](https://docs.flutter.dev/perf/best-practices)、[PageView API](https://api.flutter.dev/flutter/widgets/PageView/PageView.html)：真实设备测量、局部重建与相邻页缓存；本机 SDK 源码同时核对。
- [Kotlin Multiplatform 支持平台](https://kotlinlang.org/docs/multiplatform/supported-platforms.html)：KMP/Compose 成熟度，选型比较依据。
- [Tauri 2 架构](https://v2.tauri.app/concept/architecture/)：WebView UI 与 Rust 进程模型，选型比较依据。

## Rust 与桥接

- [Rust stable manifest](https://static.rust-lang.org/dist/channel-rust-stable.toml)：本次返回 1.99.0，rustup 实装核验；网页 release 聚合可能滞后。
- [flutter_rust_bridge 官方文档](https://cjycode.com/flutter_rust_bridge/)、[稳定版 2.13.0 release](https://github.com/fzyzcjy/flutter_rust_bridge/releases/tag/v2.13.0)、[Pub 包元数据](https://pub.dev/api/packages/flutter_rust_bridge)：桥接机制与版本。
- GitHub latest release 曾返回名字带 beta 的版本，即使 prerelease 元数据为 false 也不得直接采用；稳定筛选需同时核验 tag 与包管理器版本。

## Android 与 Windows

- [AGP 9.4.0 compatibility](https://developer.android.com/build/releases/agp-9-4-0-release-notes)：Gradle/JDK/SDK 兼容要求。
- [Google Maven AGP metadata](https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/maven-metadata.xml)与[9.4.1 POM](https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/9.4.1/gradle-9.4.1.pom)：再核验发现正式补丁 9.4.1，说明页尚未更新。
- [Temurin 21 发行](https://adoptium.net/temurin/releases/?version=21)与[Visual Studio 稳定历史](https://learn.microsoft.com/visualstudio/releases/2026/release-history)：所选 LTS 补丁及 VS stable 18.10.1。
- [Gradle current release API](https://services.gradle.org/versions/current)与[Gradle 兼容矩阵](https://docs.gradle.org/current/userguide/compatibility.html)：本次最新 9.8.0 与 JVM 要求。
- [NDK downloads](https://developer.android.com/ndk/downloads/)：最新 LTS r30、版本及 archive 摘要。
- [Flutter 内建 Kotlin 迁移](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin)：AGP 9 迁移与兼容工作。
- [WebView2 Evergreen 与 Fixed Version](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/evergreen-vs-fixed-version)：Windows 浏览器运行时分发决策。
- [WebView2 WebResourceRequested](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/webresourcerequested)：请求拦截设计需按 frame/worker 等来源核验，不能笼统声称全部流量受控。

## Apple 与扩展规范

- [Xcode 系统要求](https://developer.apple.com/xcode/system-requirements/)：稳定 Xcode、macOS、Swift 与 SDK 配套；排除 beta。
- [Apple 审核指南](https://developer.apple.com/cn/app-store/review/guidelines/)：2.5.2 下载代码、2.5.6 网页引擎等平台分发边界，实际分发前复核适用条款和例外。
- [WKContentRuleListStore](https://developer.apple.com/documentation/webkit/wkcontentruleliststore)：iOS 应用内内容过滤实现依据。
- [MCP versioning](https://modelcontextprotocol.io/specification/versioning)：官方当前稳定协议日期与版本协商。
- [Agent Skills specification](https://agentskills.io/specification)：Skill 格式、目录与按需加载规范。
- [Node.js release index](https://nodejs.org/dist/index.json)：区分 LTS 与 Current，不将已安装 LTS 宣称为最新 Current。
- [TypeScript package metadata](https://registry.npmjs.org/typescript/latest)：扩展作者工具版本观察，SDK 建立时再锁定。
