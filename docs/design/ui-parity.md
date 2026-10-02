# UI 复刻契约

角色卡/提示词本轮契约见[角色卡与提示词](character-prompts.md)：三标签、默认角色、
八字段编辑、标签与模型/记忆/工具绑定、群组列表/名称/描述/成员下拉及目录身份；业务
CRUD 仍未接入。局部选择和添加不能被描述为真实群组保存；旧群组没有规划参数、默认
徽章或手动排序，不能补造控制项。

模型与 API 默认页来自 ModelConfigScreen、ModelApiSettingsSection、ModelParametersSection、
AdvancedSettingsSection 和 ModelNameTagEditor。保留配置选择16px圆角、API/折叠卡12px圆角、
提供方30项/52协议目录、端点选择、三行模型标签与真实长按排序、四类参数、请求头六预设、
请求队列及空密钥池。配置目录复用 ModelConfigPresentation；表单暂投影旧默认值，未加载
真实配置和连接结果。新建/重命名/删除/保存/测试/获取模型/导入/导出/下载均不执行业务；
请求头行、输入、开关、协议和顺序只修改本页草稿。端点预览纯字符串变换，密钥只在
controller 生存期保留，失焦超过8字符时显示前4/星号/后4，离开页面释放。
模型页上下文与总结分别默认折叠，布局不同于独立上下文页；标准参数全部默认关闭。
默认目录是旧 Android 的文字快照，不访问当前宿主路径。供应商目录不表示服务当前可用。
共享工作台按旧 KiyoriSettingsTheme 覆盖卡片/背景/文字色，暗色不再使用浅色背景；
其它页面硬编码颜色与设备实际暗色仍需逐页验证，不能由模型页截图外推全局通过。

功能模型分配来自 FunctionalConfigScreen / FunctionConfigCard 与 FunctionType，11卡顺序
不变，保留16px外层圆角、8px当前配置/候选卡、6px模型子项、配置展开及模型二级展开。
管理模型使用宿主回调；测试、真实重置为空点击，模型选择只更新页面草稿，离屏保留。
FunctionModelsPresentation 注入配置摘要、绑定、加载/失败、媒体能力和测试结果；默认
无已知配置，不创建虚假模型或连接结果。媒体能力未知时不声称已支持或不支持。
旧 autoglm 对话主模型限制保留，结果一行省略/24px更多按钮展开遵循 ExpandableStatusText。

上下文与总结来自 ContextSummarySettingsScreen；模型默认值64K/200K、总结启用、0.7、
按消息数启用/16条来自 ModelConfigDefaults，历史媒体2/1回合来自 ApiPreferences。
页面采用6px圆角、12×8px内边距、4px纵间距、88/72px数值输入、80px最小规则编辑区。
默认快照不创建真实模型；输入、依赖开关、格式过滤和错误展示仅影响局部草稿，历史媒体
重置只恢复2/1且保留上下文与规则。标题使用旧图标语义色；窄屏大字数值移至第二行。
错误判定沿用旧实际逻辑（比例大于0且小于1、消息数正整数），说明文案保留原0.1–0.95
和1–20条；当前不自动保存，不启动总结或向模型发送内容。

聊天历史五卡来自 ChatHistorySettingsScreen，归类弹层来自 CharacterCardAssignDialog /
CharacterGroupAssignDialog，日期范围来自 MemoryRebuildDateSelector。保留20px卡片内边距、
16px间隔、320px内列表上限、搜索标签、群聊/角色/分组排序与互斥目标草稿。
旧入口只设置群聊归类标志却缺少弹层宿主的路径，在新 UI 中接通对应归类弹层；最终动作
仍为空点击。离屏保留批量与工作区选择；快照更新移除已消失条目的选中状态。
日期正文常规高度480px、底部取消/确认，短屏可滚正文；日历月份按需构建，支持范围选择
与文本输入，非法范围留在弹层提示。flutter_localizations 为 SDK 依赖，intl 随 SDK 锁定，
仅在日期弹层覆盖中文，不改全局 locale。不读取真实统计、不执行重建或删除。

六页引导来自 KiyoriOnboardingScreen / Design / Contract 与 strings_onboarding_redesign.xml。
重看由独立全屏模态路由隔离设置，顶栏48px、六段4px进度、20px正文边距、2×2等高卡片；
内容宽720且字体小于1.3才采用双列，导航图仅在宽300/高440以上且小字体显示。
法律阅读复用受控正文，在引导宿主内替换内容，返回恢复原勾选与滚动位置。
未确认时实际只有五页，确认后才加入权限页；协议事实、权限快照与本次草稿分离。
23项权限目录与设置共用，选择/清空/折叠是局部交互，授权、退出应用与首启写入由后续宿主接入。
默认快照未知，未访问 Android 或 Windows 权限系统。iOS 构建及设备像素与触摸仍待验证。

