# ADR 0006：模型配置与平台安全凭据

日期：2026-10-03。状态：已采用，基础配置批次已交付；恢复及上下文扩展已实现，
本机测试与平台验收证据见当前状态。

<!-- doc-toc:start -->
- [背景与选择](#背景与选择)
- [核心契约](#核心契约)
- [双存储提交与恢复](#双存储提交与恢复)
- [独立上下文设置](#独立上下文设置)
- [验证与后续](#验证与后续)
<!-- doc-toc:end -->

## 背景与选择

旧ModelConfigManager把模型配置、API key池和请求头保存在Android偏好中。
跨平台版本复用Rust Runtime/SQLite保存配置和稳定引用，创建实际使用的kiyori_platform
作为系统安全存储adapter。Dart只编排原生调用与投影，不建第二配置库。

Windows使用win32的CryptProtectData/CryptUnprotectData，以当前用户DPAPI保护独立引用
文件；禁止UI提示，不启用LOCAL_MACHINE。flutter_secure_storage_windows 4.2.2的缓存源码
使用DpapiJsonFileMapStorage，读取损坏后会删除全库文件，且保存含无界重试，因此不采用
其Windows实现。没有修改依赖缓存。每个新引用独占创建，失败不删除旧密文。
Android/iOS使用flutter_secure_storage 11.2.0的Keystore/Keychain实现，Android明确
resetOnError=false、独立namespace，manifest关闭备份；iOS限定当前设备、不参与同步。
Apple源集未编译，移动channel mock不等于设备安全存储验收。

直接依赖：flutter_secure_storage 11.2.0（BSD-3-Clause）、ffi 2.2.0（BSD-3-Clause）、
win32 6.4.0（BSD-3-Clause）、path_provider 2.1.6（BSD-3-Clause）；serde 1.0.229和
serde_json 1.0.151（MIT OR Apache-2.0）用于类型化选项序列化。版本固定在Pub/Cargo锁文件。
不由此引入远程服务、遥测、安装操作或用户密钥测试。

## 核心契约

schema6增加model_configs/model_names/function_models/model_secrets，不改写schema5的
角色正文和旧未知模型绑定。未知绑定可读取；编辑保存必须重新选择有效目录项。
默认配置default不可删除。默认DEEPSEEK/chat端点和deepseek-v4-flash是旧产品初始化，
不是服务可用性或最新模型推荐。新配置OPENAI_GENERIC、空端点/模型。

11项功能直接引用配置ID和模型名，重排不换绑。删除引用中的模型须显式替代；
配置删除可先重新分配或在核心命令指定替代。事务同时更新功能和角色，推进关联角色revision。
功能重置将全部功能原子绑定到默认配置的首个模型，空模型拒绝。Deferred FK允许同事务
重建模型顺序，不允许提交悬空功能引用。角色保存与引用校验同一Immediate事务。

参数保存完整类型化选项；FFI不返回密钥/headers。API key、key池、全部headers仅在
安全存储payload中，编辑按引用临时读取。普通端点拒绝userinfo、query和fragment正文，
保留旧末尾#完整端点标记；执行层仍需解析URL、TLS/重定向及凭据发送校验。
普通配置不是加密数据库，不能把任意用户写入参数/总结规则的文字都称为安全凭据。

## 双存储提交与恢复

1. 获取应用目录model-secrets.lock的OS独占锁，持有至本次native写入和核心提交结束。
   取得锁后将无活跃配置引用的遗留pending转retired，再按当前revision预留新reference。
2. native写入新引用成功后，Rust事务更新配置并将新引用置active、旧引用置retired。
3. native删除retired成功后移除账本；失败保持记录，下次读取/保存重试。
4. 保存失败只尝试退役本次预留；active检查和退役同一Immediate事务，不能删除已生效引用。

这不是跨存储原子事务。retired是不可再激活的终态，因此重复清理安全。
崩溃退出由OS释放锁；只有成功重新取得锁的writer才能回收遗留pending，不按年龄猜测。
锁忙时拒绝新凭据写入，目录仍可读取并提示清理待重试；锁文件始终保留，不能删除重建。
lease显式close或Drop释放，已关闭/跨库lease不能预留；native删除失败保留retired供重试。
schema7提高协议版本，阻止v6二进制重新打开数据库；无法关闭已经运行的v6进程，升级前
必须退出旧实例。目录canonicalize用于lease归属，错误文案不带明文、路径或native原异常。
模型/池测试使用编辑会话的内存快照；正式会话取得同一短lease，再解析当前配置及安全引用，
native读取后由Rust复核配置/角色/提示词并冻结请求，网络开始前释放lease。读取编辑凭据和
所有retired清理路径也取得同一锁，防止在native读取期间替换并删除引用。

旧页面700ms去抖和切换前刷写保留；同配置串行提交，提交中输入进入下一次。
失败保留草稿，离开可显式放弃；成功后目录刷新失败单独显示，不重复提交已成功命令。
Windows native buffer清零，Dart String无法保证内存清零，关闭编辑会话释放引用。

安全payload v3以id/key/name/enabled/availability保存池条目，编辑保留ID和启用状态并重置标记；读取v1按原顺序
分配legacy索引ID，重复值仍为独立条目。非法/重复ID或损坏payload拒绝读取，错误不包含正文。
v2无可用性字段时迁移为UNTESTED；v3只接受UNTESTED/AVAILABLE/UNAVAILABLE。
池测试已经执行并逐结果保存，配置探测轮换已由core/model_execution执行。v3不能由旧v1/v2二进制读取；池测试批次不改SQLite schema，
但写入v3后不可仅回退代码。回滚须恢复升级前整套数据库与安全存储备份，或另行实现显式降级迁移；
不得删除不可读凭据或假装恢复成功。升级仍须先退出旧进程。

已实施的轮换切片将 SQLite 升至 schema8，仅新增model_key_cursors(config_id,next_index)，FK级联删除。
Immediate事务校验配置revision、读取游标、选择候选并提交下一索引，不推进配置revision；
网络发生在事务之后，网络失败/取消不回退游标，不自动重试。编辑会话将已持有的v3快照传入
Rust解析，限制1 MiB且不Debug/记录；正式会话从native引用获取凭据采用上述短lease保护。
schema7二进制拒绝schema8，代码回退须保留新库并恢复
升级前一致备份，不能手改user_version。迁移只加表，无现有内容重写。
正式会话进一步升级至schema9，新增会话/消息/Run表；schema8旧程序同样不能重新打开新库。

## 独立上下文设置

ContextSummarySettingsScreen的currentConfig来自FunctionType.CHAT；新实现读取同一功能映射，
不依赖角色绑定或任意默认配置。schema7新增全局history_retention，默认图片2、音视频1。
save_context_settings在Immediate事务校验聊天绑定、模型revision、历史revision，局部更新
上下文/总结字段，保留模型其它参数和安全引用。仅媒体变化不推进模型revision，反之亦然；
任一校验失败整体不写，保持草稿。返回前刷写，重载显式放弃草稿并等待已有保存结束。
持久化与执行分别验收；自动/手动总结已由同一会话请求链消费，见[ADR 0008](0008-conversation-summary-projection.md)。完整用户媒体附件裁剪仍需后续接入。

## 验证与后续

密钥文本交换采用现有kiyori_platform的TextExchange。Windows COM Common Item Dialog在后台
isolate执行，限定本应用模态owner，取消不读写、不添加最近文档；Android ACTION_OPEN_DOCUMENT/
ACTION_CREATE_DOCUMENT直接流式读写选定URI，不申请全盘权限，不持久化URI、不复制明文缓存。
Activity解绑返回detached并取消provider/关闭流；已经开始的目标写入不能宣称撤销，失败可能留下
目标文件的部分内容。接口错误不包含路径、URI或原异常；iOS返回unsupported，未伪造成功。
UTF-8严格解码，原文件上限1 MiB；去BOM、逐行trim、忽略空行、追加且保留重复值与顺序。
合并后连同条目元数据也校验1 MiB，超限不改草稿。导出仅用户显式选择时写明文api_keys.txt。
安全payload仍走不可变引用协议；选择未结束时页面flush等待，移除宿主后不回填迟到结果。
本机注入选定路径测试验证真实I/O；未自动操作原生选择器、Android设备或Apple，不能由mock
或编译证明系统交互验收。无新依赖，复用win32 6.4.0和Android平台API。

核心测试覆盖迁移/重开、默认保护、稳定引用/显式替代、revision和安全引用状态；
真实Windows DPAPI测试覆盖密文、损坏保留与拒覆盖。models_business_test使用真实FFI
和DPAPI验证写入失败、清理失败、旧值可读、SQLite无凭据夹具明文、保存中输入及页面新建。
Android真实构建与Windows引擎验收按验证策略执行；真实供应商、设备和Apple另列。
真实子进程测试验证活跃锁拒绝恢复、进程终止后回收；上下文测试验证全局媒体、局部更新、
绑定切换、陈旧revision、非法输入回滚与schema6迁移。请求、池测试与已接入的轮换见[ADR 0007](0007-chat-request-runtime.md)。

来源：[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)、
[CryptProtectData](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata)、
[CryptUnprotectData](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptunprotectdata)。
文本交换来源：[Common Item Dialog](https://learn.microsoft.com/en-us/windows/win32/shell/common-file-dialog)、
[Android SAF](https://developer.android.com/training/data-storage/shared/documents-files)。
