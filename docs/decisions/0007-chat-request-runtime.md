# ADR 0007：共享模型请求与流式边界

日期：2026-10-03。状态：已采用；实际验证与交付以[当前状态](../status.md)为准。

## 需求与选择

模型测试、密钥池探测和后续会话使用同一Rust请求核心，Dart仅投影执行状态。
已实现OpenAI兼容Chat Completions与Responses文本流；Messages和本地native协议
返回明确unsupported。不能以配置保存成功推断该协议已能执行。

每个Runtime惰性建立一个reqwest Client并复用连接池；不创建平行浏览器、下载服务或
文件数据库。reqwest 0.13.5（MIT OR Apache-2.0）关闭默认features，启用
rustls-no-provider/json；Rustls 0.23采用ring/std/tls12；webpki-root-certs 1.0.9
（CDLA-Permissive-2.0）提供Mozilla根。锁文件固定实际传递版本。
使用完整DER根和ClientBuilder.tls_certs_only，避免Android依赖未初始化JNI verifier。
保留TLS证书与主机校验，不读取SSLKEYLOGFILE，不接自签名绕过；此版本不使用用户安装根。
系统与应用代理尚未接入，当前请求路径为直接连接；未来代理必须作为同一network策略接入，
不能在代理失败后静默改为直连。指定DeepSeek供应商已做授权文本验证，其余供应商与Apple未验收。

## 请求契约

仅显式测试动作触发请求。端点解析后要求HTTPS；本机loopback允许HTTP以支持本地模型
和测试。拒绝userinfo/query/fragment；末尾单个#沿用旧完整端点标记。空path补
/v1/chat/completions，末尾/v1补/chat/completions，其他path原样。
Responses分别补/v1/responses或/responses，完整端点和末尾#不改路径。
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
模型综合测试在池轮换未接入前仍拒绝任取第一项；独立池可用性测试逐条探测，不消费轮换游标。

## 密钥池可用性

旧ApiKeyPoolAvailabilityTester只排enabled且UNTESTED条目，AdvancedSettingsSection固定并发5。
core/chat/pool复用同一client/probe/execute，最多32并发和20000条，队列只保存key而不复制大草稿。
单项完整非空stop回答标可用，HTTP/网络失败标不可用；无效配置和未支持能力整体报错，不污染整池。
旧runCatching可能把取消计为不可用，新实现取消后abort并等待全部worker退出，不复制此缺陷。
Dart按稳定ID、原key和enabled核对后逐项保存，暂停等待在途保存，输入变化使旧代次失效。
切配置、编辑池、文件交换和离开前暂停，宿主移除取消；清标记后才再次测试已完成项。
标记是测试时配置的观察，不是持续健康状态；变更端点/模型需手工清标记。安全payload升级至v3。
旧ApiKeyProvider实用轮询：启用项有任一标记时只候选AVAILABLE，无可用项则失败；
全未标记时候选全部启用项，池空才可回退单key。RANDOM字段未被该旧provider消费。
此批仅实现可用性测试，上述真实轮换与游标持久化仍待后续共享模型执行切片。

## Responses文本切片

2026-10-03用户授权指定DeepSeek Responses端点和deepseek-flash进行真实验证，因此先补此协议。
复用原HTTP client、认证、TLS、SSE、取消与背压，不建第二请求运行时。旧OpenAIResponsesProvider
的max_tokens映射仍保留；文本消息改用input，显式store=false/background=false。不接旧后台续连
和previous_response_id；本切片每轮显式传完整消息，不启用服务端状态或自动重试。
协议保留字段禁止自定义覆盖。输出限制重复配置明确失败，reasoning参数按用户配置发送。
供应商默认思考可能消耗全部输出额度，incomplete/max_output_tokens映射length，不计探测通过。

只投影response.output_text.delta；reasoning事件不进入正文或日志，当前不支持其展示与不透明回传。
按item/part ID保存长度和增量指纹，终态output必须与收到的文本一致，避免最终快照重复追加或
缺失片段仍假装成功。只保留有界元数据，不累计完整聊天回复；终态快照仍受单事件1 MiB限制。
存在sequence_number时要求递增；completed/incomplete状态须匹配事件，失败/拒绝/工具及未知输出
明确报错。Responses终态不需要[DONE]，仅EOF不能证明完成。工具/媒体与思考多轮兼容仍未完成。

真实测试先用HTTP确认指定服务，再用NativeRuntimeClient→生成FFI→Rust发送两轮，均收到
KIYORI_OK/stop且仅一个终态；第二轮带前轮消息。只记录非敏感结果，凭据经stdin临时传入且未保存。
这不证明聊天页发送/会话持久化或Android设备网络已完成。具体证据以当前状态为准。

## 验证与回滚

loopback真实HTTP验证请求路径/认证/参数、中文拆流、usage尾块、HTTP错误、重定向、
错误内容不回显、断流、取消、超时、FFI释放和无订阅关闭。UI验证真实两次探测与结果卡；
取消重启的完整页面操作与设备交互仍需追加验证，不把状态代次的源码审阅当作设备证据。
新增网络依赖必须通过Windows/Android构建；本机成功不等于设备TLS或供应商协议验收。
Chat基础批次无schema变化，可回退到e859ad7。池测试扩展会写安全payload v3，不能再仅回退
代码读取新凭据；恢复边界见ADR0006，不混同SQLite schema与payload版本。

## 官方依据

2026-10-03核验：[OpenAI SSE说明](https://developers.openai.com/api/docs/guides/streaming-responses)、
[Chat delta与usage示例](https://developers.openai.com/cookbook/examples/how_to_stream_completions)、
[reqwest ClientBuilder](https://docs.rs/reqwest/0.13.5/reqwest/struct.ClientBuilder.html)。
依赖版本与许可证另由cargo info实查；不使用官方示例中的具体模型名作为产品默认值。
Responses另核验[DeepSeek端点契约](https://api-docs.deepseek.com/api/create-response/)与
[Responses指南](https://api-docs.deepseek.com/guides/responses_api/)。指定实测模型未替换旧产品默认值。
