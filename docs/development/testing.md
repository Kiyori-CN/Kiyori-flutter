# 验证与交付策略

## 按阶段选择检查

M1 已有真实工程。文档执行 `tools/check-foundation.ps1`；实现执行 `tools/verify.ps1`，需要 Windows 引擎实测时加 `-WindowsIntegration`。构建执行 `tools/build.ps1 -Platform android/windows`（二选一）。Gradle 入口在 `apps/kiyori/android`，不要使用旧工程根路径。
根目录analyze排除Git忽略的work/artifacts临时研究与产物，仍覆盖全部产品Dart源码。
target中的固定C++源码及构建缓存同样排除，不将上游历史Dart夹具作为产品代码分析。

build/verify 先核对实际工具版本。`build.ps1 -Mode debug/profile/release` 显式选择模式，默认
Debug；性能测试用 Profile，Release 不配置 Debug 签名。帧性能入口与证据边界见
[性能契约](performance.md)，默认验证不安装设备、不自动运行性能 benchmark。

以下 Android/Windows 入口已在 M1 实际使用；iOS 命令仅可在 Mac 上执行，当前未验证。

| 范围 | M1 之后的检查 | 证明范围 |
| --- | --- | --- |
| Rust | `cargo fmt --check`、`cargo clippy --workspace --all-targets -- -D warnings`、`cargo test --workspace` | 格式、静态问题和纯核心/协议行为 |
| Dart/Flutter | `dart format --output=none --set-exit-if-changed`（指定源码目录）、`flutter analyze`、各 package 的 `flutter test` | UI 状态、组件、adapter 契约 |
| FFI | `tools/generate-bridge.ps1 -Check`，`tools/verify.ps1` 的真实 Dart 测试 | 类型映射、事件顺序、取消、释放和生成一致性 |
| Android | 在 `apps/kiyori` 执行 `flutter build apk --debug --target-platform android-arm64` | APK 与本机原生库打包；不等于已安装 |
| Windows | 在 `apps/kiyori` 执行 `flutter build windows --debug` | runner、DLL、资源完整打包 |
| iOS | Mac 上 `flutter build ios --no-codesign`、模拟器/真机运行 | Apple 编译与对应运行层；签名发布另验 |

## 高价值测试

portable归档验证独立Node中文/Emoji旧19字段hash、P256链头ASCII签名、payload哈希与
修订/当前投影关联，篡改拒绝和重开封印复用；诊断验证64KiB/8MiB预算、首尾UTF16、
去重锚点、动态围栏、路径/账户假名化与幂等。旧Android进程导入仍未实测。

platform/audit用Windows真实DPAPI/AES-GCM/P256验证nonce随机、重开同身份、密文
篡改与缺失/损坏密钥拒绝、schema20迁移失败回滚/触发器恢复、正文搜索分页/链头
保留及持久签名复用/损坏拒绝。产品FFI固定装配native，Rust参考夹具只保留纯核心
测试合同；Android还需Keystore实机，JNI符号和普通编译不证明实际设备密钥可用。

历史目录：core/conversations验证删空后同事务创建/选择替代、同绑定最新回退、单删继承
分组/整组不继承、同名作用域隔离、锁定/成员版本冲突原子拒绝、排序与自动角色/聊天。
conversations_audit_tests覆盖schema19迁移保留、Unicode正文分页、全记录搜索、真实修订/
备注重开、链篡改拒绝与ZIP签名/文件哈希。chat_history_states/parity从真实FFI/SQLite
验证滑动96dp/禁方向阻力、草稿确认、实体与分组移除释放所属路由、设置单一语义、
备注/导出、向下拖排及快滚首尾；chat_precision_capture补真实宿主横屏安全区边界。
current默认与未绑定同桶覆盖列表/菜单/拖排/分组冻结，character精确桶和其它角色/
群聊隔离、锁定/成员冲突回滚、自动默认复用未绑定历史。UI回归覆盖分支与普通行
等高、父标题/AccountTree、展开/当前/置顶/锁定/生成语义、Oklab阈值/反向中间帧、
触发后回位背景、PointerCancel不执行动作及动画停止后无持续帧请求。
搜索回归覆盖Unicode标题/分组与正文异步并集、等值目录重读和持续无关通知不重置400ms
防抖、改名后重新查询、清空拒绝迟到结果；核心核对单Emoji的UTF-16正文门槛、BMP单字
不查正文、SQLite ASCII大小写与百分号/下划线字面语义。真实loopback只用合成正文。
大小写回归包含É、希腊词尾sigma、土耳其I及ß不扩展SS；五窗口捕获追加正文筛选结果。
拖排回归使用真实指针，覆盖开始/有效让位触觉、非法置顶落点过程不让位、二维跟手、
取消/搜索/外部目录/宿主释放不写库，第二指不接管首指，48dp边缘滚动和空/折叠桶保存。
松手只增加一次移动revision，返回/取消完成后无持续帧。haptics_test验证Android原生
requested/declined/unsupported/unavailable、无CLOCK_TICK回退与iOS标准调用；mock与
Android编译不能证明设备触觉。捕获追加明暗代理、上边缘视口裁剪与取消恢复图。
chat_history_payload使用真实SQLite目录/事件/正文和仅在读取边界注入的失败/等待，
验证旧独立重试文案、成功恢复、摘要单击展开与长按复制；收起期间停止后续分片，
重开从第0页重新读取且保留完整中文。捕获参数同时追加明暗失败/恢复与加载状态。
chat_history_drawer_capture以五窗口捕获明暗/320双倍字键盘/横屏/桌面；audit_exchange
测试Windows真实二进制I/O、取消不覆盖、忙守卫和移动channel脱敏。旧版完整供应商/
工具事件、旧审计包兼容、系统SAF、设备像素/触摸/Profile与Apple需独立验收。
请求审计回归使用真实loopback核对发送体、认证遮蔽、begin双记录事务回滚/无外发、
HTTP失败与取消单终态和Run顺序；既有总结回归核对实际SUMMARY请求体与独立凭据
不落审计。详情新增105备注夹具，验证raw无匹配可加载、正文全记录查询、标签查询/
页数/滚动保留及展开释放；展开JSON渲染不省略。测试截图不证明Android字体/触摸一致。

