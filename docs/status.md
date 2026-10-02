# 当前实施状态

更新时间：2026-10-02（Asia/Shanghai）。本文件是当前实施进度唯一权威；
[路线图](roadmap.md)规定顺序，[历史记录](status-history.md)保留过往批次证据。

## 当前任务：工程治理与完整交付

用户要求在继续全页面复刻前，深度审计环境、工具链、架构、目录命名、文档和复刻流程，
完成构建后全部提交推送。基线 `main` / `3a359139016171f917ecf50d211a610bc040bf18`；
承接全部未提交 UI 成果。旧源 `Kiyori-Android` /
`6b03b03aa082803bb279db5e78773583e2d91154` 只读。设备安装、发布和部署不在范围内。

当前交付状态：本地实现、验证与双平台构建通过，具备交付条件；提交及远端同步以Git记录与交付报告为准。正式 Goal 跟踪这一工程治理增量；全页面
复刻仍为长期未完成目标，不能用本批构建成功代替全部 UI 验收。

## 已有 UI 范围与缺口

| 领域 | 已有展示实现 | 尚未闭合 |
| --- | --- | --- |
| 壳与一级页 | 首页三页、五图标底栏、浏览器/工具箱/文件/设置、来源返回 | 深层菜单、真实会话与跨平台系统行为 |
| 通用设置 | 收缩顶栏、工作台、卡片/行、选择抽屉、确认/输入弹窗 | 详情通用浅暗色治理、滑轨与 Android 字形精确对照 |
| 浏览/文件/媒体/工具 | 浏览器、下载、文件、播放器四子页、音乐、文档、工具箱管理设置 | 实际文件/文档/播放工作台、B站五栏、工具深页 |
| 通用偏好 | 更多、存储、代理、广告拦截、账号、备份、权限、协议、开源、六页引导 | 非默认数据与所有平台状态组合仍需逐页覆盖 |
| 外观 | 五主题标签、颜色/聊天样式、语言、全局显示、布局 | 不写全局偏好，主题真实切换待业务接入 |
| AI 设置 | 模型/API、11功能分配、上下文、工具授权、资料、历史、LAN、回复表情、用量 | 角色卡/标签/群组、虚拟形象、模型非默认分支、完整工具目录 |
| 语音 | STT三引擎、TTS九引擎及朗读工具、唤醒三组和录音/附件弹窗 | 只投影快照，真实语音能力尚未接入 |
| 跨平台 | Android/Windows可构建、窄屏/横屏/大字/键盘组件检查 | 同设备旧新视觉/触摸/Profile、Apple真实编译 |

所有业务保存、网络、系统、录音、导入导出等保持空点击；交互草稿不代表业务生效。
详细来源与尺寸见[UI契约](design/ui-parity.md)，迁移方法见[复刻流程](development/ui-replication-workflow.md)。

## 本批工程改进

- `HomeShell` 的详情装配提取到 `SettingsNavigation`，仍使用同一个 Navigator；
  一级缓存、pager、来源返回和手势 owner 保持不变。
- 四个截图套件共用 `test/support/ui_capture.dart`，统一字体参数、PNG释放和阴影恢复；
  `tools/test-ui.ps1` 保证从正确 app 工作目录定向验证和截图。
- `tools/inspect-legacy.ps1` 只读输出旧 source revision、九模块与跟踪UI文件索引；
  本次清单为4948跟踪文件、1072 UI/设计/壳源码文件，不等于页面数或全部已复刻。
- Android启用本地Gradle task cache，不改远端缓存、全局SDK、依赖版本或Native Assets契约。
- 文档分离当前状态与历史证据，补齐复刻步骤/验证/清理规则，公共UI禁止反向依赖app/bridge。
- 原Windows引擎测试仍把账号入口当空点击，已改为验证详情返回后再使用底栏。
- 候选树396文件约5.90MB，174个非生成Dart文件，未见相对导入循环、失效相对导入、
  大小写冲突、符号链接、超5MiB文件或高置信凭据。构建产物、临时脚本、日志与字体不提交。
  无用空目录 `features/player/presentation` 的删除被自动审批拒绝，保留原样；Git不跟踪空目录。

## 验证与产物

治理前最新完整验证：6 Rust +238 Flutter +6真实FFI，Android/Windows Debug通过；
日志 `work/wakeup-verify.log`、`work/wakeup-android.log`、`work/wakeup-windows.log`。
本批 `tools/verify.ps1 -WindowsIntegration` 的静态检查、6 Rust、238 Flutter、6真实FFI
通过；首次Windows测试因账号入口断言过期失败，修订后同一入口的2项真实引擎测试通过。
日志 `work/governance-verify.log` 保留首次完整运行与失败，
`work/governance-engine.log` 保存修正后的通过证据，不把失败日志当全绿。
定向导航/TTS25项通过；四截图套件全部通过，共106张渲染图，抽查TTS与模型暗色页。
日志为 `work/governance-capture.log`、`work/governance-shell-capture.log`；本机字体不是Android像素证明。

Android/Windows最终普通Debug构建通过，日志 `work/governance-android.log`、
`work/governance-windows.log`；该次构建任务10.6秒/8.7秒，无冷缓存对照，不宣称确定加速比例。
最终固定包 `artifacts/ui-preview/20261002-124054/Kiyori-ui-preview-arm64-debug.apk`，
2026-10-02 12:40:54，97,970,173字节，SHA-256
`9B16B11D596CE8EDD0CFAEF0F64175EEED8E9229FED7007462C0F36580277F67`。
`com.kiyori`/0.1.0(1)、arm64-v8a、min24/target37、v2签名和16KB ZIP对齐通过。
Windows产物为 `apps/kiyori/build/windows/x64/runner/Debug/`，集成测试后已重建普通入口。
doctor无问题；直接运行依赖与当前可解析测试依赖保持，无强制升级。未安装设备、未部署、
未执行远端CI或Apple构建，真机触摸/性能继续待验。

用户固定检查包保留：
`artifacts/ui-preview/20261002-121113/Kiyori-ui-preview-arm64-debug.apk`，97,970,244字节，
SHA-256 `4737B19CE28857BA927CFAB62B2D05B1042A8318AC7C30BA19DBB99FA6EF3070`。
该包包含TTS/唤醒，v2签名和16KB ZIP对齐通过，但不包含之后的工程治理改动。
11:23旧包也保留。当前没有用户设备验收反馈，不能记为通过。

## 后续开发入口

本批治理提交交付后，从角色卡和提示词开始继续U2/U6：
`ModelPromptsSettingsScreen.kt` 的角色卡/标签/群组三标签及 `CharacterCardDialog.kt`。
默认角色来源 `CharacterCardBilingualData.kt`，标签默认空目录；高级模型/记忆/工具绑定、
导出模式和嵌套编辑仍须继续核对。尚未写入角色页面实现。
其后虚拟形象 → U3轻量抽屉 → U4工作台 → U5深层工具 → U6剩余AI/扩展 → U7全入口复查。
已有高级Markdown/动画图片生命周期、非默认模型与完整授权目录继续按真实来源补齐。

自动接续 `kiyori-ui` 在本批收口时实查为 `PAUSED`，本次没有恢复或重建调度。
后续开发先读取本文件与实时Git，不能把历史提交授权扩展到未来任务；以用户最新指令为准。
