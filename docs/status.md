# 当前实施状态

更新时间：2026-10-07（Asia/Shanghai）。本文是实施进度唯一入口；[路线图](roadmap.md)维护长期顺序，批次证据见[10 月归档](status-history-2026-10.md)与[较早归档](status-history.md)。

## 当前任务：架构、命名与文档治理

状态：实现与本机自动验证完成，进入 Git 交付；文档宽窄屏视觉检查待验证。基线为 `main / 138f42ea419d2407f7ceb3ec7abb6ad8da1f88be`，开始时工作树干净；旧项目只读基线为 `Kiyori-Android / 6b03b03`。本任务包含提交和普通推送，不包含发布、部署、设备安装或真实供应商调用。实际提交与远端结果以 Git ref 和交付记录为准。

目标是修正文档与源码偏差、完善文件职责与命名、保留历史证据，并修复已证实的开发工具问题。内部组织遵循现有 Flutter / Rust 边界；产品 UI、布局、配色、文案、功能、逻辑、交互、跳转、回退、弹窗和抽屉完全按旧源复刻。

| 阶段 | 交付 | 当前状态 |
| --- | --- | --- |
| 发现 | 核对旧项目、源码目录、存储与命令入口 | 已核对 |
| 整理 | 精简根文档，分离指南/契约/测试/归档，修正现状与规划 | 已完成 |
| 验证 | 基础检查、工具回归、完整 verify、双端构建与差异审阅 | 自动验证通过；文档宽窄屏视觉检查待验证 |
| 交付 | 精确暂存审计、提交、普通推送、远端 ref 核对 | 已审阅 69 文件清单；Git 结果以交付记录为准 |

## 当前产品进度

| 领域 | 实际实现 | 尚未闭合的验收或功能 |
| --- | --- | --- |
| 工程基础 | M0/M1 的 Flutter、Rust、FFI、Android/Windows 骨架 | iOS 编译、签名与设备验收 |
| M2 助手闭环 | SQLite、配置、凭据、文字会话、角色、总结、标题、历史与审计 | 统一工具与真实文件附件完整闭环 |
| 模型与扩展 | 本地前台下载/CPU 推理、TOOLPKG 管理与受控 HTTP | GPU/媒体、依赖/环境/子包、其它扩展形态 |
| 知识与工作流 | 空间、记忆、日记、图谱、检索设置、工作流定义 CRUD | 云嵌入、自动记忆、节点执行与调度 |
| 设置与产品壳 | 旧源页面、默认态与嵌套交互；部分真实持久化切片 | 未接入页面仍为空动作；完整平台业务需按领域推进 |
| 性能与保真 | 本机组件/协议/FFI 回归及历史截图证据 | 同设备像素、字体、触摸、Profile 与 Apple 实测 |

## 近期产品基线与剩余事项

前一任务“对话历史左抽屉旧源还原”仍为部分完成：目录、滑动、分组、设置、开场白与独立标题已有本机证据，完整旧工具/附件事实及设备保真未完成。本次文档归档不改变这一状态。来源与验收见[历史复刻方案](design/chat-history-replication.md)、[ADR 0017](decisions/0017-character-opening-messages.md)和[ADR 0018](decisions/0018-independent-conversation-titles.md)。

历史构建、测试数字和固定产物哈希保留在[10 月记录](status-history-2026-10.md)。它们证明对应提交和批次，不证明本次修改已验证；本轮证据在下节单独记录。

## 本轮变更与验证

根 README 面向使用者与新贡献者；此次修改理由为入口被逐控件细节淹没。事实来源为当前源码、正式 ADR 与上一批状态；细节迁入用户指南，领域语义迁入运行契约，测试清单单列。原 status 的 1,657 行批次正文逐字保留在 10 月归档。项目当前仅维护中文入口，无英文副本需要同步。

检查器补齐严格 JSON 解析、Markdown 围栏/表格与文档中心覆盖检查；共享测试夹具进入 `test/support/`，测试套件不再相互导入。完整验证发现时间线使用惰性列表估算末端，备注已保存却留在视口之外；按旧 `ConversationDetailsScreen.kt:654` 的末项定位语义逐帧校准，用户操作时撤销，回归覆盖上翻保位、新事件跳转和停止调度帧。

2026-10-07 本机证据（源基线 `138f42e` 加本批工作树）：

| 命令或审阅 | 实际结果 |
| --- | --- |
| `tools/check-foundation.ps1` | 81 文件、3 JSON；编码、结构、链接、导航及既有依赖边界通过 |
| `tools/test-tooling.ps1` | 19 内容用例、4 桥接输出清单用例通过 |
| `tools/verify.ps1 -WindowsIntegration` | 退出码 0；Rust 231 通过 / 3 忽略；应用 692 通过 / 17 跳过；平台 15 通过；桥接 22 通过 / 1 跳过；Windows 引擎 5 通过；格式、Clippy、analyze 通过 |
| `tools/build.ps1 -Platform android -NoPub` | arm64 Debug APK，`com.kiyori` / `0.1.0`；137,866,897 bytes |
| `tools/build.ps1 -Platform windows -NoPub` | 引擎测试之后重新构建普通应用入口；完整 bundle 101 文件 |
| 迁移与 Markdown 审阅 | 61 篇 Markdown 可生成 HTML；旧批次正文完全保留，拆分内容按新归属复核，补齐 10 处标题空行 |

日志保存在忽略的 `work/governance-verify.log`、`work/governance-build-android.log`、
`work/governance-build-windows.log`；Windows 完整文件哈希清单在 `work/governance-windows-manifest.json`。
APK 路径为 `apps/kiyori/build/app/outputs/flutter-apk/app-debug.apk`，SHA-256：
`70BFF6FC66F054E6BFDB4387C51317EAFE26B2E3F219627A6B37D1E759E3A6C6`。
Windows 普通包目录为 `apps/kiyori/build/windows/x64/runner/Debug/`，EXE SHA-256：
`BCB78A256A23E74F07A30D3732AC6EF7246F5D19C50D39256753412621E02C3F`。
原生 EXE/DLL 可被增量构建复用；本次 Dart 入口产物以该目录的 `data/flutter_assets/kernel_blob.bin`
及完整清单为准，不能只靠 EXE 时间判断是否更新。kernel SHA-256：
`FB6C867E9608176000AA199312965A0BD046EF7CFF08134481882FA0303E2F5C`；完整清单 SHA-256：
`4BF60C2470EDC872E7F530C075BD1DF474732D9815327B1F1ADC3CA58DC5C86C`。

未执行真实供应商/完整本地模型、设备安装、像素/触摸/Profile、iOS、远端 CI 和发布。
默认跳过项需要相应外部配置或捕获开关，本轮未启用。浏览器策略拒绝 `file:` 预览；
未绕过限制，因此生成 HTML 和结构审阅不计作宽窄屏视觉验收。

## 下一完成门槛

1. 核对本批 Git 交付记录；在允许的本地 Markdown 预览环境补验宽窄屏排版。
2. 产品后续按[历史复刻方案](design/chat-history-replication.md)补齐统一工具与文件附件，复用同 Runtime / ResourceRef / 授权；不新建平行状态。
3. 对指定设备完成保真与 Profile 验收；Apple 构建需 Mac 环境。设备、真实供应商和外部资源操作必须有对应授权。
