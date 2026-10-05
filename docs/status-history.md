# 历史实施记录

本文归档已结束批次的证据。历史任务、授权、下一步和产物仅在当时有效；当前事实以 [当前状态](status.md) 为准，归档中“当前”“下一步”均指当时。

归档日期：2026-10-02（Asia/Shanghai）；[路线图](roadmap.md)维护阶段顺序，环境证据见[环境报告](development/environment-report.md)。

## 第一轮治理交付 ca8bf6f（历史快照）

提交 `ca8bf6f2b6513c301a4e99952246d9df6dd7c426`，已推送 origin/main；第二轮开始时
实时 fetch 核对无分歧且工作区干净。第一轮提取 SettingsNavigation，统一四套截图辅助，
新增 test-ui/inspect-legacy 正式入口，启用 Android 本地 task cache，并修正 Windows
引擎测试的账号详情返回。历史候选树396文件约5.90MB，未增加业务/FFI API。

验证为6 Rust、238 Flutter、6真实FFI、2 Windows引擎测试；governance-verify.log 的
Windows阶段首次失败，修正后通过记录在 governance-engine.log，不能把前者整体说成通过。
四截图套件106张；Android/Windows普通Debug最终构建通过。产物固定在
`artifacts/ui-preview/20261002-124054/Kiyori-ui-preview-arm64-debug.apk`，
2026-10-02 12:40:54，97,970,173字节，SHA-256
`9B16B11D596CE8EDD0CFAEF0F64175EEED8E9229FED7007462C0F36580277F67`。
包名 com.kiyori / 0.1.0(1)，arm64-v8a、min24/target37、v2签名和16KB ZIP对齐通过。
12:11包（97,970,244字节，SHA-256
`4737B19CE28857BA927CFAB62B2D05B1042A8318AC7C30BA19DBB99FA6EF3070`）和11:23包均保留。
这些历史包不含第二轮治理。未安装设备、未执行远端CI/Apple构建，kiyori-ui 为 PAUSED。

## 当前任务：全页面 UI 持续复刻

基线：干净 `main` / `3a35913`；旧仓库只读 `6b03b03a` 已重新核对且干净。
正式 Goal active，当前聊天每小时自动接续（`kiyori-ui`），直到用户终止。
范围与由浅入深的顺序见 [实施方案](design/ui-replication-plan.md)。本次没有提交、推送、
安装设备或发布授权。进度为 U1/U2：原样设置公共组件与首批设置页已落代码，继续扩展。

第一批已实现：收缩标题（128→64 / 72px）、无前导图标设置行、三态选择抽屉；
网页浏览器 7 组 22 项、主页/编辑弹窗、文字预览、密码不可用态、脚本权限空态、
Cookie 确认与自定义悬浮时长；下载器 5 组 14 项和选择器；文件管理器 9 组及路径、
隐藏清单、排序/密度/刷新选择、回收说明与恢复确认。一级页和来源页返回保持。
业务保存/系统动作空点击，主页模式和文字比例仅局部预览，无文件扫描、网络或设置持久化。

本地 `tools/verify.ps1` 已通过 6 Rust + 32 Flutter + 6 FFI，含新增 13 项行为测试；
基础检查、fmt、Clippy、analyze 通过。该批 Android/Windows Debug 均已构建。
实际渲染图位于忽略目录 `work/settings-ui/`，已检查设置页、主页、选择抽屉；
后续继续补获新增文件页与异常态截图，不将旧截图当最新产物。
第二批已实现播放器 6 组 28 入口、四个专业子页与选择抽屉，业务空点击，滑块为局部
预览；播放器批完整 verify 通过 6 Rust + 38 Flutter + 6 FFI。
工具箱设置、常用/组内排序、分组管理、新建分组、批量移动两步 UI 已接入；内置入口
展示目录为单份，添加/移除/保存/移动不写配置。新建自定义组业务未接入，故重命名/
删除自定义组分支待后续数据契约接入时验收。工具箱 6 组宽度/字体/键盘测试通过。
公共抽屉已统一动画 owner，内容子树不随动画重建；修复键盘锚点和短视口正文溢出。
第二批完整 verify 通过 6 Rust + 44 Flutter + 6 FFI；最终截图已重捕并检查播放器/
工具箱默认渲染，紧凑按钮字体恢复。Android/Windows Debug 均构建成功。
第二批 APK：2026-10-02 05:35:42，95,213,450 字节，SHA-256
`88972374323A674CCA38646762AE37D293101FBEBA44316ECBB6167A7579D161`。
第三批已追加文档 4 组设置/说明、文件格式两层弹窗、音乐 10 组设置（音源、下载、
播放、歌词、历史、备份等），新增 12 项宽度/字体/层级测试通过。完整 verify 已通过
6 Rust + 56 Flutter + 6 FFI，截图已刷新并检查，Android/Windows Debug 构建通过。
第三批 APK：2026-10-02 05:48:12，95,243,841 字节，SHA-256
`6FD5268B898DAA15F061BC2B304FBE8EAFD284AF3F937EB1BF665F6637097C3A`。
没有音乐资料、联网、文件授权或导出动作。随后滑轨细节修订与后续设置仍在持续推进，
构建只能验证对应构建时的源码；未在设备安装或验证 Profile 性能。
接着继续工具箱文档设置、文件格式选择，以及 U2 其余设置和 U3 抽屉。

第四批已验证广告拦截 5 页、规则/白名单/订阅新增弹窗、内置订阅展开。
本批是旧 Store 的初始化 UI 快照（5 个内置来源、零载荷、读取中）；无规则编译、
联网或统计，不能当作广告拦截功能已实现。6 项宽度/字体/返回测试已通过。
搜索组件按旧 KiyoriSearchField 改为 42px 最小高度、14px 圆角、1px 中性描边，
复用于工具箱批量选择；音乐滑轨去除 Flutter 默认激活段增粗。
第四批完整 verify 日志确认 6 Rust + 62 Flutter + 6 FFI 通过，Android Debug 构建通过。

