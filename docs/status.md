# 当前实施状态

更新时间：2026-10-02（Asia/Shanghai）。此文件是实施进度唯一权威；[路线图](roadmap.md)维护阶段顺序，环境证据见[环境报告](development/environment-report.md)。

## 当前任务：四个底栏一级页面复刻

从干净 `main` / `c0be83d` 开始，只读对照旧 `Kiyori-Android` 的 `6b03b03a`，
补齐浏览器、工具箱、文件管理、设置一级页面。用户授权完成构建后全部提交推送至既有
`origin/main`。未接入业务保留空点击；不操作设备、旧数据、远端 CI 或发布服务。

**当前状态：四页实现、本地验证与 Android/Windows Debug 构建通过；设备视觉/触摸
及 iOS 保持 `verification_pending`。** 源码依据、默认外观和业务边界见
[UI 复刻契约](design/ui-parity.md)。

本轮真实交付包括一级导航与来源返回、按访问保留的展示状态、原页面几何和语义色、设置
原 PNG、浏览器原自有矢量，以及工具分组折叠。首页原 pager/AI 草稿保留；2 倍字体下的
既有品牌行/模式文字溢出已修复，未改变默认几何。

| 验证 | 实际结果 |
| --- | --- |
| `tools/verify.ps1 -WindowsIntegration` | 6 Rust + 19 Flutter + 6 真实 FFI + 2 Windows 引擎测试通过；格式、Clippy、analyze 和基础检查通过；截图用例默认跳过 |
| `ui_capture_test.dart` 显式捕获 | 1 项通过；四页最终 Flutter 渲染图已按源码检查，保存在忽略的 `work/four-pages/`；同时保留首页、负一屏、AI 回归图 |
| `tools/build.ps1 -Platform android` | Debug arm64 APK 成功；普通产品入口，未安装设备 |
| `tools/build.ps1 -Platform windows` | Debug 普通入口成功，集成测试后重新构建；DLL/data 与三张新增原图完整 |
| APK 静态检查 | `com.kiyori` / `0.1.0+1` / API 24–37 / arm64-v8a；Rust SO、三张 chrome 资源、v2 签名、ZIP 16KB 对齐通过 |
| 原资源 | 三张设置顶栏 PNG 的 SHA-256 与旧仓库逐一相同；浏览器底部与 AI 星形由原自有矢量路径投影 |

最终 APK：`apps/kiyori/build/app/outputs/flutter-apk/app-debug.apk`，2026-10-02
04:05:57（Asia/Shanghai），95,097,169 字节，SHA-256
`448DA2D549933A5A20E535867FEBE77868C5AEBBBF33D4179355514F2B077B7A`。
Windows：`apps/kiyori/build/windows/x64/runner/Debug/`，保留整个目录的 EXE、DLL 和 data。
本轮未重建 Profile/Release，不应使用目录内前轮 Profile 产物验收新页面。

无新增依赖、公共 Rust API 或平台通道变化；不要求重复桥接生成。回滚基线为上述起始提交。
首次完整验证因新增代码一处 if 缺少花括号被 analyze 拦下，修复后完整重跑通过。
Git 交付仅包含本轮源码、三张原图、测试和文档；构建、截图、日志、私有日记保持忽略。
远端 fetch 后基线仍为 `c0be83d`；最终提交与推送以交付报告及 `git log` / `git ls-remote`
核对，不在本文嵌入自身提交 SHA。没有远端 CI、设备或发布动作。

## 前轮：工程基础与输入性能治理（历史）

本轮目标为深度审查旧项目模块、完善新工程工具链/目录/命名/文档，并处理三页滑动的
额外构建开销，全部审计后提交推送。范围是新仓库工程基础和已有 UI；不迁移旧数据、
不扩展业务、不安装设备、不运行远端 CI。旧仓库 `6b03b03aa082803bb279db5e78773583e2d91154`
仅只读且保持干净。新仓库起点为 unborn `main` 和前轮 172 个未跟踪文件，原成果全部保留。

**交付状态：本地工程实现与验证完成；Android 真机手感及 iOS 为 `verification_pending`。**
旧项目全部九个 Android 模块、应用包树和领域契约已盘点，主要 owner 与首页关键实现已核对；
不是逐行完成第三方引擎或所有脚本审计。正式结果见[旧模块地图](architecture/legacy-module-map.md)。

