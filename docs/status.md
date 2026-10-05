# 当前实施状态

更新时间：2026-10-05（Asia/Shanghai）。本文件是当前实施进度唯一权威；
[路线图](roadmap.md)规定顺序，[历史记录](status-history.md)保留过往批次证据。

## 当前任务：模型与 API 全功能旧源复刻

### 原生 CPU 推理与 GGUF 导入（本机验收通过，设备待验证）

当前已交付基线为main/a002770d3a5c192ebfacf7799c99ec2a78900aff；恢复时工作区干净。
本批core/chat/native建立平台推理端口、Transfer同锁资源租约、UTF-8分片、有界队列、
超时与取消等待；FFI装配packages/kiyori_platform/native的静态MNN/llama adapter。
固定旧源码revision的官方archive经SHA256，不提交上游源码或预编译库；
GPU、媒体、原生工具模板及llama思考尚未接入，选择时明确拒绝。
正式Runtime的Qwen3.5-0.8B-MNN生成5、取消、再次生成5通过（product-mnn-v2）；
真实FFI配置/会话/用量/停止/重开及本地目录1项通过（work/native-model-ffi-live-v4.log）。
Release FFI正式编译通过（ffi-build-v3），默认Flutter hook独立静态构建也通过。
公开Qwen2.5-0.5B-Instruct Q4_0 GGUF固定revision9217f5d，428730208字节，SHA256
7671c0c304e6ce5a7fc577bcb12aba01e2c155cc2efd29b2213c95b18edaf6ed与官方响应一致。
产品直连下载失败；本机网络取得后经loopback供同Transfer校验交付，正式Runtime三轮
生成/取消/再生成通过（work/native-model-product-gguf-v2.log），不称直连下载通过。
Omni类型修复后MNN真实推理通过；纯文本保持mrope，媒体标签/模板隐式路径明确拒绝。
关闭MNN内部HTTP，配置附属文件只能引用已校验清单，模板context验证后内存合入，
请求thinking不被load时覆盖。Dart hook的Windows工具发现及NDK定位问题已修；
Android OBJECT库POST_BUILD通过上游命令行选项解决；完整verify-final-v2通过：
foundation61、Rust146/fmt/Clippy、376 Dart格式/analyze、应用609（15条件跳过）、
platform7、独立FFI20（1条件跳过）与Windows引擎5。日志work/native-model-verify-final-v2.log。
原生安全/生命周期/UTF-8和大回复专项7项通过（core-special-v6）。MNN设置线程保存、
真实ChatPage富文本/用量/重开1项6秒通过（work/native-model-ui-live-final.log）。
GGUF说明卡接Windows COM和Android SAF选择器；1 MiB分片进入Rust暂存、hash与头部
校验，原子交付同Transfer，完整格式由llama加载校验，不接收UI绝对路径/URI。
相同名称/hash可重选，冲突拒绝覆盖；rename后事务前中断及completed资源缺失/篡改均对账。
导入取消和提交期间生命周期2项通过（import-dialog-final），核心对账2项通过
（import-core-final-v3）；真实428730208字节GGUF由说明卡→Windows文件I/O→FFI→目录→
ChatPage回答5→停止→SQLite重开1项49秒通过（work/native-model-gguf-ui-live-v5.log）。
并行夹具时间戳目录碰撞曾导致锁失败，加入进程内唯一序号后保留完整断言通过；
首轮构建、UI和测试失败日志保留。非流式完整正文按UTF-8分事件，每事件≤1 MiB，
总输出超过8 MiB明确失败。MNN无seed接口/负惩罚/repetition<1明确拒绝。
最后修复后的Android ARM64 Debug125.8秒和普通Windows x64 Debug100.9秒串行通过，
新增ModelFile Kotlin SAF adapter已实际编译；桥-Check五文件一致。规范许可证行尾空白后
再次串行构建Android25.4秒/Windows21.5秒，许可证正文与版权声明保留。
最终固定包artifacts/ui-preview/20261005-085819：APK118050030字节、SHA256
56F3E7D0C3B6D7D63C41F4118E48258AAF510B49DCDE8C9DECDD32C99A84F475；
Windows91文件167693731字节。92份副本SHA256、APK身份/v2签名、ZIP16K/ELF、
x64/Flutter DLL pin及七份原生依赖许可证两端内容一致审计通过。
67路径精确允许清单检查凭据/私密产物/大文件/链接/子模块/嵌套Git通过；
日志、完整模型和固定包保持忽略，按本任务授权提交普通推送，最终ref见Git与manifest。
Android SAF provider取消、同设备像素/键盘/触摸/Profile和Apple仍待验证。
契约见[ADR 0010](decisions/0010-native-model-inference.md)。

用户要求深度核对旧源、全部 UI/功能、修复缺陷、完成构建并全部提交推送。
基线 main/dcc5fbb5f5050e4a659510be652275694a74f82f，开始时工作区干净；旧源
main/6b03b03aa082803bb279db5e78773583e2d91154 只读。任务契约、行为矩阵、分期依赖、
风险和验收见[实施方案](design/model-api-replication-plan.md)。恢复后网络切片已完成本机验收，
按任务授权提交普通推送main；最终ref见Git与固定包manifest.sourceCommit，继续剩余业务。

已实现共享 HTTP client 的分页模型目录、取消/超时/脱敏、搜索/筛选全选/应用抽屉、
真实剪贴板复制、模型移除的引用原子重绑与有冲突保护的撤销、目录/宿主代次隔离，
以及配置级 RPM/并发排队，保存新限制唤醒已有等待者。Chat/Responses/Messages/Gemini
文本、原生/XML echo随机结果续答与启用媒体探测接同一ChatRun；读取当前流式/思考偏好。
续答每次HTTP独立轮换，目录共用同一持久游标；旧官方特殊目录与代理前缀/认证已核对。
Gemini默认models根重复拼接、Messages厂商Bearer、XML换行被误判均已修。
配置保存成功后不再读取存储更新限流，避免提交后错误误报；Chat原生工具续答保留有界
reasoning_content，不进入正文或历史。Sol6.1自动思考参数增加五档映射，关闭时明确拒绝，
显式模型参数仍优先；官方合同及代理兼容的区别见实施方案。
生成桥已更新，不手改生成输出。

恢复阶段Rust107项通过（work/model-api-limits-save-final.log），Clippy通过（resume-clippy-v2）。
目录/真实FFI SQLite DPAPI与页面18项通过（work/model-api-resume-ui-v1.log），
四协议×流式/非流式工具调用页面8项通过（work/model-api-xml-ui.log）。桥-Check五文件一致，
foundation58文件通过。完整verify收尾v2通过：Rust107/fmt/Clippy、363 Dart格式/analyze、
应用587（13条件跳过：11捕获、2真实端点）、platform5、独立FFI18及Windows引擎5，
日志work/model-api-verify-final-v2.log；桥-Check五文件一致。
Android ARM64 Debug（141.8s）与普通Windows x64 Debug入口（21.4s）串行构建通过。
固定包artifacts/ui-preview/20261005-024348：APK117978824字节、SHA256
20AEE66A1D963A7EC6FDD8C81B076F8D88BF9D5928E1CECE727CAB5E97D1A84A；
Windows84文件159293320字节，85份副本哈希/APK身份、v2签名、ZIP16K/ELF和x64/Flutter DLL pin通过。
54路径精确清单审计通过，日志/安装包保持忽略；旧源仍只读干净。

2026-10-05用户授权两个指定供应商和模型，测试凭据只经隐藏输入进入进程内存，正式UI
测试另使用隔离临时DPAPI密文并在结束删除；合成对话/固定素材，未发送用户历史或源码。
DeepSeek/deepseek-flash和指定中转/gpt-6.1-sol：模型目录、Chat/Responses/Messages×
流式/非流式聊天/system/原生工具及图像通过。中转XML全组合通过；DeepSeek首轮XML
未验证保留，格式兼容修复后六组合通过（work/live-DEEPSEEK-20261005-020704.json）。
DeepSeek Chat音频/video及Responses音频服务返回422；中转Chat音频/video没有正确识别素材，
Responses音频返回400；两端Responses video和Messages音频/video为本地协议拒绝。
不能称这些媒体已真实可用。首轮完整结果在
work/live-DEEPSEEK.json及work/live-ROUTED.json，日志仅脱敏结果；套件成功只代表执行完矩阵。
DeepSeek正式配置控件→DPAPI→重开→ChatPage两轮→SQLite→重开通过（live-ui-DEEPSEEK-20261005-020704.log）；
中转正式UI同样通过（work/live-ui-ROUTED-20261005-021015.log）。DeepSeek思考开启的
三档有效程度×三协议×流式/非流式聊天/system/tool共54项通过（work/live-DEEPSEEK-20261005-022434.json）；
Sol6.1五档Responses×流式/非流式聊天/system/tool共30项通过（work/live-ROUTED-20261005-022716.json）。
最终捕获19项通过、20张PNG在work/model-api-review-final，已审阅手机明暗、320双倍字、
横屏双倍字与结果卡；矮屏底部操作滚动可达。首轮收尾verify与供应商测试同时使用原生DLL
出现文件占用，相关进程退出后串行重验；保留失败日志，未降断言。
本地CPU文字推理与前台共享下载资源已接入；GPU/媒体/工具模板、OS后台下载和扩展提供方仍有实际缺口，
实施依赖与完成信号已写入方案，不能把配置保存或网络测试称作全功能。
同设备并排像素、键盘/触摸/Profile与Apple为verification_pending；当前授权不含设备操作。

### 自动总结增量（本机验收通过，设备待验证）

基线为已交付190524d，按当前任务授权提交普通推送；最终ref见Git及固定包manifest。
core/conversations_summary接入独立summary
功能绑定/安全凭据、计数与比例触发、旧中文提示词/自定义规则/上一摘要、独立输入预算与
同worker取消。schema15新增请求投影缓存和独立总结usage，原消息保持完整；摘要提交前
复核配置/角色/偏好/绑定及running，迟到结果拒绝。编辑/删除/回复版本、重发覆盖与清空
使摘要失效，分支只复制其前缀内缓存。累计含总结用量，最近聊天样本不被覆盖。
契约见[ADR 0008](decisions/0008-conversation-summary-projection.md)。