provider_chat验证密钥池只调用连接handler；发送前计数使用最终history并更新同会话窗口，
与Usage分开。覆盖十进制旧别名/边界、单并发不自锁、无效/超预算阻止发送和计数/连接中
撤销等HTTP/VM释放，不把取消记为密钥不可用。model_extension_business_test执行正式
FFI密钥池与聊天并投影窗口和Usage。provider_chat/threshold覆盖低计数避免字节误触发、
高计数触发与总结后重算、独立密钥未触发不消耗、超限/取消/迟到配置和原文/用量/重开。
供应商、设备和Apple边界单列。

core/extensions/archive_tests覆盖根/嵌套JSON/HJSON选择、中文/Emoji/多行、默认字段、
schema2分发元数据、重复键/递归/尾部、相对/大小写入口、失败不回退或覆盖旧包；
真实ZipWriter流式32/64位descriptor与局部/中央篡改、隐藏条目验证完整布局，解压CRC
仍使用正式zip。包完整旧宿主能力、同设备视觉与Apple不由这些核心用例证明。

native_model_ui_live_test.dart默认跳过，显式KIYORI_NATIVE_TEST_DATA指向独立已下载MNN验收库
后走真实设置/保存/ChatPage/富文本/用量/重开；native_inference_live_test.dart补停止与目录。
gguf_import_live_test.dart显式KIYORI_GGUF_TEST_FILE选择已核对的公开Qwen2.5-0.5B Q4_0完整文件，
使用临时库从说明卡→Windows有界文件I/O→Rust导入→目录→真实聊天/停止/重开，不重复下载。
这两个入口不安装设备；Android SAF选择器与provider释放仍需设备验收。core/model_import
覆盖hash/原子交付/重复冲突/大小/坏头/锁/取消/中断清理；platform/model_file_test覆盖Windows
真实有界文件读取与源文件不变。native专项验证UTF-8/大正文完整分片/超限失败/取消等待析构。
gguf_import_dialog_test.dart覆盖取消选择/在途读取释放与提交期间禁取消；core导入回归还
覆盖rename后事务前恢复、completed资源缺失补回和篡改拒绝。默认verify不读取用户模型。
native_model_summary_live_test.dart显式KIYORI_NATIVE_TEST_DATA/PROVIDER/MODEL时执行完整模型
两轮聊天→独立自动总结→手动检查点→原文/用量重开；同时保留新问题回答的正确性断言。
core/native_summary_projection回归核对总结后最新用户输入、同配置单并发释放和手动插入，
以区分请求投影错误与模型摘要/回答质量。公开小模型通过不泛化为所有本地模型能力。

local_models_business_test.dart以合成目录投影、真实Rust/FFI/SQLite下载6字节文件，验证
暂停/Range续传/校验/重开/确认删除/刷新失败；transfer_runtime_test.dart覆盖无人消费和
暂停订阅时Runtime关闭。Rust downloads/local_models测试清单路径、实体/范围/哈希、
OS单执行者、迁移与完整目录→仓库→传输链。公开完整模型验收显式运行
`cargo run -p kiyori_core --example verify_local_model_download -- <absolute-test-dir> <model-name>`，
它会下载指定完整包并暂停续传；不纳入默认verify，不使用API凭据或用户文档。

