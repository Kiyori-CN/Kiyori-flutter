# 本机环境准备与验证报告

本文为 2026-10-02 的环境准备历史报告，不代表工具的永久最新版本或本次构建结果。当前 pin 以根 toolchains.json 为准，后续验收见[当前状态](../status.md)。

观察日期：2026-10-02，Asia/Shanghai。这里保留 M0 环境准备的历史证据；版本策略见[工具链基线](toolchains.md)，正式应用的后续验证见 [M1 实施与验收](m1-foundation.md)。本报告中的探针均位于仓库外，不是 Kiyori 应用实现。

后续工程治理已并存安装 Flutter 3.47.6 / Dart 3.13.5，项目升级 AGP 9.4.1，并完成实际
Android/Windows Debug/Profile 构建；最新证据见[当前状态](../status.md)。本轮没有改全局
current、注册表、user-env.json 或旧项目环境，以下 M0 版本与产物保留为历史。

## 已准备的环境

| 项目 | 实际结果 |
| --- | --- |
| Flutter | 安装到 `D:\01_Environment\Toolchains\Flutter\3.47.5\flutter`，建立 `current` junction；官方 archive SHA-256 匹配 |
| Dart | Flutter 自带 3.13.4，未额外安装另一份 Dart |
| Rust | 新增 1.99.0、rustfmt、clippy；安装 Windows x64、Android arm64/x64 targets；全局 stable 仍保留旧版 |
| Android | 新增 `ndk;30.0.16248370`；复用已有 API 37 / Build Tools 37 / JDK 21；保留旧 NDK |
| Gradle | smoke Wrapper 下载并使用 9.8.0，官方 SHA-256 已核验；未切换全局 Gradle 9.7.1 |
| Windows | Flutter doctor 识别 VS 2026 Enterprise 18.10.1、MSVC 和 Windows SDK；实际 Windows Debug 构建通过 |
| 持久环境 | `user-env.json` 新增 FLUTTER_ROOT、PUB_CACHE 与 Flutter PATH；UserEnv Apply 后只读复核 OK |
| iOS | 无 Mac / iPhone，Xcode/Swift/iOS SDK 未安装；未进行任何 iOS 构建 |

Flutter archive SHA-256：`0ccd71931f49c2fbe394b1eeb6d79af3d624058a043ea0d03d34160581624fb8`。

Gradle 9.8.0 archive SHA-256：`bafd5ce9cfaea0fbccfdc8439a1ac42fbd4cd9c89dc9a988228d8a2639a58e6c`。

## 真实验证命令与范围

| 检查 | 结果 | 证据边界 |
| --- | --- | --- |
| `tools/activate.ps1` + `flutter doctor -v` | `No issues found!` | Windows/Android 工具发现、许可证与网络；不含 iOS |
| `rustc --version` / `rustup show active-toolchain` | 项目选择 1.99.0 | rust-toolchain.toml 生效，不改全局默认 |
| `flutter create --platforms=android,windows,ios --org com.kiyori --project-name kiyori_environment_probe <probe>` | 生成仓库外三端模板 | iOS 文件生成不是 iOS 编译 |
| probe 内 `flutter build windows --debug` | 成功生成 EXE，28.8 秒 | 原始模板，未接入 Rust/FRB 或业务插件 |
| probe 内 `flutter build apk --debug --target-platform android-arm64` | AGP 9.4.0 / Gradle 9.8.0 / NDK r30 / API 37 组合成功，113.6 秒 | 最小 Android 应用，不是 Kiyori 安装包；未安装设备 |
| Rust `--crate-type cdylib --target x86_64-pc-windows-msvc` | 成功链接 DLL | Rust/MSVC 链接，不含 FFI 调用验证 |
| Rust `--crate-type cdylib --target aarch64-linux-android`，NDK r30 API24 clang linker | 成功链接 SO；ELF64 / AArch64 | Android 原生交叉链接；未在设备加载 |
| `env.ps1 -Action Validate` | OK | 管理清单、目录、SDK 包及入口校验 |
| `env.ps1 -Action UserEnv`（Apply 后） | OK | 持久用户变量与 PATH 策略一致 |
| `Profiles/KiyoriAndroid/audit.ps1` | OK | 旧 profile 重新指向旧项目，未改旧源码 |

