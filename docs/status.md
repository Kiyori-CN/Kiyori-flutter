# 当前实施状态

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
