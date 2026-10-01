# M1 工程骨架实施计划

## Goal 与边界

将 M0 方案转为真实可构建工程：一个 Flutter 产品入口、共享 Rust 核心、固定版本 FRB 桥接、三端 runner、正确应用身份、响应式外壳，以及初始化、能力查询、可取消异步事件的完整调用路径。Android/Windows 通过本地实际构建；Windows 必须运行真实 FFI 集成测试。iOS 仅交付同步源集与明确的待编译清单。

本轮不实现 AI provider、浏览器、数据库、媒体、插件 runtime；不创建这些功能的空实现。不提交推送、不安装设备、不触发远端 CI、不购买 Apple 主机。

## 分阶段交付

| 工作项 | 实施内容 | 完成证据 |
| --- | --- | --- |
| M1.1 工程与身份 | Pub/Cargo workspace、应用 runner、包命名、锁文件、源码/产物边界 | 工作区解析、三端 ID 检查、无重复根配置 |
| M1.2 核心契约 | Runtime 生命周期、按真实宿主查询能力、诊断任务、结构化错误、取消 | Rust 测试覆盖输入边界、事件顺序、并发读取、取消、关闭与终态 |
| M1.3 FFI/打包 | FRB 2.13.0、生成配置、Native Assets 候选、再生成入口 | Dart 调用真实 DLL；Android 包含正确 ABI 的 Rust 库；自动构建 hook |
| M1.4 应用外壳 | 自适应首页/设置、启动失败可诊断、设置内运行检查 | 小屏/大屏 widget 测试；dispose 取消，不泄漏/重复运行 |
| M1.5 验证交付 | 静态检查、核心/组件/真实桥接测试、Android/Windows Debug | 精确命令、最终产物元数据/摘要、文档同步、iOS 缺口 |

## 技术细化

采用官方 FRB 2.13 Native Assets backend 作为首先验证的打包方案，复用 `flutter_rust_bridge_hooks`，避免在三个 runner 各维护一套手工复制动态库流程。只有实际构建确认后才视为采用成功。生成器和运行包锁同一版本；代码生成与编译打包是两个独立步骤。

M1 诊断任务提供一个有界、按消费者拉取的异步事件序列，不启动无限生产的后台线程。每次读取至多一个事件；Dart 外观投影为 Stream。取消/关闭必须唤醒正在等待的事件，终态只交付一次；拒绝同一任务并发读取。此切片用于验证运行时，不冒充真实下载或助手任务。

Rust `Runtime` 拥有生命周期；每次创建会话独立，不设隐藏的第二全局业务状态。关闭禁止新任务并取消子任务，Dart dispose 释放会话。平台信息由 Rust 编译目标识别，不能由 UI 传入一个随意的字符串伪造可用能力。

## 风险、依赖与恢复点

- FRB Native Assets 是当前稳定工具提供的新集成方式，需验证 workspace 相对路径、NDK 选择、Windows MSVC、符号保留和 Android 打包；失败必须定位根因，不能用手工拷库掩盖自动构建缺陷。
- iOS 无 Apple 环境，只能审查 bundle ID、deployment target、源集及 hook 的目标映射；不得报告构建成功。
- M0 的 28 个文件是本轮既有基线，保留并仅按语义变更更新。未授权 Git 提交，阶段恢复依赖任务日记与明确文件差异，不使用清理/reset。
- 工具安装 side-by-side；不修改旧项目源码或全局默认 Rust。仓库内生成/编译产物按官方约定忽略，锁文件保留。

## README 本轮维护理由

目标读者为本项目开发者；新增真实构建/运行入口是修改理由。权威来源为本轮执行的脚本与产物。检查 Markdown 结构、链接与小屏/桌面应用布局；当前仅中文，没有需同步的英文 README。验证完成后以实际证据回填状态，不以计划替代结果。

## 后续任务拆分

M2 先落资源/授权/SQLite migration，再实现一次流式助手与带权限文件读取；没有 API 凭据时先用受控本地协议夹具验证，不自动调用外部模型。

M3 先验收原生浏览器唯一会话和资源转交，再上下载断点与后台执行；M4 先做播放器三端能力/许可 spike，再共享队列与广告规则。M5 分为 SDK/tool schema → 受限脚本 → 插件原子安装 → Skill → MCP，所有入口复用 M2 授权。M6 的终端与系统代理以各平台权限和恢复能力单独验收，不能阻塞基本工作台。M7 需要 Release、签名、迁移、依赖许可和真实设备证据。

上述依赖补充 [路线图](../roadmap.md)，当前工作状态仍以 [status](../status.md) 为唯一入口。

## M1 实际交付与复现

观察日期：2026-10-02，Asia/Shanghai。M1.1–M1.5 的限定本地验收已完成；以下记录实际结果，不代表业务或三端设备验收完成。

实际目录为 `apps/kiyori`、`packages/kiyori_bridge`、`packages/kiyori_ui`、`crates/kiyori_core` 与 `crates/kiyori_ffi`。根 Pub/Cargo workspace 统一解析依赖并保留锁文件。原生 runner 属于唯一 Flutter 应用；未为规划中的业务创建空 package。

FRB 生成器、Dart/Rust 运行库与 hooks 固定为 2.13.0。生成器安装命令：

```powershell
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked --root D:\01_Environment\Tools\FlutterRustBridge\2.13.0
```

FRB 所需 `cargo-expand` 实际安装版本为 1.0.126；Native Assets 依赖锁定 `native_toolchain_rust` 1.0.7。生成器可由 PATH 发现，本机脚本也支持受管理目录入口。复现流程在仓库根执行：