界面定制与数据备份的父级列表、AI 助手五组十四项来自 KiyoriApplicationSettingsPages，
保留父页后再打开主题/备份详情，系统 Back 逐级恢复。语言清单来自 LocaleUtils 与
LanguageSettingsScreen，八项原名及提示文案保留，语言切换为空操作。
账号页默认未连接快照；GitHub 方式选择来自 GitHubLoginMethodDialog，哔哩哔哩两模式
来自 KiyoriBilibiliAccountSection。二维码请求、验证、导入和外部跳转为空操作；Cookie
字段不持久化，切换方式或关闭即清除。AccountPresentation已覆盖已连接/失效/读取/
busy/错误快照、退出和移除确认；GitHub方式选择已接全屏登录壳，64顶栏/21图标，完成态
禁止关闭/刷新/Back。B站注入二维码图像与挑战状态，轮询中允许刷新，过期清除；有效二维码
请求、OAuth与WebView尚未接入。界面状态和实际账号认证分开验收。
虚拟形象入口接入模型目录、220px预览、六类型参数、情绪映射和完整导入指南。
草稿按模型存在期隔离，删除时关闭所属弹层；参数、默认值与生命周期证据见
[设置映射](settings-replication-map.md)。无原生renderer时使用旧不支持分支，不伪造预览。
全局显示与布局调整来自 GlobalDisplaySettingsScreen / LayoutAdjustmentSettingsScreen，
保留分组、折叠工具三档、通知和自动化条件项、1.5/3/5/10/20 Mbps、PNG/JPG、质量/缩放
滑轨，以及 2/16/1/0/12 默认数值和 0.8–2.0、0–48 等错误范围。所有设置/保存/重置
仅改局部草稿；Root 命令、前台服务、截图和偏好存储不执行。

主题设置来自 ThemeSettingsScreen、ThemeSettingsTabs、五个 ThemeSettings*Tab、
ThemeSettingsCoreSections / FontAvatarSections / BackgroundSection 和 ColorPickerDialog。
五标签保留默认 56px 几何；大字体增加高度，横屏键盘极短视口才改横排紧凑标签。
面板按访问创建，非当前面板暂停 ticker，当前滚动接入共享收缩顶栏。样式仅为局部草稿，
气泡字体/图片参数由聊天面板持有并投影预览；不保存角色配置、读取文件、创建播放器或
改变全局主题。文件选择与重置保留空操作；已选媒体与完整九宫格预览待后续覆盖。
手动色盘支持 HEX/RGB/HSV、亮度/透明度与原预设色；粘贴不访问剪贴板。

备份页来自 ChatBackupSettingsScreen / BackupCards / BackupManagementCards /
BackupDialogs，十张卡片原顺序，聊天导出为选择与格式两层，记忆导出为配置选择。
BackupPresentation 仅为展示快照，默认零值是旧初始化外观，不代表本机统计；未加载审计
保留原 spinner，列表惰性构建。最终业务按钮为空操作，不显示假成功或调用系统选择器。
数据库保留数默认 10，自动备份未读取时原开关禁用；原路径为 Kiyori-Android，帮助文案
仍保留源资源中的 Kiyori。恢复/运行结果及导入选择器返回后的分支仍待覆盖。
公共主题主容器、次色、第三色和错误色已从 KiyoriColorSchemes 显式映射，避免 seed
算法生成与原色值不同的按钮；不改变页面布局。

开源页面来自 KiyoriOpenSourceLicensesPage / OpenSourceLicenses，保留 150 项旧清单、
六分类、摘要替换、许可和网址搜索；原清单基线 2026-09-06-r1。此表是复刻快照，
不作为当前 Flutter/Rust 构建所含依赖的声明；真实依赖清单必须后续按新锁文件和二进制
审计替换数据源。查看许可/主页保持空点击，不启动浏览器或访问网络。

权限页来自 KiyoriPermissionsSettingsPage / KiyoriPermissionDisclosure /
KiyoriPermissionPresentation：五个折叠分组、23 项能力，第一组默认展开，图标与用途照录。
状态从注入快照投影；未接平台 adapter 时使用“未检查”和“—”，避免把未查询的系统状态
伪装为零授权或无需授权。此处是明确的事实边界差异；授权/刷新默认空点击，真实已授权、
部分授权、需配置、无需和按次确认分支可由测试夹具验证。折叠状态随列表离屏保留。