Rust122、Clippy通过（work/model-summary-regen-green.log、model-summary-regen-clippy.log）；
含独立budget、清空/观测、同配置单并发和重新生成边界。重新生成回归先复现最后user被
摘要替代，再验证保留问题、缓存跨界弃用、有效旧缓存、关闭总结、后续消息及旧回复版本。
正式FFI/DPAPI/SQLite/ChatPage与上下文
联合10项通过（work/model-summary-ui-v8.log），含第二轮独立总结、原文/摘要重开与编辑失效。
初轮新测试缺少extension导入、首次加载尚未结束的发送等待和用量夹具缺choices已修；
全部失败日志保留，没有降低断言。生成桥-Check五文件一致。首轮完整verify-v1中Rust121、
应用与platform5通过，独立FFI服务器清理回调滞后导致计数断言偶发失败；夹具显式等待
响应关闭，保留peak=2/active=0断言。最终完整verify-v2通过：Rust122/fmt/Clippy、
363 Dart格式/analyze、应用588（13条件跳过）、platform5、独立FFI18、Windows引擎5；
日志work/model-summary-verify-final-v2.log，桥-Check五文件一致。
Android ARM64 Debug101.5s、普通Windows x64 Debug21.2s串行构建通过；
固定包artifacts/ui-preview/20261005-040903：APK117983513字节、SHA256
8DD11CC674FD2DABE56C17EA587D1F6651E8E5367E2D701771C9035A49218F2D，
Windows84文件159366208字节；85份副本哈希/APK身份、v2签名、ZIP16K/ELF、
x64和Flutter DLL pin审计通过。30路径精确清单审计通过，日志和产物保持忽略。
两端Chat/Responses/Messages×流式/非流式共12条正式UI独立总结、两轮口令与重开全部通过：
DeepSeek日志work/live-ui-DEEPSEEK-summary-20261005-033621-*；
中转work/live-ui-ROUTED-summary-20261005-033024-*及033430-messages-*。
DeepSeek Responses流式首轮通过（work/live-ui-DEEPSEEK-summary-20261005-032448.log）；
首轮512输出额度不足，独立总结改4096后完整通过。中转Chat第一轮none参数HTTP400，
改low/4096及对应协议字段后全部链路通过；不泛化代理兼容为官方能力。
设备/Apple仍待验证；手动插入摘要消息属于后续聊天入口，未以自动总结冒充已完成。

### 本地模型下载增量（本机验收通过，设备待验证）

自动总结ca31065333c3e35f33a3acf64d9ee82a4e4f44db已提交普通推送，main/origin一致。
新增core/files、downloads、local_models，schema16/17同库保存资源、冻结清单与文件进度；
目录/单执行者/Range实体/全文件SHA256/原子交付、停止与重开恢复已接正式本地模型页。
最终Rust131/fmt/Clippy、产品analyze、应用589（13条件跳过）、platform5、独立FFI20及
Windows引擎5通过（work/model-download-verify-v3.log），桥-Check五文件一致。
下载专项7项、市场/清单2项通过；正式UI使用合成目录与6字节文件，暂停后Range/If-Range
续传、完成重开、确认删除及刷新失败保留旧列表通过（work/model-download-capture-v3.log）。
11项布局/业务回归通过，最终66张PNG在work/model-download-review-v3，已审阅320暗色
双倍字暂停态和横屏失败态；按钮沿主题继承字体，继续/重试按旧源11sp，修正独立样式方框。
独立FFI无人消费/暂停订阅时Runtime关闭2项通过（work/model-download-ffi-close-v1.log）。
首轮FFI恢复入口同步线程没有Tokio reactor，改async后重验；widget虚拟循环需结算清理
后再真实重开，独立Dart测试证明关闭无死锁。所有失败日志保留，未降低断言。
真实公共市场130项，Qwen3.5-0.8B-MNN共12文件547649117字节完整下载、暂停后续传、
逐文件大小/SHA256、config读取与SQLite重开通过（work/model-download-live-v2.log）。
首轮CDN403保留；下载增加User-Agent/no-cache避免过期签名Location缓存，HTTP失败明确
区分断点冲突。终态落库错误现经事件Err可观察；Range/实体/编码/大小/哈希失败记录
restart_required，只有用户重试重置未验证文件，正常中断仍续传，已验证前缀保留。
schema16→17迁移保留冻结任务。verify-v2因根分析扫描work内上游旧Dart测试失败，按忽略
目录契约排除work/artifacts后产品分析和v3完整验证通过；失败日志保留。
Android ARM64 Debug最终24.2s与Windows x64 Debug20.1s串行构建通过。最终固定包
artifacts/ui-preview/20261005-053253：APK118019774字节，SHA256
B01FFA06119C53FBBD1F6D64E8527438F73AF9DF632463A82C66ED55DBFB441D；Windows84文件
160085888字节。85副本哈希、APK身份/v2签名、ZIP16K/ELF、x64及Flutter DLL pin通过。
36路径精确清单审计通过，按本任务授权提交普通推送；最终ref见Git与manifest.sourceCommit。

本地推理前置spike仅在work：官方MNN ea44a3e与llama.cpp885c5bb Release库实际编译通过。
已下载的Qwen3.5-0.8B-MNN真实CPU加载、加载前4线程/关闭思考、逐token生成得到5，
status1/input31/output2；停止生成后reset并再次得到5，析构成功，日志native-model-spike/
smoke-reuse-run.log。此独立执行不是产品adapter验收，正式native句柄/流式/取消及扩展仍有缺口。
OS后台下载、同设备像素/键盘/触摸/Profile与Apple仍待验证；未安装或操作设备。

### 手动插入总结增量（本机验收通过，设备待验证）

基线main/483e7fd，开始时干净。core/conversations_manual_summary使用独立SUMMARY绑定、
同请求编译/队列/安全短lease/会话OS锁与ChatRun。用户边界排除该user，AI边界包含该回复；
完整stop后才事务插入可见summary、保留所有原消息ID/正文/版本，后续请求从有效检查点继续。
取消/失败/空输出/不完整终态无半条消息；冻结原文、边界、配置/角色/偏好复核拒绝迟到。
编辑/删除原文和回复版本使后续检查点失效但全文可见；编辑摘要重新确认，删除恢复前一
检查点/原文，分支保留Run身份。schema18的kind区分独立摘要累计和最近聊天样本。
ChatPage菜单、旧窄摘要条、详情滚动/编辑/二次确认删除接实际业务，草稿/引用保留；
按会话执行、停止/切换/关闭继续复用原owner。契约见ADR0008。

Rust137项通过（work/manual-summary-core-full-v3.log）；6项手动专项含存储提交回滚、
schema17迁移、批量删除失效、跨Runtime锁/取消/迟到及边界。正式FFI/DPAPI/SQLite页面
与旧自动总结联合12项通过（work/manual-summary-ui-v4.log），取消/切会话不会污染新会话。
27项页面与捕获通过（work/manual-summary-ui-v3.log），39 PNG在work/manual-summary-review-v3；
已审阅320暗色双倍字和844横屏双倍字详情，中文/滚动/全部操作可达。
首轮夹具revision/偏好未实际改变、确认按钮文案、旧schema夹具列集与期望版本问题已修，
失败日志保留。最终完整verify-v2通过：Rust137/fmt/Clippy、368 Dart格式/analyze、
应用609（13条件跳过）、platform5、独立FFI20、Windows引擎5；日志
work/manual-summary-verify-v2.log。首轮完整verify-v1仅新捕获测试两处花括号lint失败，
修正后全量重验；未放宽检查。桥-Check五文件一致（work/manual-summary-bridge-check.log）。
Android ARM64 Debug99.3s、Windows x64 Debug21.0s串行最终构建通过；固定包
artifacts/ui-preview/20261005-061902：APK118028209字节，SHA256
9F30941E47A8F3002B684997C22775A3E9316690B122E214C59AD74A78176FC7；Windows84文件
160233368字节。85副本哈希、APK身份/v2签名、ZIP16K/ELF、x64/Flutter DLL pin通过。
28路径精确允许清单审计通过；按本任务授权提交普通推送，最终ref见Git及manifest。
未重复已完成真实API矩阵和完整模型下载；本增量供应商手动入口与设备/Apple独立待验证。
产品native MNN/llama adapter、TOOLPKG和OS后台移交仍有实现缺口，整体任务部分完成。

## 上一批：十一组实机截图UI与交互复刻

用户提供D:/03_Default/图片/截图的22张新旧实机JPEG，并授权本轮全部提交推送；
基线main/962bc18bf9b6e78441851c152d7355c47eef9109，初始工作区干净。旧源码main/
6b03b03aa082803bb279db5e78773583e2d91154只读干净。用户选择设备手动验收。
逐屏结论与能力边界见[截图复刻审查](design/screenshot-parity-review.md)。

已修正AI标题前缀、默认品牌头像、Prompt蓝色/横向边距、输入密度、角色面板头部、
思考/off与程度条件、缩放开关和Max文案、历史头部/金色目录/分组/手势提示、统计选项，
以及负一屏数据卡前16间距。AI浏览器/文件回调接到既有页面，Back恢复原pager和草稿。
思考程度释放时保存最终值；手势提示隐藏经既有Rust偏好revision事务持久化，旧JSON兼容，
schema/依赖不变。FFI生成已执行，不手改生成文件。

定向19项通过（work/screenshot-parity-targeted-final.log），最终捕获4项通过
（work/screenshot-parity-capture-final.log），134张布局PNG在work/screenshot-parity-capture-final。
完整tools/verify.ps1 -WindowsIntegration通过（work/screenshot-parity-verify-delivery.log）：
Rust81/fmt/Clippy、359 Dart格式/analyze、应用571（12跳过：11项可选捕获及1项真实供应商）、
platform5、FFI18及Windows引擎5。连续拖动回归验证预览不改变revision，释放仅保存一次最终值。
桥接-Check核对5个生成文件一致（work/screenshot-parity-bridge-check.log）。
首次数量后缀/标题断言仍定位旧文字及4项花括号lint均已修正，保留失败日志，未降低业务断言。

