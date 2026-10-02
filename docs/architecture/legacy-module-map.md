# 旧 Android 项目模块与迁移地图

## 证据范围

参考仓库为 `D:\10_Project\Kiyori-Android`，2026-10-02 核对 `main` 的
`6b03b03aa082803bb279db5e78773583e2d91154`，工作区干净。该仓库仅只读，不能把其
Gradle、terminal 子模块、包根和数据库布局套进新仓库。

本次覆盖 settings 的全部九个 Android 模块、Git 跟踪的应用包树、全部运行时契约目录、
主要状态所有者声明以及首页手势/预组合实现。下表是领域级覆盖及后续源码导航，
不表示逐行审计所有第三方引擎、所有扩展脚本，也不表示所有旧功能已经实现或设备验收。
具体迁移前仍须读取对应实现、调用方和测试，不能用本表替代源码。

以下 `operit/` 表示 `app/src/main/java/com/ai/assistance/operit/`，
`kiyori/` 表示 `app/src/main/java/com/kiyori/`。旧目录是来源地址，不是新项目命名建议。

## 工程与原生模块

| 旧模块/工程 | 已核对职责 | 新项目归属与迁移条件 |
| --- | --- | --- |
| `:app` | Android 产品组装、Compose、业务、资源、服务 | Flutter runner 只装配；Dart UI、Rust 业务和 native adapter 分离 |
| `:terminal` | 独立 Git 子模块，终端服务、AIDL、PTY、rootfs | `terminal` 领域与平台进程端口；不共享旧 home/socket/rootfs |
| `:quickjs` | JavaScript 引擎绑定 | `extensions/scripts` 的候选执行后端，先验证资源限制/取消及三端支持 |
| `:mnn`、`:llama` | 本地模型 JNI 后端 | `assistant/providers` 与原生推理 adapter；模型内存/线程/卸载需独立 spike |
| `:dragonbones`、`:mmd`、`:fbx` | 角色动画与模型格式后端 | `avatar` UI 与原生渲染端口；不把这些 Android 库当三端能力 |
| `:showerclient` | 虚拟显示/系统控制客户端 | `automation` 平台能力，权限与可用性分开 |
| `buildSrc` | 自定义 Gradle task 类型，不进入 APK | 只保留新工程实际需要的 build hook，不迁移整个旧构建体系 |
| `web-chat` | Web 聊天与构建资产 | 是否保留必须做 Markdown/选择/平台视图性能比较，不能双重渲染同一消息 |
| `examples`、`tools/mcp_bridge`、`tools/shower` | 脚本/ToolPkg 源码、MCP bridge 与辅助工程 | 分属未来 SDK、扩展示例和宿主工具；有真实消费者时建立目录 |
| `config/architecture`、`ci`、`docs/TODO` | 旧边界检查、测试与历史任务 | 只提取有效不变量；新项目不复制哈希快照或旧门禁 |

## 产品与运行时覆盖