第五批已验证更多功能、存储与路径、AI 产物目录编辑，以及网络代理六层默认页面。
存储页保留旧默认路径快照，编辑、恢复默认和离开确认仅管理局部草稿；不访问旧目录。
产物页独立滚动正文、840px 最大宽度、固定底栏，72px 滚动对应标题 128→64px。
网络页依据旧空配置，保留节点/订阅/规则/脚本/日志空态、订阅地址与自定义规则弹窗、
日志搜索/筛选与重置确认；没有代理核心、DNS、订阅导入、规则保存或系统动作。
已有数据的节点组、测速、订阅操作菜单、规则编辑和运行异常分支继续待覆盖。
第五批完整 verify 为 6 Rust + 76 Flutter + 6 FFI，通过本地截图与 Android/Windows Debug。
截图发现规则选中勾号缺字，已改为同尺寸 Material 图标，网络 6 测试和截图重验通过。
第六批用户协议/隐私政策阅读页已落代码，完整移植旧受控中文正文（各 16 段、版本
2026-09-08-r1），4 项章节定位测试通过，修复大字体跳转时章节标题移出视口的问题。
正文是旧 UI 阅读快照，不代表新跨平台实现已经具备正文所述全部能力或完成法律审阅；
不写入同意记录。权限页五分组/23 项入口已实现，7 项尺寸/折叠/快照投影测试通过。
未接平台查询，默认“未检查”和“—”统计，明确区别于旧 Android 真实权限；刷新与授权
动作空点击，测试夹具可投影实际状态分支。引导、开源清单和数据备份继续推进。
第六批完整 verify 已通过 6 Rust + 87 Flutter + 6 FFI；随后开源页面追加原 150 项
清单、六分类与搜索，2 项搜索/双倍字体测试通过。当前开源内容仅为旧 UI 清单快照，
不能当作 Flutter/Rust 新构建的实际依赖或许可证审计；新构建归属需单独按锁文件整理。
第六批最终 verify 为 6 Rust + 89 Flutter + 6 FFI；权限/开源截图已刷新检查，
Android/Windows Debug 构建通过。该批 APK 为 95,388,473 字节，SHA-256
`6CD0F81AD0C0073FBF3B0F6253E02C20CB6A39049977662C2B6E458A34C8727E`。
第七批数据备份正在实现：十张原卡片、聊天选择/格式两层、记忆配置选择与删除确认，
列表快照可注入，文件扫描、导出、删除、恢复和设置写入为空操作。完整 verify 已通过
6 Rust + 96 Flutter + 6 FFI，包含新增 7 项备份测试；默认零计数不是宿主扫描结果，
审计未加载保留原 spinner 外观。修复选择弹窗惰性列表的 intrinsic 尺寸断言与按钮字体
继承，截图重捕通过。Android/Windows Debug 成功（APK 95,417,325 字节，SHA-256
`4E4D1034F5617B9E28D2DF99A68E4DA5F5D792D00067D9650B797AA01E34C114`）。
随后卡片按原 Material medium token 核对为 14px，外观设置进入五标签逐源复刻，
五标签已接入主题设置页面：主题、背景、聊天、输入栏与 AI 界面，包含颜色编辑、字体、
气泡/头像/图片参数等默认外观及局部草稿。12 项专项测试通过，覆盖三种窗口、1×/2×字体、
键盘、玻璃互斥及样式草稿保持；修复短横屏键盘标签溢出。五标签/色盘截图已捕获检查。
完整 verify 为 6 Rust + 108 Flutter + 6 FFI，通过；本批平台构建待更新。
气泡字体与左右内边距已投影到预览，切换风格不丢草稿；文件/媒体选择和保存为空点击。
路由复核发现界面定制与数据备份跳过原父级导航列表，已补齐四项/两项原列表与返回路径。
第九批追加我的账号两组、GitHub 方式选择、哔哩哔哩扫码/Cookie 弹窗、语言八项清单、
AI 助手五组十四入口；7 项账号尺寸/键盘/空动作/父页返回测试通过，静态分析通过。
当前没有账号读取、OAuth、Cookie 导入/验证、二维码请求或 locale 写入，账号默认未连接；
凭据输入仅随弹窗生存，切换方式及关闭时清除。全局显示/布局与 AI 深层入口继续待覆盖。
第九批完整 verify 通过 6 Rust + 115 Flutter + 6 FFI，Android/Windows Debug 构建通过。
修正原一级测试对账号空点击的过期假设，改为验证详情返回后继续一级滚动。截图已重捕
并检查账号/登录弹窗/语言页；测试字体的韩文字形覆盖仍有限，不作为 Android 缺字证据。
APK：2026-10-02 07:48:33，95,504,418 字节，SHA-256
`CD7B4015DE11EACA060078C7E44CF2DE1AFFEBA58914049744EE000A62E00B7E`。
界面定制父级的全局显示与布局调整已追加：显示默认项、条件阈值、自动化截图/码率、Root
草稿和五个数值编辑/错误范围/Markdown 预览均按 GlobalDisplaySettingsScreen 与
LayoutAdjustmentSettingsScreen 投影；13 项专项测试（账号父页及显示布局）通过，覆盖六个组合。
Root、通知、截图、保存不执行业务，恢复默认只改局部数值草稿。最终完整 verify 为
6 Rust + 121 Flutter + 6 FFI，Android/Windows Debug 构建通过。截图检查通过，实际拖动
验证控件到达与条件展开；修复测试 ensureVisible 在嵌套滚动中不能保证可点击的问题。
APK：2026-10-02 08:03:00，95,526,240 字节，SHA-256
`6155598A9AE074ECE50B64F3D323601F7ACF5A6F7F73FF3F951320FCDD9B1A34`。
“重新查看首次引导”六页已接入独立全屏模态路由：四页介绍、协议和权限；返回/跳过、
法律阅读、默认五页限制和同意后六页、权限共用选择草稿均已落代码。复用受控法律正文和
23项权限目录，协议与权限真实状态由快照注入；不写首启完成、同意或授权事实。
9 项引导专项测试通过，覆盖六种尺寸/字体、拖动折返取消、已授权快照、目录选择同步、
阅读返回与首启拒绝弹窗。完整 verify 通过 6 Rust + 130 Flutter + 6 FFI，截图重捕通过；
Android/Windows Debug 均构建成功。首次截图从仓库根启动导致资产未打包，已按 app 目录
正式入口重跑并覆盖产物，未将缺字截图当成功。未安装设备，像素、手感与 iOS 仍待验证。
APK：2026-10-02 08:35:19，95,577,272 字节，SHA-256
`113EEE2E7B00ACED274F2F09E56A56880F0E323AB4647FBE209C5F2E31AE98D6`。
聊天历史管理五卡、角色/群聊归类、删除确认与记忆重建参数/日期弹层已实现；默认空快照，
操作仅修改局部草稿。6种尺寸/字体专项通过，实际日期选择/清除、非法范围修正、群聊归类
专项通过。修复离屏草稿保留、测试回滚查找越过目标、缺失群聊排序、日期短屏/大字溢出。
该批完整 verify 通过 6 Rust + 137 Flutter + 6 FFI，截图复核与 Android/Windows Debug
构建通过。APK：2026-10-02 09:06:11，97,324,077 字节，SHA-256
`F5251C47C112084F92FC1818AA7F0011122535F77092D510CCBB685BFE566420`。
设备像素/触摸和 iOS 仍待验证。AI 设置中的上下文与总结已接入，6种尺寸/字体专项通过，
覆盖错误修正、依赖禁用、媒体重置范围和键盘适配。旧默认值与实际校验边界逐源核对，
保留原说明文案与控件顺序；不写模型配置、不启动总结。完整验证通过6 Rust + 143 Flutter
+ 6 FFI，截图检查通过。随后功能模型分配11卡与两层选择已实现，7项专项通过，包含六尺寸
和加载/失败、媒体能力、结果展开与主模型限制；完整 verify 通过6 Rust + 150 Flutter
+ 6 FFI，截图复核与 Android/Windows Debug通过。APK：2026-10-02 09:23:56，
97,361,529字节，SHA-256 `1F2D667D460E0540D05F97CB693C34DFC0E30B84A66F715D72B22842BA1A00B6`。
模型与API主页面正逐块核对来源，包含提供方/协议、模型列表、参数、请求头和高级设置；
功能页“管理所有模型配置”暂为空点击，等待这一真实页面接入。
随后模型与 API 默认页及两个导航入口已接入，含30提供方/52协议、模型标签添加/排序、
上下文/总结两卡、参数四标签、请求头六预设、请求队列和空密钥池。供应商与模型标签各6项、
模型页7项专项通过，首轮完整 verify为6 Rust +169 Flutter +6 FFI；截图已捕获核对。
真实拖动采用连续采样，修复测试落点跳跃及短屏抽屉说明溢出。截图另发现工作台暗色背景
未覆盖，已按旧主题补齐共享颜色并修正新建按钮/端点间距；这一后续调整及配置切换测试
正在复验，尚未刷新双平台产物。主页面只展示旧默认配置，不声称加载真实配置数据；
上游模型结果、非空密钥池与自定义参数已有数据的完整投影仍待后续覆盖。
模型/API该批后续全验通过6 Rust +171 Flutter +6 FFI，浅暗截图刷新核对，Android/Windows
Debug构建通过。APK：2026-10-02 10:15:00，97,465,073字节，SHA-256
`F66BF946FC36A4CB0A879E6748382A32CEA7D28517315B7ED05B4763712E6085`。
此后AI工具授权页：全局三态、两例外组、工具搜索/选择弹窗已落代码，6项专项验证通过。
工具目录默认空快照，不初始化旧工具注册器或保存授权；原说明两处覆盖关系的文案按原样
保留，不以UI文字代替未来领域权限裁决。
用户资料页追加 Markdown 高亮编辑、基础预览、恢复模板、旧档案抽屉与返回确认；
9项专项验证通过，含六种尺寸/字体、键盘、超限全文保留、组合输入和畸形 Markdown。
修复旧档案抽屉半展开/双倍字体标题溢出；标准 Markdown AST 新增 markdown 7.3.1，
不访问文件、不保存、不加载网络媒体。高级 Markdown 图表/公式及完整工具目录待覆盖。
本批完整验证通过6 Rust +186 Flutter +6 FFI，42项基础检查与静态分析通过，浅暗截图
已重捕核对；修复截图等宽字体未加载及编辑标签多余勾号。Android/Windows Debug通过。
APK：2026-10-02 10:41:08，97,812,844字节，SHA-256
`7CFA497B987E4E7B68DB31B1DC77BD912351B556C3C27F70AA73500DB418615C`。
随后开始局域网与自动化十卡复刻；状态和地址只投影快照，不启动HTTP服务或探测网卡。
局域网7项专项通过，含运行/异常/端口缺失分支；修复端口粘贴应过滤并截取前五位的差异。
回复与表情11张原卡片和自定义表情子页已接线，回复6项、表情7项专项通过；覆盖草稿保留、
条件展开、分类、创建校验、删除/恢复空点击、图片预览和53原图解码。9目录共3,632,112字节
素材逐文件SHA-256与旧源一致，未转换格式。普通列表使用惰性构建，缩略图按格子尺寸解码。
大写类别输入先转小写再校验，纠正旧页面按转换前输入误报无效的问题。完整验证通过
6 Rust +206 Flutter +6 FFI；截图刷新、Android/Windows Debug通过，APK内53素材实际验包。
APK：2026-10-02 11:04:19，97,854,530字节，SHA-256
`DB5E9B92147A8A6866E241AB2483A5DFC8101552BCA9AE2A0020AF90A051A186`。
随后AI用量与费用：统计快照、分布图、模型卡、两种定价草稿和重置弹窗已接入，7项专项
通过；新增可选工作台顶栏操作，修复窄屏图表布局与非有限/负价格可保存的问题。
11:04历史产物不包含用量页，本批最新产物见下。
STT 三引擎、配置选择和名称/删除弹窗已接入，7项专项通过；覆盖配置移除、空目录、
草稿往返、密钥显隐、六种尺寸/字体和键盘。用量修订后7项专项再通过。
按用户要求已生成可手动安装检查的APK。完整 `tools/verify.ps1` 通过6 Rust +220 Flutter
+6真实FFI，42项基础检查、格式和静态分析通过；4个截图测试默认跳过，本批显式运行
`profile_permissions_capture_test.dart` 通过并重捕用量/STT等页面，截图已人工检查。
Android/Windows Debug均构建通过；APK包名 `com.kiyori`、版本0.1.0(1)、arm64-v8a、
minSdk24/targetSdk37，v2签名与16KB ZIP对齐检查通过。未安装设备，未进行真机性能验收。
固定检查包：`artifacts/ui-preview/20261002-112314/Kiyori-ui-preview-arm64-debug.apk`，
2026-10-02 11:23:14（Asia/Shanghai），97,897,117字节，SHA-256
`9B2875002BFFF3670F61B4A41AEC5A045673CB118141EBC446A56FDD8CC0ACCD`。
日志：`work/manual-preview-verify.log`、`work/manual-preview-android.log`、
`work/manual-preview-windows.log`；固定包独立于后续默认构建输出，不随其覆盖。
等待用户手动检查反馈不改变总体Goal的active状态，后续继续TTS、语音唤醒与更深层页面。
TTS 九引擎设置与朗读工具页已接入；默认Next HTTP预设按旧初始化路径核对。系统音色和
远程目录使用快照，清理模板/配置/输入仅为局部草稿。8项表单/JSON/六尺寸字体测试通过，
新增2项音色/模型选择、键盘与工具错误清除测试通过。修复HTTP方法窄屏大字溢出与选择
弹窗短视口/键盘的intrinsic尺寸错误；本批截图已捕获，完整验证与最终构建待执行。
最终已通过6 Rust +231 Flutter +6 FFI，新增工具箱/设置双入口返回验证通过；工具顶栏
补齐64px、14sp半粗标题、21px图标与0.5px分隔，输入框最小120px。静态分析/基础检查
通过，Android/Windows Debug均通过（日志 `work/tts-final-verify.log`、`work/tts-android.log`、
`work/tts-windows.log`）。APK：2026-10-02 11:59:16，97,949,991字节，SHA-256
`6A2E01E428652063E918C7B0B208F18D95DDD3D2C0C331A1B12FEACB08DB19C0`。
11:23固定检查包保持不变，不包含后续TTS增量。
语音唤醒三组及个人模板、附件编辑/新增/删除弹窗已接入；7项专项通过，覆盖六种尺寸/
字体、模式切换草稿保持、监听/录音空动作、关键词键盘、二级确认与注入模板状态。
默认词、响应和四附件按旧偏好核对，超长数字粘贴仍限制1–600秒。截图已捕获检查；
唤醒本批完整回归通过6 Rust +238 Flutter +6真实FFI；42项基础检查、格式、Clippy及
静态分析通过。Android/Windows Debug均构建成功，日志为 `work/wakeup-verify.log`、
`work/wakeup-android.log`、`work/wakeup-windows.log`。11:59历史构建不包含唤醒页。
最新固定检查包：`artifacts/ui-preview/20261002-121113/Kiyori-ui-preview-arm64-debug.apk`，
2026-10-02 12:11:13（Asia/Shanghai），97,970,244字节，SHA-256
`4737B19CE28857BA927CFAB62B2D05B1042A8318AC7C30BA19DBB99FA6EF3070`。
该包包含TTS与唤醒；`com.kiyori`/0.1.0(1)、arm64-v8a、min24/target37，v2签名与
16KB ZIP对齐检查通过。11:23固定包仍保留且hash未变，等待用户手动安装检查反馈。
下一批角色卡和提示词工作台已核对三标签、默认Kiyori内容、标签空目录、角色/群组/
标签编辑层级；尚未写入角色页面代码，继续对照高级配置和嵌套选择器后实施。