Android ARM64 Debug串行构建53.1s通过（work/screenshot-parity-android.log），
Windows引擎测试后重建普通产品入口x64 Debug 11.2s通过（work/screenshot-parity-windows-delivery.log）。
固定包artifacts/ui-preview/20261004-232210：APK117940874字节，SHA256
2BEC475959782CE40CC6197AD6720724994B21B8F7AA1419381090A4F9AB061C；Windows84文件158624616字节。
85副本哈希、APK身份/ARM64/v2签名/ZIP16K与4个原生库ELF、Windows x64/Flutter DLL pin通过，
包含libkiyori_ffi.so与kiyori_ffi.dll；最终Dart kernel时间/哈希已核对。
本轮28文件精确允许清单经凭据形态/私密配置/产物/大文件/链接/子模块审计，按授权普通提交推送main，
最终ref见Git和固定包manifest.sourceCommit；过程日志、截图与安装包保持忽略。

浏览器仍为空壳，天气、文件扫描/资源访问、设备附件、语音、工具执行及动态思考引导
尚未完成；不能宣称全部功能或逐像素一致。真实供应商、同设备并排/键盘/触摸/Profile
与Apple仍为verification_pending，不操作设备。截图重复前缀缺协议证据，合成完整流
保持原文且Markdown正常，不做猜测去重。

## 上一批：AI对话精确复刻与即时点击

### 顶栏多任务与CLASSIC附件增量

继续原目标，基线main/9803bec800b3c2f201ec7be06e34ad185d206107，起始工作区干净。
按旧ChatHeader补真实并行运行数胶囊、展开背景及显示/隐藏语义；统计入口补可实际触发的
无障碍动作。CLASSIC附件恢复输入行下方内联两行八项，展开/收起、颜色、尺寸及文案沿旧源；
AGENT保留右下弹卡。包空态移除旧版不存在的搜索框。记忆选择由常驻宿主持有，展开选择器
立即收起面板；成功发送、切换会话、换owner或切换输入风格均清理相应瞬态。
专项8项通过，work/chat-header-ui-final.log；4张捕获在work/chat-header-capture-final，
覆盖真实双请求→停止→完成、面板关闭、语义点击、包取消、记忆选择、旧会话结果隔离、
320暗色/键盘及AGENT形式。初轮测试未等路由语义树恢复、语义句柄释放及lint问题均保留日志，
修复测试时序/释放并保留实际语义动作断言。完整tools/verify.ps1 -WindowsIntegration通过，
work/chat-header-verify.log记录Rust80/fmt/Clippy、358 Dart格式/analyze、应用569（11跳过）、
platform5、FFI18及Windows引擎5。Android ARM64 Debug（23.0s）及普通Windows产品入口
x64 Debug（18.5s）串行构建通过，日志work/chat-header-android.log、chat-header-windows.log。
固定包artifacts/ui-preview/20261004-155853：APK117931727字节，SHA256
1FDC4D3BAB4AEA442344400ECCA278686670BF8712B71E149E0EA10A836F9053；Windows84文件158598504字节。
85副本哈希、APK身份/ARM64/v2签名/ZIP16K/ELF及Windows x64/Flutter DLL pin通过；
原生runner与Rust DLL复用，最终Dart kernel时间/哈希已核对。9文件精确清单通过，按本轮授权
提交普通推送main，最终ref见Git和manifest.sourceCommit；过程日志/安装包保持忽略。
本批不更改Rust API/schema/依赖；设备附件、语音/悬浮、工具执行、复杂消息渲染继续，
同设备并排与Profile仍为verification_pending，不宣称全功能或像素验收完成。

### 请求内观测与用量容错增量

继续原目标，基线main/9e7bde8c6ce599adfbdfc3f8f41df9ecb92a64d9，起始工作区干净。
对照旧GenerationSpeedTracker、TokenStatisticsDelegate、ChatUtils/TokenCacheManager，
接入同Runtime的每会话最新请求tracker：核心Instant计时、逐条UTF-16估算、首输出等待、
至少两分片的有效速度、完成供应商输出及最近样本；分支/重开不恢复历史样本，取消/失败清除。
顶栏圆环与抽屉使用真实上下文估算和当前模型上限；明暗语义色及阈值、百分比精度沿旧源。
可选usage缺失/错类型/负值/越界只跳过该观察，保持有效回复；仅输入样本不计完整覆盖。
不改schema/依赖，不操作设备或供应商端点。完整tools/verify.ps1 -WindowsIntegration通过，
work/chat-observation-verify-v2.log记录Rust80/fmt/Clippy、355 Dart格式/analyze、应用565
（11条件跳过）、platform5、独立FFI18及Windows引擎5；桥生成-Check五输出一致。
观测/统计UI专项7项及最终捕获专项5项通过，最终7张PNG在work/chat-observation-capture-final，
已检查速度卡及统计代表图；包含取消、未知输出、非流式、两分片、UTF16与重开边界回归。
首轮发现探测collector适配遗漏、测试Responses流缺delta、语义标签合并、惰性卡片未滚动，
均按实际契约修复，最终完整验证首轮新测试花括号lint也已修复；保留失败日志，未降低断言。
最终Android ARM64 Debug（70.0s）、普通Windows x64 Debug产品入口（19.4s）串行构建通过，
日志work/chat-observation-android.log、chat-observation-windows.log。固定包
artifacts/ui-preview/20261004-152316：APK117922609字节，SHA256
5D23B954FC66631CC3B3C76EBBB74EEF8AB41547F9155047E008780AD3E687E0；Windows84文件158583216字节。
85副本哈希、APK身份/ARM64/v2签名/ZIP16K/ELF及Windows x64/Flutter DLL pin通过；
原生runner增量复用，最新Dart kernel与Rust DLL均核对。25文件精确清单审计通过，
按本轮授权提交并普通推送main，最终提交/ref见Git与固定包manifest.sourceCommit。
源码/测试/正式文档入库，固定包与过程证据保持忽略；旧源6b03b03仍只读干净。
本批仍不等于全部AI功能/像素完成：并行运行历史数量胶囊、附件/语音/悬浮、工具执行及
复杂消息渲染继续；同设备并排、实际键盘触摸/Profile与Apple仍待验证。

### 已交付的供应商用量细分

继续原目标，当前统计增量基线main/fb52ede229fafc0f5ffa097fa1c8c1db51bfff31，工作区干净。
按旧ProviderUsageSnapshot、OpenAIResponsesProvider.parseUsageCounts与统计抽屉语义，
接入缓存读取/写入、推理细分、有效缓存分母、未分类输入和覆盖率。schema14新增三个可空列，
旧历史保持未知，同Run重复usage替换，分支复制保留；累计排除仍在运行的请求。
消息信息读取真实缓存字段。未提供、明确0和无效缓存分桶分别处理；异常桶不丢有效输入/输出，
整数范围校验及饱和聚合防止回绕/SQLite求和溢出。上下文估算和进程内速度仍待接入。
Rust76项通过，generate-bridge.ps1 -Check五输出一致；真实FFI/两轮/分支/重开/界面专项5项
通过，work/chat-usage-ui-v2.log；截图work/chat-usage-capture-v2确认总输入10000、有效分母1000、
读取600时60.0%，最近未报告时为未知。完整tools/verify.ps1 -WindowsIntegration通过，
work/chat-usage-verify-v2.log记录Rust76、355 Dart格式/analyze、应用563（11条件跳过）、
platform5、独立FFI18及Windows引擎5。之后发现UI总量直接相加的极值回绕，按旧Long
饱和加法修复；新增真实请求/SQLite/界面回归先失败后通过，日志chat-usage-overflow-before
与after，最终专项2项通过；修改后格式检查和flutter analyze通过。
最终Android ARM64 Debug（74.5s）、普通Windows产品入口x64 Debug（19.3s）串行构建通过，
日志work/chat-usage-android.log、chat-usage-windows.log。固定包artifacts/ui-preview/20261004-144535，
APK117917248字节，SHA256 67D89B41260440D009845FBCD1516E3224FDBE228B4F7EE7C0DC2D3FD280F748；
Windows84文件158547304字节。85副本哈希、APK身份/ARM64/v2签名/ZIP16K/ELF及
Windows x64/Flutter DLL pin通过，最新Dart kernel已核对；原生runner增量复用。
本批21文件精确清单交付，未升级依赖；按当前授权提交并普通推送main，最终ref以Git和
固定包manifest的sourceCommit为准。源码、测试及正式文档进入Git，固定包与过程证据不入库。
仍需修复最近请求从历史Run恢复与旧进程内样本生命周期的差异，并接上下文估算/速度；
基础usage缺少输入或输出仍按协议错误处理，尚未对齐旧版不完整样本语义。
不据本批细分接入宣称全部统计或聊天复刻完成；设备并排/触摸/Profile仍待验证。
回滚须恢复schema14升级前一致数据库与匹配二进制，不修改user_version或直接降级开库。

### 已交付的界面与点击修复

本轮用户恢复开发并授权最终提交推送，基线main/40568a06d13009a65da6269961efb7f03b233be6，
工作区干净；旧Kiyori-Android/6b03b03保持只读干净。沿聊天交互对照继续，未操作设备、
指定供应商或远端CI。目标是顶部四入口、输入边缘/弹窗、消息渲染与软件滑动后点击。

已修历史和角色面板/遮罩跨顶栏：以状态栏+64.5为边界，历史仅按自身宽度滑入，
角色卡在内容区再向下60；回退和实体释放沿ChatModalSession。输入默认亮色按旧五层
6px外扩阴影绘制、暗色按1px顶部线及2px辉光，暗底为surface/onSurface的8%混色。
模型/设置/附件使用旧surfaceContainerHigh、3px阴影，说明改为220宽右下卡。
统计恢复完整中文说明、五卡结构、窄屏/大字纵排、数字格式及完整复制摘要；未知事实
仍显示未提供，不伪造缓存/推理/上下文指标。角色语义色、消息标题贴右、复制预览高度、
消息信息字段及输出耗时含义已核对：消息durationMs已是输出耗时，不能再减等待。
已有目录先显示再刷新，不等待整套目录读取。面板和遮罩响应打开期间安全区变化；
设置二级区域恢复旧标题冒号、语义色、40高权限胶囊、管理配置顺序与记忆保存文案。