| 领域 | 旧源码入口/真实所有者 | 新项目位置（业务均为计划）与必须保留的细节 |
| --- | --- | --- |
| 首页、负一屏、导航 | `kiyori/app/shell/KiyoriAppShell.kt`、`KiyoriShellState.kt` | `app/shell`；唯一导航、来源 Back、系统栏、三页/五图标参数 |
| 首启、权限、主题 | `kiyori/app/startup`、`kiyori/design/theme`、`operit/ui/permissions` | `onboarding`、permissions、`kiyori_ui`；授权事实共用，弹层不抢后台 Back |
| AI provider 与执行 | `operit/api/chat/llmprovider`、`EnhancedAIService`、`ModelRequestCompiler` | `assistant`；协议能力、请求身份、工具闭合、未知提交结果，不盲重试 |
| 对话与消息 UI | `operit/core/chat/AIMessageManager.kt`、`ui/features/chat` | `feature/assistant`；草稿/选区归 UI，流式稳定节点、附件引用、历史搜索归领域 |
| 角色/提示词/模型配置 | `operit/data/preferences` 中 CharacterCard、ModelConfig、Prompt managers | assistant 设置子域；配置 ID 与角色/记忆空间隔离，凭据只保留引用 |
| 审计与恢复 | `operit/data/audit/ConversationAuditRepository.kt`、ProviderExecutionRepository | `audit`、assistant；不可变事件/修订、脱敏、seal 与密钥依赖分开 |
| 工具与权限 | `operit/core/tools`、`defaultTool/standard`、`system` | `tools` + permissions；人工/AI 同一服务，Root/Shizuku 不是普通应用权限 |
| Script / ToolPkg / Skill | PackageManager、ToolPkgManager、SkillManager | `extensions`；依赖图、包版本与 API 版本分开、取消、撤权、路径边界 |
| MCP | `operit/core/tools/mcp/MCPToolExecutor.kt` 中 MCPManager、`data/mcp` | `extensions/mcp`；协商、重连、取消、工具变更，不默认有移动端 stdio runtime |
| 工作流 | `operit/core/workflow/WorkflowExecutor.kt`、WorkflowRepository | `workflows`；节点依赖、运行快照、取消/失败、副作用不重复执行 |
| 工作区与 AI 产物 | `operit/core/workspace`、`ui/features/chat/webview/workspace`、KiyoriArtifactStoragePolicy | workspace、files；绑定目录和导出偏好不同，AI 与文件 UI 同一 ResourceRef |
| 记忆、日记、知识 | `operit/data/repository/MemoryRepository.kt`、`ui/features/memory` | `knowledge`；同空间统一内容/关系、归档、UUID，派生向量绑定模型与内容指纹 |
| 浏览与网页工具 | StandardBrowserSessionTools、`defaultTool/websession`、`ui/features/websession/browser` | browser；同一标签唯一原生视图，Profile/Cookie、窗口恢复、网页提取与导航代际 |
| 广告、用户脚本、密码 | WebSessionBrowserSettingsStore、BrowserAdBlockStore 及同目录规则实现 | adblock、browser/extensions、accounts；原子规则快照、站点豁免、凭据隔离 |
| 文件管理 | `ui/features/chat/webview/workspace`、FileManagerViewModel | files；双栏会话、索引、回收站、SAF/Android/Linux/SSH 不能混用路径与结果 |
| 下载与媒体捕获 | `defaultTool/websession/browser/BrowserDownloadSupport.kt` 中 BrowserDownloadManager | downloads；同一任务执行者、请求身份/路由冻结、Range/分片/发布/重试语义 |
| 视频、音频、FFmpeg | `operit/core/player/PlayerSession.kt`、`runtime/MpvPlayerEngine.kt`、`core/ffmpeg` | media；控制所有者唯一，seek 代际、音频焦点、纹理释放、处理任务不复制下载器 |
| 音乐库、音源、歌词 | `operit/core/player/MusicWorkspace.kt`、MusicSourceService、MusicPlaybackService | media/library + `feature/music`；歌曲引用有界，收听视频复用播放事实，不创建第二曲库 |
| B站账号与五栏内容 | `kiyori/platform/accounts/bilibili/BilibiliAccountRepository.kt`、`platform/bilibili`、`ui/features/toolbox/bilibili` | accounts + content/bilibili；账号/内容/播放分层，推荐/热门/番剧/影视/我的共享服务 |
| 网络与代理 | `kiyori/platform/network`、Mihomo 生命周期/路由 | network；应用 HTTP、WebView、媒体分别验证，禁止失败静默直连 |
| 语音输入/输出 | `operit/api/speech`、`api/voice`、SpeechProfileServiceOwner | speech；配置租约、麦克风/播放生命周期、停止与释放，不把 TTS 当播放器队列 |
| 角色形象与悬浮 | `operit/core/avatar`、`ui/floating`、`services/floating` | avatar 与平台窗口；模型/纹理生命周期，后台暂停，Android 悬浮权限不外推 iOS |
| 系统自动化与外部入口 | `core/tools/agent`、`services/assistant`、`integrations/{http,intent,tasker,externalchat}` | automation + integrations；来路认证、显示会话、重放保护、系统授权和用户授权分开 |
| 路径、日志、备份 | `kiyori/platform/{storage,logging,lifecycle}`、`operit/data/backup` | storage、diagnostics、backup；原始数据/导出/缓存分离，恢复先校验，失败不覆盖 |
| 天气、工具箱、设置 | `operit/ui/main/weather`、`ui/features/toolbox`、`ui/features/settings` | 各领域服务 + toolbox/settings UI；工具箱是目录，设置不持有第二业务数据库 |

旧应用主包树还包括 `util/stream`、native ripgrep、序列化、DAO、provider、widget 和 crash
支撑代码；迁移时按消费领域归属，不复制 `util` 杂物层。`com/k2fsa/sherpa` 等第三方绑定、
兼容包名、JNI/AIDL 名称和许可证保留准确身份。

