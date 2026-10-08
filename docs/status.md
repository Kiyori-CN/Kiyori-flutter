# 当前实施状态

本轮交付复验日期：2026-10-08（Asia/Shanghai）；首轮实施跨越 10 月 7–8 日。本文为实施进度唯一入口，长期顺序见[路线图](roadmap.md)，历史证据见[10 月归档](status-history-2026-10.md)。

## 当前任务：五平台工程基础与架构完善

状态：本轮限定范围实现与本机验收已完成；2026-10-08 重新执行完整验证、Windows 引擎集成、Android/Windows 普通构建与产物审计，全部通过。iOS/macOS/Linux 保持 source_ready / verification_pending。实现基线为 main / c71e60623dfda867de068e0fda09dad54e493eb6，首轮开始时工作树干净。本次用户已授权全部提交推送，Git 交付结果由本批提交与 main / origin/main 核对；未执行设备安装、远端 CI、发布或部署，旧 Kiyori-Android 未修改。

目标是在保持产品 UI、业务所有权、数据格式和旧源行为的前提下，为 Android、Windows、iOS、macOS、Linux 建立可维护工程。强制验收为 Android arm64 Debug APK、Windows x64 Debug bundle 与 Windows 引擎集成；其它平台仅工程准备，必须显式保留未构建和业务缺口。

| 阶段 | 交付 | 当前状态 |
| --- | --- | --- |
| 调查 | 平台工厂、runner、原生构建、FFI、命名与文档调用链 | 完成 |
| 实现 | 新 runner、凭据接线、共用构建代码、命名与文档矩阵 | 完成 |
| 定向验证 | 工具路由、系统存储、原生目标映射及不支持边界 | 已通过初轮检查 |
| 完整验证 | verify、Windows 引擎、双端普通构建及产物审计 | 全部通过；其它平台运行待验证 |

## 当前产品进度

| 领域 | 实际实现 | 尚未闭合 |
| --- | --- | --- |
| 工程基础 | 五平台 Flutter runner，Rust/FFI，共用构建入口 | iOS/macOS/Linux 首次编译、运行和原生适配 |
| M2 助手 | 配置、文字会话、角色、总结、标题、历史与审计 | 统一工具与文件附件完整闭环 |
| 模型与扩展 | Android/Windows CPU 推理与 TOOLPKG；共享下载/配置 | Apple/Linux 引擎、GPU/媒体、完整旧包宿主 |
| 知识与工作流 | 知识/记忆/日记/关系、检索设置、工作流定义 CRUD | 云嵌入、自动记忆、节点执行与调度 |
| 产品壳与设置 | 旧源页面及部分真实持久化切片 | 未接入仍为空动作；无障碍、触摸和像素验收 |
| 性能 | 既有组件/协议/FFI 回归 | 同设备 Profile、字体、高刷和生命周期验收 |

前序历史抽屉复刻仍为部分完成，统一工具/附件和设备保真未闭合。前次文档宽窄屏视觉验收仍待验证；本轮平台治理不改变这些产品状态。

## 本轮架构与文件变更

- macOS/Linux runner 由锁定 Flutter 3.47.6 模板生成，元数据由 Flutter 更新；同一 Dart 入口，macOS 使用已有品牌图标，应用名 Kiyori，Linux 程序名 kiyori。
- SystemSecretStore 复用现有 Android/Apple/Linux 系统插件，工厂与实现分离；Windows DPAPI 格式、Android namespace 和 iOS accountName 不变。限制统一按 UTF-8 字节计算。
- native 目录更名 inference；Cargo、hook、文档和测试同步。build_support/cmake.rs 共用 CMake 查找、NDK/ABI 配置和输入追踪，未接入 Windows 架构直接拒绝。
- build.ps1 支持五目标并提前拒绝错误宿主；Rust targets 覆盖五平台并保持两个 pin 与 toolchains.json 一致。
- [ADR 0019](decisions/0019-five-platform-foundation.md)记录取舍，[平台矩阵](design/platforms.md)区分源码、能力接线与真实构建，命名/布局/路线图同步。

## 本轮验证证据

初轮平台测试 18 通过；构建路由 15 组、内容工具 19 项、桥接输出清单 4 项和原生目标映射 4 项通过。完整验证初次发现 Native Assets 要求显式 toolchain.targets；已按锁定依赖源码修复并重跑，没有升级依赖、修改第三方源码或降低检查。

首轮证据（源基线 c71e606 加工作树，实际执行跨 10 月 7–8 日；本次交付复验见下节）：

| 命令/审阅 | 实际结果 |
| --- | --- |
| `tools/check-foundation.ps1` | 84 文件、4 JSON；编码、链接、目录、Rust 版本/target 一致性通过 |
| `tools/test-tooling.ps1` | 15 宿主路由、19 内容、4 桥接输出清单用例通过 |
| `tools/verify.ps1 -WindowsIntegration` | 退出码 0；Rust 236 通过/3 忽略；应用 692 通过/17 跳过；平台 18 通过；桥接 22 通过/1 跳过；Windows 引擎 5 通过；fmt/Clippy/analyze 通过 |
| `tools/build.ps1 -Platform android -NoPub` | 退出码 0；arm64 Debug APK；com.kiyori / 0.1.0；minSdk 24 / targetSdk 37；137,870,646 bytes |
| `tools/build.ps1 -Platform windows -NoPub` | 退出码 0；引擎测试后重新构建普通入口；完整 bundle 101 文件 |
| 静态工程与差异审阅 | 18 Apple XML 解析通过；无大小写碰撞；迁移的六个推理源码/清单保持 blob 一致；锁文件及 Android/Windows runner、产品页面源码无变化 |