probe 为 `D:\01_Environment\Work\Kiyori\environment-probe-20261002`。本轮未运行 UI、设备安装、业务单测、Release、签名分发、远端 CI 或 iOS 编译。

## 产物复核

下列路径相对 probe 根；时间为本机 Asia/Shanghai。不是正式发布物。

| 产物 | 字节数 | SHA-256 |
| --- | --- | --- |
| `build/app/outputs/flutter-apk/app-debug.apk` | 77283263 | `c9c650e5e72fb0968f8607ef83f6bf6157cdbacbadefbeb31fbfcd6f6475cc5b` |
| `build/windows/x64/runner/Debug/kiyori_environment_probe.exe` | 1270272 | `8efa048f725d198fb0e332f9726870f17b4ffe3f2a3be070c3b23616cc519fed` |
| `kiyori_environment_probe.dll` | 9216 | `204609e665ee67137b9c89f3a7720c56b2b3eac42aef02746af05060ceb0f747` |
| `libkiyori_environment_probe.so` | 4547600 | `4150daf64a5d86ed685744952ac3821489e58fec7cef25a3065ca1d381835a42` |

APK 最终时间 00:59:41，aapt 复核：`com.kiyori.kiyori_environment_probe`、minSdk 24、target/compile SDK 37、`arm64-v8a`。这个包名仅供环境探针；新应用正式身份仍按命名规范使用 `com.kiyori`。

## 问题与处理

- Flutter 初次 doctor 报 flutter/dart 不在 PATH；登记受管理环境并运行项目激活后复核无问题。
- 最新 Gradle 9.8.0 第一次 Wrapper 使用损坏缓存，报 `zip END header not found`。从官方地址重新下载，SHA-256 校验匹配；原缓存保留至本轮备份目录，替换后真实构建通过，未降低 Gradle 版本。
- 旧 KiyoriAndroid profile 仍指向新空仓库。备份后精确修正其项目路径和输出路径到 `D:\10_Project\Kiyori-Android`；旧仓库 `main...origin/main` 仍干净。
- 环境脚本输出已包含 PowerShell format 对象，用 `Select-Object` 截尾曾触发显示管道错误。改用 `Out-String` 后重跑只读 UserEnv/audit 均成功；没有把首次退出码当成成功证据。
- cmdline-tools 23 有既有不兼容记录，当前保留已验收版本 22；本轮 SDK 安装和审计成功。安装器提示 sdkmanager 已弃用，迁移 Android CLI 可另做有测试的环境任务，不在本轮重写全局工具。
- 构建完成后分别停止本轮使用的 Gradle 9.8.0 和 9.6.1 daemon，最后未发现残留 java 进程。

## 环境文件变更与回滚

仓库外精确修改：

- `D:\01_Environment\manifest.json`：登记 Flutter、Kiyori Rust target、NDK r30，修正旧 profile 路径。
- `D:\01_Environment\Variables\user-env.json`：Flutter root、Pub cache、Flutter PATH。
- `D:\01_Environment\Profiles\KiyoriAndroid\profile.json`、`activate.ps1`、`audit.ps1`、`build-debug.ps1`：旧项目准确路径。

原文件备份在 `D:\01_Environment\Work\Kiyori\foundation-backup-20261002`。工具安装 side-by-side，旧版本未删除。若恢复配置，先确认没有后续环境修改，再逐文件审阅恢复备份并通过环境管理器同步；不要整体覆盖后续用户配置。

本轮只执行相关 Validate、UserEnv 与旧 profile audit，没有运行会改无关注册/系统变量的 RegisterPython/SystemEnv Apply，也没有执行全局清理或其它项目构建。

## 尚未验证

FRB 2.13.0 的 Dart/Rust/生成器联调、正式 Kiyori 三端 runner、原生插件、后台与设备行为留给 M1/对应模块。Android x64 Rust target 已安装但本轮只链接 arm64。Node/TypeScript SDK、播放器依赖、脚本执行器不提前安装，实施相应模块时必须检查版本并锁定。
