# 设置全树复刻映射

## 基线与索引约定

唯一旧源为只读`D:/10_Project/Kiyori-Android`，revision
`6b03b03aa082803bb279db5e78773583e2d91154`。下表旧路径以
`app/src/main/java/com/ai/assistance/operit/`为根，新路径以
`apps/kiyori/lib/features/`为根；类名配合文件名定位，行号只作该revision的提示。
本文件保存入口/状态/证据契约，当前完成情况仅见[status](../status.md)。

主目录来源`ui/main/shell/KiyoriSettingsHomePage.kt:132`的
`kiyoriSettingsHomeGroups`，四组三行；新`settings/presentation/settings_page.dart`
同序，app的`SettingsNavigation`借用Navigator压栈。详情返回来源页，模态先消费Back；
更多→存储→同一设置页返回存储，工具箱/文件工作台入口返回原工作台。
顶栏和输入组件参数继续追踪实际宿主，不以默认截图或文件存在代替覆盖。

## 一级与子树入口

| 稳定ID / 入口 | 旧文件与符号 | 新实现 / 导航 | 必须核对的子树与状态 | 证据入口（test/下） |
| --- | --- | --- | --- | --- |
| S01 我的账号 | `ui/main/shell/KiyoriApplicationSettingsPages.kt` / KiyoriAccountSettingsPage，KiyoriBilibiliAccountSection | `accounts/presentation/account_settings_page.dart` | GitHub登录方式/退出确认、B站扫码/Cookie/验证/已连接/失效、嵌入页目的地、错误与加载 | application_settings_test.dart |
| S02 AI助手 | 同文件 / kiyoriAiAssistantSettingsGroups | `assistant/presentation/assistant_settings_page.dart` → SettingsNavigation | 五组14项；模型/API、功能模型、角色/提示词、资料、形象、回复/表情、TTS/STT/唤醒、上下文、工具授权、用量、自动化、产物 | application_settings_test.dart、各领域测试 |
| S03 工具箱 | `ui/main/shell/KiyoriToolboxSettingsPage.kt` / ToolboxGroupEditor、Manager、MoveToolsDrawer、ToolboxLayout | `toolbox/presentation/toolbox_settings_page.dart`、toolbox_settings_presentation/session | 常用/分组/移动抽屉、已有自定义组改名删除、清色、文档设置；关键词筛选/稳定ID选择；NFKC名称校验、加载/错误/保存退出限制 | toolbox_settings_test.dart、toolbox_states_test.dart、toolbox_states_capture_test.dart、document_file_settings_test.dart |
| S04 网页浏览器 | `ui/main/shell/KiyoriBrowserSettingsPage.kt` / WebSessionBrowserSettingsStore | `browser/presentation/browser_settings_page.dart` | 主页、文字比例、密码、脚本授权；fresh偏好、选择器/输入/依赖状态 | settings_detail_test.dart |
| S05 文件下载器 | `ui/main/shell/KiyoriDownloadSettingsPage.kt` / BrowserDownloadSettingsStore | `downloads/presentation/download_settings_page.dart` | 引擎、并发、路径选择与权限、系统引擎依赖禁用；存储入口返回 | settings_detail_test.dart、storage_settings_test.dart |
| S06 文件管理器 | `ui/main/shell/KiyoriFileManagerSettingsPage.kt` / FileManagerPreferences | `files/presentation/file_settings_page.dart` | 筛选/路径/格式规则、FileOpenDefaultsDialog→FileOpenWithDialog、已有规则/删除 | document_file_settings_test.dart |
| S07 视频播放器 | `ui/main/shell/KiyoriPlayerSettingsPage.kt` / PlayerModels、PlayerExperienceSettings | `video/presentation/player_settings_page.dart`、player_experience_page.dart | 六组28项及字幕/声音/弹幕/控制栏，选项、颜色、数值、重置及路径 | player_settings_test.dart |
| S08 音乐播放器 | MusicSettingsPage / MusicSourceSettings、MusicDownloadSettings、MusicDesktopLyricSettings、MusicBackupSettings | `music/presentation/music_settings_page.dart` | 十分组、音源导入/详情/移除、下载/歌词、备份预览与确认、空/非空 | music_settings_test.dart |
| S09 广告拦截器 | `ui/main/shell/KiyoriAdBlockSettingsPage.kt` / BrowserAdBlockStore、SubscriptionCatalog | `browser/presentation/adblock_settings_page.dart` | 概览/订阅/规则/白名单/诊断；初始化、载荷、错误、自定义编辑/删除/同步、搜索 | adblock_settings_test.dart |
| S10 界面定制 | KiyoriApplicationSettingsPages / ThemeSettingsScreen、LanguageSettingsScreen、GlobalDisplaySettingsScreen、LayoutAdjustmentSettingsScreen；BackgroundSection、CoreSections、FontAvatarSections、AvatarPicker、BubbleImageBackgroundSurface | `settings/presentation/appearance/` | 父级四项；主题五标签、已选媒体/视频帧与九宫格/拉伸预览、自定义字体/头像、色盘、语言八项、显示/布局数值与条件项 | appearance_settings_test.dart、appearance_identity_test.dart、appearance_media_test.dart、appearance_media_capture_test.dart、display_settings_test.dart、settings_theme_capture_test.dart |
| S11 数据备份 | KiyoriApplicationSettingsPages / ChatBackupSettingsScreen、BackupManagementCards、BackupDialogs、RoomDbBackupComponents、ChatHistorySettingsScreen | `settings/presentation/data_settings_page.dart` → backup_settings_page.dart、`assistant/presentation/history/` | 十卡备份、两层导出、六种导入格式、配置/策略、最近备份、覆盖确认/重启提示、运行/错误快照；历史五卡、归类/删除/重建日期 | backup_settings_test.dart、backup_states_test.dart、chat_history_capture_test.dart |
| S12 更多功能 | `ui/main/shell/KiyoriMoreFeaturesSettingsPage.kt` / KiyoriStoragePathsPage、KiyoriNetworkProxySettingsPage | `settings/presentation/more_settings_page.dart` | 存储五目的地、代理六层、协议/隐私、权限、开源、六页引导；已有代理数据/错误/确认 | storage_settings_test.dart、network_settings_test.dart、permissions_settings_test.dart |