点击根因由本机Flutter源码与回归确认：ScrollPosition在惯性/驱动activity中屏蔽子树。
KiyoriScrollBehavior在滚动通知时解除该屏蔽，保留arena/hold/slop/物理模拟；无点击重放。
5项覆盖惯性首击、驱动首击、手指释放首帧前、翻页未停稳首击、Android路由入场点击；
最终联合生命周期/动态安全区/消息时长回归9项通过，work/chat-final-regression.log。
最终59张捕获通过并审阅代表图，work/chat-precision-capture-v4；覆盖五视口与设置二级、
模型和编辑弹层。完整tools/verify.ps1 -WindowsIntegration通过，证据
work/chat-precision-verify-v3.log：56文档/4脚本、Rust73/fmt/Clippy、354 Dart格式/
analyze、Flutter562（11条件跳过）、platform5、独立FFI18及Windows引擎5。
首轮惯性失败、测试花括号lint、动态inset夹具未指定DPR的失败日志均保留，修正后通过；
没有降低断言。Android ARM64 Debug（51.5s）和普通Windows x64 Debug（19.8s）
串行构建通过，日志work/chat-precision-android.log与chat-precision-windows.log。
固定包artifacts/ui-preview/20261004-140954，保留之前预览包；APK117919777字节，SHA256
627BB3B91AE8CF5ED5C275E89D49010580A1A868052B98C625466D5D94350C4B。
Windows84文件158538192字节；85副本哈希、APK身份/ARM64/v2签名/ZIP16K/ELF及
Windows x64/Flutter DLL pin通过。原生runner/DLL增量复用，当前Dart由kernel核对。
27源码/测试/文档精确允许清单通过，无敏感模式/链接/gitlink/异常大文件；未改依赖、
Rust公共API、桥或schema。按本轮授权提交并普通推送main，最终提交/ref以Git和固定包
manifest的sourceCommit为准，产物及证据不进入Git。

这不是整个AI全功能或像素验收：附件设备读取、语音/悬浮窗、工具插件执行、群组运行、
外部Markdown图片链接、数学/复杂XML渲染、历史角色文件夹作用域、上下文估算与速度等
仍需继续；Android旧新并排、实际键盘触摸/Profile与Apple仍verification_pending。

## 上一批预览交付记录

本轮从已交付766eb0c承接，重新逐项核对[聊天交互对照](design/chat-replication-checklist.md)。
用户于2026-10-04要求适时停止开发并构建、提交、推送以手动安装APK检查。
当前按该要求冻结新增功能，已完成阶段预览包构建与本机验证；全清单复刻仍未完成，
交付后暂停开发等待用户手动安装反馈。
本轮已修API协议缺少summary造成右侧值、模型安全操作同owner锁竞争及SafeArea外警告；
models定向15项通过（work/parity-models-v5.log），含32px状态栏及真实清理失败/恢复；
实际清理失败保留retired并可重试，锁忙不误报。全屏草稿、停止按钮、左侧历史及正文搜索、
长按复制、消息片段编辑与失败保留、300/420模型卡及真实MAX保存、模态路由租期已实施；
parity-editor-v1/popup-v1各9项、parity-lifecycle-v1十二项通过。
统计区分未报告与报告0，保存首次正文时刻；schema11加入历史文件夹、置顶/锁定/排序与聊天偏好。
完整Rust73项通过（work/parity-verify-v3.log），含旧版本迁移、角色切换事务和思考参数边界；
schema12新增运行角色名称快照，schema13保存角色ID与回复版本；旧数据未知来源保持空值。
历史按角色/文件夹分组、折叠、重命名及失败草稿保留已接入；组合回归11项通过
（work/parity-history-v2.log）。角色选择默认不改写历史归属，自动切换由Rust同一事务完成。
流式Markdown后台解析与持续delta节流通过；主题模式保存和BUBBLE/CLASSIC基本投影已接入，
模式交互回归已通过；最终截图套件20项通过，13张PNG位于work/parity-capture-final，
明暗、320大字/键盘、模型弹层、角色、统计、编辑及历史代表图已人工审阅。
后续增量已实施CLASSIC设置/模型嵌套与回复预览、历史拖拽/左右滑动与角色排序隔离、
多选Back及批量删除事务、非流式真实请求、Markdown保守增量与终态状态保留。
schema13新增消息回复版本，单条再生成保留后续消息和原回复，分支复制独立版本；
work/parity-actions-rust-v2十二项、parity-regression-v5十项、parity-history-v4六项通过。
parity-incremental-v3五项通过，含每个流前缀与正式Markdown完整解析对照；HTML边界差异已修。
记忆文件夹选择/预览/移除及非流式正式请求扩展三项通过（work/parity-memory-nonstream-v3.log），
工具发送明确能力边界并保留草稿。
再生成按运行中保存的角色ID准备配置/凭据，旧数据缺少身份时明确拒绝，不猜测当前角色。
其余附件布局、历史文件夹作用域、消息分享与完整旧版细节仍待继续核对，不能宣称清单全部复刻。
本轮完整tools/verify.ps1 -WindowsIntegration已通过（work/parity-verify-v3.log）：
56文档/4脚本、Rust73/fmt/Clippy、345 Dart格式/analyze、Flutter554（11条件跳过）、
platform5、独立FFI18和Windows引擎5；含正式页面/DPAPI/SQLite本地两轮及历史重开。
初轮Clippy写法和两处Dart格式问题已修，失败日志保留；未降低检查标准。
按用户收尾要求本轮不追加供应商请求，不引用上轮请求当本轮证明。
generate-bridge.ps1 -Check五个输出一致。Android ARM64 Debug（59.4s）和普通产品入口
Windows x64 Debug（11.5s）已串行完成，日志parity-android-final / parity-windows-final。
固定artifacts/ui-preview/20261004-021908，旧20261003-223817保留：
APK117892490字节，SHA256 51CA40FDE39E99A43D29003DDBF066BE3A0ADB82F0DB74C10449C1BC5542033B；
Windows84文件158471576字节；Rust DLL10374656字节，SHA256
0C21FB550028A04E4A39DFDB0181AA5793BD6273B95ABEB6D798A56955D200C1。
85副本哈希、APK身份/ARM64/v2签名/ZIP16K/ELF及Windows x64/Flutter DLL pin通过；
Windows原生runner增量复用，最新Dart由kernel hash与时间核对，manifest记录完整文件哈希。
本批69个源码/测试/文档按精确允许清单审计，无敏感模式、异常大文件或链接/gitlink，
固定包/日志/测试临时数据不进入Git；提交后普通推送main，最终ref以Git及manifest为准。
Android安装/触摸/键盘/安全存储实机、Profile、Apple和本轮指定供应商保持待验证；
SQLite已迁移到schema13，回滚需恢复对应二进制与升级前一致数据，不能直接降级覆盖新库。
以下各批记录仅为历史实现证据，不代表本轮已达到相关UI/交互复刻验收。

当前收敛切片为“配置API并正常基本文字对话”，基线main/21044e8，承接未提交密钥轮换与
会话核心。历史批次schema9、正式ChatPage发送/停止、历史、新建/切换/重命名/删除、基础消息菜单、
角色与模型选择、安全短lease和多轮持久化已实现并完成上轮交付；不是本轮最终验证证据。
core/conversations复用Runtime/SQLite，先保存后投影、OS锁恢复中断、不自动重试；重发先校验
配置与凭据，再事务替换历史。流式局部32ms合并，上翻停止跟随。默认UI按旧CURSOR/AGENT。

work/conversation-verify-v2完整通过：55文档/4脚本、Rust65及fmt/Clippy、319 Dart格式/analyze、
Flutter529（11跳过，其中10捕获/1需凭据）、platform5、独立FFI18、Windows引擎4。
随后补模型选择/消息编辑/重命名实际菜单回归，conversation-menu-final七项通过；
最终七PNG在work/conversation-capture-final，明暗/长文/历史/320大字键盘/横屏/桌面均已审阅。
角色条统计位置已修，弹窗controller随组件释放。最终analyze及文档核验见交付日志。
Windows集成新增真实打包ChatPage/DPAPI/FFI/两轮/重开用例，conversation-windows-integration-v5五项通过。
初轮原生IME与测试文本注入竞争、回调expect与pump冲突均为夹具问题，已按Flutter本机源码
显式注册本用例模拟文本通道并保留断言；不声称物理键盘验收。失败日志保留。
真实供应商conversation-live-v3通过：正式API密钥控件输入→
Windows DPAPI保存→重开→ChatPage两轮发送→Rust/SQLite→重开，均KIYORI_OK/completed，4条消息恢复。
只发两次合成请求；没有上传仓库或日志，凭据未写源码/日志/截图，临时加密测试数据已清理。
最初夹具编码/入场动画及跨假时钟等待失败保留；控制器收尾提前解除busy已修。
新发现请求参数text误作string处理已修且新增回归通过，重发先删后验证改为同事务并经真实FFI验证。

最终Android ARM64 Debug（55.8s）与Windows普通产品入口Debug（13.8s）串行构建通过，
日志conversation-android.log / conversation-windows.log。固定artifacts/ui-preview/20261003-223817：
APK117724820字节，SHA256 B404E08AF9C5FE5810DCC5DBAAF08C6FBB6C80EBAEE229CE63247D5F7312ACD2；
Windows84文件157829664字节；Rust DLL10179072字节，SHA256
8FB32B2BE06734332D4E19384BA3DBE4A646A5F2D9971BCFF90713616F274D64。
85副本哈希、APK身份/ARM64/v2签名/ZIP16K/ELF及Windows x64/Flutter DLL pin通过，
证据work/chat-artifacts-20261003-223817。Windows原生EXE增量复用，最新Dart由kernel哈希确认。
572文件/315人工Dart交付树审计无warning、大文件或相对导入环；授权凭据精确扫描无残留。
本批按精确清单提交普通推送main，提交与远端状态以Git及固定包manifest的sourceCommit为准。
设备安装/触摸/Profile/Android安全存储实机、Apple、其它供应商未验证；历史文件夹/置顶/
批量导入导出、回复变体、修订审计、工具/媒体/复杂群组属于后续范围，不宣称整个AI阶段完成。
当前恢复日记7bfbbfa8-2c43-4cbc-a19d-26c39690a2f8，独立本机记录，未改旧聊天Goal。

