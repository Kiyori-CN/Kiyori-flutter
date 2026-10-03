# ADR 0007：共享模型请求与流式边界

日期：2026-10-03。状态：已采用；实际验证与交付以[当前状态](../status.md)为准。

## 需求与选择

模型测试、密钥池探测和后续会话使用同一Rust请求核心，Dart仅投影执行状态。
首个切片实现OpenAI兼容Chat Completions；Responses、Messages和本地native协议
在接入前返回明确unsupported。不能以配置保存成功推断该协议已能执行。

每个Runtime惰性建立一个reqwest Client并复用连接池；不创建平行浏览器、下载服务或
文件数据库。reqwest 0.13.5（MIT OR Apache-2.0）关闭默认features，启用
rustls-no-provider/json；Rustls 0.23采用ring/std/tls12；webpki-root-certs 1.0.9
（CDLA-Permissive-2.0）提供Mozilla根。锁文件固定实际传递版本。
使用完整DER根和ClientBuilder.tls_certs_only，避免Android依赖未初始化JNI verifier。
保留TLS证书与主机校验，不读取SSLKEYLOGFILE，不接自签名绕过；此版本不使用用户安装根。
系统与应用代理尚未接入，当前请求路径为直接连接；未来代理必须作为同一network策略接入，
不能在代理失败后静默改为直连。未进行真实供应商或Apple验收。

## 请求契约

仅显式测试动作触发请求。端点解析后要求HTTPS；本机loopback允许HTTP以支持本地模型
和测试。拒绝userinfo/query/fragment；末尾单个#沿用旧完整端点标记。空path补
/v1/chat/completions，末尾/v1补/chat/completions，其他path原样。
关闭自动重试和全部重定向；网络失败不能推断服务端未执行，错误注明未自动重试。

认证和自定义headers只持有本次内存快照，不写SQLite或日志，不在错误中回显URL、
请求正文、认证头或供应商错误正文。HeaderValue标记sensitive；传输控制header不可覆盖。
自定义参数不能替换model/messages/stream/n或尚未接入的工具字段；请求正文上限8 MiB。
没有自动获取密钥、探测目录或发出其他供应商请求。

## 流与生命周期

SSE逐字节保存跨网络块UTF-8，支持CR/LF/CRLF、注释与多行data。单事件上限1 MiB；
8事件有界队列背压，不在core积累完整回复。只接受单choice index0，usage空choice有效。
结束原因与[DONE]均须出现；缺失完成标记是interrupted，工具调用/过滤/未知结束原因
不能假装文本成功。连接15秒、读取60秒、调用总期限100毫秒至600秒；模型探测90秒。
超大内容明确失败，不静默截断。模型探测最多保存64000字符用于判断。

取消token为Runtime子级；关闭Runtime、取消或释放run会取消网络任务；终态只交付一次。
FFI同时读取被拒绝，Dart订阅暂停停止继续拉取，关闭处理未订阅的run，迟到句柄立即取消。
界面按稳定配置ID隔离；取消后上一代结果不能覆盖新请求，删除页面释放请求。

## 旧源与产品投影

旧revision 6b03b03aa082803bb279db5e78773583e2d91154的ModelConfigScreen按钮先flush，
运行时按钮为取消，结果卡位于按钮下方。ModelConfigConnectionTester以Hi检查非空回答，
SystemInstructionCapabilityProbe用随机口令只放system检查实际遵循情况。新探测的提示词、
参数转换、64000字符限制和结果判定全部归Rust，Dart不另行判断服务输出。
新实现沿用此流程；聊天结束length不计完全通过。工具和启用媒体在探测实现前标未验证。
密钥池调度尚未实现时拒绝池测试入口使用任意第一项冒充轮换行为。

## 验证与回滚

loopback真实HTTP验证请求路径/认证/参数、中文拆流、usage尾块、HTTP错误、重定向、
错误内容不回显、断流、取消、超时、FFI释放和无订阅关闭。UI验证真实两次探测与结果卡；
取消重启的完整页面操作与设备交互仍需追加验证，不把状态代次的源码审阅当作设备证据。
新增网络依赖必须通过Windows/Android构建；本机成功不等于设备TLS或供应商协议验收。
无schema变化，可回退本批代码和依赖到e859ad7，既有配置与安全存储数据保持可读。

## 官方依据

2026-10-03核验：[OpenAI SSE说明](https://developers.openai.com/api/docs/guides/streaming-responses)、
[Chat delta与usage示例](https://developers.openai.com/cookbook/examples/how_to_stream_completions)、
[reqwest ClientBuilder](https://docs.rs/reqwest/0.13.5/reqwest/struct.ClientBuilder.html)。
依赖版本与许可证另由cargo info实查；不使用官方示例中的具体模型名作为产品默认值。