首份通用页面目录草稿因不满足原样复刻已撤除，未把说明页或说明弹窗接入产品。
完整页面范围尚未完成；Android 同设备视觉/触摸、Profile 与 iOS 编译仍待验证。

## 前轮：四个底栏一级页面复刻

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

## 第二轮工程治理 ad815390（历史快照）


更新时间：2026-10-02（Asia/Shanghai）。本文件是当前实施进度唯一权威；
[路线图](roadmap.md)规定顺序，[历史记录](status-history.md)保留过往批次证据。

## 当前任务：第二轮工程治理与完整交付

用户要求在继续全页面复刻前，审计环境、工具链、架构、目录命名、文档和复刻流程，
完成验证构建后全部提交推送。实时基线 `main` / `ca8bf6f2b6513c301a4e99952246d9df6dd7c426`；
工作区原本干净，fetch 后与 origin/main 无分歧。旧源 `Kiyori-Android` /
`6b03b03aa082803bb279db5e78773583e2d91154` 只读。上一轮交付证据已归档，不能代替本轮验证。

当前交付状态：本轮修复、完整验证、截图审阅、双平台固定产物和交付树审计已完成。
本记录随本轮治理交付；最终提交标识及 origin/main 同步事实以 Git 记录和交付报告为准，
不在同一提交内维护自引用 SHA。正式 Goal 覆盖全部提交推送闭环，未设置 token 预算。
全页面复刻与真实业务仍是长期未完成目标。

