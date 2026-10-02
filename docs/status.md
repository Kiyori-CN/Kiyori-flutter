# 当前实施状态

更新时间：2026-10-03（Asia/Shanghai）。本文件是当前实施进度唯一权威；
[路线图](roadmap.md)规定顺序，[历史记录](status-history.md)保留过往批次证据。

## 当前任务：设置全树与AI真实业务连续开发

当前正式Goal为active、无预算。开工实查main/HEAD及fetch后的origin/main均为
`4a69550bc5e2489c02d144b3a4eb45e5266870fa`，左右差异0/0，工作区与暂存区干净。
只读旧仓库HEAD为`6b03b03aa082803bb279db5e78773583e2d91154`且干净。
本任务授权范围内实现、验证、串行Android/Windows构建、精确提交与普通推送；不操作
设备、账号、私人收费端点、生产或CI，不启动自动化，不委派。日记local_only、Asia/Shanghai。

执行阶段A/B：核对12项设置及全部设置子树，完善公共组件、非默认态、弹层和返回来源。
设置本地验收后立即进入AI左抽屉与真实业务切片；AI重要功能未实现时Goal保持未完成。
每周期按相关性合并有效实现，完成批次继续下一批。总验收包括源码映射、行为/截图、
静态/FFI/集成、双端构建、固定产物及远端一致；设备/供应商/Apple缺口单列。

已确认一级12项顺序一致；AI虚拟形象入口已补接并覆盖模型空态/启用/预览/Mood/导入说明，
账号页已补已连接/失效状态，
角色与群组同源紧凑字段已归并，账号状态和设置映射已实施。当前批次已通过账号、形象、
应用设置及角色/群组44项定向测试、设置相关157项回归、形象15项极端状态测试通过。
形象动作菜单/自定义弹层在模型删除后释放，320px、横屏、桌面双倍字/160px键盘通过。
此前失败的极端用例完整保留并恢复原断言；修正双向滚动定位器，未降低命中警告。

本批完整`tools/verify.ps1`通过：脚本4项、Rust fmt/Clippy/6测试、Dart格式/analyze、
Flutter298项（8捕获套件按默认入口跳过）、真实FFI6项；日志
`work/settings-tree-verify-v3.log`。无Rust API、桥、依赖或lock变更，未重复Windows引擎测试。
账号/角色43张捕获见`work/settings-tree-first-capture/`，最终形象10张见
`work/settings-avatar-capture-final/`；明暗、空/非空、Mood、相机与编辑弹层代表图已审阅。

串行`tools/build.ps1 -Platform android/windows -NoPub`均通过，普通产品入口固定到
`artifacts/ui-preview/20261003-001934/`，旧包保留。APK 104677398字节，SHA256
`86AF870685F12EB02F3BD8C30FF05B03B95D7A980174705B109D2F05F0B1791B`；包名com.kiyori、
0.1.0/1、min24/target37、ARM64、v2签名、ZIP16K与ELF LOAD对齐通过。
Windows x64完整82文件117533806字节，Flutter DLL与pin一致，含kiyori_ffi.dll；逐文件
SHA256及来源状态在manifest，审计在`work/settings-tree-artifacts-20261003-001934/`。
第一批已交付`c738090d49cfc96182ee7352ba33c58b55093e2a`，推送后本地/远端一致，左右0/0。

第二批补入GitHub方式选择→全屏内嵌登录壳、B站已生成二维码/刷新/确认/过期投影；补入广告
拦截运行时五阶段、URL/元素/白名单目录、按域折叠、内置5条订阅、自定义订阅状态/编辑/删除。
账号登录6项测试与12张状态截图、广告规则/订阅18项测试与16张截图通过；分析无源码问题，
过程中的一次Dart线程创建错误仅保留日志，未作为成功证据。WebView/OAuth、二维码生成、广告
Store下载/编译执行仍为空操作，真实业务 owner 未接入。