上下文与凭据恢复批次已交付687fb21d527d4cbbe28faf309a7dd6b6c983cf3f，普通推送后0/0干净。
密钥池文本导入导出本机实现与构建验证通过：Windows COM系统选择器、Android SAF单次URI读写，无明文缓存；
1 MiB与严格UTF-8检查、取消/脱敏错误、全池导出、逐行追加和大池清空确认已经实现。
导入未完成时返回/切换的flush等待，宿主退出忽略迟到结果；iOS明确返回不支持，尚未实现。
完整work/text-exchange-verify-v1.log通过54文档/4脚本、Rust45/fmt/Clippy、307 Dart格式/
analyze、Flutter518（10捕获跳过）、platform5、FFI13。整行按钮按旧源校正后定向15项通过，
work/text-exchange-ui-final.log；暗色大池截图work/text-exchange-capture-v2已审阅，最终analyze通过。
Android31.1s、Windows19.9s串行构建通过，native系统选择器/Android provider仍待实际交互验收。
未改依赖/Rust API/桥，Windows引擎最近证据仍是前一批4项，本批平台真实文件I/O单独验证。
固定artifacts/ui-preview/20261003-144455：APK117610606字节，SHA256
BE5A2F571483DE805F161579F033188ECFF23A4A98E52CD788C64235DE43F0ED；Windows84文件153949256字节。
85份复制hash、APK身份/ARM64/v2/ZIP16K/ELF、Windows x64/Flutter DLL pin通过，549文件审计无发现。
已精确提交并普通推送e859ad746bc39864357f194106ed33bd1656fafb，0/0干净；历史产物保留。
业务首轮假时钟等待停滞，仅终止该测试子进程；修测试推进原生事件及帧后原断言通过。
模型连接/轮换执行与会话业务继续推进，总Goal保持active。

共享Chat请求核心与单密钥模型测试本机验收通过，正式契约见ADR0007。Runtime单client，
无自动重试/重定向，HTTPS直连与固定Mozilla根；loopback可HTTP，其他协议明确不支持。
Rust持有SSE解析、背压、取消/超时、错误和探测规则；模型页面flush后测试聊天与system随机口令，
按稳定配置/执行代次隔离，工具/媒体未验证。取消等待worker释放，未订阅与关闭无死锁。
Android主manifest补INTERNET，未操作设备/供应商/私人密钥，代理与用户CA不支持。

work/chat-verify-v2.log通过55文档/4脚本、Rust52/fmt/Clippy、311 Dart格式/analyze、
Flutter519（10捕获跳过）、platform5、FFI16、Windows引擎4。v1仅新测试花括号lint失败已修。
FFI初轮fixture未设UTF8导致中文无法写出，修后3项通过；UI初轮按错误工具模式查标签，
按真实配置修正后通过。探测判定后移至Rust，完整verify覆盖最终实现，生成v4的类型推断
失败显式标注Option<String>后v5通过。所有失败日志保留。
work/chat-capture-final两套件通过、7PNG，模型页按钮和暗色结果卡已审阅；bridge-final五文件一致。
Android141.1s、普通Windows40.7s串行Debug通过，未声称设备TLS、触摸/Profile或Apple验收。

固定artifacts/ui-preview/20261003-154337：APK117648075字节，SHA256
8232990C911F3BC875AC72C4B2E7D307B5F66D1DE238E349A1B6EA1B2B965C58；Windows84文件157121400字节。
Rust DLL9684480字节，SHA256 86D1B5661616709E799C73AC955F8A548403ECBC4A935CCFA054FBC701E26311。
85副本hash、APK身份/网络权限/ARM64/v2/ZIP16K/ELF、Windows x64/Flutter DLL pin通过；
ARM64 Rust库8733696字节，新增网络实现已进入包。558文件审计无发现。已精确提交并普通推送
b1125f47162d3ba3d07220c77be9cf4292e24ff2，恢复时fetch核对0/0；旧源HEAD与干净状态未变。

密钥池可用性测试扩展本机验收通过：Rust复用共享请求与5并发，enabled+UNTESTED筛选，
逐ID加密保存结果、暂停等待worker与在途保存、清标记、输入失效和宿主移除取消。
安全payload v3兼容v1/v2读取但旧二进制不能读v3，回滚边界见ADR0006；SQLite仍schema7。
work/pool-ffi-v1.log两项真实FFI、pool-clippy-v2通过；pool-ui-v4八项及两张截图通过，暗色已审阅，
新增暂停等待保存回归pool-ui-v5两项通过。UI v1/v2失败是夹具删除仍被绑定的默认模型导致保存正确拒绝，
修为保留模型后真实请求与原断言通过。pool-verify-v1通过55文档/4脚本、Rust52/fmt/Clippy、
314 Dart格式/analyze、Flutter522（10捕获跳过）、platform5、真实FFI18、Windows引擎4。
bridge-final五文件一致；Android34.5s、普通Windows10.5s串行Debug通过。
固定artifacts/ui-preview/20261003-161740：APK117661891字节，SHA256
D639735C6A39A6D93C01348945C19CF8761A2B19A5682FC56CA99C621C9D4841；Windows84文件157277928字节。
Rust DLL9808896字节，SHA256 AA0755DDFF2F707C87D3FE04845C4AC29CD2453358D18EB081D4C652673D241D。
85副本hash、APK身份/ARM64/v2/ZIP16K/ELF与Windows x64/Flutter DLL pin通过；562文件树审计无发现。
已提交并普通推送c4422a2215d8a16c7cbe2875df6490c10e05cb4d，0/0干净；该批未调用供应商或设备。
池轮换与会话仍未实现，总Goal保持active。

用户随后明确授权指定DeepSeek Responses端点与deepseek-flash实测，下一批改为先接Responses文本流。
首个HTTP请求16输出token被默认思考用尽，真实返回incomplete；关闭思考后HTTP200/completed/KIYORI_OK。
随后work/responses-live-v1.log记录项目NativeRuntimeClient→FFI→Rust两轮真实请求均KIYORI_OK/stop，
各一个终态，usage分别11输入5输出、32输入5输出；第二轮显式带历史。密钥只经内存/stdin使用，未写文件。
Responses复用同一请求核心；input/token参数映射、终态/usage/输出快照校验、思考隔离已实现。
responses-ui-v1两协议聊天/system回归及两PNG通过，暗色结果卡已审阅。完整responses-verify-v2通过
55文档/4脚本、Rust55/fmt/Clippy、314 Dart格式/analyze、Flutter523（10捕获跳过）、platform5、FFI18、
Windows引擎4。v1因忽略目录实测脚本被analyzer纳入、命名/依赖归属lint失败；脚本保留为dart.txt，
不改检查规则，v2完整通过。最终移除校验后的unwrap，定向responses-rust-final十一项与Clippy通过。
无依赖/公共FFI变化。Android59.8s、普通Windows34.3s串行Debug通过。
固定artifacts/ui-preview/20261003-164625：APK117661340字节，SHA256
F157ACAF1949B27BB81CDB8DF640ED181F021823A12755D1CF96E1CE2892EAB2；Windows84文件157328104字节。
Rust DLL9859072字节，SHA256 E2AE5B29352F5261427495F8EA0F296679D3D7ADCDF4257422D241D6EEADC9F5。
85副本hash、APK身份/ARM64/v2/ZIP16K/ELF、Windows x64/Flutter DLL pin通过；563文件审计无发现。
实测脚本/日志及交付树无密钥模式残留。已提交并普通推送21044e82190e96f10f25bf705e41c1963673dc2e，0/0干净。
真实供应商核心链路已验证，但聊天页发送/会话持久化仍未实现，设备/Apple仍未验收。

配置探测的密钥轮换已实现，正在完整验证。schema8新增独立游标且不推进配置revision，
Rust按旧启用/可用性规则选择候选；已标记且无可用项明确失败，全未标记池空才允许单key回退。
ROUND_ROBIN持久轮询，RANDOM补全旧字段未被消费的行为；默认行为和UI不变。
首次SQLite u64读取编译失败已改为有界u32；rotation-rust-v3四项含重开、并发、删除/迁移通过。
rotation-rust-all-v1的58项与Clippy通过（最后补的边界测试另定向通过）；桥生成v1通过。
rotation-ui-v1四项与三PNG通过，真实Chat/Responses请求分别发送两个不同候选；未额外调用供应商。
完整验证与双端构建尚未完成。正式会话的凭据读取短lease、会话持久化和聊天页发送仍未实现。

模型配置基础批次已提交并普通推送029128357a2a38b360c404d03ffed67a215cb738。
schema7扩展本机验收通过：跨进程凭据lease/崩溃pending恢复、密钥池稳定ID编辑与payload迁移、
独立上下文页和全局媒体偏好已接入。上下文按chat绑定读取；模型/媒体revision同事务校验，
媒体重置不改模型选项，错误保留草稿，返回刷写。旧v6进程须在升级前退出。

work/context-verify-v2.log通过54文档/4桥夹具、Rust45/fmt/Clippy、303 Dart格式/analyze、
Flutter515（10捕获跳过）、platform2、真实FFI13、Windows引擎4。v1仅新代码4处lint失败，
已修后完整重跑；定向pool-v1十五项、pool-v2四项通过。context-ui-v1十五通过/一失败，
失败为测试用标准pageBack查找自定义顶栏，改系统返回事件后context-ui-v2两项真实业务通过。
work/context-capture-v2/context-invalid-draft.png暗色错误态已审阅；既有六视口UI回归通过。
bridge-final Check五文件一致；Android94.2s、普通Windows20.0s串行Debug构建通过。