chat_business_test.dart使用真实DPAPI、生成FFI、SQLite和loopback验证界面发送/多轮/取消/
错误/切换/重开、原子重发、消息修改与短凭据lease。带Capture可生成明暗/320大字键盘/
横屏/桌面与历史截图。chat_live_test.dart默认跳过，只有用户明确授权并向进程内存注入
KIYORI_LIVE_KEY、KIYORI_LIVE_ENDPOINT、KIYORI_LIVE_MODEL时才执行两轮合成请求；
不得将实际值写命令历史、源码、日志、截图或Git。供应商验收与设备验收分别记录。
增加KIYORI_LIVE_SUMMARY=1时创建独立总结配置与DPAPI引用、summaryCount=1，第二轮必须
产生摘要并保留口令，重开核对摘要及四条原始消息。chat_business_test用loopback覆盖同链路
及编辑失效；summary用量、预算和迟到身份保护由Rust专项验证。
手动摘要覆盖user/AI边界、完整历史、继承检查点、失效/删除/编辑/分支、独立认证、
取消/空输出/不完整终态与迟到配置/历史变更。chat_business_test从菜单经真实FFI/
DPAPI/SQLite插入、详情编辑及二次确认删除并重开；chat_summary_capture_test核对
320/440/844横屏/1440桌面、明暗/双倍字与长正文滚动，不代替同设备像素验收。

core/chat通过真实loopback HTTP覆盖POST、拆流、结束/usage、错误/重定向与取消；
packages/kiyori_bridge/test/chat_runtime_test.dart覆盖真实FFI事件、取消等待、未订阅关闭和超时。
model_connection_test.dart用真实Rust及loopback探测聊天和system口令并捕获结果卡。
该测试同时运行Chat/Responses；core/chat的Responses回归覆盖input/token参数映射、usage、无DONE终态、
incomplete、工具/失败/断流、思考不进入正文及最终快照不一致。供应商实测仅在明确授权后运行，
密钥不得写入测试源码/日志；单个端点的成功不泛化为其他供应商或完整聊天页验收。
Responses流式回归包括reasoning_text的content_part added/done与思考条目终态，验证思考
不进入正文，同时保留未知输出拒绝、最终正文指纹和不完整终态检查。真实矩阵可设置
KIYORI_LIVE_REQUIRE_ALL=1，逐条断言所选能力通过；探索模式的退出码不能代替脱敏JSON审阅。
pool_runtime_test.dart验证真实并发上限、启用/未标记筛选、重复值独立ID、401和取消不污染标记。
model_pool_business_test.dart验证DPAPI逐项保存/重开、清标记、输入失效、宿主移除以及暂停等待在途保存。
model_execution_tests.rs验证轮询重开、revision隔离、标记/回退规则、随机候选边界、schema7迁移、
10个独立连接的原子分配及删除级联。model_connection_test.dart通过真实FFI/loopback验证Chat与
Responses聊天/system探测分别发送第一、第二候选；不以配置里存在密钥池字段宣称轮换已执行。
这些不替代真实供应商、TLS根/代理、Android设备或Apple环境验收。

模型配置补充：core/models测试迁移、模型名引用/显式替代和安全引用状态；
apps/kiyori/test/models_business_test.dart在Windows使用真实FFI和DPAPI验证保存失败、
清理重试、并发输入与UI写入。packages/kiyori_platform/test使用Windows真实加密和
移动channel mock，后者只证明调用约定；不替代Android/Apple设备安全存储验收。
schema7恢复测试只终止测试自己启动的专用子进程，验证真实文件锁释放与pending回收。
context_business_test.dart通过真实FFI验证上下文保存、媒体独立重置、并发草稿和返回前刷写；
models核心补绑定切换拒绝、事务回滚与迁移，model_credentials_test.dart验证payload迁移与脱敏。
text_exchange_test.dart使用Windows真实文件I/O与注入的选择结果验证取消、大小/编码和脱敏；
mobile通道mock只验证契约。model_pool_test.dart覆盖导入/导出/清空和迟到结果，models_business
补选择完成前flush等待及真实DPAPI密文。原生选择器交互和Android provider生命周期需设备验证。

页面迭代可从根目录运行 `tools/test-ui.ps1 -Test <name>_test.dart`；指定 `-Capture`
复用真实 app 资源和本机字体捕获。脚本不会替代完整 verify，详见
[复刻流程](ui-replication-workflow.md)。截图必须在可追溯源码版本上生成，不能在验证中修改输入。

