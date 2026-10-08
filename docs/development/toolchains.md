# 工具链基线与开发环境

<!-- doc-toc:start -->
- [版本原则](#版本原则)
- [Windows 本机激活](#windows-本机激活)
- [在另一台机器准备](#在另一台机器准备)
- [可复现与升级](#可复现与升级)
- [本轮检查边界](#本轮检查边界)
<!-- doc-toc:end -->

## 版本原则

核验日期：2026-10-02。机器可读权威为根 `toolchains.json`；Rust 的实际选择由 `rust-toolchain.toml` 执行，基础检查保证两者一致。此表记录本轮选型，不是永久宣称这些版本始终最新。

采用最新**兼容且实测的稳定组合**；预览版不进入基线。框架模板版本、上游最新版本和当前机器版本分别记录。JDK、宿主编译器等构建依赖按兼容需求选择；不为追逐单个最高版本破坏旧工程。

| 工具 | 本轮基线/观察 | 用途与限制 |
| --- | --- | --- |
| Flutter / Dart | 3.47.6 / 3.13.5，stable | 官方 Windows archive + SHA-256；五平台 UI |
| Rust | 1.99.0，edition 2024 | side-by-side 安装，项目 pin；全局 stable 不切换 |
| flutter_rust_bridge | 2.13.0 稳定版 | M1 已接入 Dart/Rust/生成器/hooks 同版组合；Native Assets 实际打包 |
| AGP / Gradle | 9.4.1 / 9.8.0 | 正式 Google Maven 补丁 + Wrapper；不依赖全局 gradle |
| Android SDK / Build Tools | API 37 / 37.0.0 | minSdk 候选 24；API/权限行为需设备验证 |
| Android NDK | 30.0.16248370，r30 LTS | 与现有旧 NDK 并存，Rust arm64 原生链接验证 |
| Java | Temurin 21.0.12.1+1 | 已有稳定 LTS 工具，选作本项目 Gradle JVM；不是宣称 Java 最新 major |
| Kotlin | Flutter 模板声明 2.4.0 | AGP 内建 Kotlin 迁移以官方说明与真实插件验证为准 |
| Windows | VS 2026 18.10.1、MSVC 14.51.36231、SDK 10.0.26100.0 | 已有 C++ 桌面工具链，实际 doctor/构建验证 |
| Xcode / Swift / iOS SDK | 观察到正式版 27 / 6.4 / 27 | 当前没有 Apple 主机，未安装/编译 |
| Node.js | 当前机器 24.21.0 LTS；上游 Current 26.10.0 | 扩展作者工具在 M5 精确锁版，不需要移动设备安装 Node |
| pnpm / TypeScript | 观察到 12.4.2 / 7.0.2 | SDK 建立时选择兼容组合；当前不创建空 JS 工作区 |

初次在 Flutter 3.47.5 模板观察到 AGP 9.1.0、Gradle 9.3.1、NDK 28.2.13676358、API 36。正式 runner 已显式锁定表中验证值，不依赖可能变化的 `flutter.ndkVersion` 默认。3.47.6 补丁升级继续复用已验证组合，不修改全局 Flutter SDK 模板。

Flutter 3.47 的官方迁移说明要求 AGP 9+ 应用在确认应用和插件已迁移后启用 `android.builtInKotlin=true`；M1 的应用没有 legacy KGP 插件，已启用并通过 Android 构建。`android.newDsl=false` 仍保留为 Flutter 3.47 兼容开关，待后续插件/DSL 实际迁移后单独验证，不把它与 Kotlin 开关混为一谈。

## Windows 本机激活

本机 SDK 归 `D:\01_Environment` 管理，持久配置归 `Variables/user-env.json`。仓库 `tools/activate.ps1` 复用 `Maintenance/EnvPolicy.psm1`，只给当前 PowerShell 选择项目 Flutter/JDK；不会改注册表或切换全局 Rust 默认。

```powershell
Set-Location D:\10_Project\Kiyori-flutter
. .\tools\activate.ps1
flutter --version
dart --version
rustc --version
flutter doctor -v
.\tools\check-foundation.ps1
```

`activate.ps1` 与检查器使用 PowerShell 7。持久用户环境策略已登记 Flutter/Pub；其它终端需运行激活脚本或按环境管理器同步，不应依靠当前 Codex 进程的 PATH。不要对新仓库使用旧 `KiyoriAndroid` profile。

激活只对当前 shell 生效，新 shell 的裸 flutter 仍可能解析到旧全局 current；正式
test-ui/build/verify 的版本检查会拒绝不匹配SDK。不要在排错时绕过这个入口混用 SDK。
本轮一次未激活的直接诊断构建使用了3.47.5/3.13.4，随后3.47.6/3.13.5复用该hook.dill
报 `Invalid SDK hash`：hooks_runner记录旧SDK version文件路径，而旧并存SDK未变化。
恢复时按失败日志定位单个不兼容hook目录，先保留副本再让pin重新生成；不全量clean、
不修改全局current、不把未用pin的成功构建作为正式交付证据。

## 在另一台机器准备

1. 安装 Git 与 PowerShell 7，按官方 archive 获取锁定 Flutter 稳定版并校验平台对应摘要。将 SDK 放版本化目录，缓存独立于源码。
2. Windows 安装 Visual Studio 的 Desktop development with C++，含受支持 MSVC、CMake 与 Windows SDK。Android 安装 JDK、SDK Platform、Build Tools、NDK 和已验收的命令行工具；按本机规则处理许可证。
3. 安装 rustup，再在仓库执行 `rustup show`，按 `rust-toolchain.toml` 安装指定 compiler/components/targets；标准库不包含平台 SDK。不要求将它设为全局默认。
4. 设置所需 SDK/JDK 路径与缓存，运行 `flutter doctor -v`。没有受管理环境可手动配置；项目脚本会明确报缺少 policy，不偷偷猜其它 SDK。
5. 在无业务依赖的最小工程验证 Flutter Windows/Android 与 Rust 两平台链接；实际应用接入 FFI 和原生插件后必须再构建。

Apple 主机按[平台设计](../design/platforms.md)准备，不能在 Windows 安装一个 Swift 工具就视为有 iOS 工具链。

## 可复现与升级

Rust pin 固定编译器、rustfmt/clippy 与五平台 target 清单；Native Assets 依赖要求显式列出
当前目标。rustup 可能安装对应标准库，但不提供其它平台 linker 或 SDK，不表示构建验收。
根 pin、crate-local pin 与 `toolchains.json` 保持一致。macOS/Linux 构建入口与环境见[五平台矩阵](../design/platforms.md)。

正式工程提交 Wrapper（含 `distributionSha256Sum`）、Cargo.lock、Pub workspace lock。FRB 各部分版本一致；`tools/generate-bridge.ps1` 生成桥接，`-Check` 核对再生成，`tools/build.ps1` 构建，`tools/verify.ps1` 执行相关静态与行为检查。编译器与原生依赖版本不能只记录在开发机 PATH。

`tools/check-toolchains.ps1` 在 build/verify 前核对实际 Flutter channel/version、随附 Dart、
PATH 直接调用的 Dart 和 rustc，防止 format/test 使用另一套 Dart；
基础检查核对 AGP/Gradle/摘要/SDK/NDK/FRB 的配置接线。其他机器可以手动配置同版本 PATH，
不必创建本机 `D:\01_Environment`。`activate.ps1` 仅是这台受管理机器的便捷入口。

2026-10-02 再核验官方 manifest，稳定 Flutter 更新为 3.47.6；归档 SHA-256 为
`a01bb0d26de91bc23c97cd9ccfaad281a612fb8304213fdd5df1119a09404796`，并存安装至
`D:\01_Environment\Toolchains\Flutter\3.47.6\flutter`。旧 3.47.5 保留，未切换全局 current。
Pub outdated 确认直接运行依赖最新，test/analyzer 等受 Flutter SDK pin 的依赖已是最新可解析
组合；不使用 overrides 强制提升。未用到的 Node/TypeScript、Apple 工具只记录观察，不预装。

Google Maven 稳定版本列表和 9.4.1 POM 确认 AGP 补丁可用；官方聚合说明页仍停留在
9.4.0，记录此差异并以正式制品和实际构建验证为准。JDK 保持最新已验证的 21 LTS 补丁，
不是追逐与 Gradle/插件组合尚未验证的新 major。VS stable 18.10.1 与本机一致。

Native Assets 依赖要求 `crates/kiyori_ffi/rust-toolchain.toml`，因此保留一份 crate-local pin，基础检查器保证其与根 pin 一致；不是第二版本来源。Apple targets 安装标准库不代表具备 Apple linker 或 Xcode。

Android应用的`defaultConfig.ndk.abiFilters`跟随Flutter `target-platform`，避免JNI依赖
AAR把未构建Flutter/Rust库的ABI带入单目标APK。`split-per-abi=true`时由Flutter的splits
负责过滤，不同时设置NDK过滤。正式build入口仍为ARM64；新增目标需要对应构建验收。
依据[Flutter ABI过滤说明](https://docs.flutter.dev/release/breaking-changes/default-abi-filters-android)
及本机pin的Gradle源码，最终以APK实际native-code和全部原生库审计为准。

Native Assets hook 显式登记根 Cargo 清单/lock/pin、core 与 ffi 两个 crate 清单及本地 pin。
Cargo dep-info 自动记录源码，但不能代替这些配置输入；产物 hook output 中可核对最终依赖集。
桥接 `-Check` 比较递归 Dart 输出和 Rust 输出的完整路径/摘要集合，新增或删除也会失败。
生成后仅对生成 Rust 文件使用 pin 中的 edition 执行 rustfmt，不顺带格式化人工源码。
检查会实际再生成；若失败，保留并审阅生成差异，不自动覆盖恢复。

新增依赖时先确认五平台支持、维护状态、许可证与稳定版本，再通过最小切片验证。每次升级在版本基线注明观察日期和实际证据，保留旧 side-by-side 工具以便恢复。未用到的播放器 SDK、脚本引擎、MCP server runtime 与大型 Android 模拟器不预装。

## 本轮检查边界

本地 Android task output cache 由 `org.gradle.caching=true` 启用；保留已验证的工具链
组合，不因开发批次开始就升级。没有配置远端缓存或自动外发 build scan；configuration
cache 必须等 Flutter/Native Assets 插件组合经过实际兼容验证后再启用。

环境 doctor 证明基础工具可发现；最小构建证明工具能协同生成产物；它们都不能证明 Kiyori 业务完成、FFI 集成正确或设备体验通过。本轮实际命令与结果见[环境报告](environment-report.md)。