## 第一轮发现与设计修订

1. 新模块表此前遗漏 documents、knowledge、workflows、speech、avatar、accounts/content、
   backup/audit/automation/integrations；现已补到模块目录和里程碑依赖，不预建空模块。
2. 旧文件/浏览/音乐/AI 工具共用运行时。新架构继续维持一个业务 owner + 原生句柄 owner，
   页面预热不等于启动后台服务、数据库或网络。
3. 旧 Shell 两次帧信号后预组合邻页；AI 为保留复杂宿主放在 Pager 外并使用专用手势桥。
   新项目三个 Flutter 页面在一个 PageView 内，无需复制第二手势桥。底栏每像素重新 build
   及输入全页 setState 已移除；具体策略与测量见[性能契约](../development/performance.md)。
4. 旧 AI 桥的释放阈值为 400 dp/s 或严格超过半页；普通页仍用 Compose Pager 默认行为。
   新 PageView 使用 Flutter 的框架分页与系统手势阈值。两者弹簧/速度算法不完全相同，
   必须同设备测量后再决定是否实现自定义 physics，不能声称本轮已逐帧一致。
5. 旧文档/记忆/工作流的既有持久格式只是导入来源。新应用不读写旧私有数据库；迁移要有
   版本化导出包、校验、预览、冲突处理和凭据边界。

## 第二轮源码复核与证据层级

2026-10-02 第二轮仍以同一 `6b03b03a` 为只读基线。重新读取运行时契约索引，按领域
核对 product_shell、browser、media_downloads、platform_storage、network_proxy、
ai_execution、ai_interaction、extensions_workspace、artifact_storage 及 B站三个契约。
九模块的构建声明及 buildSrc/web-chat/examples/辅助工具的用途已复查；以下深度各有边界。

| 复核链路与实际代码证据 | 提取的不变量 | 新项目状态与尚未验证部分 |
| --- | --- | --- |
| `kiyori/app/shell`、首启契约、`kiyori/design/theme/KiyoriSettingsTheme.kt` / `KiyoriSemanticColors.kt`，设置/主题/引导消费者 | 来源返回、模态隔离、明暗角色色、初始草稿与持久主题分开 | 已有 Dart 壳/设置/引导；本轮修复共享色表和隐藏焦点，平台权限仍未接入 |
| AI 执行/交互契约、模型配置与请求编译入口；新 `kiyori_core/src/runtime.rs` → FFI → `runtime_client.dart` → `runtime_controller.dart` | 任务身份、拉取背压、取消/关闭释放、错误脱敏 | M1 诊断运行时已实现并有真实 FFI 测试；provider/消息/角色持久业务仍计划，不宣称全 provider 逐行审完 |
| `operit/core/tools/mcp/MCPToolExecutor.kt` 中 MCPManager 的注册代次、连接缓存与关闭路径，扩展契约 | 注册身份和工具变更必须隔离旧连接，权限不由扩展文本授予 | 工具授权 UI 已有；统一执行、Script/ToolPkg/Skill/MCP 真实运行时未接入，各执行后端仍需独立复核 |
| 浏览器/媒体/产物契约；`StandardBrowserSessionTools.kt` 中 WebSession 及关闭路径；`DocumentOfficeEngine.kt` 的 generation/lane/render revision | AI 与手动入口共用会话、Profile/Cookie、资源；过期渲染不能发布到新文档 | 已有设置与空工作台投影，浏览/文档/下载真实 owner 仍计划；未逐条验证广告规则与密码恢复 |
| `operit/core/player/PlayerSession.kt` 的生命周期、seek/surface 代次，媒体契约 | 队列/播放事实唯一，界面和原生纹理分别释放 | 只有设置 UI；音乐库、歌词/字幕、捕获/队列与音频焦点待真实 adapter |
| `kiyori/platform/bilibili/BiliLibraryController.kt` 完整读取及账号/内容契约 | 活跃状态、账号 revision、游标、generation 与取消共同限制发布 | B站账号外观已迁移；五栏服务与播放未实现，旧服务端响应未重新请求 |
| `kiyori/platform/network/KiyoriNetworkProxyManager.kt` mutationMutex/generation 和网络契约 | 路由变更串行、旧代次失效，失败不能无声直连 | 代理配置仅局部草稿；应用 HTTP/WebView/媒体三条链路都待接入 |
| `SpeechProfileServiceOwner.kt` 完整读取，`SpeechServiceFactory.kt` / `VoiceServiceFactory.kt` 调用与 reset | 同步创建/配置替换，先清 owner 再 shutdown，防止复用已释放服务 | STT/TTS/唤醒展示已实现；不启动音频服务；实体移除时弹层回写有回归测试 |
| `core/avatar/common/control/AvatarController.kt` 生命周期边界和模块构建声明 | 真实渲染句柄、暂停/销毁属 adapter，悬浮权限为平台事实 | 虚拟形象 UI 尚未迁移；未深审全部原生渲染引擎或声称三端可用 |
| `MemoryRepository.kt` 空间/向量键，`WorkflowExecutor.kt` 执行/拓扑，`ExternalChatHttpServer.kt` 启停/认证 | 向量受空间与模型约束；工作流复用工具；外部入口认证不由 UI 草稿替代 | 只有相关设置快照；持久化、恢复、Intent/Tasker 的完整调用和实测仍待对应切片 |
| 存储/产物契约、`ConversationAuditRepository.kt` 事务与 seal、备份边界 | 原始数据和派生索引分离，审计封存、恢复校验和凭据生命周期分别负责 | 存储/备份 UI 已有，数据库迁移、崩溃恢复、日志持久化未实现 |