协议阅读页对应 KiyoriLegalDocumentScreen / LegalDocumentBody，正文直接从旧
values/strings.xml 的 CDATA 按旧章节规则提取，版本 2026-09-08-r1，两份各 16 段。
保留完整正文、选择、展开目录和章节定位；定位标题自身以避免大字长段将标题滚出视口。
这属于旧 UI 快照，未替新跨平台版本做法律审阅，不修改正文、不写同意记录；正式发布前
必须按实际实现重新核对软件范围、第三方归属、数据处理和联系地址。

更多功能和存储汇总来自 KiyoriMoreFeaturesSettingsPage / KiyoriStoragePathsPage；
产物编辑来自 ArtifactStorageSettingsScreen、ArtifactPathRules 和 values/strings.xml。
原路径仅作为旧默认外观快照，不映射到本机磁盘、不建立目录、不迁移数据。
工作台以共享 SettingsWorkspacePage 保留独立正文与底部操作；标题消耗 72px 滚动而
只减少 64px 高度。路径预览和错误外观属于草稿投影，真实校验仍须由未来 storage owner 接管。

网络代理来自 KiyoriNetworkProxySettingsPage / KiyoriNetworkProxyModels：概览、节点、
订阅、规则、脚本、日志六层。产品默认使用 Ready 空配置的 UI 快照，默认直连，无订阅；
空态原文、代理模式三段按钮、添加地址、规则类型菜单、匹配动作和日志筛选均保留。
匹配外观校验使用原类型与 4096 字符上限；CIDR 只做本地数值地址解析，不进行 DNS。
真实配置和代理仍无 owner，不启动核心、网络、系统代理、文件选择器或导入/保存操作。
NetworkProxyPresentation可注入已有目录、配置不可读、外部路由、五运行阶段和反馈。
URL/本地订阅编辑预填、删除确认、当前订阅原始规则、自定义规则/脚本模式均可达；
节点按旧480上限列表、分组下划线、名称/延迟排序，测速与切换不改写快照。
日志逆插入顺序、级别/内容查询、清空确认保留，复制/导出无副作用。实体移除和宿主
卸载精确关闭所属路由；规则更新/当前订阅切换释放旧规则草稿，忙碌时禁止确认与退出。
弹窗标题与正文共同滚动，修复横屏大字键盘下输入区被挤压；按钮仍位于底部。

广告拦截 5 页来自 KiyoriAdBlockSettingsPage，公开内置订阅来自
BrowserAdBlockSubscriptionCatalog。默认保留5个启用但无载荷的内置来源及“读取中”快照，
不代表后台加载事实；AdblockPresentation另可投影加载/编译/就绪/失败和已有目录。
URL/元素/白名单搜索与编辑、域名折叠、自定义订阅与删除确认已接入，订阅失败可显示
仍可用的旧规则计数，批量同步互斥投影禁用。实体移除释放所属弹层，搜索不删除实体；
保存、切换、删除、同步为空动作，实际读取/过滤/编译/联网仍待共享领域owner。

## 播放器与工具箱设置追加

文档设置来源 DocumentSettingsScreen / DocumentWorkspace / DocumentEditingPolicy：
阅读 18sp、编辑 15sp、行距 1.65、宽度 720dp；说明原文照录，不代表本阶段已有文档
引擎。文件格式弹窗来自 FileOpenDefaultsDialog / FileOpenWithDialog；只投影格式推荐，
输入规范化与嵌套选择，不执行文件打开或保存规则。

音乐设置来源 MusicSettingsPage、MusicSourceSettings、MusicDownloadSettings、
MusicDesktopLyricSettings、MusicBackupSettings 与对应 MusicWorkspace 默认值。
共 10 分组；ThinSlider 的轨道 2px、圆点 10px，局部预览；默认未启用音源、320k、
顺序播放、音量 100%、桌面歌词关闭。音源/备份资料为空，真实选择器与网络为空点击；
MusicSettingsPresentation另投影音源目录/详情、链接更新、切换/移除、忙碌/错误与LX
备份预览、合并/替换同ID、撤销及导出确认。所有确认保留空业务动作；脚本正文不进入UI。
音乐偏好与桌面歌词接收类型化快照；下载别名依赖标签，罗马音依赖歌词文件或内嵌歌词。
滑块拖动结束回到权威快照，不把空操作伪装为已保存。详情和编辑随实体存在期释放；
备份预览取消后不会因列表离屏回收再弹出，新的解析ID才建立新会话。