### 任务契约与计划

范围为现有工程基础和已有 UI 的真实问题，不扩展角色/形象等新页面。保留旧源码只读、
原固定检查包、暂停的 kiyori-ui 自动化；不安装设备、不部署、不触发远端 CI、不升级全局环境。
验收以定向行为测试、完整 verify、截图审阅、Android/Windows 产物检查及远端 ref 为准。
Android 真机视觉/触摸/Profile 与 iOS 编译继续单列 `verification_pending`。

| 阶段 | 工作与影响范围 | 状态 |
| --- | --- | --- |
| 1 | 规则、授权、实时 Git/旧源/自动化基线 | 已核对 |
| 2 | 工具链、lock、Native Assets、生成与构建入口 | 已审计并修复 |
| 3 | 旧契约、九模块、领域 owner/调用/释放映射 | 已记录实际读取层级，见模块地图 |
| 4 | app/UI/bridge/core 依赖、主题、草稿和资源生命周期 | 已审计，保持现有分层 |
| 5 | 实施根因修复，补充高信号回归 | 8项治理回归、4项脚本行为通过 |
| 6 | 完整验证、截图审阅、双平台构建及固定包 | 已完成，120张捕获及83个产物文件核对通过 |
| 7 | 文档、长期缺口、最终差异/资产/凭据审计 | 已完成，交付清单不包含本机证据和二进制 |
| 8 | 精确暂存、提交推送、远端/工作区核对 | 随本批交付收口，提交身份及远端核对记录于Git与交付报告 |

风险重点为生成检查漏检、缓存输入遗漏、草稿身份漂移和隐藏页资源活动；按证据先查
脚本/所有权再改消费者，验证期间冻结输入。回滚点为干净基线 ca8bf6f，通过可审阅补丁
或后续 revert 恢复，不覆盖未知文件，不清理共享缓存。任务日记只作恢复导航。

## 本轮问题、方案与证据

| 问题及根因证据 | 影响与修复文件 | 选择理由与验证/状态 |
| --- | --- | --- |
| 生成检查仅枚举已有顶层Dart文件，漏新文件/子目录 | `tools/generate-bridge.ps1`、`bridge-output.ps1` 比较递归路径/摘要集合 | 不维护第二清单；4种夹具通过，实际再生成5文件不变 |
| 生成脚本 cargo fmt --all 顺带修改人工Rust | 同脚本改为显式edition的单生成文件rustfmt | 检查副作用限定在生成输出；实际 -Check 通过 |
| 旧Native Assets hook output缺ffi Cargo.toml | `packages/kiyori_bridge/hook/build.dart` 补输入依赖 | Cargo dep-info不能替代清单；最终Android/Windows hook output均已包含清单 |
| Flutter随附Dart正确不等于PATH的Dart正确 | `tools/check-toolchains.ps1` 同时核验直接调用版本 | 本机3.13.5通过，不改全局SDK；pub/lock无变化 |
| 同批定向测试和构建重复解析依赖 | `test-ui.ps1`、`build.ps1` 增加可选 -NoPub | 默认仍解析，仅依赖已解析且未变化时使用；首次构建暴露单字符串splat按字符拆分，已改成数组累加 |
| 详情/卡片/选择器浅色常量和工作台色表漂移 | `kiyori_ui`统一SettingsTheme/PrimaryPalette，消费者按宿主投影IconTone；修正引导渐变和主题语义色 | 对照旧设置/角色色/语义色源码；不改几何、图标、顺序和主题偏好；明暗回归/截图 |
| Offstage缓存页可抢焦点；模型缓存ticker未停 | `home_shell.dart`、`model_api_page.dart` 排除隐藏焦点并暂停ticker | 保留缓存草稿，行为回归覆盖焦点与返回 |
| IndexedStack位置包装让内层实体Key重排丢失State；菜单保存旧索引 | 模型页直接Keyed Offstage子节点，菜单返回ID并在当前目录解析 | 重排测试先失败、修复后通过；移除再加入不复活旧controller |
| 跨测试文件导入夹具形成套件耦合 | `test/support/{fake_runtime,ui_test_helpers,assistant_fixtures}.dart` 提取现有共用代码 | 不建通用框架，实际消费者改用support；246项组件回归通过 |
| 首次捕获先于PNG解码完成，截图可能漏图标 | 共用 `ui_capture.dart` 在截图前等待可见Image首帧 | 只修复测试证据，实际首张设置截图已核对图标，不向产品添加等待 |
| 方案残留旧自动接续/无提交授权，历史记录自称当前权威 | CONTEXT、模块地图、布局、验证/工具链/复刻流程、方案及历史同步 | 当前状态唯一权威，不固化本轮授权；基础检查48文件通过 |

保留已有设计：SettingsNavigation只装配，Shell唯一导航owner；Rust/FFI拉取背压、取消
及关闭契约不变，不新增依赖/业务数据库/路由层。TTS配置移除时的待返回音色弹窗经实测
被现有实体Key和mounted保护隔离，无需平行机制。较大的TTS/标签/工具箱文件仍围绕
同一展示职责，不按行数拆分。滑轨/分页物理差异留给同设备测量后决策。
Flutter Image已响应TickerMode；不建立GIF管理器，不声称列表缓存区按像素暂停。

## 已有 UI 范围与缺口

| 领域 | 已有展示实现 | 尚未闭合 |
| --- | --- | --- |
| 壳与一级页 | 首页三页、五图标底栏、浏览器/工具箱/文件/设置、来源返回 | 深层菜单、真实会话与跨平台系统行为 |
| 通用设置 | 收缩顶栏、工作台、卡片/行、选择抽屉、确认/输入弹窗，共享明暗表面色 | 滑轨与Android字形精确对照、设备视觉验收 |
| 浏览/文件/媒体/工具 | 浏览器、下载、文件、播放器四子页、音乐、文档、工具箱管理设置 | 实际文件/文档/播放工作台、B站五栏、工具深页 |
| 通用偏好 | 更多、存储、代理、广告拦截、账号、备份、权限、协议、开源、六页引导 | 非默认数据与所有平台状态组合 |
| 外观 | 五主题标签、颜色/聊天样式、语言、全局显示、布局 | 不写全局偏好，主题真实切换待业务接入 |
| AI设置 | 模型/API、11功能分配、上下文、工具授权、资料、历史、LAN、回复表情、用量 | 角色卡/标签/群组、形象、模型非默认分支、完整工具目录 |
| 语音 | STT三引擎、TTS九引擎及朗读工具、唤醒三组和录音/附件弹窗 | 只投影快照，真实语音能力未接入 |
| 跨平台 | Android/Windows工程、窄屏/横屏/大字/键盘组件检查 | 同设备旧新视觉/触摸/Profile、Apple真实编译 |

