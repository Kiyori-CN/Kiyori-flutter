# 模块实现与接线

本文记录当前实现位置及接口接线，基线为 `138f42e`。阅读全局归属先看[模块目录](module-catalog.md)，事务与生命周期见[运行契约](runtime-contracts.md)。出现 schema 数字表示引入该能力的迁移版本，不表示当前数据库仍停在该版本。

<!-- doc-toc:start -->
- [已实现接线](#已实现接线)
- [扩展与脚本](#扩展与脚本)
- [资源、下载与本地推理](#资源下载与本地推理)
- [模型、会话与凭据](#模型会话与凭据)
- [路由与共享 UI](#路由与共享-ui)
- [存储、知识与工作流](#存储知识与工作流)
- [界面投影与未接入边界](#界面投影与未接入边界)
<!-- doc-toc:end -->

## 已实现接线

`core/audit_crypto`定义正文保护/签名窄端口，`platform/audit`拥有Keystore/JNI或
DPAPI/AES/P256句柄，FFI显式装配到同AppStore。schema21的安全公钥、元数据和
持久封印仍归SQLite；参考Rust测试运行时不是产品回退路径。见ADR0015。

## 扩展与脚本

`core/extensions`拥有持久TOOLPKG包、受控导入、恢复账本、目录身份与撤销；
FFI公开包/目录/导入/四handler端口，Dart外观管理句柄与关闭。schema19复用同SQLite
和ResourceRef，执行仍归core/scripts；feature/extensions/presentation投影AI抽屉包管理，
Windows/Android与模型导入共用分片文件端口。详情后台核验原包，不建立第二目录数据库。
同owner解析JSON/HJSON清单和相对入口，ZIP完整布局验证与正式解压CRC分别承担元数据
与正文校验；依赖、环境和子包能力按ADR0012继续实施。
core/extensions/http复用同client
并限定URL/认证，core/chat/extension连接正式目录/正文/用量/取消和总结；合同见ADR0013。

`core/scripts`实现执行预算、取消/关闭等待与有界结果；`packages/kiyori_platform/scripts`
实现QuickJS-NG独立实例，由FFI装配。注册与四handler为真实JS调用；包目录、受控 HTTP
与文字提供方已接入同 Runtime；完整旧包能力仍按 TOOLPKG 方案推进。

## 资源、下载与本地推理

`core/files`首个ResourceRef用例管理应用私有模型资源；`core/downloads`保存并执行同库
Transfer，`core/local_models`编译公共市场/仓库清单。Dart的PersistentLocalModelsPage
投影这些事实及生命周期，不拥有下载HTTP或文件数据库。schema16/17、Range及校验见ADR0009。

`core/chat/native`为本地推理建立资源租约和blocking worker契约；平台Rust/C++ adapter
在`packages/kiyori_platform/inference`，由FFI装配，复用ChatRun事件及SQLite会话。
具体引擎、参数与平台验收状态见status及ADR0010；配置字段不等于GPU/媒体已接入。

下文描述现有接线与展示边界。`core`指`crates/kiyori_core/src`；
`feature`指`apps/kiyori/lib/features`；`native`指已建立安全存储adapter的
`packages/kiyori_platform`。不存在“其它功能都放工具箱”的兜底模块。

## 模型、会话与凭据

core/models拥有配置、功能绑定、参数验证与安全引用账本；schema15的core/conversations拥有
会话、消息、Run、恢复锁与历史修改事务，复用同一storage；core/context将chat绑定的
上下文选项与全局媒体偏好按各自revision在同一事务保存。native安全存储只保护
不可变payload，Dart的ModelsController/ModelEditSession编排保存和短期草稿，不另建数据库。
凭据不得进入目录DTO，双存储失败/恢复限制见[ADR 0006](../decisions/0006-model-secrets-and-configurations.md)。
native的TextExchange提供用户选中的单次文本读写，不缓存路径或另建资源数据库；
Windows使用COM/后台isolate，Android使用SAF与受控I/O生命周期，iOS当前返回unsupported。
native的TransientNotice只转发Android系统长Toast并随Activity释放，返回请求/不可用
原因；非Android不调用channel，Dart宿主使用现有短暂消息，不持有业务状态。
core/chat/pool使用同一请求client做有界并发可用性探测，Dart的ModelPoolTestController仅管理
页面执行代次和逐项安全保存；core/model_execution拥有候选筛选与独立SQLite游标，
配置模型测试按revision调用，不能由UI自行选择首个密钥。
core/chat/responses只适配Responses请求体和事件解码，复用同一client/生命周期，未建立新网络owner。
core/chat/observation属于同一请求链路，Runtime按会话持有最新tracker，负责单调计时、
输入估算与进程内最近样本；不入库、不从历史耗时反推，不建立第二份累计账本。
core/conversations_summary管理总结功能绑定与请求投影缓存，原始历史仍由conversations持有；
使用同HTTP client、限流和Run取消，summary_usage计入同库累计，不替换聊天最近样本。
core/conversations_manual_summary冻结手动边界、复用摘要请求编译，完整终态原子插入
可见检查点；同会话OS锁/ChatRun/SQLite，不建立第二历史或执行器。
core/conversations_opening投影单角色无user时的开场白，同事务同步当前消息与审计。
schema23非生成消息元数据与Run事实分别保存；FFI可空created_at不代表请求发送时间。
创建/选择/当前加载共用同函数，分支复制独立快照，迁移和回滚见ADR0017。
core/conversations_title在同SQLite保存独立标题工作，复用client/凭据/限流/取消/
provider审计，辅助执行不占chat Run或聊天用量。schema24标题版本和源消息CAS、
Runtime生命周期锁及恢复避免迟到覆盖与自动重发；FFI类型由正式入口生成，见ADR0018。

## 路由与共享 UI

详情路由由 app 的 `SettingsNavigation` 装配，feature只提供页面/快照/类型化回调。
目录按现有领域继续迭代，不按单页拆package；`video`与`music`保留UI语义，共享播放事实
未来归media领域，不新建平行player状态。捕获测试辅助只在test/support，不进入产品依赖。

## 存储、知识与工作流

core/storage拥有SQLite连接和统一迁移，runtime拥有关闭边界；core/workflows和core/knowledge
分别实现定义目录与空间/记忆事务，FFI只映射DTO。不得为每个领域打开第二数据库。
core/diary从正文推导阶段，core/graph管理关系，core/memory_search拥有检索偏好与本地评分；
三者均复用knowledge空间与storage连接，坐标和临时输入仍属于Dart投影。
core/prompts拥有角色八字段、标签、群组有序成员和活跃选择，schema5复用storage迁移；
引用验证、revision冲突、级联和提示词组合在Rust实现，FFI提供类型化DTO/命令。
feature/workflows/presentation负责不可变目录、读取代次、提交互斥和页面/弹层。
app通过path_provider取得应用支持目录，并把同一runtime的client注入工作流controller；
HomeShell消费该投影更新抽屉计数与内部导航。定义CRUD不包含节点、执行器或调度器。

## 界面投影与未接入边界

当前已有 `feature/assistant/presentation` 及 browser、toolbox、files、settings 的一级 UI。
已追加 browser 设置及子页、downloads 设置、files 设置、video 设置及字幕/声音/弹幕/控制栏子页，
toolbox 设置与常用/分组/批量选择抽屉。工具箱入口展示目录共用，非领域工具注册表。
toolbox 的 ToolboxSettingsPresentation 提供稳定目录/加载/保存/错误只读快照，
ToolboxSettingsSession 只管理页面弹层生命周期；名称校验使用unorm_dart的完整NFKC，
不建立Dart布局数据库或工具执行器。
browser/presentation/adblock 由 AdblockPresentation 投影运行时和规则/订阅目录；按ID维护
编辑弹层、域名折叠和状态快照，更新/删除保留空动作边界，不下载、解析或执行过滤规则。
browser_credentials_presentation分开凭据摘要和临时详情；页面搜索不遍历密码，详情/编辑
默认遮蔽，实体移除/保险库失效/宿主退出撤销路由。平台安全描述由快照提供，不把Android
Keystore文案当Windows安全事实。browser_scripts_presentation只投影声明和运行状态。
files/presentation的FileSettingsSession统一持有格式/隐藏列表/确认路由，快照仅提供
现有规则、路径和计数；不建立文件偏好数据库，不执行恢复、删除或清理。
documents 设置及说明弹窗、files 格式选择器、music 设置和音源导入/备份确认也已加入
UI 投影；没有加载文档、播放、下载、调用系统选择器或实际导入导出。
music/presentation以MusicSettingsPresentation投影音源目录、偏好、播放速度/历史和
LX列表预览；source/backup组件拥有模态会话，原始脚本/解析/存储仍待Rust与native owner。
settings 追加更多功能、存储汇总、产物目录编辑和网络代理六层状态投影，app 负责跨领域导航。
NetworkProxyPresentation提供运行事实与订阅/节点/规则/脚本/日志目录；nodes和editors
只管理筛选/排序/输入，page管理实体存在期与所属模态，不接管network领域业务。
工作台顶栏/固定底栏在 kiyori_ui，输入草稿仍局部持有；路径与代理外观校验不构成
文件访问、授权或网络策略，未来领域 owner 必须重新验证并返回权威快照。
settings 中的备份页面以 BackupPresentation 投影计数、配置、独立操作阶段和已解析备份，
backup_operation渲染进度/结果，backup_dialogs与backup_restore_dialogs提供选择/恢复/重启/
模型安全提示；页面管理路由和目录失效，不建立备份存储或扫描器。法律、开源阅读和权限
分组同属展示层，系统事实由后续 adapter 注入。
settings/presentation/appearance 按原五标签拆分，聊天面板持有样式草稿，编辑器与预览
共享该草稿；AppearanceMediaPresentation借用资源owner的已解码图像，背景/九宫格预览
不读路径、不解码或创建播放器。AppearanceNineSlice拥有局部纹理并随组件释放，模式/缩放
复用切片；字体快照只引用已注册family，头像选择器与聊天预览使用借用资源。媒体路径与
全局主题事实尚未接入，不建立第二配置存储。
accounts/presentation 由 AccountPresentation 投影未连接、已连接、读取、失效及错误，
包含方式选择与退出/移除确认；不拥有凭据存储、登录控制器或 WebView。
GitHubLoginDialog和BilibiliQrPresentation只投影内嵌壳、加载/完成/二维码状态，不创建
WebView、OAuth客户端或二维码请求。
assistant/presentation 的设置入口通过类型化回调交给 app 装配。
models/local_models_page展示LocalModelsPresentation目录和下载状态，搜索在输入或目录
变更时计算，删除确认随目录/权限状态释放；页面不访问网络、文件或复制下载管理器。
prompts/tag_export_dialog管理标签选择与目录代次；tag_market_page及presets展示旧本地
13项预设，不执行提示词、HTML或外链。persona_generation_page复用角色目录，按实体
持有侧栏字段/输入草稿并投影消息/生成阶段；没有Dart角色仓库或独立工具执行器。
assistant/presentation/avatar 投影模型目录、预览、六类型参数、Mood绑定与导入指南；
参数草稿按模型ID及存在期隔离，菜单/编辑路由随宿主释放。当前没有资源导入、持久化或
原生renderer，无adapter时显示旧不支持分支；不建立平行配置存储或动画运行时。
appearance 的 global_display_page 与 layout_adjustment_page 只投影旧默认值和验证外观，
不接 DisplayPreferencesManager、UserPreferencesManager、前台服务、Root 或截图管线。
onboarding/presentation 保存引导导航和本次草稿，复用 settings 的法律正文及权限目录；
app 用全屏模态路由装配重看入口，系统权限和首启完成均不在 UI 中写入。
assistant/presentation/history 投影聊天概览、角色/群聊统计、批量归类和无绑定工作区，
复用 settings 的卡片外观；只读快照由后续领域 owner 注入，不另建聊天库或文件扫描器。
assistant/presentation/context 的纯展示组件持有上下文/总结/历史媒体局部表单，字段与错误按局部
监听更新；真实上下文保存复用core/context与模型配置owner，700ms去抖和返回刷写。
assistant/presentation/models 目前投影11功能的模型分配卡片与配置/模型两层展开，
共享摘要类型不包含凭据；管理配置由app接线，模型/API测试通过core/chat的共享请求核心。
同目录模型/API页按连接配置、上下文/请求头/高级卡片、参数与标签编辑器拆分；每个已访问
配置子树保留独立草稿，配置目录变化按 ID 对齐。供应商协议目录是只读展示常量，密钥仅随
编辑与请求快照存活，ModelsController投影core/models事实并委托native安全存储。
ModelConnectionTest仅投影Chat和系统指令探测，core/chat拥有HTTP/SSE/超时/取消与错误；
不建立Dart HTTP客户端。协议、TLS根与未实现能力见ADR0007。
assistant/presentation/prompts 包含角色/标签目录快照、中文默认角色、编辑与嵌套绑定弹层。
复用 models 的配置摘要，不持有角色、标签、群组或活跃目标的业务存储；弹层仅有局部
草稿与自己的路由释放责任。group_card_tile/editor 投影群组列表、成员下拉与编辑草稿；
群组无独立模型/记忆/工具配置，成员引用角色ID。PromptsController复用app的Runtime连接，
投影真实CRUD、复制、激活和市场添加；编辑器保存中隔离返回，失败保留草稿。
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
上述尚未接入业务的 UI 保留旧默认外观、草稿及空点击；已接入的持久宿主按所属章节处理。目标领域与完成信号见[模块目录](module-catalog.md)。