播放器来源为旧 KiyoriPlayerSettingsPage、PlayerModels、PlayerExperienceSettings、
PlayerExperienceSettingsContent 与 PlayerPanels。主设置 6 组 28 项；四个体验子页使用
16px 水平内边距、10px 垂直内边距、8px 间隔、13/12/11px 紧凑正文；按钮和滑块仅展示
或编辑局部草稿。默认队列结束为关闭播放器，字幕比例为 100%，不建立独立业务设置存储。

工具箱来源为 KiyoriToolboxSettingsPage、ToolboxGroupEditor、ToolboxGroupManager、
ToolboxMoveToolsDrawer 与 ToolboxLayout。一级页与抽屉共用内置入口展示，默认包含
4 个常用入口与 5 个管理分组（含空的未分组）。业务添加/删除/保存/移动均为空点击；
拖动只在手势中移动，结束回到权威快照，不伪造保存成功。自定义组按`custom:` ID投影
重命名预填、删除后移入未分组说明、保存错误；名称使用旧空白归一、控制字符、40 UTF-16
字符和NFKC+小写重名校验。菜单按当前稳定实体解析，实体移除或保存禁用时释放菜单，
对应编辑会话随实体/宿主释放，同ID重入不复活旧输入。批量移动按标题、说明与关键词逐词
匹配，目录变更过滤已移除工具/目标组；系统Back直接关闭两步抽屉，底部上一步仅切换步骤。
加载/错误通知、全量已加入常用、清色确认与保存期间禁用投影已补入；真实布局owner未接入。

所有选择器和管理抽屉共用 modal_drawer 的三态动画、系统 Back、遮罩、handle 与安全区，
键盘改变部分展开锚点，内容子树不随动画逐帧重建。短屏或大字体时管理正文整体滚动，
标题与底部操作固定，避免原固定说明/搜索区挤压正文视口；默认参数不变。
公共抽屉新增可选退出检查，返回、遮罩、关闭与handle下拖共用检查，拒绝拖动退出后恢复
展开锚点。搜索输入新增可选enabled，保存时同时禁用触摸和已聚焦键盘输入。

## 全页面持续复刻（2026-10-02）

方案见 [分层实施](ui-replication-plan.md)，进度只在 [status](../status.md) 更新。
当前 `kiyori_ui` 新增收缩设置标题、无前导图标行与三态选择抽屉；参数来源为
`KiyoriCollapsingSettingsPage.kt`、`KiyoriSettingsUi.kt`、`KiyoriDraggableBottomDrawer.kt`。
注意 selection 的 26dp 常量未用于旧抽屉实际 shape，实际使用 `KiyoriUiShapes.sheet`
的 16dp 顶角。标题滚动 72dp 完成 128→64 高度、32→54 左距、60→20 顶距、26→20 字号。
高频偏移仅更新顶栏，不重建列表。

设置页现可导航到浏览器、下载器、文件管理器子页。浏览器、下载、文件各自持有原
Kotlin 页面内容，不用万能目录生成替代工作台。来源为同名 `ui/main/shell` 文件和
WebSessionBrowserSettingsStore、BrowserDownloadSettingsStore、FileManagerPreferences。
未实现功能仍空点击；弹窗编辑仅保留草稿，保存不持久化；主题 dialog shape 统一旧 20dp。
密码管理投影原“不可用”分支，原因采用当前事实“本机凭据存储不可用”，不宣称已用 Keystore
加密；用户脚本采用旧默认的不可用/未授权态，保持原依赖灰态而非按未实现统一禁用。

发现上一轮 browser `about:blank` 是会话种子外观，不能推断首次安装设置值：
`FRESH_INSTALL_BROWSER_SETTINGS` 主页是 `https://web.gotab.cn/`，返回不重载、强制缩放、
密码保存均开启。本轮设置使用实际 fresh 值；已有浏览器空白 UI 仍不加载外网。
后续浏览器首页表面需对照 presentation owner 继续核对，不能把空白种子当全部主页已复刻。

跨平台改名后的资源路径使用 Kiyori，不接触旧 Kiyori-Android 数据；Android 风格设置
中的系统名/描述保持原文，但不会在桌面启动 Android 系统操作。窄窗/双倍字体时选择抽屉
提高最小可见高度保证标题/取消区可达；默认手机几何和旧宽度断点保持。

