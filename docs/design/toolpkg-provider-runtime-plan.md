# TOOLPKG 模型提供方运行时接入方案

## 目标与来源

范围为模型与API的动态TOOLPKG提供方，复用同一Runtime、配置、ChatRun、Transfer和
ResourceRef。安装、启停、卸载、目录、请求、测试与计数必须有真实执行，不能用静态列表
替代。第一批不迁移旧Android任意Java/native桥，不新增浏览器或文件数据库。

旧基线6b03b03，来源为ToolPkgAiProviderRegistry、ToolPkgHookBridgeSupport中的
ToolPkgAiProviderRegistration、ToolPkgJsAiProviderService与examples/custom_ai_provider。
真实注册包含listModels/sendMessage/testConnection/calculateInputTokens四个handler，
按已启用容器生成动态目录。事件携带config、chatHistory、参数、工具、思考、流式和
用量；中间结果与最终结果必须区分，已有流式正文不能在final时再次追加。

## 执行器候选与实证

2026-10-05核对官方[QuickJS文档](https://bellard.org/quickjs/quickjs.html)、
[QuickJS-NG构建](https://quickjs-ng.github.io/quickjs/building/)和
[v0.17.0发行](https://github.com/quickjs-ng/quickjs/releases/tag/v0.17.0)。原QuickJS
文档的Windows路径为MinGW交叉编译；本项目Windows产品使用MSVC，需要真实编译。
当前候选QuickJS-NG v0.17.0/tag commit 6d46d07d04041b40f4f49eaa7fdebe44c314c699，
官方archive SHA256 559bc4c420475e55c7ab4510adbc562f55d7524d75e8e89d79ce4bb02f5687d9，MIT。
spike后开始正式静态adapter接入，固定同一archive；产品验收状态见status，SDK兼容范围
不等于旧Android全部宿主桥。

仅链接qjs，QJS_BUILD_LIBC=OFF；不装std/os/文件/网络/进程或模块加载器。Windows MSVC
Release实际编译且12项运行通过：中文JSON、宿主全局缺失、模块导入拒绝、循环超时、
捕获异常不能逃逸中断、外部取消、16 MiB内存、512 KiB栈、Promise结果/拒绝/未决/循环。
日志work/extension-engine-spike/windows-run-v2.log。每次请求独立runtime/context RAII；
Promise job也检查时限/次数，不能只限制同步eval。
追加旧custom_ai_provider/dist/main.js原文件运行：注册全部四handler与真实token计数
函数返回通过；三个网络handler在未安装OkHttp宿主时按预期拒绝，不发生网络请求。
连同前12项共16项通过（windows-run-v3），这不表示网络宿主或全部TOOLPKG包兼容。

同spike经NDK30、API24编译Android ARM64成功，ELF LOAD均0x4000。该证据只证明编译，
没有安装或运行设备。Windows上游编译警告保留，不通过关闭断言伪装上游零警告。
Apple未编译；线程/内存限制不是OS安全沙箱，原生漏洞仍具有宿主进程影响。

## 实施切片与唯一所有者

1. 受控执行端口：core/scripts拥有取消、时限、内存/输出/并发策略与稳定错误；
   platform/scripts仅持qjs实例。FFI装配，无UI→脚本执行器旁路。注册与调用均在
   blocking worker，结束等待释放；中间结果采用既有有界队列。
2. 包与目录：core/extensions在同SQLite保存包身份、版本、摘要、启用及存在代次。
   安装经受控字节导入与ResourceRef，manifest/相对路径/符号链接/数量/总大小校验后
   原子交付。禁任意bytecode/native库；只接受受支持JS源，权限声明不是授权事实。
3. provider注册：ToolPkg.registerAiProvider映射四handler并严格验证；稳定身份绑定
   package+provider+version/revision，不能仅全局小写字符串覆盖内置或另一包。
   启停/更新/卸载推进目录代次，先禁止新调用并取消在途任务，结算后解除注册。
4. 网络端口：JS不直接拥有HTTP client或明文密钥。受控host请求复用Runtime client，
   配置端点主机/方法/大小/认证/取消/重定向策略由core核对；包声明的host范围须得到
   用户配置授权。绝不根据脚本输出转发凭据到新主机。旧OkHttp示例需SDK兼容层和
   明确支持范围，不能直接把Android对象暴露为通用跨平台契约。
5. 产品接线：既有provider抽屉消费动态目录；安装/启停/删除入口沿旧源外观和返回语义。
   配置引用的包撤销时明确失败并保留配置，不静默回退内置provider。测试结果标明
   本次实际快照和handler；未知计数不伪造成真实token。

## 受控 HTTP 宿主与正式聊天（已实现，验收见status）

旧custom_ai_provider实际依赖OkHttp builder/request/execute以及chunk回调，不只依赖
Promise。采用单次blocking VM中的窄宿主回调：Rust在同worker等待Runtime的共享client，
流片段只在所属VM线程调用JS函数，不跨线程移动JSValue。网络等待同时检查调用取消与
期限；取消返回后必须等待HTTP future、JS对象和包租约释放，不能遗留后台请求。

注册阶段和无宿主调用仍不安装OkHttp。正式模型调用先从当前启用包和revision冻结目录，
构造旧eventPayload/config/chatHistory语义；脚本只接收认证占位引用，明文密钥和安全请求头
由Rust持有并在发往配置端点时注入。SDK仅兼容旧示例实际使用的builder方法，不暴露Java
对象、任意client或文件句柄。HTTP失败只发布稳定原因，不回传原始异常、响应头或私密正文。

配置端点限定同源及已批准操作路径，禁止脚本新增主机、账号、认证参数或重定向；方法、
请求/响应大小、调用次数和总期限有界。RPM/并发沿用配置owner，避免在一个请求上重复
获取同一并发许可导致自锁。脚本结果仍经模型领域核对目录、正文、usage与唯一完整终态。
验收包含旧示例真实loopback目录/流式正文/连接/计数、恶意主机/认证/重定向拒绝、取消、
超量和包撤销，以及动态抽屉、配置保存/重开和正式会话持久化；供应商实测另用授权合成输入。

## 验收与回滚

先运行端口的无权限、恶意输入、超时/取消、Promise、背压和析构测试，再测安装路径
穿越/链接/超量/manifest/事务中断；真实包从安装到四handler、动态目录、聊天、保存、
撤权、升级/卸载和重开闭环。请求结束/usage/final必须与已有ChatRun终态规则一致。
真实网络使用loopback合成服务及已授权的供应商合成请求，日志不回显源码/凭据。

正式依赖固定commit/archive/hash并附MIT全文；公共Rust契约生成桥和-Check，完整verify、
Android/Windows产品构建及包审计。Android设备运行和Apple编译独立记录。回滚采用
一致数据备份与前一schema二进制，不直接改user_version或清空用户包/配置。

正式端口已通过核心5项生命周期/身份与Windows原生6项行为回归，旧示例在正式端口
注册/计数及网络拒绝1项通过。正式四handler调用支持同步和可自行结算的Promise，
没有宿主I/O时未决Promise明确失败。执行端口完整验证与双端构建已通过，实际批次见status。
core/extensions现已实现schema19包持久化、受控ZIP导入、安装/升级/启停/卸载与代次撤销，
公共FFI及Dart桥已接入；具体合同与兼容缺口见[ADR 0012](../decisions/0012-persistent-provider-packages.md)。
包生命周期核心及真实QuickJS/FFI、整体验证与双端构建已通过。受控网络、动态目录与
正式ChatRun/总结接线已实现，当前验收见status；AI抽屉插件导入/详情/启停/卸载已接，
密钥池连接与发送前输入计数分别接旧testConnection/calculateInputTokens，窗口与Usage
分开投影，计数/发送共用单模型配额；自动总结按提供方窗口或消息数触发，生成后重算。
触发前不消耗总结密钥/用量，触发释放聊天配额后复核身份并总结，避免同配置单并发自锁。
JSON/HJSON清单、schema1/2分发元数据及流式ZIP兼容见ADR0012；排序与完整旧宿主
能力仍待实现，未接扩展标签动作保留旧外观。
精确网络、配额与结果合同见[ADR 0013](../decisions/0013-controlled-provider-http.md)。

正式源码位于core/scripts与platform/scripts，内存1–128 MiB、栈64 KiB–1 MiB、
期限10–600000ms、Promise job最多100000；并发4，事件8槽，每条1 MiB、总8 MiB。
等待并发槽也消耗期限，取消等待独立finished且不抢事件读取者；Runtime.close等待
所有已登记worker。默认32 MiB/512 KiB/30000ms。注册目录最多32项，稳定id只含
ASCII字母数字与_.-；元数据需严格JSON字段和唯一身份。SDK捕获内建函数并用无原型
注册快照，拒绝调用期间重新注册；普通handler返回仍按不可信数据验证。
无任意bytecode入口，模块loader明确拒绝；C++与JS错误正文不穿越公共边界。

构建缓存target/native-scripts按target独占OS锁，KIYORI_SCRIPT_ARCHIVE只接受固定
SHA256内容，KIYORI_SCRIPT_BUILD_DIR可重定位缓存。Flutter hook显式登记CMake/adapter
输入，MIT全文进入平台资源和LicenseRegistry。Apple未编译时返回Unsupported。