第二批完整`tools/verify.ps1`通过：50文档、4脚本、Rust fmt/Clippy/6测试、Dart格式/analyze、
Flutter316项（10捕获套件跳过）、真实FFI6项。日志`work/settings-login-adblock-verify.log`，
最终截图28张在`work/settings-login-adblock-capture-final/`。未改变公共Rust API/桥或依赖。
串行Android/Windows Debug构建通过，固定`artifacts/ui-preview/20261003-011013/`：APK
104702293字节，SHA256`A47555DDF31EBBBD00E31EA8AC0C77D96E96413F8DB4AC3CA19B5B960C592FA4`，
ARM64/身份/v2签名/ZIP16K/ELF LOAD对齐通过；Windows x64共82文件117595494字节，DLL
与pin一致、native资产和复制哈希一致，逐文件manifest保留。本批按精确清单交付后继续代理。

第三批已实现并验证网络代理六层非空目录与运行状态：订阅编辑/删除、节点分组与排序、规则/
脚本选择、日志搜索/级别/清空。按实体存在期清理路由，当前订阅规则更新或切换释放旧
草稿，已打开弹层同步busy状态；未创建配置、核心或网络服务。修复横屏双倍字键盘下
输入区域被固定标题挤压的问题，标题与正文共同滚动。代理22项行为/视口检查通过，
48张截图在work/settings-proxy-capture-v2；全量verify为Flutter332项（10捕获跳过）、
Rust6/FFI6/脚本4、50文档和221 Dart格式/analyze通过。首次lint两处缺花括号已修复，
失败日志保留；最终日志work/settings-proxy-verify-v2.log。公共选择器消费者已全量回归。
串行Android/Windows Debug成功，固定artifacts/ui-preview/20261003-015123：APK
104751079字节，SHA256为42496172A4394D87F33B06424AB72223CEB3F7A98BC7249D86A26352500F9D5D；
Windows82文件117708422字节。APK身份/ARM64/v2/ZIP16K/ELF对齐、Windows x64/DLL pin/
native资产及逐文件复制哈希通过；无Rust API或依赖变动。本批精确提交推送后继续音乐。

这不是完整设置验收：其余非默认态、有效二维码服务、音乐音源/备份和外观媒体等仍需继续；形象导入/渲染和真实AI业务尚未实现。设备视觉、
触摸/Profile、真实账号/供应商、Apple构建没有执行，不能由本机Debug结果外推。

恢复入口：读取[设置映射](design/settings-replication-map.md)、当前Git差异和本机日记
`c3e66803-02cf-452e-aae6-a3ad0662dae0`，接续音乐音源详情/导入更新/切换/移除与备份预览/撤销。
上一批固定产物`artifacts/ui-preview/20261002-171634/`保留。

## 最近已交付：第四轮群组卡草稿垂直切片

基线为 main / b2ded4b0f7b60e82acc0a6e452e48611699ed556，原任务开始时干净、与
origin/main为0/0。中断恢复时保留原17个未提交文件，暂存区为空；复核后接续交付。
旧源 Kiyori-Android / 6b03b03aa082803bb279db5e78773583e2d91154 保持只读且干净。
kiyori-ui仍为PAUSED。正式Goal不设预算，日记local_only、Asia/Shanghai；没有子智能体、
外部研究、设备操作、部署、远端CI或全局工具链变更。

目标是群组列表与编辑草稿的完整UI切片，复用角色工作台的实体身份、模态生命周期、
设置入口与返回来源。非目标是Rust持久化、真实创建/保存/删除/复制/激活、会话关联、
网络请求和虚拟形象。回滚参考为上述基线，固定包和失败证据均保留。

本批群组UI实现、回归、截图、Android/Windows Debug构建和产物审计已经完成。
本轮按精确允许清单交付到main，实际提交与远端ref以Git为准。设备视觉/触摸/Profile、
TalkBack、Apple构建及真实业务接入保持 verification_pending，全产品复刻尚未完成。

## 实际实现与旧源结论