## 四个一级页面增量（2026-10-02）

本次沿用旧 `D:\10_Project\Kiyori-Android` 的 `6b03b03aa082803bb279db5e78773583e2d91154`，
从新仓库干净 `main` / `c0be83d` 开始，用户授权构建后全部提交推送。范围为底栏打开的
浏览器、工具箱、文件管理、设置一级页面；不迁移旧偏好、文件或账号，不接入业务、安装设备
或运行远端 CI。以下新契约覆盖后文历史中的“底栏目的地空点击”。

| 旧源码（相对 `app/src/main/java`） | 当前迁移 |
| --- | --- |
| `com/kiyori/app/shell/KiyoriPrimaryNavigation.kt`、`KiyoriShellState.kt` | 唯一一级导航、选中动画、首页 Back；浏览器隐藏主底栏、顶栏退出恢复来源 |
| `com/ai/assistance/operit/ui/main/shell/KiyoriCollapsingSettingsPage.kt` | 固定标题区 64，标题左 16 / 顶 20 / 20sp，操作区右 8 / 顶 8 / 高 48；卡片圆角 16 |
| `ui/features/toolbox/ToolboxPage.kt`、`ToolboxCatalog.kt`、`ui/main/screens/ScreenRouteRegistry.kt`（同一 operit 根） | 原常用四项、内容七项、AI 四项、开发七项、设备两项；卡片外 16、上/间隔 14，内 12/8；48 触区与 38 胶囊，分组折叠 |
| `ui/main/shell/KiyoriFileHomePage.kt`、`KiyoriFileManagementPage.kt`（同一 operit 根） | 六类四列网格、四个快捷项、五个存储位置；外 16、上/间隔 10，36/16 网格徽标、32/20 列表徽标；未统计和容量不可用沿用旧文案 |
| `ui/main/shell/KiyoriSettingsHomePage.kt`（同一 operit 根） | 四组十二入口，原顺序和 15.5sp；外 15、间隔 14，行内 16/10/14/10，34/17 徽标，0.6 分割线；顶栏原 PNG 与 0.48 透明度 |
| `ui/features/websession/browser/WebSessionBrowserTopBar.kt`、`chrome/WebSessionBrowserBottomBar.kt`（同一 operit 根） | 原 8/6 间距、42 高圆角 14 地址框、40 操作区；底部 44 触区、26 图标和 20 窗口计数框；复制原自有矢量路径 |
| `core/tools/defaultTool/websession/browser/BrowserSessionRecoverySupport.kt`（同一 operit 根） | 默认启动创建 `about:blank` 的外观：空白正文与计数 1；仅展示该默认态，不构造假会话或原生视图 |
| `com/kiyori/design/theme/KiyoriSettingsTheme.kt`、`KiyoriIconColors.kt` | 背景 #F6F7F9、白卡、正文 #20242A、副文 #6E747C；图标按原真实字形身份色，保留回收站专用色 |

实现位于 `features/{browser,toolbox,files,settings}/presentation`；共享标题、卡片和语义色在
`kiyori_ui`。首页三页仍由一个 PageController 持有；按访问创建一级页并保留轻量展示状态，
没有领域 I/O、额外 Rust API 或依赖。搜索、设置子项、工具、文件、管理和主题按钮均空点击，
不显示开发提示或额外灰态。浏览器前后按钮保留原初始 0.38 外观但同样空点击。

自动验证覆盖 320/390/1280 宽度、正常/双倍字体、滚动末项、返回来源、空点击、折叠和
AI 草稿保留。双倍字体测试同时发现首页既有两处横向溢出，改为仅约束文字宽度，默认几何
保持原值。可选捕获输出四页实际 Flutter 渲染图，按上述源码检查布局；同设备旧新逐像素、
真实触摸、系统字体渲染和 iOS 编译仍为 `verification_pending`。最终构建/交付证据见
[当前状态](../status.md)，不能将参数对照与本地截图说成全平台像素验收。

## 目标与基线

本文的版本、授权和产物记录是前轮 UI 复刻历史；2026-10-02 后续工程基础优化、
Flutter 补丁升级与提交推送以 [status](../status.md) 为准，分页变更见[性能契约](../development/performance.md)。

重构保留原 UI 和功能设计，改善目录架构、内部实现和多平台支持。用户在 2026-10-02 明确要求，当前优先级高于 M2 业务开发。旧仓库 `D:\10_Project\Kiyori-Android` 仅只读参考，基线提交 `6b03b03aa082803bb279db5e78773583e2d91154`。新仓库起点是 M1 的 148 个未跟踪文件，main 尚无 HEAD；本轮不提交推送或安装设备。