## AI设置内部入口与边界

| 稳定ID | 新子树 | 状态/弹层与来源 | 真实owner边界 |
| --- | --- | --- | --- |
| S02.models | assistant/presentation/models | 配置切换、提供方/协议、模型排序、参数四标签、头部/密钥池、导入/下载；ModelConfigScreen及子section | Rust配置/provider；密钥引用交native安全存储 |
| S02.functions | assistant/presentation/functions | 11功能、两层选择、测试/错误快照、管理模型再返回 | 同一模型配置owner |
| S02.prompts | assistant/presentation/prompts | 角色/标签/群组、八字段、大屏编辑、绑定、确认、导出；详见[角色契约](character-prompts.md) | Rust角色/标签/群组及会话关系 |
| S02.profile | assistant/presentation/profile | 编辑/预览、旧档案、恢复/离开确认、超限 | Rust资料与共享资源引用 |
| S02.avatar | assistant/presentation/avatar_settings_page.dart及avatar目录 | KiyoriAssistantExperienceSettingsPages / AvatarConfigSection / AvatarPreviewSection；模型、导入说明、Mood、相机、重命名删除确认 | Rust配置与native渲染；当前参数和绑定只为草稿，测试avatar_settings_test.dart |
| S02.replies | assistant/presentation/replies | 分句/合并/提示词/自拍、表情库分类/选择/编辑 | Rust角色与回复策略 |
| S02.tts / stt / wakeup | speech/presentation | 引擎/配置/模型/音色/规则/附件弹层、监听/录音快照、朗读工具目的地 | Rust语音配置与native音频会话 |
| S02.context | assistant/presentation/context | 上下文/总结依赖数值、规则/错误、历史媒体重置 | Rust模型与上下文策略 |
| S02.permissions | assistant/presentation/permissions | 三态与允许/禁止例外、目录筛选与空态 | Rust统一权限与工具目录 |
| S02.usage | assistant/presentation/usage | 统计/价格/汇率/重置与模型分布 | Rust统计事实 |
| S02.server | assistant/presentation/server | 端口/Token草稿、运行/错误状态、HTTP与Intent示例 | Rust服务策略与native生命周期 |
| S02.artifacts | settings/presentation下产物设置 | 与S12存储同一编辑器、路径预览/错误/离开确认 | Rust共享storage，不写旧路径 |