| 本轮交付 | 已验证事实 |
| --- | --- |
| 稳定工具链 | 官方 manifest/摘要校验并存安装 Flutter 3.47.6 / Dart 3.13.5；Google Maven 确认 AGP 9.4.1 并完成真实构建；Rust 1.99.0、Gradle 9.8.0、FRB 2.13.0、NDK r30 保持 |
| 结构与语言 | feature 不再反向引用 app；共享按钮移至 kiyori_ui；运行诊断移至 app/diagnostics；正式命名/编码/依赖方向规范及轻量接线检查 |
| 领域规划 | 补齐 documents、knowledge、workflows、accounts/content、speech/avatar、backup/audit/automation/integrations 的所有权、错误/取消和阶段入口 |
| 滑动与输入 | 首帧后缓存邻页、稳定页面身份、底栏/图标子树复用、草稿局部更新；系统阈值、旧几何和空点击保持 |
| 自动验证 | `tools/verify.ps1 -WindowsIntegration`：6 Rust + 12 Flutter + 6 真实 FFI + 2 Windows 引擎测试通过；截图用例默认跳过 |
| 代码生成与文档 | `tools/generate-bridge.ps1 -Check` 通过；基础检查 40 个文档/脚本/根配置通过；flutter analyze 无问题，fmt/Clippy 通过 |
| Android | AGP 9.4.1 下 Debug/Profile arm64 APK 通过；com.kiyori、API 24/37、Rust SO、v2 签名及 ZIP 16KB 对齐核对通过 |
| Windows | Debug/Profile 普通入口构建通过；Profile driver 完成首次四次 + 热四十次分页并保存原始帧数组 |

### 性能实测与边界

Windows 11 x64、Flutter Profile、显示器 240Hz、DPR 1.5、逻辑窗口约 1265×683。
原始报告在忽略目录 `apps/kiyori/build/integration_response_data.json`；
`tools/summarize-performance.ps1` 使用微秒数组与实际刷新率，nearest-rank 计算分位数。

| 场景/阶段 | 帧数 | P50 / P90 / P99 ms | 最差 ms | 超出 240Hz 4.167ms 预算 |
| --- | --- | --- | --- | --- |
| 首次四次 / UI | 109 | 0.142 / 0.289 / 1.516 | 3.899 | 0 |
| 首次四次 / raster | 109 | 1.979 / 6.353 / 7.548 | 12.165 | 40（36.697%） |
| 热四十次 / UI | 1118 | 0.141 / 0.225 / 0.447 | 1.414 | 0 |
| 热四十次 / raster | 1118 | 1.866 / 5.479 / 7.295 | 27.070 | 382（34.168%） |

这是一轮桌面测量，不是优化前后对比，不是硬件实际呈现掉帧计数，也不能外推 Android。
UI 构建时间低，raster 仍有高刷超预算，不能宣称零掉帧或 240Hz 达标。
Windows driver 末尾报告 native integration_test plugin 未检测到的框架提示，但 VM driver
成功回收完整 JSON、测试结果及 1227 帧数据；这里采用 driver 通道，不声称跑过原生仪器测试。
下一步是目标 Android 真机旧新同模式、同刷新率至少三轮对照，并用 DevTools/Perfetto 区分
栅格化、系统呈现、输入仲裁与触摸延迟；详见[性能契约](development/performance.md)。

### 当前产物

2026-10-02（Asia/Shanghai）最终 Android 产物：

- `apps/kiyori/build/app/outputs/flutter-apk/app-debug.apk`：79,750,188 字节，SHA-256 `0589EBE5518BDAB2A0659BCE544621EA4830FC3F5D77ED01411593FEF4C46FE8`。
- `apps/kiyori/build/app/outputs/flutter-apk/app-profile.apk`：26,610,989 字节，SHA-256 `C86702A9198E12B8DFF15326A171065E1EA2D2FF65254573026A14CD7AB60CC5`。
- Windows 普通入口在 `apps/kiyori/build/windows/x64/runner/Debug/` 与 `Profile/`；使用时保留整个目录的 DLL/data，不能只复制 EXE。基准执行后已重新构建普通产品入口。

### Git 交付契约

用户本轮明确授权全部提交推送，目标为 `main` 与既有 `origin`。首次提交包含前轮成果和
本轮优化；候选树已排除 SDK、构建产物、本机配置、凭据、缓存、日记和临时记录。
推送前重新确认远端仍无 refs，不覆盖其他历史。最终 SHA 与远端结果由本轮交付报告和
`git log` / `git ls-remote origin refs/heads/main` 核对，本文件不嵌入自身提交 SHA。

## 前轮：原 UI 复刻（历史）

用户明确重构目的为目录与实现治理及多平台支持，UI 保持原项目设计。本轮已替换应用图标，落实三页外壳、五图标底栏原参数、搜索/AI 模式与 AI 本地草稿；未接入按钮仅保留点击/选中反馈，业务为空操作。源码映射和验收见 [UI 复刻契约](design/ui-parity.md)。24 项行为测试、独立截图检查及 Android/Windows Debug 构建已通过；原设备的并排视觉/触摸和 iOS 编译仍为 `verification_pending`。

## M1 可运行工程骨架（历史）

