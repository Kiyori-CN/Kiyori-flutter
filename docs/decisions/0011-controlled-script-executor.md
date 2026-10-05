# 受控脚本执行端口

## 决策与范围

状态：正式端口已实现并通过Windows本机行为测试和双端产品构建；扩展业务接线继续。
旧来源为6b03b03的JsToolPkgRegistration、ToolPkgAiProviderRegistry、
ToolPkgJsAiProviderService与custom_ai_provider示例。保留ToolPkg.registerAiProvider、
exports.registerToolPkg、四个函数handler、sendIntermediateResult和eventPayload语义。
此阶段没有包安装目录、HTTP宿主、任意Java桥或稳定通用插件SDK。

core/scripts拥有类型化失败、限额、并发、取消树和终态；platform/scripts是独立Rust/C++
静态adapter，FFI在Runtime发布前装配，核心不依赖平台。Dart不建立第二执行器。
每调用独立QuickJS runtime/context及闭包注册表，不保存跨请求JS对象或KV状态。
注册和调用均真实执行源文件；没有静态列表或函数名扫描替代执行。

## 候选、构建与许可

选择QuickJS-NG v0.17.0，tag commit为6d46d07d04041b40f4f49eaa7fdebe44c314c699，
官方tag archive SHA256为559bc4c420475e55c7ab4510adbc562f55d7524d75e8e89d79ce4bb02f5687d9。
原QuickJS官方Windows路径为MinGW；本项目Windows使用MSVC，候选先经实际编译/运行。
rquickjs未进入产品，以窄C接口避免当前MSVC绑定风险与第二生命周期所有者。
依据[官方构建说明](https://quickjs-ng.github.io/quickjs/building/)和
[固定发行](https://github.com/quickjs-ng/quickjs/releases/tag/v0.17.0)，仅链接qjs，
QJS_BUILD_LIBC关闭；不链接qjs-libc，不安装std/os或文件/网络/进程对象。

CMake FetchContent必须验证固定hash，源archive与原生缓存不进Git。
KIYORI_SCRIPT_ARCHIVE只提供同hash的本机archive；target/native-scripts按target共享
Release缓存，OS文件锁覆盖配置、构建、安装，避免Cargo不同profile并发破坏缓存。
Flutter hook显式登记清单、build.rs、CMake和C++输入。MIT全文随平台assets和
LicenseRegistry交付。Apple目前无真实构建，adapter返回Unsupported。

## 执行、结果与关闭

核心默认期限30秒、内存32 MiB、栈512 KiB、最多100000 Promise jobs。
期限范围10–600000ms、内存1–128 MiB、栈64 KiB–1 MiB；源码最多2 MiB。
并发4，等待并发槽计入期限；8事件队列、单事件1 MiB、累计输出8 MiB，最多65536事件。
输出无法完整交付时明确失败，禁止静默截断。最终结果与中间队列分离，终态只交付一次。

同步eval、注册函数、异步handler和Promise job共享中断状态；未安装I/O宿主时
无法自行结算的Promise返回UnresolvedPromise，不等待假想网络。死循环、递归、
内存分配和输出超额按实测失败；输出拒绝后即使JS捕获异常也保持失败事实。
普通handler数据仍须由消费领域进行schema验证；深层/循环/非JSON结果不能冒充有效输出。
异常只返回稳定分类，不带JS异常正文、源码、输入、路径或凭据。

SDK在加载源码前捕获所需内建函数，注册目录及条目使用无原型投影，避免包修改
Object.prototype/Array.prototype/RegExp.prototype后伪造宿主身份。注册最多32项、
ID唯一且只含ASCII字母数字与_.-；必须有全部四handler。调用开始后关闭注册窗口。
每次调用重新注册同一冻结源码，不持久保存或加载未验证bytecode。

取消等待独立finished，不能抢占页面的next_event读取；没有消费者时也可终止背压。
Runtime关闭先取消树，再等待所有登记worker返回并析构；新调用在同一登记锁下
拒绝关闭状态。并发permit和活跃标记在adapter返回后释放，之后才发布终态。
线程、中断与内存限制不是OS安全沙箱；原生引擎漏洞仍可影响宿主进程。

## 验收与回滚

核心5项覆盖停止等待、读取冲突、并发排队期限、drop、无人消费关闭、错误与终态。
Windows正式adapter6项覆盖四handler、Promise、中文、无宿主权限、模块拒绝、
死循环、异常捕获、内存/栈/job/输出、注册篡改与重新执行；旧示例原文件独立1项证明
真实注册/计数和未装网络宿主时三个网络handler明确失败。日志与全量结果见status。
双端产品构建、静态包与许可证一致性继续验收；Android设备/Apple独立记录。

本切片不改变schema和UI，不执行用户包或供应商请求。回滚代码保留现有模型、
配置和历史；无持久JS状态要迁移。后续包/HTTP/配置目录必须复用同Runtime/SQLite/
ResourceRef和client，撤销先停止并结算，不因执行端口存在而自动获得网络或文件权限。