本轮范围：应用图标、中央首页、左侧负一屏、右侧 AI 对话空会话及五图标底栏。未接入的业务动作保留空点击，不新增假数据、提示弹窗、替代页面或真实模型调用。页面滑动、模式切换、输入草稿与返回属于本轮真实 UI 交互。旧项目用户自定义主题/字体/背景不迁移，以源码默认浅色样式为基线。

## 源码依据与几何

旧仓库路径均相对 `app/src/main`：

| 依据 | 迁移契约 |
| --- | --- |
| `java/com/kiyori/app/shell/KiyoriSoftwareHome.kt` | 0.382 高度定位；内容底部预留 72；宽度断点 600/840，左右留白 24/48/72，最大宽度 544/584/624；搜索框 114，高度不足 440 时 96；边框 1、圆角 18；模式栏 120×40；品牌图标 18 |
| `java/com/kiyori/app/shell/KiyoriPrimaryNavigation.kt` | 顺序：首页、浏览器、工具箱、文件管理、设置；44 点击盒；图标 26，中央 25；左右 16、下方 6，加系统底部 inset；无文字、无涟漪；选中黄色填充与背景色细节 |
| 同上动画 | 70ms FastOutLinearIn 收缩，然后 stiffness 420 / dampingRatio 0.42 弹簧；设置为 0.55；最终比例 1.1/1.1/1.12/1.1/1，设置起始 0.9；选中交叉淡化 160ms |
| `java/com/kiyori/app/shell/KiyoriAppShell.kt` | 左/中/右三页；中央页 offset 的绝对值控制底栏 alpha = clamp(1-abs(offset),0,1)；边页底栏不接收点击 |
| `KiyoriMinusOnePage.kt` | 标题 20；收藏/书签/历史/下载；卡片圆角 18、条目 16；八项快捷工具 4×2，原 0.58 透明度保留，按本轮要求空点击 |
| `ChatScreenHeader.kt`、`ChatHeader.kt`、`AgentChatInputSection.kt`、`AppContent.kt` | AI 顶栏及工具入口、次级历史/悬浮/角色/统计栏、空消息区、底部 Agent 输入框；输入 14sp/20 行高、顶部圆角 20、模型选择及调节/附件/语音操作 |
| `java/com/kiyori/design/theme/KiyoriColorSchemes.kt`、`KiyoriIconColors.kt` | 白底、正文 #202124、副文 #5F6368、主色 #256DB0；底栏选中 #FFC153；保留角色颜色 |
| `res/drawable-nodpi/ic_kiyori_app_icon.png` 与 launcher foreground、adaptive icon | 同源应用/品牌图标，Android 自适应前景直接复制；Windows/iOS 根据同源图生成所需尺寸 |

尺寸单位映射为 Flutter logical pixel；系统 inset 由平台提供，不硬编码状态栏或导航栏高度。桌面保留相同五图标底栏，首页内容采用原有宽度断点，不再切换 NavigationRail。字体使用各平台系统字体；不同字体栅格器、系统栏、Compose/Flutter 动画积分和触摸采样须在同设备对照验收，源码参数相同不等于已经证明每帧像素相同。

## 实施和验证计划

STT 依据 `SpeechServicesSettingsScreen.kt` / `SpeechServicesPreferences.kt`：语音配置
选择、新建/重命名/删除弹窗，本地 Sherpa、远程 OpenAI/Deepgram 引擎及端点/密钥/model
字段，能力说明与密钥显隐。配置默认名称沿用旧初始化快照，不代表已执行数据迁移。
切换配置保留独立输入，移除配置释放草稿；保存、删除、识别与服务初始化均未接入。

TTS 同源复刻九引擎；首次默认依据 `SpeechServiceProfilesPreferences.ensureInitialized`
选中 Next 内置 HTTP 配置。系统配置后、远程配置前保留正则清理列表及五个模板；语速/音调
0.5–2.0、六分区，字段14px或原默认4px圆角。HTTP方法/Content-Type普通横排，窄屏大字
改纵排；选择弹窗在键盘与短视口下可滚动。系统音色、远程模型/音色和加载/错误快照不
触发系统或网络访问；只有旧静态的Realtime、MiMo、豆包、硅基目录直接作为展示常量。
朗读工具依据 `TextToSpeechScreen.kt`：16px间距/卡片、五行输入、56px操作按钮、状态/错误
和说明卡；播放/停止为空，清除错误只隐藏本页快照。滑轨逐像素与平台顶栏仍需设备对照。