M1 本地工程骨架已完成，详细契约、计划与最终证据见 [M1 实施与验收](development/m1-foundation.md)。Android 设备行为与 iOS 编译仍为 `verification_pending`，不影响本轮限定的本地骨架验收；业务功能尚未实现。本次起点保留 M0 的 28 个未提交文件，不提交推送、不安装设备、不运行远端 CI。

| 项目 | 当前状态 | 证据或剩余任务 |
| --- | --- | --- |
| Pub / Cargo workspace 与三端 runner | 已实现 | 正式应用 `apps/kiyori`；Android/iOS ID `com.kiyori`，Windows `Kiyori.exe` |
| Rust 生命周期与任务契约 | 已验证 | 6 项测试；Clippy `-D warnings` 通过 |
| FRB 2.13 + Native Assets | 本地集成已验证 | 独立 FFI 6 项、真实 Windows Flutter 引擎集成 1 项通过；Android APK 含 arm64 Rust SO |
| 自适应应用外壳与设置检查 | 已验证自动测试 | 5 项界面/生命周期测试；360/1280 宽度及双倍字体无 overflow |
| Android Debug APK | 构建及静态验包通过 | `com.kiyori`、API 24/37、arm64-v8a、Rust SO 与 v2 签名；未安装设备 |
| iOS 源集 | 已维护，待编译 | iOS 15+、bundle ID、Apple Rust targets；无 Mac/iPhone |
| 开发脚本与最终文档 | 已验证 | build/verify/generate 已落地；代码生成一致性与基础文档检查通过 |

## M0 任务契约（历史）

- 目标：为全新 Kiyori 确定语言框架、目录命名、模块职责，建立专业 docs 与必要项目基础，并准备/验证当前 Windows 可执行的工具链。
- 范围：Android/Windows 优先、iOS 同步设计；工具版本官方核验、本机 side-by-side 安装、最小构建、文档与基础检查。
- 非目标：业务实现、复制旧项目、旧数据迁移、设备操作、购买 Apple 资源、远端 CI、提交推送或发布。
- 风险与回滚：多语言/FFI 增加打包成本，M1 先验证；环境修改已备份，原工具保留；iOS 缺口不伪装为完成。
- 验收：文档覆盖请求的模块与边界，命名一致，版本可追溯，Windows/Android 工具探针真实产物可核验，清楚标明未实现/未验证部分。

## M0 交付（历史快照）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| 技术选型与目录命名 | 已完成 | ADR 0001、仓库布局、命名、整体架构 |
| 所有请求模块的基础规划 | 已完成 | 模块目录、AI/扩展、浏览器/网络、文件/下载/媒体、平台和数据设计 |
| docs 与仓库基础文件 | 已完成 | 文档导航、根契约、版本配置、激活与检查脚本 |
| Windows / Android 基础环境 | 已完成 | doctor 无问题、Flutter EXE/APK、Rust DLL/arm64 SO 与摘要 |
| 正式 Kiyori 应用及 FRB 集成 | 未开始 | 规划进入 M1，不把工具探针当产品 |
| iOS 环境与构建 | 待验证 | 用户无 Mac/iPhone；已完成设计，不声称已编译 |
| 文档/配置静态验收 | 已完成 | 基础检查 28 文件通过；人工审查模块/依赖/边界，表格列数、文件大小、符号链接与明显凭据/品牌扫描通过 |

## M0/M1 Git 基线与授权（历史）

新仓库为 `D:\10_Project\Kiyori`，origin 指向 `https://github.com/Kiyori-CN/Kiyori.git`，分支为尚无提交的 `main`，不存在 HEAD。M0 起点只有 `.git`；M1 起点已有 28 个未提交文件。M1 收尾时共 148 个未跟踪交付文件，未暂存、未提交、未推送，构建目录与本机配置已忽略。远端空分支列表是 M0 的只读观察，本轮未做远端写入。旧项目源码未修改。

## 下一完成门槛

优先取得 Android 三页真机 Profile/真实手指对照证据，消除现有手感疑问，避免接入重页面后
扩大问题；随后推进 M2.1：ResourceRef、workspace 范围、调用来源、授权撤销和平台文件读取。
后续每个 feature 按模块地图核对旧源码，并带自己的性能场景。外部 API、设备操作与远端 CI
按对应授权执行。iOS 若仍无 Mac，同步接口与源集并保留待编译状态。

## 文档验收说明

根 README 面向新项目使用者/开发者；M0 建立定位与导航，M1 补充真实构建/运行入口，权威来源为脚本和实际产物。当前仅中文，无双语副本。Markdown 结构与本地链接通过检查，应用宽窄屏及双倍字体通过自动测试；未做 Markdown 宽窄屏人工渲染或完整应用视觉验收，不能混称为已通过。
