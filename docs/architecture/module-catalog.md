# 模块目录与验收边界

本表描述目标模块，全部业务仍待实现。`core` 指 `crates/kiyori_core/src`；`feature` 指 `apps/kiyori/lib/features`；`native` 指 `packages/kiyori_platform`。不存在“其它功能都放工具箱”的兜底模块。

详情路由由 app 的 `SettingsNavigation` 装配，feature只提供页面/快照/类型化回调。
目录按现有领域继续迭代，不按单页拆package；`video`与`music`保留UI语义，共享播放事实
未来归media领域，不新建平行player状态。捕获测试辅助只在test/support，不进入产品依赖。

当前已有 `feature/assistant/presentation` 及 browser、toolbox、files、settings 的一级 UI。
已追加 browser 设置及子页、downloads 设置、files 设置、video 设置及字幕/声音/弹幕/控制栏子页，
toolbox 设置与常用/分组/批量选择抽屉。工具箱入口展示目录共用，非领域工具注册表。
documents 设置及说明弹窗、files 格式选择器、music 设置和音源导入/备份确认也已加入
UI 投影；没有加载文档、播放、下载、调用系统选择器或实际导入导出。
settings 追加更多功能、存储汇总、产物目录编辑和网络代理默认态，app 负责跨领域导航。
工作台顶栏/固定底栏在 kiyori_ui，输入草稿仍局部持有；路径与代理外观校验不构成
文件访问、授权或网络策略，未来领域 owner 必须重新验证并返回权威快照。
settings 中的备份页面以 BackupPresentation 投影原始计数、配置和会话选择，
不建立备份存储或扫描器；法律、开源阅读和权限分组同属展示层，系统事实由后续 adapter 注入。
settings/presentation/appearance 按原五标签拆分，聊天面板持有样式草稿，编辑器与预览
共享该草稿；媒体路径与全局主题事实尚未接入，不建立第二配置存储。
accounts/presentation 由 AccountPresentation 投影未连接、已连接、读取、失效及错误，
包含方式选择与退出/移除确认；不拥有凭据存储、登录控制器或 WebView。
assistant/presentation 的设置入口通过类型化回调交给 app 装配。
assistant/presentation/avatar 投影模型目录、预览、六类型参数、Mood绑定与导入指南；
参数草稿按模型ID及存在期隔离，菜单/编辑路由随宿主释放。当前没有资源导入、持久化或
原生renderer，无adapter时显示旧不支持分支；不建立平行配置存储或动画运行时。
appearance 的 global_display_page 与 layout_adjustment_page 只投影旧默认值和验证外观，
不接 DisplayPreferencesManager、UserPreferencesManager、前台服务、Root 或截图管线。
onboarding/presentation 保存引导导航和本次草稿，复用 settings 的法律正文及权限目录；
app 用全屏模态路由装配重看入口，系统权限和首启完成均不在 UI 中写入。
assistant/presentation/history 投影聊天概览、角色/群聊统计、批量归类和无绑定工作区，
复用 settings 的卡片外观；只读快照由后续领域 owner 注入，不另建聊天库或文件扫描器。
assistant/presentation/context 持有上下文/总结/历史媒体局部表单，字段与错误按局部
监听更新；不复刻旧偏好存储与自动保存协程，真实写入后续统一交给模型配置 owner。
assistant/presentation/models 目前投影11功能的模型分配卡片与配置/模型两层展开，
共享摘要类型不包含凭据；管理配置由 app 接线，测试不构造客户端或发起网络请求。
同目录模型/API页按连接配置、上下文/请求头/高级卡片、参数与标签编辑器拆分；每个已访问
配置子树保留独立草稿，配置目录变化按 ID 对齐。供应商协议目录是只读展示常量，密钥仅随
局部输入控制器存活，领域配置 owner 仍待接入，不复制旧自动保存或服务刷新流程。
assistant/presentation/prompts 包含角色/标签目录快照、中文默认角色、编辑与嵌套绑定弹层。
复用 models 的配置摘要，不持有角色、标签、群组或活跃目标的业务存储；弹层仅有局部
草稿与自己的路由释放责任。group_card_tile/editor 投影群组列表、成员下拉与编辑草稿；
群组无独立模型/记忆/工具配置，成员引用角色 ID。真实 CRUD 仍待后续领域接入。
assistant/presentation/permissions 投影工具目录与授权草稿，允许/禁止例外共用一个映射；
不建立权限裁决器。assistant/presentation/profile 包含资料编辑、语法颜色与静态 Markdown
预览；AST 仅随正文变化解析，不加载外部媒体，不替代未来共享流式聊天 renderer。
资料快照、旧档案与保存结果后续由领域 owner 注入，当前不接文件读写或剪贴板。
assistant/presentation/server 投影 HTTP 配置、状态、地址与旧调用示例，不持有 socket、
网卡探测或令牌生成器。replies 持有回复参数与自定义表情 UI；打包素材目录和类别选择是
展示模型，未来角色范围、增删和资源引用由共享领域 owner 接入，不建第二角色数据库。
assistant/presentation/usage 将已折算金额、请求/Token计数和模型价格映射成统计卡片与
分布图；定价弹窗只保存控制器草稿，真实计价、汇率和重置仍归领域层。
speech/presentation 已有语音配置选择/名称弹窗与 STT 三引擎表单；独立配置草稿随页面
存活，不创建识别器、音频设备句柄或远程客户端。TTS 追加九引擎设置、清理规则、
系统/远程目录选择及朗读工具页，复用同一展示快照边界；语音唤醒包含三组设置与
个人录入、附件编辑/新建/删除弹窗，不建立监听器、录音器、上下文抓取器或偏好仓储。
这些 UI 只投影旧默认外观与局部展示草稿，业务调用保留空点击；这不改变下表的业务待实现边界。

## 产品模块

| 模块与代码位置 | 所有者与数据 | 依赖、输入输出 | 关键验收 |
| --- | --- | --- | --- |
| AI：`core/assistant`、`feature/assistant` | 会话、消息、Run、provider 配置 | 输入消息/附件引用；调用 tools、tasks、storage、network；输出有序事件 | 流式中断、工具拒绝、结果未知、恢复均有准确状态 |
| 工具系统：`core/tools`、`feature/toolbox` | 描述、schema、调用记录；工具箱只是展示入口 | permissions + 具体领域服务；输入参数，输出类型化结果/资源引用 | 同一工具的手动/AI 调用行为一致，调用者不可伪造 |
| Script：`core/extensions/scripts` | 执行上下文、预算、宿主 API 会话 | 工具系统与受限执行器；源码/输入 → 有界输出 | 超时、中止、内存/输出限额、无授权网络/文件访问被拒 |
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