此表记录本轮实际读取的高价值链路，不等于所有领域都达到同一审计深度。
现有模块职责和 Dart/Rust/native 分界仍适用，本轮没有引入平行 Manager、Router 或业务数据库。
目录与协议命名保留生态标准；旧九模块的 JNI/AIDL/引擎只作为后续验证输入，不直接复制。

## 每个领域实施前的源码核对

第四轮完整读取同 revision 的 `GroupCardTab` / `GroupCardItem` / `GroupCardDialog`、
`CharacterGroupCard.kt`、`CharacterGroupCardManager.kt`、`ActivePromptManager.kt`；按
相关分支复核 settings 宿主保存/复制/删除/头像与中文资源、CharacterCard 字段及聊天绑定
调用。旧群组无规划参数、默认标记、手动排序或重置；成员为角色 ID + orderIndex，选择
使用下拉菜单后添加。新投影复用 prompts 的身份代次与模态 owner，真实业务尚未接入；
群组执行器、完整会话历史服务未逐行审计，见[角色卡契约](../design/character-prompts.md)。

第三轮新增角色/提示词切片：实际读取 `ModelPromptsSettingsScreen.kt` 的宿主、三标签、
初始化与角色/标签操作、排序、确认及导出层级；完整读取 `CharacterCardDialog.kt` 的
编辑、嵌套选择与紧凑组件，以及 `CharacterCardBilingualData.kt`。读取角色模型、
CharacterCardManager 默认初始化/CRUD 关键段、PromptTagManager 与群组目录/创建、
ActivePromptManager 活跃切换与会话引用。新 Rust/FFI 仍只有 M1 runtime，没有对应业务 owner。
新实现是 UI 草稿垂直切片，不声明完整群组、全部 Tavern 编解码或形象引擎已审。
精确证据深度、尺寸、生命周期与未实现项见[角色卡契约](../design/character-prompts.md)。

工程治理复查再次核对同一旧revision的九模块声明、运行时契约索引与壳/浏览器/媒体/
平台/AI/扩展边界。`tools/inspect-legacy.ps1 -Source <旧checkout> -Filter <路径片段>`
生成只读JSON导航清单，包含revision与观察时间；不会读取未跟踪私密文件或修改旧源码。
本轮跟踪文件4948个，UI/设计/壳层Kotlin文件1072个。数字是定位范围，不是页面覆盖率。

对各模块的迁移结论保持：app转为按领域UI；terminal、showerclient属于平台能力；
mnn/llama属于推理adapter；dragonbones/mmd/fbx属于avatar渲染adapter；quickjs属于
扩展运行时。没有一个旧JNI模块可凭Android编译通过就算三端已支持；本批不复制这些
二进制或旧数据。全模块逐行审计与真实能力实现必须随具体切片推进。

先查旧仓库 `docs/doc-src/contracts/README.md` 和对应 `architecture/`，再追踪本表 owner
的构造/调用、状态更新、取消/释放与测试；记录来源 commit。用真实用例列出尺寸/手势、
成功/错误/取消、后台恢复、权限和大数据行为，划分已实现与未接入。平台特有能力先做
可丢弃 spike，真实失败据实修订 ADR；不得为了目录整齐搬入旧 Android 全套技术栈。