固定artifacts/ui-preview/20261003-141631：APK117606050字节，SHA256
F980D68E13BE044BF3D131987FD558019CFD9FB10A9068C8F7F6D9235A094C93；Windows84文件153928928字节，
Rust DLL6621696字节，SHA256 8467A69269D49FDBE0FCF3514080C2826BAB244471D994DA3D0EA6B1BFA87314。
85份复制hash、APK身份/ARM64/v2/ZIP16K/ELF、Windows x64/Flutter DLL pin通过；544文件审计
无发现。该批未改依赖；旧仓库干净。已精确提交并普通推送687fb21；设备/Profile/供应商/Apple未验证。

基础批次的schema6配置、完整选项、稳定模型名引用、
功能选择/事务重置、角色模型选择、安全引用退役已接FFI与页面。700ms自动保存串行排空，
失败保留草稿，离开可显式放弃；绑定模型删除需选择替代，新配置自动选中且隔离凭据。
人设页消费真实角色目录。新建kiyori_platform，Windows当前用户DPAPI保护独立引用，
Android/iOS委托Keystore/Keychain；设计及恢复边界见ADR0006。

work/models-verify-v1.log：54文档/4桥夹具、Rust41/Clippy、298 Dart格式/analyze、
Flutter509（10捕获跳过）、platform2通过。最后新增FFI关闭断言直接调用同步拒绝方法而
失败；修为闭包且仍精确断言BridgeError/runtimeClosed后，work/models-ffi-v2.log十三项通过。
首轮定向28项通过；最后新建选中回归/DPAPI与截图4项通过，work/models-ui-v2.log，
7张PNG位于work/models-capture-v2，真实目录和手机暗色已审阅。最终analyze无问题。
Windows引擎4项通过（work/models-windows-integration-v1.log），包含真实DPAPI重开；
bridge Check五文件一致。Android112.1s、普通Windows12.7s构建通过。

固定产物artifacts/ui-preview/20261003-133406：APK117570454字节，
SHA256 B5BE23E8F4F51FED383FBC7AE0C0BFA0260E22DBCFF7B4B9A185E061E57B7DA9；
Windows84文件153769296字节，Rust DLL6555648字节，SHA256
3D3682575CB783CAF34B1AF3AF2BF3EDAAACA303A5819F1AA0387F06A3ECE8B8。
85文件复制hash、APK身份/ARM64/v2签名/ZIP16K/ELF、Windows x64/Flutter DLL pin检查通过。
538文件树审计无发现，历史产物保留。设备/Profile/真实供应商/Apple尚未验证。

当前扩展之后继续密钥文件导入导出、池测试/轮换、真实请求/会话；
这些仍未实现，不能标为仅待设备验证。总Goal保持active。

角色/标签/群组持久化批次本地验收闭环，已提交并推送main/fe10772。schema5共享Runtime/SQLite，
角色八字段/标签/绑定、标签CRUD、群组有序成员、复制/激活/默认角色重置与市场添加
已接真实命令。revision拒绝过期覆盖，级联推进关联revision，活跃删除回默认；完整提示
组合提供真实接口。头像主题/形象/表情克隆、导入导出、会话关联、人设生成与模型执行
仍未实现，不能把本批当AI阶段完成。下一批推进模型配置、安全凭据与共享目录。

验证日志work/prompts-verify-v1.log：53文档/4桥脚本夹具、Rust37/Clippy、286 Dart
格式/analyze、Flutter506（10捕获跳过）通过。新增FFI最后关闭断言误写StateError而失败；
改为实际BridgeError/runtimeClosed后work/prompts-ffi-v2.log十二项通过，未降低断言。
Windows引擎三项通过，work/prompts-windows-integration-v1.log；bridge Check五文件一致。
联合角色/群组/市场46项通过（work/prompts-ui-v2.log），26张捕获保存在
work/prompts-capture-v2，真实目录与320暗色双倍字键盘弹窗已审阅。完整verify随后还验证
新增群组菜单复制/激活/删除回退。首轮预览模式创建接线与市场测试选择器错误已修复，
失败日志保留。默认语音资源632字符与已有完整中文常量逐字一致。

双端普通Debug构建通过：Android55.1s、Windows18.6s。固定目录
artifacts/ui-preview/20261003-122250：APK113015932字节，
SHA256 F1566F13EFD3E30348DBDCFE6ED647D432D85B4546EF4B9427222E9B4A14E46D；
Windows83文件134515905字节，Rust DLL6259712字节、
SHA256 2CADBC07AD274E049BC091AAF05DF267EB4A92C0C9FE303E0544ADDFF8FAACDF。
84文件复制哈希、APK身份/ARM64/v2签名/ZIP16KB/ELF对齐和Windows x64/Flutter DLL pin
审计通过；历史产物均保留。521文件树审计无敏感路径/异常大文件/相对导入环发现，
临时日志/脚本/产物全部忽略。设备/Profile/真实供应商/Apple尚未验证；无新增依赖。

当前正式Goal为active、无预算。开工实查main/HEAD及fetch后的origin/main均为
`4a69550bc5e2489c02d144b3a4eb45e5266870fa`，左右差异0/0，工作区与暂存区干净。
只读旧仓库HEAD为`6b03b03aa082803bb279db5e78773583e2d91154`且干净。
本任务授权范围内实现、验证、串行Android/Windows构建、精确提交与普通推送；不操作
设备、账号、私人收费端点、生产或CI，不启动自动化，不委派。日记local_only、Asia/Shanghai。

阶段A/B已完成设置UI的本地验收：12项及设置子树的映射、状态、弹层、返回和代表截图
以settings-replication-map及下述十一批证据为准。当前转入AI左抽屉及真实业务切片；
AI重要功能未实现时Goal保持未完成。设置业务写入与平台动作仍不计为已实现。
每周期按相关性合并有效实现，完成批次继续下一批。总验收包括源码映射、行为/截图、
静态/FFI/集成、双端构建、固定产物及远端一致；设备/供应商/Apple缺口单列。

AI第一批实施基线main/248d49a与origin/main同步；设置正式代码为450999b，
428b0ad误跟踪本机产物清单后已由248d49a普通提交移出索引，当前最终树与450999b相同。
产物继续保留本机忽略目录，不再强加索引。抽屉28项联合回归通过，6张最终捕获在
work/ai-drawer-capture-v3，analyze-v3无问题；320明暗/标题已审阅。
工作流已加入Rust SQLite目录存储、schema1、真实应用支持目录与桥接DTO，创建/编辑/
启用/删除及原子批量删除通过真实存储和跨桥验证。
范围与旧源见[AI映射](design/ai-replication-map.md)；节点/模板/执行/调度、扩展与记忆真实
业务尚未实现；本批定义切片已完成本机验证和双端构建，不能视为AI阶段完成。

工作流随后补入编辑/启用、来源Back、浮动菜单、多选/全选/清空/批量删除及更新时间投影。
最终完整verify-final-v2通过：53文档/4脚本、Rust fmt/Clippy/12测试、265 Dart格式/analyze、
Flutter470（10捕获跳过）、真实FFI7、Windows引擎3；日志work/workflow-verify-final-v2.log。
桥接Check五文件一致。工作流v5十三项及12PNG通过，work/workflow-capture-v5保留；
320明亮列表/错误及1280暗色列表已审阅。初轮类型、测试帧推进、未使用导入和花括号lint
失败均已修正，原失败日志保留，没有缩小断言或关闭检查。

双端Debug构建通过；首次固定产物20261003-073131审计发现path_provider的JNI传递依赖
混入非目标ABI，原目录保留且不作为最终交付。Gradle现按Flutter target-platform过滤
依赖JNI，split-per-abi仍交给Flutter；Android重建37.2s通过，Windows未受影响复用已验证
普通产品构建。最终固定artifacts/ui-preview/20261003-073852：APK91429003字节、SHA256
14C9EB99EE73876313056E857802C7617CA7817B4ECDA101AE64F7BBBF4426F0；Windows83文件129905521字节。
APK实际ARM64、身份/v2签名/ZIP16K/全部ELF LOAD对齐、Windows x64/DLL pin/native资产
及84个副本逐文件哈希通过。本机manifest及失败审计留在忽略目录，精确提交不包含产物。
本批交付后继续扩展和记忆根关联树，设备/Profile/供应商/Apple仍未执行。

AI第一批已交付`b1c354af826c1e4c17ac580d8616bd95d9e7346f`，普通推送后本地/远端一致，
0/0干净；44文件精确提交，491文件交付树审计无发现，固定manifest仅本机补提交。
第二批正在实现记忆库空间/目录与手工条目：将共享连接和迁移提取到core/storage，schema2
新增记忆空间、活跃空间、目录、条目及标签，schema1工作流数据保持。创建/编辑/归档/删除、
空间固定身份和删除级联、目录重命名/保正文删除、Rust分页搜索已通过18项Rust测试。
列表每页100条400字符摘要，详情按空间/ID读完整正文，105条跨页与长正文回读已测。
Flutter十六项定向v11通过；v10十四项及30PNG位于work/knowledge-capture-v10，已审阅
320明亮列表/暗色目录、844横屏编辑和1280暗色筛选。小屏双倍字空态按钮需滚动可达；
标题省略、目录折叠树/长按子目录菜单、标签单选与完整候选集仍需后续校准。
工作流和记忆共享迁移owner，目录与筛选已校准底部抽屉、编辑主题/目录下拉与详情菜单。
完整verify-v3通过：53文档/4脚本、Rust fmt/Clippy/18、270 Dart格式/analyze、Flutter486
（10捕获跳过）、真实FFI8、Windows引擎3。v1/v2花括号lint、v8错误Tooltip定位已修，
失败证据保留；v11补控制器替换释放和迟到详情错误隔离。桥Check五文件一致。
双端普通产品Debug构建通过，Android38.8s、Windows18.3s；固定产物为
artifacts/ui-preview/20261003-085102。APK112838380字节，SHA256
9800BCA9FD72F0881D4A1B26BF3FFBA716C643DC1E998CB46DD5B6F18C978911；Windows83文件130333977字节。
ARM64/身份/v2签名/ZIP16K/ELF LOAD、Windows x64/DLL pin/native资产与84份复制哈希通过。
包内Rust DLL时间为08:30:51，晚于最后Rust源码08:30:31，hook依赖包含knowledge/storage；
直接加载固定包DLL的8项FFI再次通过，未以时间戳推断陈旧产物。审计498文件无发现。
日记开篇/续写、文档导入/语义索引/图谱未实现，不能称记忆树完成。