APK：`apps/kiyori/build/app/outputs/flutter-apk/app-debug.apk`，SHA-256：
`EE250C8FC3B9A76747986DB67A12E803CB4E7C688951DB9626DF9BEC0BD719AC`。
APK 仅含 arm64-v8a；libkiyori_ffi.so、libflutter.so、libdartjni.so 与 Debug 验证层齐备。

Windows 普通包：`apps/kiyori/build/windows/x64/runner/Debug/`。完整清单保存在
`work/platform-windows-manifest.json`，SHA-256：
`68C8448CE55B5101F5D42CFCF3561A24DBD387CD520A08F7589DD9F3F4D1D76F`。
EXE SHA-256：`BCB78A256A23E74F07A30D3732AC6EF7246F5D19C50D39256753412621E02C3F`；
kernel SHA-256：`D30C80B7A602BB61D970E86BBA484B11B8BA2DE0564EF8388BBF21F3EAD3B199`。
原生 EXE 可被增量复用，因此不能仅凭其时间或摘要判断 Dart 入口，需结合 kernel 和完整 bundle。

完整日志位于忽略的 `work/platform-verify.log`、`work/platform-native-tests.log`、
`work/platform-build-android.log`、`work/platform-build-windows.log`；产物摘要在
`work/platform-artifacts.json`。临时模板、脚本、日志、缓存和产物不进入交付。
默认跳过项需要真实供应商、完整模型或截图配置；本轮未执行设备、Profile、Release/签名、
iOS/macOS/Linux 编译和远端 CI。Apple XML 与 mock 不能代替原生编译或钥匙环运行验收。

### 2026-10-08 交付复验

本次在同一实现基线上重新执行正式入口，未修改产品源码或锁文件。最新交付证据如下：

| 命令/审计 | 实际结果 |
| --- | --- |
| `tools/verify.ps1 -WindowsIntegration` | 退出码 0；基础检查 84 文件/4 JSON；Rust 236 通过/3 忽略；应用 692 通过/17 跳过；平台 18 通过；桥接 22 通过/1 跳过；Windows 引擎 5 通过；格式、Clippy、analyze 通过 |
| `tools/build.ps1 -Platform android -NoPub` | 退出码 0；assembleDebug 164.6 秒；arm64 Debug APK，137,873,580 bytes |
| `tools/build.ps1 -Platform windows -NoPub` | 退出码 0；Windows 引擎集成后重新构建普通入口，36.6 秒；完整 bundle 101 文件 |
| APK 与 Windows 原生产物 | APK 的 com.kiyori / 0.1.0 / minSdk 24 / targetSdk 37 / arm64-v8a 核对通过；Debug 签名及 16 KB 对齐通过；Windows EXE、Flutter DLL、Rust FFI DLL 的 PE 目标均为 x64 |
| 交付源码审阅 | 六个迁移的推理文件保持原 Git blob；18 个 Apple XML 解析通过；未发现敏感配置、密钥模式、重解析链接或异常大文件 |

本次 APK SHA-256：`229E858BA03B3D8E3FD00F9FA51F15A9AA5516372CC1501C82FA74B6DA9E2235`。
Windows 普通入口 kernel SHA-256：
`46CA26F740F872A4CF4F270C99386FFE145D6D0726CF0F9C34CC71B575FFCCD0`；
EXE SHA-256 仍为首轮记录值。完整 Windows 清单 SHA-256：
`75E33BC06E0800A4310B65F4D3391867CE39CA365CBCFE6FA5ECEB35DABCFDC9`。

本次日志位于忽略的 `work/delivery-20261008-eb89256f-verify.log`、
`work/delivery-20261008-eb89256f-build-android.log` 与
`work/delivery-20261008-eb89256f-build-windows.log`；产物摘要及完整清单分别为
`work/delivery-20261008-eb89256f-artifacts.json`、
`work/delivery-20261008-eb89256f-windows-manifest.json`。这些本机证据与构建产物不进入 Git。
本次复验不扩大首轮的设备、其它平台、真实供应商、Profile、Release 和远端验收范围。

## 下一完成门槛

1. 在 macOS/Linux 对应宿主完成首次构建、插件注册、Native Assets、启动及钥匙环实测；iOS 继续需要 Xcode。源集准备不代表功能完成。
2. 按平台矩阵逐项接入文件交换、推理、脚本、审计，保持同一 Runtime 和明确错误。后续产品工作仍按旧源推进完整工具/附件与设备保真。
3. 本批按当前授权提交推送，Git 交付以实际提交和远端 ref 为准。发布、设备和其它平台运行验收分别处理。
