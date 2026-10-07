# 模块目录与验收边界

本文区分现有实现与目标领域。`core` 指 `crates/kiyori_core/src`，`feature` 指 `apps/kiyori/lib/features`，`platform` 指 `packages/kiyori_platform`；它们是文档缩写，不是新的目录根。

## 当前代码边界

| 入口 | 当前职责 | 核对来源 |
| --- | --- | --- |
| `apps/kiyori/lib/app` | 启动、Runtime 装配、一级导航与详情路由 | HomeShell / SettingsNavigation |
| `apps/kiyori/lib/features` | 16 个已有领域的 UI 与交互状态 | 实际目录；数量不等于完成页面数 |
| `kiyori_core` | 会话、模型、知识、定义目录、资源、扩展及统一存储 | `src/lib.rs` 与私有 `storage.rs` |
| `kiyori_ffi` / `kiyori_bridge` | 句柄、DTO、生成协议与 Dart 外观 | Cargo / Pub workspace |
| `kiyori_platform` | 凭据、文件交换、推理、脚本及审计适配 | Dart 包与 native/scripts/audit 三个 Rust 成员 |
| `kiyori_ui` | 语义颜色、排版及无业务 UI 原语 | 包公共导出入口 |

具体接线见[模块实现](module-implementation.md)，生命周期见[运行契约](runtime-contracts.md)。Rust 小领域保留 `models.rs`、`storage.rs` 等文件，大模块使用 `chat/`、`extensions/`；不为匹配目标图而移动实际代码。

## 目标领域与完成信号

以下为目标归属；路径可能尚未创建，不能当作当前 API 或实现承诺。当前助手实现分布在 `chat`、`conversations`、`models` 等模块；审计实际为 `conversation_audit` / `audit_crypto`，不另建 `assistant` 或 `audit` 副本。

| 模块与代码位置 | 所有者与数据 | 依赖、输入输出 | 关键验收 |
| --- | --- | --- | --- |
| AI：`core/assistant`、`feature/assistant` | 会话、消息、Run、provider 配置 | 输入消息/附件引用；调用 tools、tasks、storage、network；输出有序事件 | 流式中断、工具拒绝、结果未知、恢复均有准确状态 |
| 工具系统：`core/tools`、`feature/toolbox` | 描述、schema、调用记录；工具箱只是展示入口 | permissions + 具体领域服务；输入参数，输出类型化结果/资源引用 | 同一工具的手动/AI 调用行为一致，调用者不可伪造 |
| Script：`core/scripts` | 执行上下文、预算、宿主 API 会话 | 工具系统与受限执行器；源码/输入 → 有界输出 | 超时、中止、内存/输出限额、无授权网络/文件访问被拒 |
| Plugin：`core/extensions/plugins`、`feature/extensions` | 包 manifest、安装版本、授权、启停状态 | 校验与原子安装；公开 SDK；不直连 DB | 损坏包、路径穿越、版本冲突、撤权和升级回滚 |
| Skill：`core/extensions/skills` | manifest/索引、内容、按需上下文加载 | 标准 SKILL.md；可选脚本经 scripts 执行 | 格式解析、引用边界、内容不会提升权限 |
| MCP：`core/extensions/mcp` | 连接、会话协商、工具/资源映射、凭据引用 | Streamable HTTP；可用平台的 stdio；统一调用策略 | 重连/取消/协议版本协商、工具变更和恶意返回处理 |
| Browser：`core/browser`、`feature/browser`、native browser | Rust 保存标签/历史；原生实例拥有页面和 Cookie 生命周期 | network/adblock 策略、download/file/media 转交 | 同一标签唯一 WebView，销毁无悬挂，弹窗/下载/权限可解释 |
| Files：`core/files`、`feature/files`、native files | ResourceRef、授权根、收藏、操作任务 | 路径/URI/bookmark → 可读写资源；权限与任务服务 | 撤销授权、重命名冲突、不可 seek、取消/错误均闭环 |
| Downloads：`core/downloads`、`feature/downloads`、native transfers | Transfer 与断点信息，OS task ID | network、files、tasks；请求 → 临时资源 → 原子交付 | ETag 变化、Range 不支持、断网、空间不足、后台恢复 |
| Media：`core/media`、`feature/video`、`feature/music`、native playback | 一个媒体库/队列，原生引擎一个活跃会话 | 文件/网络资源、音频焦点、系统媒体控制 | 连播、seek、后台切换、耳机拔出、窗口关闭不泄漏 |
| Adblock：`core/adblock`、native browser filters | 订阅与版本化规则快照、站点豁免 | 网络获取规则、平台特定编译与加载 | 无效更新不破坏现用快照；命中来源可查；三端差异明确 |
| Network：`core/network`、native network | 代理配置、域策略、连接诊断 | 应用 HTTP 与系统引擎能力；不拥有浏览标签 | DNS/代理作用范围、认证失败和不可代理能力可见 |
| Terminal：`core/terminal`、`feature/terminal`、native terminal | 会话元数据、进程/PTY 原生句柄 | permissions、tasks、显式工作目录/env | 取消进程树、输出背压、退出码、与旧应用 home/服务隔离 |
| Settings：`feature/settings` | 各领域设置的展示，非平行全局数据库 | 类型化查询和命令；版本化设置 | 修改原子生效，有效范围清晰，迁移不会静默丢值 |
| Documents：`core/documents`、`feature/documents`、native documents | 文档、revision、草稿、保存状态与阅读位置 | files、格式解析器和单前台渲染/编辑引擎 | 大文档分段不截断、整行翻页、未知保存结果与恢复 |
| Knowledge：`core/knowledge`、`feature/knowledge` | 同一空间的记忆/日记/知识、关系、归档与派生向量 | storage、files、授权 embedding provider | UUID/空间隔离、模型与内容指纹、索引失效与导入 |
| Workflows：`core/workflows`、`feature/workflows` | 定义、运行快照、节点状态与恢复 | tools、permissions、tasks | 依赖环、取消、部分失败、恢复不重做未知副作用 |
| Accounts：`core/accounts`、`feature/accounts` | 产品账号和凭据引用 | 平台安全存储、network、browser 明确导入 | 登录/退出原子性、身份变化与脱敏 |
| Content：`core/content`、`feature/bilibili` | 内容查询和分页，不拥有播放/下载 | accounts、network；资源交给 media/downloads | 五栏/分页、过期资源、请求身份与取消 |
| Speech：`core/speech`、native speech | STT/TTS 配置与会话，原生录音/播放句柄 | permissions、音频与 provider adapter | 租约切换、撤权停录、流背压和实例释放 |
| Avatar：`core/avatar`、`feature/avatar`、native avatar | 角色资源配置与渲染会话 | files、原生纹理/渲染后端 | 离屏暂停、模型加载限额、格式支持与资源释放 |
| Backup / Audit：`core/backup`、`core/audit` | 版本化导出恢复、执行修订证据 | storage、files、安全存储 | 校验失败不覆盖、恢复事务、凭据/设备密钥边界 |
| Automation / Integrations：`core/automation`、`core/integrations` | 系统动作与外部入口会话 | permissions、tools、平台能力 | 来源认证、权限撤销、显示/进程取消与平台限制 |