## 公共控件与验收契约

账号状态核对KiyoriAccountConnectionsSettingsPage和KiyoriBilibiliAccountSection全文：
GitHub连接后无userInfo显示读取中，B站读取/busy禁用操作、失效保留账号、错误无账号时
可清理确认；取消/退出/移除不在展示层伪造事实。测试account_states_test.dart及截图套件。

GitHub登录方式已接入独立GitHubLoginDialog：方式选择切换全屏内嵌登录壳，加载/完成时保留
关闭、刷新和Back边界；WebView、OAuth状态和外部浏览器仍由共享owner注入，不伪造网页。
B站二维码状态以BilibiliQrPresentation注入已生成图像，扫码中允许刷新/打开确认，过期清除
图像并保留原账号；Cookie切换释放局部输入。有效二维码和真实验证仍未调用。

广告拦截实际核对KiyoriAdBlockSettingsPage及BrowserAdBlockSubscriptionCatalog：
AdblockPresentation投影运行时读取/加载/编译/就绪/失败、规则计数和同步进度；URL规则按ID、
元素规则按域折叠、白名单、内置5条订阅和自定义订阅编辑/删除均可达。订阅状态保留旧规则
错误分支，更新期间禁用动作；不下载、编译或执行规则，真实Store owner仍待接入。

形象实际核对KiyoriAssistantExperienceSettingsPages.kt:84–253、AvatarConfigSection全文、
AvatarPreviewSection/HowToImportSection、AssistantConfigViewModel初始化、AvatarRepository
默认设置、AvatarMoodType和strings资源。预览220高/16圆角/.8描边，配置18×14内边距；
DragonBones缺省scale=.5，其余1；位移±500，MMD俯仰±90、glTF/FBX±89；不同距离
范围和初始值按各类型保留。空模型不显示参数/Mood，不伪造可用动作。指南完整正文
保留原导入结构、按钮；原生/外链动作未接入。目录按ID及存在期隔离，移除精确关闭
所属菜单/编辑；名称controller等退出动画结束再释放。新增15项含实体切换/删除重入、
模型移除时动作菜单与自定义弹层退出、320/横屏/桌面双倍字和160键盘、六类型参数。
当前没有真实成功/失败运行结果或导入renderer，不能把空态UI认定为真实形象功能完成。

- 设置收缩顶栏：KiyoriCollapsingSettingsPage的128→64、滚动72、32→54左距、60→20顶距、26→20字号；新SettingsDetailPage/SettingsWorkspacePage分别保留对应宿主。
- 选择抽屉：KiyoriDraggableBottomDrawer实际16顶圆角、三态/安全区/Back/遮罩；不要误用未消费的26常量。
- 搜索：KiyoriSearchField最小42、14圆角，提示不浮动；带图标/清除时核对真实占位与点击区域。
- 角色与群组：CharacterCardDialog.kt:1666的CompactTextFieldWithExpand，12字/11标签、6圆角、32右留白、40展开按钮/14图标；浮动标签不裁切，大字/多行按内容增长。群组展开旧回调为空，归并不改变它。
- 模型数值：ModelSettingsField的14正文/12提示、6圆角与12×10内边距；上下文的13正文、88/72宽和8×6内边距保持独立，不能合成全局固定高度。
- 普通OutlinedTextField与紧凑字段按旧源区别处理；TTS/STT并非都使用角色字段的12字号。公共组件不拥有controller或业务状态。