语音唤醒依据 `KiyoriAssistantExperienceSettingsPages.kt` / `VoiceAutoAttachComponents.kt` /
`WakeWordPreferences.kt`：三设置组、两识别模式、三遍录音模板与清除确认；原唤醒词
“小欧”、响应“我在”、分组“全局助手”、5秒超时与四种默认附件关键词原样保留。
字段18×8px内边距/14px圆角；附件96px最小宽、8px间距、22px图标、14px圆角和0.8px描边。
附件网格高度随字体伸展，避免旧320px上限裁掉大字内容；录音弹窗、附件二级删除弹窗在
小屏/键盘下可滚动。超时粘贴用任意精度整数限制1–600，纠正旧Int溢出后不限制的输入漏洞。

AI用量与费用依据 `TokenUsageStatisticsScreen.kt` / `TokenUsageStatisticsComponents.kt`：
统计卡、模型分布、模型详情/空记录、汇率卡和顶栏重置，16px卡片/内边距、12px卡间距；
分布图180px、原七色轮换与前八项图例，窄屏/大字改纵排避免原固定220px容器溢出。
定价包含Token三价格与按次一价格、重置模型/全部两种确认。新增共享工作台可选48px
顶栏操作，原无操作页保持16px标题尾距；有操作页64px。保存/重置为空动作，货币由快照
提供；定价校验排除非有限值和负数，避免旧 toDoubleOrNull 接受无效费用状态。

局域网与自动化依据 `ExternalHttpChatSettingsScreen.kt`：十张16px圆角/内边距卡片，
卡间12px、内部8px、14px输入框和示例背景，原端口18094及四类状态文本。已保存端口和
令牌决定示例，输入不即时替换这些事实；重置、服务启停、复制和保存均为空动作。
回复与表情依据 `WaifuModeSettingsScreen.kt` / `WaifuPreferences.kt`：11卡、24px卡间距、
16px内边距、14px默认卡圆角、合并间隔500–10000ms/100ms步进、打字200–1000ms/20ms步进，
默认250ms/5000ms及原提示词；自拍展开不丢草稿，不显示伪造的“设置已保存”。
自定义表情依据 `CustomEmojiManagementScreen.kt`：目标卡、类别、三操作按钮、三列方格、
8px格距、16px网格内边距、右下56px添加按钮和方形图片预览；53张同源资产原样打包。
创建类别按规范化后文本校验，避免旧源码将大写转小写后仍报错；创建/导入/删除/恢复不执行。
当前未验证GIF离屏/切页在真实引擎的解码暂停和帧成本，不能据widget解码成功宣称性能通过。

工具授权依据 `ToolPermissionSettingsScreen.kt`：原介绍、全局允许/询问/禁止、使用说明、
允许/禁止两例外卡、搜索/选择弹窗。16px 卡片圆角与内边距、12px 按钮圆角、8px 间距、
工具名称忽略大小写排序、代理类工具过滤均按源投影；草稿切组互斥，不调用旧注册器。
资料页依据 `UserPreferencesSettingsScreen.kt`、`MarkdownSyntaxHighlighting.kt` 与
`CanvasMarkdownNodeRenderer.kt`：12×10 外边距、14px 工具栏圆角、16px 编辑区圆角、
14px 等宽编辑、12000 字符提示、编辑/预览与未保存、返回/恢复弹窗、旧档案抽屉。
默认模板沿用空串；超限不截断输入，保存与复制为空操作。正文标准 Markdown 的标题、
段落、列表、引用、代码和表格由 AST 投影；媒体、公式与图表仍待共享渲染层复刻。
空间不足时档案标题可随正文滚动；普通尺寸仍固定标题与复制区。详细依赖与边界见
[资料预览决策](../decisions/0003-profile-markdown-presentation.md)。

1. 固化上述基线，复制品牌素材并转换原自有导航矢量；不引入旧项目包命名。
2. UI package 负责主题、图标和复用点击控件；app shell 负责 pager、选中动画及页面生命周期；首页/负一屏/AI 按页面拆分。
3. M1 Rust 会话生命周期保留。运行检查仅通过开发入口进入，不占产品首页或接管设置空点击。
4. 测试页面次序、导航空点击、底栏几何/动画/淡出、草稿保持、小屏和大屏；输出实际 Flutter 渲染图进行视觉检查。
5. 静态检查与相关行为测试、Android/Windows 构建、APK 身份/资源检查；iOS 同步图标和源码但待 Apple 编译。设备并排视觉/触摸验收未执行时保留 `verification_pending`。

