# ADR 0006：模型配置与平台安全凭据

日期：2026-10-03。状态：已采用，基础配置批次本地验证通过；恢复扩展仍在实施，
本机测试与平台验收证据见当前状态。

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

1. 核心按当前revision预留随机不可变reference，状态pending。
2. native写入新引用成功后，Rust事务更新配置并将新引用置active、旧引用置retired。
3. native删除retired成功后移除账本；失败保持记录，下次读取/保存重试。
4. 保存失败只尝试退役本次预留；active检查和退役同一Immediate事务，不能删除已生效引用。

这不是跨存储原子事务。retired是不可再激活的终态，因此重复清理安全。
崩溃发生于native写入或提交前时，pending保留为未决记录；当前不按时间或启动扫描删除，
因为另一个进程可能仍在写同一预留。安全的跨进程独占恢复及未决引用回收仍未完成，
不能宣称已经闭合崩溃孤儿回收。已提交配置保持可读，未决密文可能占用空间。
删除配置也保留其pending记录直到能证明写入结束。错误文案不带明文、路径或native原异常。

旧页面700ms去抖和切换前刷写保留；同配置串行提交，提交中输入进入下一次。
失败保留草稿，离开可显式放弃；成功后目录刷新失败单独显示，不重复提交已成功命令。
Windows native buffer清零，Dart String无法保证内存清零，关闭编辑会话释放引用。

## 验证与后续

核心测试覆盖迁移/重开、默认保护、稳定引用/显式替代、revision和安全引用状态；
真实Windows DPAPI测试覆盖密文、损坏保留与拒覆盖。models_business_test使用真实FFI
和DPAPI验证写入失败、清理失败、旧值可读、SQLite无凭据夹具明文、保存中输入及页面新建。
Android真实构建与Windows引擎验收按验证策略执行；真实供应商、设备和Apple另列。
模型请求、文件导入导出、完整key池管理、上下文页真实接入和pending恢复继续推进。

来源：[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)、
[CryptProtectData](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata)、
[CryptUnprotectData](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptunprotectdata)。