| 范围 | 已实现 | 边界 |
| --- | --- | --- |
| 入口与目录 | 群组标签、默认空态、注入列表、更新时间降序、成员数/摘要、活跃徽章 | 产品默认仍空目录，不注入测试群组；群组活跃时抑制角色徽章 |
| 菜单 | 编辑与删除确认、复制/激活入口，40px菜单区域 | 最终创建、复制、激活、删除为空动作；无重置或导出 |
| 编辑 | 48px头像外观及添加/重置按钮、名称、可选描述、成员列表 | 头像及字段展开沿用旧空回调；最终保存不写业务事实 |
| 成员 | 按orderIndex初始化，下拉选择后添加、尾部追加、单项移除，排除已有ID | 无拖排、默认成员、数量上限、规划参数或群组模型绑定 |
| 异常引用 | 初始缺失显示ID，重复引用按出现项隔离，曾存在角色被移除时过滤草稿 | 同ID新代次不恢复旧成员；真实引用完整性归后续owner |
| 生命周期 | ID/存在代次隔离，重排保留，删除/宿主替换释放会话和所属菜单，Back逐层取消 | 返回按当前角色ID/代次验证，不误关无关页面 |
| 视口与主题 | 明暗、小屏、大字/键盘、横屏、桌面，取消/保存可达 | 本机Flutter证据，不等于Android像素或触摸验收 |

指定旧源没有规划参数、默认群组、手动排序或重置流程，这些建议项判为不适用。
成员选择不是独立确认对话框：选择只回填待添加项，再点击添加才改变草稿。旧空白名称
保存直接返回，无错误提示；新最外层保存保持空动作，不补造成功、错误或禁用外观。

来源深度、几何、持久化键和后续owner条件见[角色卡契约](design/character-prompts.md)。
群组组件/模型/Manager/ActivePrompt已完整核对；聊天绑定仅定向读取调用方，未宣称
群聊执行器、完整历史服务或整个settings文件逐行审计。Rust公共API、桥、依赖及lock
均无变化，没有重新生成或手改生成代码。

## 验证与修复证据

最终定向33项通过（原15项角色回归及18项群组用例），见work/group-prompts-tests-resumed.log。
覆盖来源返回、空目录/活跃互斥、名称/描述隔离、保存空动作、下拉取消/选择/添加、
顺序/重复项移除、重排/删除/同ID重入、过期角色选项拒绝、控制器/焦点释放、无关路由
保留、小屏双倍字/180px键盘及横屏滚动。宿主替换覆盖菜单首帧之前和之后。

初轮28项中2项发现真实生命周期问题：目录帧尾发布后再延迟一帧清理，却未请求新帧，
静止界面残留旧弹层。PromptDialog增加ensureVisualUpdate，保留断言复跑通过。
后续扩展的返回定位器按ShellAction真实结构修正，没有降低断言或关闭命中警告。
菜单首帧前宿主替换需在内容首次构建时登记/撤销真实路由，现有回归覆盖。
初始/扩展失败日志保留在work/group-prompts-tests-initial.log及对应failed日志。

捕获套件1项通过，35 PNG（既有20张及新增群组15张）在work/group-prompts-review-delivery/，
日志为work/group-prompts-capture-delivery.log。审阅手机明暗、下拉/添加、菜单/删除、
桌面、横屏、大字键盘代表图，修正下拉左侧下方锚点和40px菜单点击区；初轮图保留在
work/group-prompts-review-initial/。最终捕获之后仅补路由释放与测试，没有改变几何，
恢复时再次审阅代表图。本机字体与Debug截图不能充当Android像素或性能验收。

所有构建/验证先执行tools/activate.ps1，使用Flutter3.47.6 / Dart3.13.5 / Rust1.99.0。
恢复后完整复跑最终源码，不以旧日志结束状态推定最后新增分支已执行。

| 入口 | 结果 | 本机证据 |
| --- | --- | --- |
| tools/verify.ps1 -WindowsIntegration | 文档49份、脚本4项、Rust fmt/Clippy/6测试、Dart格式/analyze、Flutter279项、FFI6项、Windows引擎2项通过 | work/group-prompts-verify-resumed.log |
| tools/test-ui.ps1 -NoPub -Test character_prompts_test.dart | 33项通过 | work/group-prompts-tests-resumed.log |
| tools/test-ui.ps1 -NoPub -Capture -Test character_prompts_capture_test.dart -Output work/group-prompts-review-delivery | 1套件、35 PNG | work/group-prompts-capture-delivery.log |
| tools/build.ps1 -Platform android -NoPub | ARM64 Debug通过 | work/group-prompts-android.log |
| tools/build.ps1 -Platform windows -NoPub | x64 Debug通过，引擎测试后恢复普通产品入口 | work/group-prompts-windows.log、work/group-prompts-windows-restored.log |
| tools/check-foundation.ps1、git diff --check | 最终文档和差异核验 | work/group-prompts-foundation-final.log |

