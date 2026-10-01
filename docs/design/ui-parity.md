# UI 复刻契约

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