## 基础模块

| 模块 | 边界 | 关键约束 |
| --- | --- | --- |
| permissions | 能力授权、资源范围、调用来源与撤销代次 | 执行前及重要副作用前检查；OS 已授权不等于用户授权 AI |
| tasks | 任务 ID、取消、进度、结果与诊断关联 | 各领域保留自己的状态机，不把所有行为强塞进万能任务表 |
| storage | SQLite 连接、事务、迁移、blob 引用与导出 | 领域经仓储接口访问；Dart/插件不能直写 DB |
| platform | 能力查询与宿主服务端口 | 不可用返回结构化原因，不在核心散落平台判断 |
| diagnostics | 脱敏日志、trace ID、性能与错误摘要 | 初期作为核心公共模块按需要创建；默认不外发 |
| kiyori_ui | 颜色、字体、组件、响应式与可访问性 | 仅 UI 原语，不含具体领域请求或数据库 |
| kiyori_bridge / kiyori_ffi | 跨语言 DTO 与命令、事件和装配 | 不创造第二领域模型，生成文件不得手工修改 |

## 依赖顺序

基础资源/权限/任务 → 文件和网络 → AI 与工具 → 浏览器/下载 → 媒体 → 扩展与高级系统能力。浏览器、媒体可与 AI 迭代并行，但权限与资源模型必须共用。扩展执行器和完整终端不应阻塞第一条 AI + 文件闭环。

新增领域先写清权威状态、输入输出、生命周期、平台能力、错误/取消和测试夹具，再建立目录。具体 API 在首个真实调用时定稿，避免设计大量无人调用的接口。

旧项目覆盖与来源见[旧模块地图](legacy-module-map.md)；补充领域的详细约束见
[文档、知识与工作流](../design/documents-knowledge-and-workflows.md)。本表为目标归属，不代表这些目录已存在。