恢复点为 M1 文件与任务日记；不清理未知用户文件，不改共享 Rust 契约。README 本轮面向开发者，修改理由是产品入口改为原样复刻；权威来源为本文源码依据与实际实现；结构/链接检查和 Flutter 渲染图分别验证，不声称做过 Markdown 宽窄屏预览；当前无英文副本。

## 本轮实际结果

已复制旧项目品牌图标；`apps/kiyori/assets/branding/kiyori-app-icon.png` 的 SHA-256 为 `2220044E62C8BDAD0AFB9BB03C00AC2D106AB55D417EEFA26AB52E0A833DBE01`，与旧文件一致。Android 自适应前景 SHA-256 为 `9AAF6FA98EA65D8FA5D82F5017C8B9924C7D430AC6EE2A8C1588B3CDC4E9D2C3`，也与旧文件一致。Windows ICO 与 iOS AppIcon 各尺寸来自同一源图。五项导航原矢量转换为 4 倍逻辑尺寸的透明 PNG，保留原轮廓、填充和细节分层。

页面实现在 `app/shell/` 与 `features/assistant/presentation/`。首页默认居中，负一屏保持四项数据卡和 4×2 快捷工具，AI 页保持顶栏、次级会话栏、空消息区和 Agent 输入区。底栏五项均有选中交叉淡化和原参数收缩/弹簧；未接入目的地保持当前页面，仅投影图标选择反馈。Rust 运行时生命周期保留，开发诊断改用 `KIYORI_DIAGNOSTICS=true` 独立入口，不占用产品设置按钮。

| 验证 | 结果 |
| --- | --- |
| `tools/verify.ps1 -WindowsIntegration` | Rust fmt/Clippy、6 个核心测试、Dart format/analyze、10 个 Flutter 测试、6 个真实 FFI 测试通过 |
| `flutter test integration_test/runtime_test.dart -d windows` | 2 个实际引擎测试通过：核心任务完成/取消，以及产品图标加载、AI 页面和空操作 |
| `tools/build.ps1 -Platform windows` / `-Platform android` | 两端普通 Debug 构建通过；Windows 在集成测试后恢复正式入口 |
| 可选 `ui_capture_test.dart` | 1 个捕获用例通过；实际 Flutter 四张渲染图经检查，未设未经对照的黄金图基线 |
| 品牌图标、Android 前景 SHA-256 | 与旧源图逐字节相同 |

主验证共 24 项行为测试（6 Rust + 10 Flutter + 6 FFI + 2 Windows），截图用例另行执行。普通验证默认跳过截图用例，显式运行方式是在 app 目录执行 `flutter test test/ui_capture_test.dart --dart-define=KIYORI_CAPTURE=D:/10_Project/Kiyori/work/ui-parity`；其它机器可用 `KIYORI_CAPTURE_FONT` 指定本地字体，不分发系统字体。初次捕获未预加载 Material 字体和异步图像，已修正捕获流程并重生成，不能把初次缺字图当产品结果。

本地图片位于忽略目录 `work/ui-parity/`，包括 `home-phone.png`、`minus-one-phone.png`、`chat-phone.png`、`home-desktop.png`。视觉检查纠正了模式背景高度、窗口计数尺寸和历史入口未选择背景。未执行旧/新应用同设备并排验收；Compose 与 Flutter 的字形、涟漪及 Pager 动画逐帧一致性仍需设备对照。iOS 图标与共享源集已同步，未编译。保留 `verification_pending`，不把本地截图称为全平台像素一致。

最终 Android APK：`apps/kiyori/build/app/outputs/flutter-apk/app-debug.apk`，2026-10-02 02:41:28（Asia/Shanghai），94866954 字节，SHA-256 `F1CFECA1F8358658EB1868DCCD36E4F9BB27175399DA53F5C62F638B3F9EB18D`；aapt 确认 `com.kiyori`、Kiyori、minSdk 24 / target 37、arm64-v8a 与自适应图标，apksigner v2 验证通过。Windows 普通 Debug 位于 `apps/kiyori/build/windows/x64/runner/Debug/`，须保留 DLL/data 全目录。

Git 仍为 unborn main，无 HEAD、暂存、提交或推送；收尾共 172 个未跟踪交付文件（含 M1 基线），忽略 work、构建目录和本机配置。旧仓库仍干净，本轮 Gradle daemon 已停止。