同一批依赖已解析且 pubspec/lock 未变化时，`test-ui.ps1` 和 `build.ps1` 可加 `-NoPub`
复用解析结果。新检出、依赖变更或解析缺失时保留默认行为。完整 verify 仍负责正式批次检查。
`tools/test-tooling.ps1` 随 verify 执行，用临时夹具验证桥接输出集合不变、新增嵌套文件、
内容修改和删除四种行为；实际生成一致性仍用 `generate-bridge.ps1 -Check` 核对。

核心优先覆盖权限撤销、流取消、提交结果未知、任务恢复、数据库迁移、资源 URI/路径差异、规则切换、Range 续传和扩展输入边界。测试行为与契约，不为每个 getter、目录存在或低风险文本修改写镜像测试。

UI 关注响应式布局、键盘/鼠标/触摸、大字体、可访问性和生命周期。原生能力采用真实平台集成测试，mock 只能验证调用约定，不能证明后台服务、权限弹窗、音频焦点或 WebView 行为。

动态实体目录还需验证打开菜单后的重排/删除、保留实体的 controller 身份、移除后释放、
离屏焦点/ticker 和待返回弹层。`governance_regression_test.dart` 覆盖这些现有失效路径；
`settings_theme_capture_test.dart` 为设置、浏览器设置、TTS、主题、备份、权限和引导捕获明暗两态。
暗色宿主注入验证组件适配，不代表全局主题偏好已经接入。Windows 引擎集成结束后，
交付前重新构建普通 Windows 入口，不能把测试 runner 当用户检查包。

## 设备矩阵

TOOLPKG包管理：core/extensions回归覆盖真实ZIP路径/CRC/大小写别名/入口篡改、安装升级
启停卸载与墓碑代次、重开、pending恢复、取消等待及跨Runtime锁，以及安装Future丢弃/
关闭等待注册worker、schema18迁移保留与结构冲突回滚；
packages/kiyori_bridge/test/extensions_runtime_test.dart执行真实QuickJS/FFI/SQLite的
合成包安装、四handler、流式中间/最终结果、撤销活动VM、重开、升级、卸载重装，以及
无消费者/部分导入的Runtime关闭。合成包无网络，不能代替HTTP宿主或产品聊天验收。

受控HTTP：core/extensions/http_tests验证限定URL/安全头/凭据引用、跨片段UTF8和
secret回显、共享client、停滞体取消、重定向/超量拒绝。platform/scripts/tests/http
执行真实QuickJS四handler和包撤销，未改旧示例通过显式只读源路径验收。
provider_chat执行正式目录、流式/缓冲、system、多轮、自动/手动总结和SQLite重开，
以及单并发活动/排队禁用、非法用量/缺失及伪造终态、捕获HTTP失败和网络超时。
model_extension_business_test通过真实FFI验证旧抽屉选择、保存/重开与撤销保留配置。
extensions_business_test从插件产品UI经真实文件句柄、QuickJS/FFI/SQLite安装、启停、详情、
取消删除、卸载与重开；extension_import_lifecycle_test验证取消/失败释放、启停事实恢复及
同ID新revision关闭详情和确认，不删除新包。extensions_capture_test覆盖明暗、320宽双倍字、
横屏和桌面；本机字体截图不替代同设备像素验证。model_file_test验证TOOLPKG/GGUF共用
同一有界句柄和类型限制，移动channel mock仅证明调用合同。
默认测试不调用真实供应商，真实端点结果和设备像素验收分别记录。

首轮 Android arm64 真机、Windows x64；Android x64 模拟器在需要时添加。iOS 没有 Mac/iPhone，明确保留待验证，后续先模拟器再真机。旧应用和新应用并存需查安装包标识、Provider、数据目录、终端 home/socket/端口，再测试同时启动。

## CI 与发布

本机脚本作为未来 CI 的共同入口；Git 提交推送授权不自动包含远端计算资源/工作流运行，
新增会在 push 时自动触发的 workflow 需对应授权。Windows + Android CI 接线单独推进，Apple runner
仍需资源授权，不宣称本地脚本已在 CI 验证。

产物保存在忽略的 `artifacts/` 或 CI artifacts，不提交 APK、EXE、DLL、SO、SDK 和私钥。记录源 revision、工具版本、目标 ABI、构建时间和 SHA-256。Debug 编译通过不表示 Release、签名、商店审核或用户设备验收完成。

## 基础检查器边界

`tools/check-foundation.ps1` 检查 UTF-8/LF、一个一级标题、标题层级、闭合代码围栏、本地文件链接、JSON 可解析、PowerShell 语法、工具链接线以及 feature 不反向 import app。它不访问外部链接、不解析复杂 Markdown、不验证锚点或完整架构正确性。文档事实、表格与命名需人工审阅，不为了显示“全绿”扩大脚本的能力声明。