每个子树完成需补齐旧资源/default初始化证据、实际输入/模态/返回测试和截图索引。
已有测试入口只供定位，不代表本轮已运行或覆盖该行全部状态。空/非空/加载/错误快照
仅由测试或正式owner注入，不把fixture放产品默认数据。独立工作台的完整业务不因设置
导航自动纳入设置验收；AI关联工作台进入下一阶段真实功能矩阵。

设备明暗/字形/触摸/Profile、真实账号/供应商、Apple构建独立验收；本机PNG只证明渲染
布局。每批固定产物和准确命令见status，历史包及失败证据保留。

## 网络代理状态与模态映射

旧KiyoriNetworkProxySettingsPage.kt:500–1415提供六层正文与菜单/编辑器，1434–1614
提供删除/重置/清日志与订阅输入，1644–1980提供策略组、排序、运行描述与日志顺序，
2020–2380提供480列表、44菜单、组下划线和模式几何；模型来自KiyoriNetworkProxyModels。
新settings/presentation/network_proxy_presentation.dart只承载不可变展示快照，默认不注入
目录。network_proxy_nodes.dart投影搜索/排序；两个editor文件持有临时输入；page负责
六层装配和实体所属路由，公共showSettingsSelection的onRoute供宿主精确释放抽屉。

验收入口network_proxy_states_test.dart覆盖同ID更新/重排、删除释放、规则版本变化、
active订阅切换、嵌套菜单、脚本抽屉、busy更新、时钟回退日志和节点选择事实不变；
network_settings_test.dart保留空态，network_proxy_capture_test.dart覆盖六层非空、明暗、
320/844/1280视口、大字与键盘弹层。失败证据和捕获路径由status记录。

## 音乐设置目录、偏好与备份

旧ui/features/toolbox/MusicSourceSettings.kt、MusicBackupSettings.kt全文定义音源切换/
详情/链接更新/移除、列表预览/合并/同ID替换/撤销/导出；MusicSettingsPage与
MusicDownloadSettings定义canEdit/importing/播放状态依赖、历史确认和下载依赖项。
MusicDesktopLyricSettings及core/player/MusicDesktopLyricStyle的read定义字体、颜色、
位置、范围与默认值，MusicWorkspace定义loaded/writable/restoring/committing编辑边界。

新music_settings_presentation.dart只提供摘要和类型化快照；music_source_settings/
music_source_dialogs管理实体草稿与路由，music_backup_settings管理单次解析预览身份。
page持有历史确认/偏好选择路由，desktop_lyric_settings只投影同一快照，不启动悬浮窗。
music_states_test、music_preferences_test及music_states_capture_test覆盖实体更新/删除、
链接遮蔽、busy错误、备份取消/重入、滑块权威值、下载依赖和明暗/小屏/横屏/键盘。
真实脚本执行、网络更新、文件选择/备份编解码、播放与桌面歌词服务仍未接入。

## 备份运行状态与字体头像

ChatBackupSettingsScreen的文件选择返回、Profile→Strategy、恢复确认与重启分支分别对应
BackupPromptKind会话；BackupManagementCards定义四类操作卡，RoomDbBackupComponents定义
最近备份14px圆角/12px内距。新页面不读取文件或启动Room；BackupOperation分别承接聊天、
角色、记忆、模型、数据库备份/恢复与文件快照阶段。backup_states_test覆盖选择取交集、
配置切换/删除、会话替换/取消、宿主退出、失效恢复文件、离屏动画与六种视口主题组合。
测试快照不是默认业务数据，导出/恢复/重启按钮不生成结果。

字体/头像核对ThemeSettingsFontAvatarSections、AvatarPicker、CoreSections的
BubbleFontStyleEditor与PreviewChatAvatar，以及ChatTab的previewUserAvatarUri。
appearance_identity_test覆盖文件名/注册字体、头像回退、重置可点性、名称controller与
同值草稿生命周期；3视口明暗/双倍字捕获详见status。加载字体、选图、写偏好仍待业务owner。