业务保存、网络、系统、录音、导入导出均保持空点击；交互草稿不代表业务生效。
产品入口仍固定浅色，暗色通过宿主注入测试；本轮没有接入全局主题偏好。
来源与尺寸见[UI契约](design/ui-parity.md)，方法见[复刻流程](development/ui-replication-workflow.md)，
旧源码实际复核深度见[模块地图](architecture/legacy-module-map.md)，不宣称全部旧代码逐行审完。

## 验证与产物

本轮8项治理回归通过：`work/governance2-regressions-closure.log`。重排首次失败保留于
`governance2-regressions.log`；首次主题截图测试缺Scaffold已修复，失败证据保留。
实际桥接 `-Check` 通过：`work/governance2-bridge-check.log`，5个输出不变。
完整 `tools/verify.ps1 -WindowsIntegration` 通过，最终日志 `work/governance2-verify-final.log`：
6 Rust、246 Flutter、6真实FFI、2 Windows引擎；fmt、Clippy、analyze、48文件基础检查和
4项脚本行为通过。5个capture套件在普通回归中按设计跳过，用捕获参数另行执行。
首轮完整verify也通过，后续截图审阅发现权限/备份两个固定浅色值后修正并重跑，未降低断言。
备份提示条同源底色随后补齐，相关备份/权限/治理22项回归通过，最终analyze无问题。
最终5个截图套件全部通过，生成120张PNG；已审阅设置明暗、浏览器、语音、主题、引导、
权限、备份、历史和模型等代表画面。截图字体来自本机，不能替代Android字形与阴影实测。
Android首次脚本因-NoPub字符串splat失败已修正；排错时一次直接命令漏激活，使用旧全局
Flutter并生成不兼容hook缓存。pin重建报告Invalid SDK hash后，仅将日志指向的
`.dart_tool/hooks_runner/kiyori_bridge/4f230121a5` 保留到work再重建，不删除其它缓存。
这次旧SDK构建不作为交付证据，详细失败日志保留。
本轮doctor无问题；直接运行依赖与当前可解析测试依赖保持，不强制升级。

最终验证入口与日志：

| 入口 | 本轮结果与证据 |
| --- | --- |
| `tools/verify.ps1 -WindowsIntegration` | `work/governance2-verify-final.log`，完整静态/单元/FFI/Windows引擎通过 |
| `tools/generate-bridge.ps1 -Check` | `work/governance2-bridge-check.log`，5个生成文件完全一致 |
| `tools/test-ui.ps1 -NoPub -Test backup_settings_test.dart,permissions_settings_test.dart,governance_regression_test.dart` | `work/governance2-final-colors.log`，最后颜色变更后的22项回归通过 |
| `tools/test-ui.ps1 -Capture -NoPub -Output work/governance2-release-review` | `work/governance2-release-review.log`，5套件/120张PNG |
| `flutter analyze --no-pub` | `work/governance2-analyze-delivery.log`，最终代码无诊断 |
| `tools/build.ps1 -Platform android -NoPub` | `work/governance2-android-verified.log`与`governance2-android-repackage.log`，pin工具链构建与重新打包通过 |
| `tools/build.ps1 -Platform windows -NoPub` | `work/governance2-windows-verified.log`，引擎测试后已重建普通产品入口 |

上表作为交付证据的Flutter命令均使用当前shell的 `tools/activate.ps1` 环境；`-NoPub` 只在依赖已解析且
manifest/lock未变化时使用。热构建耗时不能作为冷构建加速或真机性能证据。

固定交付目录为 `artifacts/ui-preview/20261002-141807`，固定时间为
2026-10-02 14:18:10（Asia/Shanghai）；`manifest.json`记录全部83个产物文件的大小、
mtime和SHA256，逐文件复核无误。APK与Windows目录合计203,533,790字节：

| 产物 | 大小与实际生成时间 | SHA256 |
| --- | --- | --- |
| `Kiyori-ui-preview-arm64-debug.apk` | 86,318,424字节；14:17:04 | `7ED53295DA96DE4FDFA5F6F1BFB1F1EFBB5C29F161EAB50BC0451117EA1DBC3A` |
| `windows-debug/Kiyori.exe` | 1,281,024字节；02:33:25（未变的原生runner复用） | `221590339BBEA871886F8C98D01B227D4603B7E605AEEDD29D4E5F4E1C2D1475` |
| `windows-debug/data/flutter_assets/kernel_blob.bin` | 53,675,368字节；14:06:18（本轮产品Dart负载） | `BDBE7A1C1AA7411AF5A1221868F0F39C4E93A2836C4124A7ED1289A1F3813E1D` |
| `windows-debug/kiyori_ffi.dll` | 553,984字节；13:45:55 | `8A64AB530621EF8CA05C1519A8094EDE586834FB62F7ED1FB4919C5E66FD7FAA` |
| `manifest.json` | 描述APK及完整Windows目录；Windows为82文件/117,215,366字节 | `48338801CC5DF1D55DEAC1F8409C220C21F6F3ED3DAD2BE87EA90F80F69A2F9B` |

APK核对为 `com.kiyori` / `0.1.0(1)`、arm64-v8a、minSdk24/targetSdk37，Debug证书
v2签名、16KB ZIP对齐及3个SO的ELF LOAD对齐均通过；品牌资源和53张内置表情齐全。
Windows核对为x64完整普通入口目录，Flutter DLL与pin SDK一致，FFI DLL与Native Assets
清单对应。必须保留完整DLL/data目录，不能单独复制EXE。

一次增量APK含Zipflinger空闲区而达到118,594,345字节。保留该包后仅移动已生成的
APK输出并重新打包，最终没有空闲跨度，前后220个ZIP条目的未压缩内容摘要完全一致。
这是包布局恢复，不是业务代码缩减或运行时性能提升。产物审计日志位于
`work/governance2-artifacts-20261002-141807`，摘要为 `work/governance2-artifacts-summary.json`。

先前11:23、12:11、12:40固定包与有用构建缓存保留，旧产物信息见历史记录。
不绕过 `features/player/presentation` 空目录此前删除拒绝；Git不跟踪该目录、不影响构建。
仅删除本轮已无用临时迁移脚本，日志/失败截图保留于忽略的work；不提交字体或二进制。
交付树审计403文件、179个非生成Dart：无失效导入/导入循环、feature反向app、公共UI依赖
业务、高置信凭据、链接、嵌套.git/子模块或超5MiB文件。四条已有公开展示复用保持单向，
详见仓库布局。表情happy_4与miss_you_1内容相同，但与旧源两个分类路径摘要一致，保留。

## 后续开发入口

本轮交付后，从角色卡和提示词继续U2/U6：`ModelPromptsSettingsScreen.kt` 的角色卡/
标签/群组三标签及 `CharacterCardDialog.kt`。默认角色源为 `CharacterCardBilingualData.kt`，
标签默认空目录；先核对宿主、默认初始化、高级模型/记忆/工具绑定、导出模式和嵌套编辑。
完成条件为真实入口/返回、所有弹层与草稿身份测试、明暗/小屏/大字/键盘截图及批次构建；
业务仍由后续领域owner接入。本轮未写入这些新页面。
其后虚拟形象 → U3轻量抽屉 → U4工作台 → U5深层工具 → U6剩余AI/扩展 → U7全入口复查。
高级Markdown、列表GIF缓存策略、非默认模型与完整授权目录继续按真实来源和实测补齐。

kiyori-ui实查为 `PAUSED`，本轮不恢复、不删除、不重建。后续任务先核对本文件与实时Git，
本轮提交授权不延伸到未来任务。设备安装、远端CI、部署、发布和Apple资源均需对应授权。