记忆基础批次已交付2399b5ec014ceeb8d7ac168e930954f0150faeb3，普通推送后0/0干净。
下一批补目录惰性折叠树、长按/更多、新建子文件夹固定目标，以及完整查询范围标签候选。
候选由Rust在同一读事务按空间/类型/搜索/归档/目录计算，不受分页和主题/标签筛选截断；
筛选抽屉改为单选惰性列表，超过8项可搜索、重置清空输入、已选候选保留。
定向v5十八项与30PNG通过，代表目录明暗/横屏和暗色筛选已审阅；Rust18通过。
首轮Sliver菜单锚点错误改为行内Builder，标签测试文本重复定位改为真实RadioListTile，
失败日志保留。完整tree-verify-v1通过：Rust18、272 Dart格式/analyze、Flutter488
（10捕获跳过）、真实FFI8、Windows引擎3，桥Check五文件一致。串行双端Debug通过，
固定artifacts/ui-preview/20261003-091731：APK112846387字节，SHA256
7A63E4D54DF6E5BAEAB4BCB2327082C2BF2DC37B1F8112A7D37BD35720CCA7E9；Windows83文件130360809字节。
ARM64/签名/ZIP16K/ELF LOAD和Windows x64/DLL pin/native资产与84份复制哈希通过。
审计500文件无发现，无新依赖或schema变化；日记、图谱、导入及记忆设置继续实施。

目录/标签批次已交付be6a8d0bf76b7438c23c9e36f5372629db290f6d，远端一致0/0干净。
日记批次实施中：Rust正文阶段解析、开篇、原子追加、完结/恢复与列表摘要、状态筛选已接；
Flutter开篇阶段、时间线、续写/结束、全文编辑提示、日期组和状态筛选已投影。
diary-core-v5共22通过，含独立runtime并发追加和103条状态跨页。后续补真实日期校验、
全文编辑前续写确认、失败收尾总结保留/重试、状态徽章、日期计数和时间线连线。
最终diary-ui-v15六通过、17PNG，真实Native开篇→续写→全文编辑→状态筛选贯通；
记忆18项在v13通过，代表明暗/320/横屏/桌面、开篇/列表/筛选截图已审阅。
完整diary-verify-v2通过：Rust fmt/Clippy/22、276 Dart格式/analyze、Flutter494（10捕获
跳过）、真实FFI9、Windows引擎3；bridge-check-v1五文件一致。早期DTO漏字段、测试
定位/帧等待、小屏溢出与v1花括号lint均已修，失败证据保留。505文件交付树审计无发现。
串行Android/Windows普通产品Debug构建通过，分别72.0s/19.0s；固定产物
artifacts/ui-preview/20261003-102209。APK112881267字节，SHA256
B557FB0F433F5EF4B5AD3FF0F4490D2F7F49D9ED8896672ACAC686F773BFE605；Windows83文件130511265字节。
ARM64/身份/v2签名/ZIP16K/ELF LOAD和Windows x64/DLL pin/native资产与84份复制哈希通过。
本批24文件精确交付后继续图谱关系；没有依赖/schema变更。设备/Profile/Apple仍待验证，
全文单节超长布局和大规模状态扫描尚无Profile证据，日期分组只覆盖已加载页。

日记批次已交付19ee6acbfe8d174d2c1cfc2d263c686e5efb7427，远端一致0/0干净后继续图谱。
图谱关系实施中：schema3关系表与级联、同读事务200项查询、描述回读、去重/自环/跨空间
拒绝及原子批删已实现。graph-verify-v1完整通过：Rust fmt/Clippy/27、280 Dart格式/analyze、
Flutter498（10捕获跳过）、真实FFI10、Windows引擎3；桥Check五文件一致。
Flutter图谱、平移/缩放、两点连线、边详情/编辑删除、框选删除已接入；v4联合28通过、
57PNG，v6图谱五项和12PNG通过，真实SQLite连线→描述编辑→缩放→边删除→框选批删贯通。
末轮补空图谱新建入口、相同拓扑引用快速返回、长标题关系编辑器整体滚动，320/844双倍字
与键盘保存通过；代表键盘/边标签截图已审阅。首轮框选起点、异步帧等待、字体与lint失败
已修，原日志保留。布局采用有界隔离线程力导向、稳定初始位置和标签缓存，未作Profile
性能结论。图谱开关当前仅页面状态，按空间持久偏好随检索设置切片接入。
最终graph-ui-final联合29项、analyze和foundation通过；510文件审计无发现。串行普通产品
Android/Windows Debug构建47.9s/18.4s通过；固定artifacts/ui-preview/20261003-110631，
APK112937982字节，SHA256
91A3C4BE68C7FF647DAC7E0D69795D7D8DA9B3662C4353BED16A3316C6D320C1；Windows83文件130735385字节。
ARM64/身份/v2签名/ZIP16K/ELF LOAD、Windows x64/DLL pin/native资产和84份复制哈希通过。
本批本地实现验证闭环，下一批记忆检索设置与偏好，随后继续扩展和AI真实业务。

图谱批次已交付5cee6d164245a95176a301f32807cedede5d3950，普通推送后远端一致0/0干净。
记忆检索设置实施中：schema4保存空间权重、间隔、规则与图谱偏好；图谱独立列更新避免
设置草稿覆盖另一窗口显示选择。Rust本地模拟搜索逐条扫描完整正文，Jieba搜索分词、
词法/标签RRF、反向包含与范围内关系传播已实现；31项Rust、Clippy及analyze已通过。
最终memory-search-ui-v4四项通过，含真实SQLite保存/模拟/重开、切空间释放弹层及偏好隔离；
v3五张捕获已审阅代表模拟/暗色键盘/失败草稿。v1惰性列表定位改实际滚动，FFI-v1关闭后
同步异常改用closure断言，失败证据保留。完整memory-search-verify-v1通过：Rust31、283
Dart格式/analyze、Flutter503（10捕获跳过）、真实FFI11、Windows引擎3；桥Check五文件一致。
515文件审计无发现；双端普通产品Debug构建108.0s/18.2s通过。固定产物
artifacts/ui-preview/20261003-114143：APK112965836字节，SHA256
EECB605F9F155CA508AF24F4CAC952B0232D130C823126BBF742C47C6904D403；Windows83文件134181169字节。
ARM64/身份/v2签名/ZIP16K/ELF LOAD、Windows x64/DLL pin/native资产及84份复制哈希通过。
旧列表仍使用原字面
查询，模拟分数尚未替换列表或接AI召回。自动保存开关/执行、云配置/安全凭据、向量索引和
资料导入仍未实现；间隔/规则保存只代表偏好持久化，不代表调度已运行。

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

代理已交付672333735d148b5f080d8900ad046a9f25db156c，本地/远端核对0/0、当时干净。
第四批音乐已交付：音源详情/链接修改/切换/移除、LX备份预览与导出/撤销状态已接入
可注入快照；偏好依赖、历史清理、播放速度与桌面歌词非默认投影已补入。音源/备份模态
随实体/页面释放，取消过的预览离屏不重弹。取消身份保存在页面会话，不保活离屏进度条，
修复忙碌组件持续请求帧。音乐19项状态/偏好/视口回归和36张捕获通过，证据在
work/settings-music-regression-v4.log及work/settings-music-capture-v4。完整verify通过：
Flutter345项（10捕获跳过）、Rust6/FFI6/脚本4、50文档及229 Dart格式/analyze。
日志work/settings-music-verify.log；未改变Rust API、桥和依赖。串行双端Debug成功，固定
artifacts/ui-preview/20261003-022730：APK104778774字节，SHA256
A0A390ED8123612717E7492ADA0756098E1C342B5C8396D18C9A612EA61957AD；Windows82文件117771694字节。
身份/ARM64/v2/ZIP16K/ELF、Windows x64/DLL pin/native资产与逐文件哈希通过。本批按精确
清单交付为266228c44d97ed81f607654efc7912916bef0d9a，已普通推送且manifest补入sourceCommit；
设备与真实音乐服务未运行。

第五批工具箱已实现自定义分组重命名/删除、清色确认、NFKC名称校验、稳定工具ID筛选与
批量移动、加载/保存/错误快照和实体弹层生命周期。保存中返回/遮罩/拖动/关闭统一拦截；
快照移除工具/分组时清理选择与路由，名称草稿重排保留、删除释放。未写布局或颜色，未执行工具。
原6视口回归及新增14项状态/视口通过；36张捕获在work/settings-toolbox-capture-v3，
代表横屏键盘与小屏双倍字图已审阅。日志work/settings-toolbox-regression-v2.log及
work/settings-toolbox-capture-v3.log；首次失败为测试定位同时命中透明路由底层同名文案，
已限定当前对话框/可点击项。完整verify-v2通过：51文档、4脚本、Rust fmt/Clippy/6测试、
234 Dart格式/analyze、Flutter359项（10捕获跳过）、真实FFI6项。首次完整验证一处截图测试
花括号lint已修，日志work/settings-toolbox-verify-v2.log。新增unorm_dart0.3.2和锁文件，
无Rust公共API或桥变动；未重复Windows引擎集成。串行双端Debug通过，固定
artifacts/ui-preview/20261003-025918：APK105036647字节，SHA256
C321A5E45E92DC5B8D8D48E5B0ABBE3ABAE4C31BF5D1170FC0820807C4D2B9CC；Windows82文件118469988字节。
APK身份/ARM64/v2/ZIP16K/ELF、Windows x64/DLL pin/native资产及复制哈希通过；审计457文件、
230 Dart、93资产，无warning/大文件/import循环。本批精确交付后进入外观媒体/九宫格状态。
工具箱已交付1de816a5b73db18632ee0b1b55716df64e3eb338，远端一致0/0，固定manifest已补提交。