```powershell
. .\tools\activate.ps1
flutter pub get
.\tools\generate-bridge.ps1 -Check
.\tools\verify.ps1 -WindowsIntegration
.\tools\build.ps1 -Platform windows
.\tools\build.ps1 -Platform android
.\tools\check-foundation.ps1
```

Windows 集成测试将测试入口编译到常规构建目录，交付前需重新运行普通 Windows build，使 `data` 恢复正式应用入口；本轮已执行。Windows 应用需要 EXE、DLL 和 `data` 整个目录，单个 EXE 的摘要不代表完整应用内容。

Native Assets hook 自动构建与打包 Rust，Android 无手工拷库步骤。实际 Flutter 引擎集成不设置外部动态库路径；独立 Dart FFI 测试按 FRB 官方支持使用 `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR` 指向测试 DLL 目录，脚本退出恢复变量。独立测试通过与应用内打包验证是两类证据，不能相互替代。

### 验证结果

| 验证 | 实际结果 | 证据范围 |
| --- | --- | --- |
| `cargo fmt --all --check` | 通过 | Rust 格式 |
| `cargo clippy --workspace --all-targets --locked -- -D warnings` | 通过 | 工作区静态检查 |
| `cargo test`（由 verify 脚本执行） | 6 项通过 | 有界输入、事件顺序、取消、关闭、并发读取、终态 |
| Dart format / Flutter analyze | 通过，No issues found | Dart 格式与静态检查 |
| Flutter widget/controller tests | 5 项通过 | 360/1280 布局、双倍字体、延迟启动取消、重复启动、初始化中 dispose |
| 独立真实 DLL FFI tests | 6 项通过 | 初始化、能力、错误、事件、取消、关闭及未消费流释放 |
| Windows Flutter engine integration | 1 项通过 | 打包 Rust DLL、界面完成/取消诊断任务 |
| Android / Windows Debug build | 两端通过 | 当前应用与 Native Assets 打包，不是 M0 探针 |
| `generate-bridge.ps1 -Check` | 通过 | 再生成内容一致 |
| `check-foundation.ps1` | 32 个基础文件通过 | UTF-8/LF、标题、围栏、本地文件链接、JSON、PowerShell、Rust 固定版本一致 |

共 18 项行为测试。Android 最终 APK 经 aapt 检查为 `com.kiyori`、显示名 Kiyori、版本 0.1.0+1、minSdk 24、target/compile SDK 37、ABI arm64-v8a；含 `lib/arm64-v8a/libkiyori_ffi.so`（685760 字节），Debug v2 签名验证通过。built-in Kotlin 已启用，保留 Flutter 当前要求的 `android.newDsl=false`。

### 最终产物

路径相对仓库根。Android APK 最终生成时间为 2026-10-02 01:42:51；以下均为 Debug 开发产物。

| 产物 | 字节数 | SHA-256 |
| --- | --- | --- |
| `apps/kiyori/build/app/outputs/flutter-apk/app-debug.apk` | 79554155 | `BF61E2EADE48FB39938C8E54891E63BAFA5C52F3E9EB7EDC83EB29247AC04D3D` |
| `apps/kiyori/build/windows/x64/runner/Debug/Kiyori.exe` | 1270272 | `5F311E874CFA5A25A5A166EE5C8D0C50D69A24ED562B7F066CA29360F2753016` |
| `apps/kiyori/build/windows/x64/runner/Debug/kiyori_ffi.dll` | 553984 | `ECFC49E3105C203E51505CADFE20023E06EB8005C4497854CCC3A3A1D5BFDC11` |

### 问题处理与环境记录

- FRB 生成后直接 rustfmt 未使用 Cargo edition 上下文，导致生成结果和工作区格式检查漂移。生成脚本统一在结尾执行 `cargo fmt --all`，再生成一致性已通过；没有手工改生成文件。
- Native Assets 需要 crate 本地 Rust pin，因此 `crates/kiyori_ffi/rust-toolchain.toml` 与根文件同步，基础检查验证二者一致。hook 还声明根清单/锁文件和核心 crate 清单依赖，避免修改后错误复用缓存。
- Dart Stream 未消费时关闭运行时也必须释放任务。桥接实现覆盖关闭与订阅的竞争，并以真实 FFI 测试验证后续订阅结束，不残留悬挂流。
- `D:\01_Environment\manifest.json` 登记 FlutterRustBridge 与 CargoExpand；变更前备份为 `D:\01_Environment\Work\Kiyori\manifest-before-m1-20261002.json`。生成器目录通过 `current` junction 管理，环境 Validate 已通过。恢复时先核对后续改动，不整份覆盖配置。
- 安装 Apple Rust 标准库 target 只支持后续交叉编译准备，未安装 Xcode 或 Apple 链接器，不代表可在 Windows 构建 iOS。旧项目源码未改。

### 未验证边界与后续入口

Android 未安装设备，故 Rust SO 在 Android 实际加载、交互和新旧应用并存仍待设备验证；Windows 通过自动引擎测试，人工视觉、键盘和完整无障碍验收尚未进行。iOS runner 与共享源集已维护，但无 Mac/iPhone，未编译、链接、签名或运行。Release、安装器、远端 CI 与所有产品业务模块均未交付。

README 的实际命令和产物位置已核对，Markdown 结构与本地链接通过检查；没有英文副本。应用布局由自动测试覆盖，Markdown 宽窄屏人工预览未做，不将两者等同。首轮应用图标仍为 Flutter 开发模板资源，最终品牌图标属于后续 UI 设计。

下一步仅按 [M2 顺序](../roadmap.md)启动 ResourceRef 与资源授权；M1 运行检查留作开发诊断，不发展成第二套业务任务系统。