完整验证按设计跳过6个捕获套件，本批相关捕获单独执行。工具提示7个传递依赖有更高
但不兼容当前约束的版本，本轮未升级。交付树审计415文件、194 Dart：无人工源码依赖环、
失效相对/本地package导入、feature→app、公用UI→业务/bridge或测试互导问题；FRB生成
内部循环单列且本轮未改。无新增依赖、异常大文件、链接、子模块、嵌套Git或高置信敏感
内容发现，结果见work/group-prompts-full-audit-reviewed.json。产物、截图、日志、临时
脚本仅保留忽略目录，不进入精确提交清单。

## 本机固定产物

最终目录artifacts/ui-preview/20261002-171634/：APK1个、Windows完整目录82文件，
共222,050,445字节；Windows为117,420,950字节。83个文件副本与构建源逐一核对SHA256。
manifest保存pin、来源基线/最终提交、时间、路径、大小及完整哈希；固定二进制不因
后续构建覆盖。证据在work/group-prompts-artifacts-20261002-171634/，同时记录367个源码及
构建输入哈希。首次固定目录20261002-170727保留；恢复产品入口后kernel哈希改变，
因此新建最终目录并再次审计，83文件与最后构建源一致，没有覆盖旧固定包。

| 产物（相对固定目录） | 字节 | 修改时间（2026-10-02，Asia/Shanghai） | SHA256 |
| --- | ---: | --- | --- |
| Kiyori-ui-preview-arm64-debug.apk | 104629495 | 17:06:11.169 | D34054104BB46FD3BD9978012C0637B850A671E67FA3CF9834261BB14942D17C |
| windows-debug/Kiyori.exe | 1281024 | 02:33:25.021 | 221590339BBEA871886F8C98D01B227D4603B7E605AEEDD29D4E5F4E1C2D1475 |
| windows-debug/data/flutter_assets/kernel_blob.bin | 53880952 | 17:12:26.301 | A385BC6D1FA8A7155B06DF857C53B7224F24F9EAE5F36EC91B8A130540E228CB |
| windows-debug/kiyori_ffi.dll | 553984 | 13:45:55.575 | 8A64AB530621EF8CA05C1519A8094EDE586834FB62F7ED1FB4919C5E66FD7FAA |

APK为com.kiyori / 0.1.0(1)、min24/target37、ARM64、Debug v2签名，ZIP16KB及3个原生库
ELF LOAD对齐通过，含53个默认表情。Windows PE为x64，Flutter DLL与pin SDK一致，
运行时NativeAssetsManifest引用随包kiyori_ffi.dll；根native_assets.json绝对路径只为
构建期记录。EXE原生runner未改变而增量复用，新Dart内容由kernel证实。
上一轮固定包20261002-161431及更早包保留，上一轮APK SHA256仍为
32121CDCD6DFE6E764A17D23A30BE5FA00724D0D91DB21480A2FD0020A26DDB0。

## 上一批证据与衔接

M1运行时已实现，业务M2尚未开始；UI轨道U2/U6新增群组草稿切片。性能只落实源码
工作边界：目录/成员变化时计算候选集、列表惰性构建、复用角色ID到名称索引，无服务
订阅或后台I/O；没有同设备前后Profile，不能声称帧/触摸/内存目标达标。

上一批遗留标签批量导出、市场、人设生成与虚拟形象入口纳入当前设置/AI关联矩阵。
真实群组owner需定义持久化/引用完整性、取消/错误和会话关联契约，不能由Dart草稿承担；
本次长期任务已授权实施真实业务。当前优先级和授权以本文顶部为准。

最短本机复核：先激活工具链，再运行tools/test-ui.ps1 -NoPub -Test character_prompts_test.dart。
产品默认群组仍为空，非空群组/编辑由测试注入快照验证，可查看35张捕获；固定包不代表
真实群组业务可用。第四轮日记已经关闭，本次使用新的长期任务段，不改写其历史。
第四轮本地UI验收已闭环；真实业务未实现与设备/Apple待验证分别记录。