## 第三轮角色卡交付 b2ded4b（历史快照）

归档时间：2026-10-02（Asia/Shanghai）。以下为第三轮交付时的状态快照，后续群组实现
以[当前状态](status.md)为准；本节的“下一步”和验证数量仅描述该历史批次。

### 当前任务：第三轮角色卡与提示词垂直切片

基线 `main` / `ad815390401d656ed5f0f2a9ec3e1c174854d121`，开始时工作区干净，
fetch 后 main 与 origin/main 为0/0。旧源 `Kiyori-Android` /
`6b03b03aa082803bb279db5e78773583e2d91154` 保持只读。kiyori-ui 为 PAUSED。
正式 Goal 不设预算；日记 local_only，仅本机保存，不派子智能体或调用外部研究服务。

本批目标是一个可交互的角色编辑 UI 切片：设置入口、目录、八字段与嵌套编辑、绑定
选择、稳定实体身份及返回释放。非目标为 Rust 持久化、网络请求、设备安装、部署、
远端 CI、全局 SDK 变更或自动化恢复；最终仅审计后的本轮允许清单提交推送。
回滚基线为上述 HEAD，历史固定包不覆盖。本轮没有新增依赖、修改 Rust API 或生成桥。

当前状态：本轮角色编辑 UI 草稿切片、本地验证、20张截图、双端 Debug 构建与交付树
审计完成；本批精确清单提交推送，实际提交与远端 ref 以 Git 为准。设备视觉/触摸/Profile、
TalkBack、Apple 构建及真实业务接入保持 `verification_pending`。

### 本批实现与业务边界

| 范围 | 实际交付 | 未实现或待验证 |
| --- | --- | --- |
| 入口与返回 | 设置 → AI 助手 → 角色卡和提示词，弹层优先 Back，返回来源 | AI 抽屉其它来源随 U3 实现 |
| 角色目录 | 中文 Kiyori 默认快照、品牌头像、活跃徽章、三种排序、菜单和导入入口；显式空目录不虚构默认卡 | 数据初始化、激活、复制、删除、重置均无业务副作用 |
| 角色编辑 | 八文本字段、完整默认语音文本、标签选择、放大编辑确认/取消、头像与翻译外观 | 最外层保存/创建空操作；不发 AI 请求、不复制文件 |
| 高级绑定 | 复用模型摘要，配置/模型两层选择、记忆 ID 选择、四类工具筛选与局部确认，use_package 前置校验 | 不修改全局模型、记忆空间或权限；默认目录为空 |
| 标签 | 默认空目录、非空快照、三字段新建/编辑与删除确认 | 保存、导入、导出、市场不执行；批量导出选择未迁移 |
| 导出 | JSON/PNG/多维码三卡、多维码2/4/8/16色选择与返回 | 不生成二维码、不写文件、不伪造保存路径或成功 |
| 群组 | 三标签中的默认空态、原创建按钮空点击 | 非默认群组、成员编辑、规划参数、持久化待下一切片 |
| 生命周期 | 菜单和弹层绑定 ID/存在代次；重排保留，移除释放嵌套模态；重新加入不复用草稿 | 后续真实请求的超时/取消/错误由业务 owner 补齐 |

旧源读取深度、几何、行为与后续 owner 条件见[角色卡契约](design/character-prompts.md)。
CharacterCardDialog 与双语默认数据全文已读；主工作台按相关分支读取，未宣称完整 Tavern
编解码、全部群组编辑或所有角色服务逐行审计。当前产品仍中文/浅色预览，明暗由宿主
注入测试；不增加全局主题或语言偏好 owner。默认快照不等于真实业务初始化。

### 验证与发现

15项最终定向测试：`work/characters-tests-delivery.log`。覆盖实际设置入口、系统 Back、嵌套
编辑确认/取消、目录重排/删除/重新加入、菜单存在代次、模型/记忆目录更新、标签选择、
工具搜索/取消/确认/目录过滤、外部工具校验、空目录/排序/导出、宿主退出焦点释放、
844×320横屏、320×600双倍字与180px键盘的明暗布局。

首次9项测试3失败：入口测试漏文案空格；惰性列表缺新位置映射导致菜单State丢失；
父级构建阶段同步发布跨路由ValueNotifier。修复精确文案、findItemIndexCallback与帧后
通知后全部通过。扩展横屏测试首次点了屏外菜单，补充真实滚动后通过，不关闭命中警告。
失败证据保留 `work/characters-tests-initial.log`、`characters-tests-expanded.log`。
首轮截图发现浮动标签裁切与字体符号缺字，已留绘制空间并恢复 Material 图标。

20张本机 Flutter 捕获涵盖手机明暗、默认/空/非默认目录、编辑/高级/工具弹层、放大编辑、
模型选择、标签编辑、群组空态、桌面暗色、大字键盘和来源返回；复用 ui_capture.dart。
最终图片为 `work/characters-review-delivery/`，捕获日志为
`work/characters-capture-delivery.log`；已审阅代表图并修正浮动标签裁切、头像按钮图标。
本机字体截图不等于 Android 真机像素验收。

所有 Flutter/Dart/Rust 命令先执行 `./tools/activate.ps1`，使用 pin 工具链
Flutter 3.47.6 / Dart 3.13.5 / Rust 1.99.0。实际本地验证如下：

| 命令/入口 | 结果 | 本机证据 |
| --- | --- | --- |
| `./tools/verify.ps1 -WindowsIntegration` | 基础文档49份、脚本4项、Rust fmt/Clippy/6测试、Dart格式/analyze、Flutter 261项、真实FFI 6项、Windows引擎2项通过；6捕获套件按设计跳过 | `work/characters-verify.log` |
| `./tools/test-ui.ps1 -NoPub -Test character_prompts_test.dart` | 最后视觉修正后15项通过 | `work/characters-tests-delivery.log` |
| `./tools/test-ui.ps1 -NoPub -Capture -Test character_prompts_capture_test.dart -Output work/characters-review-delivery` | 1套件通过、20 PNG | `work/characters-capture-delivery.log` |
| `flutter analyze`（app目录） | 最后视觉修正后无问题 | `work/characters-analyze-delivery.log` |
| `./tools/build.ps1 -Platform android -NoPub` | ARM64 Debug通过 | `work/characters-android.log` |
| `./tools/build.ps1 -Platform windows -NoPub` | x64 Debug通过，已重建正常产品入口 | `work/characters-windows.log` |

完整 verify 在最后浮动标签 `Stack.clipBehavior` 修正之前；该绘制修正后重新运行定向测试、
捕获、analyze与串行双端构建，不将更早的完整验证冒充最后代码的全量复跑。无Rust公共
API或生成文件变动，未重复生成 bridge。最终文档另执行 foundation 和 `git diff --check`。

交付树审计413文件、192 Dart（含生成代码），人工源码无失效相对/本地package import、
循环依赖、feature→app、公用UI→业务/bridge、测试互导或高置信敏感内容问题。
FRB生成内部循环单独列出，核对本轮未修改；未手改生成文件。未新增依赖、lock变化、
重复资源、异常大文件、链接、子模块或嵌套Git；`work/characters-full-audit-reviewed.json`
保存结果。构建、截图、失败日志和临时审计脚本仅留忽略目录，未清理旧包或缓存。

### 本机固定产物

固定目录 `artifacts/ui-preview/20261002-161431/`：APK 1个、Windows目录82文件，
共221,980,682字节；Windows完整目录117,370,198字节。83文件逐一核对构建源与副本
SHA256一致。`manifest.json` 保存完整清单；提交后仅补来源提交元数据，不重写二进制。