第六批外观媒体已实现背景图/视频已选态、裁剪入口/静音/循环草稿、用户/AI源图九宫格
与`.9`拉伸/平铺渲染。图像从共享资源owner借用，界面不读取路径、不创建播放器；局部
切片按源图/裁剪区缓存并释放，着色器处理平铺，保持旧物理像素缩放与窄目标角区压缩。
同ID等值快照重建保留草稿，参数变更/媒体移除重置；气泡卡与预览暗色底色改为旧主题语义。
既有12项外观测试通过，新增5项像素/状态与6视口通过，30张最终捕获在
work/settings-appearance-capture-v5，日志work/settings-appearance-regression-v5.log。
已审阅明暗/横屏/双倍字背景、源图网格和两种预览。过程中的测试颜色常量误判及const长度
断言编译失败已修，失败日志保留。完整verify通过：51文档/4脚本、Rust fmt/Clippy/6测试、
238 Dart格式/analyze、Flutter370项（10捕获跳过）、真实FFI6项；日志work/settings-appearance-verify.log。
双端串行Debug通过，固定artifacts/ui-preview/20261003-032327：APK105052267字节，SHA256
E11324CC8530F649686CE1CCA4DCDC906CD3FE5F0A5B67670D3A815D2A4782CD；Windows82文件118503628字节。
身份/ARM64/v2/ZIP16K/ELF、Windows x64/DLL pin/native资产与复制哈希通过；无依赖/Rust API/桥变动。
审计461文件234 Dart93资产，无warning/大文件/import循环。自定义字体/头像非空态继续下一批。

第七批字体/头像与备份运行状态已实现并通过本机验证。字体family由资源owner
注册，角色/全局头像选择器独立、样例30px圆形回退；等值媒体更新保留名称与字体草稿。
备份独立操作进度/结果、聊天六种导入格式、记忆配置→策略、最近备份覆盖确认、恢复后
重启和模型导出安全提示均由快照投影。页面唯一管理模态路由，目录移除与宿主退出释放
所属选择/格式/策略/确认；未执行文件选择、导入导出、恢复、重启或偏好写入。
联合定向40项通过，96张捕获在work/settings-identity-backup-capture-v5；日志
work/settings-identity-backup-regression-v5.log。已审阅字体/头像、进度、最近备份、导入/
策略、横屏安全提示；离屏进度停止请求帧通过。首次测试const索引编译、动画捕获等待及
只向下滚动的测试定位器失败已修，日志保留；暗色安全确认按钮改用onPrimary前景。
完整tools/verify.ps1通过：51文档/4脚本、Rust fmt/Clippy/6测试、242 Dart格式/analyze、
Flutter391项（10捕获跳过）、真实FFI6项；日志work/settings-identity-backup-verify.log。
无依赖/Rust API/桥变动，未重复Windows引擎集成。串行双端Debug通过，固定
artifacts/ui-preview/20261003-040134：APK105080454字节，SHA256
FF85FD4FCBFE2418906F99629B309A16FBE1451D0D59B36FDEE2E9B250C25605；Windows82文件118572644字节。
身份/ARM64/v2/ZIP16K/ELF、Windows x64/DLL pin和逐文件复制哈希通过。交付树审计465文件、
238 Dart、93资产，无warning/大文件/import循环。设备/文件业务与Apple边界仍未验证。

这不是完整设置验收：角色标签批量导出、市场/生成等关联入口及其余非默认态仍需继续；
有效二维码服务、音乐/外观资源业务、形象导入/渲染和真实AI业务尚未实现。设备视觉、
触摸/Profile、真实账号/供应商、Apple构建没有执行，不能由本机Debug结果外推。

恢复入口：读取[设置映射](design/settings-replication-map.md)、当前Git差异和本机日记
`c3e66803-02cf-452e-aae6-a3ad0662dae0`，核对第七批Git交付后进入角色标签相关缺口。

第八批角色关联入口已实现：标签批量导出选择、旧13项标签市场与添加预填、人设生成工作台
的角色侧栏/八字段/消息/生成中/清空与上限状态，均复用PromptsPresentation并保持实体
代次隔离；设置页导航可进入市场和人设页，Back返回标签/角色来源。真实标签导入导出、
市场写入、角色创建删除、模型请求、消息历史、自动保存和工具执行仍未接入。
20项联合定向通过，48张明暗/320/844/1280/双倍字/键盘捕获在
work/settings-tags-persona-capture-v2，日志work/settings-tags-persona-capture-v2.log。
初次导出弹层惰性列表固有尺寸错误已改为有界滚动列；角色菜单命中警告已改为稳定选择器，
失败日志work/settings-tags-states-v1.log保留。市场正文来自旧TagMarketBilingualData，
人设入口/字段/上限来自旧PersonaCardGenerationScreen。
本批完整verify-v2通过：51文档、4脚本、Rust fmt/Clippy/6测试、Dart格式/analyze、
Flutter411项（10捕获跳过）、真实FFI6项。初轮花括号lint已修，DartWorker线程错误保留
失败日志。串行Android/Windows Debug通过，固定artifacts/ui-preview/20261003-043340：
APK105132790字节，SHA256 AA9A63CA70EC675D41892805DC4FA1D57AB96EC55890B4E3C24DE2F6C83C41E2；
Windows82文件118694020字节。身份/ARM64/v2/ZIP16K/ELF、x64/DLL pin/native资产与复制
哈希通过；审计473文件246Dart无发现，无Rust API、桥或依赖变动。本批精确交付后继续
人设空目录八字段/消息尾部定位及模型下载目的地核对，尚不宣布设置全树完成。
上一批固定产物`artifacts/ui-preview/20261002-171634/`保留。

第八批已交付d46ad85e0505c53de29a11f3fcff9866dadec9ae，本地/远端一致0/0，manifest
已补sourceCommit。第九批继续补设置边界：本地模型下载目的地、目录加载/失败/空态、
六种下载状态、搜索和删除确认已投影；设置及功能模型管理入口共享同一路由并准确返回。
人设空目录仍显示八字段，未绑定草稿不回填新角色；首次和切卡定位历史末尾，尺寸变更
继续校准惰性列表估算，用户上翻后停止跟随。真实下载、模型执行和人设业务仍未接入。
本批22项联合检查通过，90张捕获位于work/settings-local-models-capture-v2；模型配置
既有回归在regression-v1通过，唯一失败为新测试将RawTooltip强转IconButton，已修复
为按真实控件属性定位，失败日志保留。完整verify-v2通过：51文档/4脚本、Rust6与fmt/
Clippy、253 Dart格式/analyze、Flutter423（10捕获跳过）及真实FFI6；初轮三处测试
花括号lint已补齐。串行双端Debug通过，固定artifacts/ui-preview/20261003-045532：
APK105141756字节，SHA256 E4629904CD71940BEEF32019D6B4DE45E00E4D02890F84165A854BED6474E44D；
Windows82文件118717244字节。APK身份/签名/16K/ELF及Windows架构/DLL pin/native资产/
复制哈希通过，无Rust API或依赖变化。下一批补浏览器密码/脚本授权和文件隐藏/格式目录
非空分支；仍未宣布设置全树闭环。

第九批已交付9b06b6b04c73a3c72643921d6f60749dc06c53a7，普通推送后HEAD/远端相同、
0/0干净，manifest已补提交。第十批已实现浏览器凭据加载/可用/错误、摘要搜索、详情遮蔽、
编辑/删除确认及实体/宿主释放；脚本声明目录和四种运行标签按旧优先级显示，非总授权
开关。文件隐藏/格式规则目录、当前默认/MIME推荐、嵌套失效释放、清理计数/busy/错误
确认已补。最终保存、恢复、复制和清理仍为空业务动作，不接触真实密码、剪贴板或文件。
浏览器10项、文件9项联合通过，54PNG在work/settings-browser-files-capture-v2；此前
文档文件6项回归通过。新测试的语义选中定位和未先滚动已修，失败日志file-states-v1保留。
完整verify通过：51文档/4脚本、Rust fmt/Clippy/6、259 Dart格式/analyze、Flutter442
（10捕获跳过）及真实FFI6。串行双端Debug通过，固定artifacts/ui-preview/20261003-052526：
APK105170556字节，SHA256 E35A9420BCB91E8FFB7D9F2FE2E9EB449ACB832539701AA5F9B34853FED0874C；
Windows82文件118786796字节。APK身份/签名/16K/ELF与Windows x64/DLL pin/native资产/
复制哈希通过；482文件255人工Dart审计无发现。无Rust API或依赖变化。后续收口用量定价、
局域网、上下文及语音实体的权威值更新/弹层释放，设置关闭条件继续按映射核对。

第十批已交付77af2994cfedd11f953c0cce31d6cf12d4fe018b，manifest已补提交。第十一批
收口资料加载/干净刷新与未保存草稿、上下文configId及字段刷新、LAN Token重遮蔽、
用量定价目录和语音实体存在期。统一音色选择器失效结果守卫，配置/目录更新或宿主退出
释放所属弹层，controller延后到旧控件卸载后释放。系统默认音色空ID保留合法选择。
联合既有六组页面回归54项通过，最终生命周期8项通过，9张PNG位于
work/settings-lifecycle-capture-v3；代表定价/资料/系统音色截图已审阅。
全量初轮发现旧治理测试的弹层移除同帧迟到点击会误pop底层页面；TtsOptionDialog现校验
当前有效路由再返回，保留原迟到点击步骤后治理+生命周期16项通过，失败日志完整保留。
本批完整verify-v2通过：51文档/4脚本、Rust fmt/Clippy/6、260 Dart格式/analyze、
Flutter450（10捕获跳过）及真实FFI6。串行双端Debug通过，固定
artifacts/ui-preview/20261003-060325：APK105188296字节，SHA256
4A11C4FC61EDE7E1AF0AC81397EFB8AAB97AB7E1AD4A9CDCCC48476C4DFCE401；Windows82文件
118824940字节。APK身份/签名/16K/ELF及Windows x64/DLL pin/native资产/复制哈希通过；
审计483文件256人工Dart无发现。没有Rust API/桥/依赖变化，不重复Windows引擎集成。
本地UI验收按S01–S12累计证据关闭；后续从KiyoriAiDrawer、ScreenRouteRegistry和
OperitNavigationStackPolicy继续AI主阶段，保持HomeShell唯一一级导航owner与既有草稿。
真实设置持久化、系统动作、设备/Profile/Apple及供应商验收仍单列，不能称业务完成。

## 历史交付：第四轮群组卡草稿垂直切片

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