| 产物（相对固定目录） | 字节 | 修改时间（2026-10-02，Asia/Shanghai） | SHA256 |
| --- | ---: | --- | --- |
| `Kiyori-ui-preview-arm64-debug.apk` | 104610484 | 16:10:41.005 | `32121CDCD6DFE6E764A17D23A30BE5FA00724D0D91DB21480A2FD0020A26DDB0` |
| `windows-debug/Kiyori.exe` | 1281024 | 02:33:25.021 | `221590339BBEA871886F8C98D01B227D4603B7E605AEEDD29D4E5F4E1C2D1475` |
| `windows-debug/data/flutter_assets/kernel_blob.bin` | 53830200 | 16:12:33.165 | `3B04A9DFCB48421E1E9BB9FAD0EF1B3399FD3FC8432B4B8B19C147E3E56494B5` |
| `windows-debug/kiyori_ffi.dll` | 553984 | 13:45:55.575 | `8A64AB530621EF8CA05C1519A8094EDE586834FB62F7ED1FB4919C5E66FD7FAA` |

EXE为未变化原生runner的增量复用，本轮Dart内容以新kernel为证；不能用EXE时间称本轮
未构建。Windows PE为x64，Flutter DLL与pin SDK一致，运行时NativeAssets manifest引用
随包`kiyori_ffi.dll`；根目录native_assets.json保留构建期路径，不充当可移植运行证据。
APK `com.kiyori` / 0.1.0(1)、min24/target37、ARM64、Debug签名v2、ZIP 16KB对齐及
3个原生库ELF LOAD对齐通过，包含53个默认表情。证据在
`work/characters-artifacts-20261002-161431/`。固定包20261002-141807与20261002-124054
保留，前者SHA仍为`7ED53295DA96DE4FDFA5F6F1BFB1F1EFBB5C29F161EAB50BC0451117EA1DBC3A`。

性能只落实工作边界：角色/标签排序在目录或排序选择变化时计算，角色列表惰性构建；
不会因每次文本输入重新排序目录，没有服务订阅或后台任务。无前后 Profile 对照，
不声称帧、延迟或内存目标已达标。

### 长期进度与下一入口

M1运行时已实现，业务M2仍未开始；U2/U6本轮新增角色编辑展示切片。既有壳、一级页、
设置、模型/语音等范围保留，明细见历史与UI契约。全产品复刻尚未完成。

下一优先级是旧 `ModelPromptsSettingsScreen.kt` 的 `GroupCardDialog` / `GroupCardItem`：
逐项核对成员身份、顺序、规划参数、默认/非默认状态及保存边界；复用本轮目录身份和
模态释放约束，补行为测试、明暗小屏截图与批次构建，再接标签批量导出/市场、人设生成。
之后角色到虚拟形象入口 → U3轻量抽屉 → U4工作台 → U5深工具 → U6剩余 → U7入口复查。

最短验证启动：`. ./tools/activate.ps1` 后运行
`./tools/test-ui.ps1 -NoPub -Test character_prompts_test.dart`；开发先读本文件与角色卡契约，
再核对实时Git和旧源。真实owner与设备验收需另行授权对应操作，本轮授权不延伸到后续任务。

## 2026-10-06：对话历史复刻分批实施证据

以下为最终收敛前的分批快照；其中的“当前”“下一步”和待办只在当时有效，当前事实以status.md为准。

### 对话历史左抽屉旧源还原（分批快照）

任务状态：部分完成；首批已提交推送，续批实现、本机验证与双端检查包已完成，设备验收待验证。基线为
2026-10-05 main/c8dc3274，起始工作区
干净，与origin/main一致；旧源只读Kiyori-Android/6b03b03。用户已授权本批全部提交普通
推送到main，未授权设备安装、供应商调用或发布。详细来源/参数与范围见
[复刻方案](design/chat-history-replication.md)，持久化契约见
[ADR0014](decisions/0014-conversation-history-and-audit.md)。

删除当前聊天与替代处于同一SQLite事务；同绑定最新会话优先，无候选则新建并选择，
删除所有聊天仍保留真实空会话。单删继承分组，整组删除不继承；分组冻结角色/群组
作用域和成员revision，锁定/生成/版本冲突原子拒绝。设置三模式、自动角色/聊天、
搜索并集/防抖、菜单八动作、可见桶排序/完整桶置底、跨分组拖排、快滚和折叠保留
已实施。滑动按旧依赖96dp、禁方向1/10、400ms回位与600ms涟漪；标题/行高/字号/
图标/语义明暗色按旧源核对。会话和分组移除释放实体及所属确认，不误关历史目录。

详情接入基础事件链、真实消息修订/备注、正文分页、Markdown/签名ZIP及Android SAF/
Windows文件导出。schema20不改写旧消息；旧修订/供应商原始事件未知，签名仅证明
自包含包完整性。旧版供应商/工具完整事件、封印/附件/旧包导入尚未接入，原始事件
搜索限已加载元数据，不能称整个旧详情工作台完全复刻。iOS导出不可用。

完整`tools/verify.ps1 -WindowsIntegration`通过（work/history-verify-v4.log）：foundation67、
tooling4、Rust核心177/HTTP3/provider_chat13/原生6、398 Dart格式与analyze、应用635
（17条件跳过）、platform11、独立FFI22（1条件跳过）、Windows引擎5。Rust三项旧源/
真实API条件跳过，不代表真实供应商验收。桥Check五输出一致（history-bridge-check-v3）。
最终UI联合11项通过（history-final-ui-v3），包括删空、固定阈值/禁方向、草稿/实体失效、
设置语义、真实备注/签名导出、导出失败留弹窗和重试、向下拖排及快滚首尾；最终analyze-v2
无问题。捕获五窗口50张（history-drawer-capture-v6），明暗、窄屏大字键盘、横屏和桌面
代表图已审阅。短横屏快滚溢出、拖排提交时旧目录回填、测试旧预期/异步等待已修；最后
错误目录直接调用Flutter导致DLL/字体加载失败，改用正式test-ui入口通过。桥v2的Windows
映射占用重试后通过；失败日志均保留，没有禁用检查或降低产品断言。

串行普通入口Android/Windows Debug最终构建24.7s/19.4s通过（history-android-v2与
history-windows-v2）；首次完整构建167.1s/61.3s同样成功。固定包位于
`artifacts/ui-preview/20261006-003401/`：APK137248567字节，SHA256
`9B9B6EE366F34463FF1B01D9AEF888BFE34FCA8F4C5CEC75FB22CFC929725E05`；Windows99文件
170771978字节。APK身份com.kiyori/ARM64/min24/target37/v2签名、ZIP16K/ELF对齐、53表情、
15份两端许可证、Windows x64/Flutter DLL pin及100副本逐文件hash通过。manifest保存完整
哈希与来源，最终sourceCommit在Git交付后记录；证据为work/history-artifacts-20261006-003401。
739文件树审计无warning/大文件/相对导入环；47路径精确允许清单通过，未改依赖和lock。
2026-10-06提交前fetch/ls-remote确认origin/main仍c8dc3274，ahead/behind0/0。47路径已提交为
`89c75c662e223fc6e14a6b3215d06204c1fe4bd3`并普通推送；ls-remote核对远端相同，0/0且
工作区干净。交付只包含本批源码、测试和正式文档；后续本节的交付记录补充只改文档，
固定manifest保存最终Git来源及实现提交，过程证据和二进制未入库。

同设备像素/字体、真实触摸、TalkBack、系统SAF/文件选择器、Profile和Apple仍
verification_pending。整体完全复刻仍需接入工具完整事件、旧封印/附件及旧包
兼容；随后在获授权设备进行并排视觉/手势/Profile验收。旧AuditRaw限定已加载事件，
全文检索由时间线承担，不将原始事件全记录检索列为旧行为缺口。

续批从main/a420ce5继续：已实现独立标签查询/滚动、独立正文检索游标、
搜索无匹配仍可加载更早页、紧凑raw行和时间线最新/未读入口。请求审计接既有EventSender，
真实发送前原子保存语义体/attempt，HTTP状态/协议和单终态共用Run，扩展在最终计数与
条件总结后记录，本地推理保留最终参数/history，自动/手动总结均有SUMMARY事实。
认证/header值及常见无空格JSON凭据先遮蔽；失败阻外发，取消/超时等写入与worker释放。
公共FFI/schema/依赖未变。终态先释放上游及save闭包会话锁再交给UI，修复总结结束后
立即下一轮偶发“此会话正在生成，请先停止”；回归不靠额外cancel/wait规避竞态。
最终verify-v5通过：foundation67/tooling4、Rust核心181/HTTP3/provider13/native6、398
Dart格式/analyze、app636（17条件跳过）/platform11/FFI22（1条件跳过）/Windows5。
最终capture-v4联合12项通过，v10五窗口60张，已审阅明暗raw展开、窄屏双倍字、设置与
横屏导出。普通入口Android23.0s/Windows19.3s串行构建通过（continuation双端v2）。
新固定包`artifacts/ui-preview/20261006-020350/`：APK137352338字节，SHA256
`FA8CDB1986A347E74FB19142CEEDDAC413025B7F699D4E2D3F458C0DFA8D0970`；Windows99文件
170969602字节。身份/v2签名/ZIP16K与ELF/53表情/15许可证/x64/DLL pin/100副本hash
审计通过。16路径精确清单与凭据/产物/链接/嵌套Git/子模块审计通过；提交前fetch与
ls-remote确认远端仍a420ce5，最终Git来源在交付manifest中固化。旧工具事件、Keystore加密/
持久ECDSA封印、完整旧包与附件仍未接，不宣称完整审计复刻。无设备或供应商操作。
SaveableStateProvider不保留普通remember的展开集，已按旧行为切标签释放；之前将
查询、列表与展开一并称为saveable不准确。截图发现展开JSON的ellipsis会提前省略，
改为完整换行并增加RenderParagraph断言。失败日志保留，未禁用检查或降低产品断言。

该续批已提交普通推送为ad10c4e20e81d15ab72de8e9667476dd0ec44bb9，远端一致、0/0、clean；
020350固定manifest已核对100文件并固化来源。继续从该提交核对详情色表与正文分页：
旧详情自带SettingsTheme，已修页面/卡片/图标色、16/12/14圆角、备注180/编辑220和8间距、
空闲遮罩退出与写入互斥。正文12000 UTF-16按代理对安全边界分页，搜索跳到首个命中；
消息标签仅用户/AI并按timestamp检索，空正文修订保留身份/原文/历史用量。事件Run和
终态同次查询投影，未知字段保持未知。核心审计7项通过；UI-v1联合14项通过（真实
FFI空修订、12000跨Emoji拼接与正文搜索定位），v11已审阅明暗详情/raw及备注输入。
截图后修正输入顶部对齐、标签48最小高/卡片背景/3高圆角指示线及raw行6间距。
最终UI-v3联合14项通过，v13五窗口60张，已审阅明暗详情/raw及备注和窄屏双倍字。
最终verify-v2完整通过：foundation67/tooling4、core181/HTTP3/provider13/native6、398
Dart格式/analyze、app638（17条件跳过）/platform11/FFI22（1条件跳过）/Windows5。
普通入口Android184.9s/Windows19.5s串行构建成功，日志为history-details双端v1。
固定包`artifacts/ui-preview/20261006-024610/`：APK137363321字节，SHA256
`4CA179517572EA54E6AE05F7B0C96BC09AEDA791547AC4733592577E7C8EFDFB`；Windows99文件
171010874字节。100副本hash、APK身份/v2/ZIP16K/ELF、53表情/15许可证/x64/DLL pin通过。
8路径精确清单与凭据/产物/链接/嵌套Git/子模块审计通过，按授权提交普通推送；最终
sourceCommit在manifest中固化。最后几何补丁括号错误已修，失败v2日志保留，未降低断言。
整体目标保持部分完成，继续旧包/平台持久封印及剩余导出选项几何；设备验收仍待验证。

详情批次已提交普通推送为6674271e92db22cfb3cf8dfff460e315fb63da21，远端相等、0/0且
clean；024610 manifest核对100文件并固化来源。下一安全增量从该clean基线实施：
platform/audit实现Keystore/JNI与Windows DPAPI/AES-GCM/P256，FFI显式装配到同AppStore；
schema21保存大小/Run投影、安全公钥和持久封印，旧明文迁移失败回滚。导出选项14圆角
与页面背景已修，3间距原本正确。native-v2真实Windows用例与core-native-v3的core181/
native1通过；Clippy-v2无警告。Android-v1发现jni0.22名称/签名类型需JNIString/jni_sig，
修正后v2普通构建196.6s成功；签名核验修补发生于构建中，v2仅诊断，最终构建须重跑。
新增真实schema20失败回滚、缺失密钥/安全公钥绑定和损坏封印拒绝已通过；最终
verify-v1完整通过：foundation68/tooling4、core181/HTTP3/provider13/native6/native-audit1、
398 Dart格式/analyze、app638（17跳过）/platform11/FFI22（1跳过）/Windows5。
桥Check五输出一致。最终history-crypto-ui-v1联合14项通过，capture-v14五窗口60PNG，
已审阅明暗导出、设置、备注、横屏导出和窄屏双倍字备注。普通入口Android141.5s/
Windows20.5s串行成功；固定包`artifacts/ui-preview/20261006-033641/`，APK137437049字节，
SHA256`4A24086FBB53E3655FDA1A5FCDB0A6DDB2BE50AE6D92FB528F41BFFB69E83057`，Windows
101文件171082075字节。102副本hash、身份/v2/ZIP16K/ELF、53表情、17两端许可证与x64/
DLL pin通过，APK确认JNI bind符号及AuditCrypto类。34路径精确清单审计后按授权提交推送，
最终Git来源固化到manifest。当前独立四文件ZIP还不是旧完整包，整体保持部分完成。
本次旧源复查确认左抽屉/详情没有导入入口，旧包导入归备份模块，不扩大本任务入口；
详情可达的签名包导出与Markdown预算/去重/假名化继续，未实现工具owner不伪造事件。

详情归档续批从abbcd9aa29745f8aaf1e188bdf374f284dcf5250 clean基线实施；安全增量已推送，
远端一致0/0，033641 manifest固化102文件来源。旧格式导出改为schema1/BASIC移植投影，
九类文件、去重payload、已观察消息修订/当前投影、持久链头P256签名；Markdown预算/
去重/路径账户假名化与动态围栏已接入。core-v4通过184/native1，v5一次既有下载40ms
等待竞争（0而非3字节）失败，未改断言；v6重跑184/native1通过、Clippy-v3无警告。
初轮schema可见性、假名重复变化与Clippy切片建议已修，失败日志保留。最新Run用量/variant
投影补充后完整验证尚未执行，整体仍部分完成，设备与旧进程导入不由本机合同测试证明。
