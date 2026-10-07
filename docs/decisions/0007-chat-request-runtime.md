# ADR 0007：共享模型请求与流式边界

日期：2026-10-03。状态：已采用；实际验证与交付以[当前状态](../status.md)为准。

<!-- doc-toc:start -->
- [需求与选择](#需求与选择)
- [请求契约](#请求契约)
- [流与生命周期](#流与生命周期)
- [旧源与产品投影](#旧源与产品投影)
- [密钥池可用性](#密钥池可用性)
- [Responses文本切片](#responses文本切片)
- [正式文字会话](#正式文字会话)
- [统计证据补充（2026-10-04）](#统计证据补充2026-10-04)
- [请求内观测与可选计量容错（2026-10-04）](#请求内观测与可选计量容错2026-10-04)
- [验证与回滚边界](#验证与回滚边界)
- [官方依据](#官方依据)
<!-- doc-toc:end -->

## 需求与选择

模型测试、密钥池探测和后续会话使用同一Rust请求核心，Dart仅投影执行状态。
已实现OpenAI兼容Chat Completions、Responses、Anthropic Messages及Gemini原生网络协议。
MNN/llama.cpp本地原生与扩展提供方返回明确unsupported。不能以配置保存成功推断该协议已能执行。

每个Runtime惰性建立一个reqwest Client并复用连接池；不创建平行浏览器、下载服务或
文件数据库。reqwest 0.13.5（MIT OR Apache-2.0）关闭默认features，启用
rustls-no-provider/json；Rustls 0.23采用ring/std/tls12；webpki-root-certs 1.0.9
（CDLA-Permissive-2.0）提供Mozilla根。锁文件固定实际传递版本。
使用完整DER根和ClientBuilder.tls_certs_only，避免Android依赖未初始化JNI verifier。
保留TLS证书与主机校验，不读取SSLKEYLOGFILE，不接自签名绕过；此版本不使用用户安装根。
系统与应用代理尚未接入，当前请求路径为直接连接；未来代理必须作为同一network策略接入，
不能在代理失败后静默改为直连。指定DeepSeek供应商已做授权文本验证，其余供应商与Apple未验收。

## 请求契约

仅显式测试或聊天发送动作触发请求。端点解析后要求HTTPS；本机loopback允许HTTP以支持本地模型
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
新实现沿用此流程；聊天结束length不计完全通过。已接原生/XML echo调用和随机结果续答，
保留Messages思考签名、Responses不透明reasoning及Gemini thoughtSignature供探测续答。
XML允许旧源接受的换行/解释文字，但只有一个echo(text=ping)才生成本地结果。
图片、音频、视频使用旧素材按协议编码；关闭开关或协议不支持时拒绝发送，错误答案不标通过。
模型综合测试现用已保存配置revision执行轮换；独立池可用性测试逐条探测，不消费轮换游标。

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
后续core/model_execution已实现此候选规则和持久轮询，模型综合测试每次请求取一次候选。
RANDOM历史字段现按其明确语义执行安全随机候选选择；这是对旧provider未消费字段的补全，
默认ROUND_ROBIN行为保持。随机模式不推进轮询游标；无新UI或新依赖。选择失败不发送请求。
游标只记录候选序号，无明文凭据；编辑/重排候选后按当前候选数取模。配置删除级联游标，
陈旧revision与非法输入拒绝；网络失败或取消消耗已选位置，不回滚为重复候选。

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

## 正式文字会话

schema9的conversations、conversation_messages、conversation_runs与活跃选择复用同一SQLite。
会话创建绑定当前单角色，群组自动执行明确拒绝；发送时解析角色当前组合提示词与固定模型，
否则使用chat功能绑定。历史按position读取，包含已收到的取消/失败正文，不把空助手消息送入请求。
配置参数包括text/json的类型在Rust转换。没有通用tokenizer时以UTF-8字节作为保守预算，
同时限制1000消息、8 MiB请求/回复；超限明确失败，保留原文，不静默截断。
schema15接入显式启用的自动总结，执行与缓存合同见[ADR 0008](0008-conversation-summary-projection.md)。

准备句柄持有安全引用短lease，启动时重新校验配置/角色/提示词；同事务推进密钥游标、
保存用户消息/空助手/Run。网络后再释放的只有会话OS锁；安全lease在请求冻结后释放。
文本与终态先保存再投影，空回复和incomplete为失败，取消保留已保存正文。
每会话仅一个running；读取时仅在取得该会话OS锁后恢复遗留running为interrupted。
切换界面不换执行归属，删除/编辑活跃会话由核心拒绝；关闭Runtime传播取消，worker保留
同一store至终态结束。突然杀进程不保证最后未提交字节，重开不重发请求。

编辑重发使用同事务尾部替换，凭据/配置验证失败不先删除历史；普通消息编辑、
删除、回滚和会话重命名/删除校验revision。schema13单条重新生成保存旧回复版本，
只替换目标助手的当前投影，保留后续消息；版本切换/删除与分支复制同样由核心事务完成。
版本保存不等于普通编辑的修订审计，后者仍未实现。
ChatPage保留CURSOR用户卡与AGENT输入几何，按消息ID懒加载；流中32ms合并局部正文通知，
流中80ms节流并在isolate解析Markdown，普通闭合段落保留AST与widget身份；复杂块留在尾部，
后置引用或HTML触发全文求值保证语法正确。终态保留同一渲染State，历史正文不随token重算；
上翻停止跟随，切会话重新定位尾部。没有Profile数据，不宣称帧性能达标。
Markdown不加载外部图片，代码块复制写系统剪贴板；工具/媒体/完整思考展示仍为非目标。

chat_business_test覆盖真实DPAPI/FFI/SQLite/loopback与UI两轮、取消、失败、切换、重复发送、
重开、消息编辑/删除、事务重发和短lease并发。chat_live_test默认跳过，只接受显式环境注入
授权端点/模型/凭据，且不截图/打印凭据；2026-10-03指定服务两轮与重开通过，见当前状态。
Windows组件测试不等于Android设备、Profile或Apple验收。当前schema14须恢复一致备份回滚。

## 统计证据补充（2026-10-04）

schema10增加运行记录的usage_reported与first_output_at，同一SQLite事务负责入账。
旧schema9的正用量可确认已报告，零值历史无法区分缺失与真实零，迁移后保留未知。
新Usage事件显式记录已报告，统计返回可空值；Dart不得把缺失值换成0或把字节预算当token。
首次正文时刻由核心首次非空Text事件写入，未观测的历史时刻保持空；不推算历史速度。
本次迁移无删除，不接受旧二进制重新打开新库；回滚必须同时恢复升级前二进制及一致数据备份。
面板通过现有Runtime查询，打开时订阅刷新、关闭时释放，不建立第二套计费账本。

schema14增加Run的可空cache_read_tokens/cache_write_tokens/reasoning_tokens；旧记录保持NULL。
core/chat/usage按旧OpenAIResponsesProvider.parseUsageCounts核对字段别名、整数范围、
缓存桶和输入总数关系及推理不超过输出。缓存异常排除细分，输入/输出总数仍保留；
total由输入+输出得到，不重复计入推理。超出i64范围的总量明确拒绝，防止无符号转存回绕。
同一次Run的usage以最后有效样本替换，分支复制保留字段；累计仅包含非running请求，
逐请求饱和相加避免SQLite SUM溢出。缓存率按有效缓存样本的输入token加权，分母0时为0%；
没有有效样本则未知。按旧展示语义，累计写入/推理无正值仍显示未提供，最近请求保留明确0。
上下文token估算及进程内速度tracker见下节，不以累计用量推算。
新增可空列不删除历史；新二进制必须完成迁移，旧二进制拒绝schema14。回滚恢复升级前
一致数据库与匹配二进制，不降低user_version。chat_usage_test覆盖真实FFI、两轮合成请求、
有效分母、分支、重开及统计面板；core回归覆盖schema13迁移、替换和未报告/零值。

## 请求内观测与可选计量容错（2026-10-04）

旧GenerationSpeedTracker、TokenStatisticsDelegate、ChatUtils和TokenCacheManager是来源。
core/chat/observation在请求链路内按Instant单调计时，事件进入有界投影队列前更新；
不以Dart接收时刻或SQLite历史耗时推算速度。输入估算来自冻结的实际消息，每条按汉字
1.5、其它UTF-16单元0.25截整数后相加；既有UTF-8保守请求限制仍独立，不冒充token数。
Runtime每会话持有最新tracker，切换可读该会话当前样本，分支/重开无样本；
新请求替换旧tracker引用，旧回调不能污染新请求。删除与关闭释放，运行终态保留上下文估算。
速度至少需要两个非空分片与正时间/输出，非流式不生成；运行中是逐分片估算，完成时使用
供应商输出计数，未报告最终输出不发布完成速度；取消/失败清除最近样本。仅完成样本显示
供应商模型与最近用量，运行中可显示已获得的有效速度/首输出等待，累计继续由SQLite计算。
UI面板打开且该会话执行中以250ms合并刷新，关闭释放；顶栏只读controller快照，
不因token分片重建。上下文上限使用当前模型配置，首轮/重开无估算时按旧默认0显示。

共享usage解析对非对象、缺少输入、负数/错类型/越界计数返回无观察，不让可选计量破坏
有效正文/终态。仅报告输入时保存不完整标记，最近样本保留输入，累计不计入已报告覆盖；
以后完整样本仍替换同Run。该变更不修改schema或凭据合同，也不添加供应商重试。
Chat/Responses×流式/非流式回归覆盖容错；单调计时使用确定时间测试，真实loopback/FFI
覆盖两分片、部分用量、统计显示和重开；Debug证据不能替代设备/Profile验收。

## 验证与回滚边界

schema11增加聊天偏好与历史目录组织，schema12为每次运行保存角色名称快照。
旧回复缺少快照时返回未知，不用当前角色或历史归属推断回复来源。默认CURSOR/AGENT、
历史按文件夹、两个自动切换关闭、思考关闭/质量2、自动记忆开启、工具询问，来自旧源偏好。
角色选择仅改变当前提示角色；自动切对话开启时核心事务选择最近会话或创建新会话。
选择历史时只有自动切角色开启才改变当前提示角色；请求冻结当前提示角色，历史归属保持。
历史文件夹重命名/删除和会话元数据更新是事务写入，revision冲突保留UI草稿。
偏好由core/chat_preferences持有，Dart只投影快照；未接入的语音/媒体/工具执行不报告成功。
disable_stream映射正式Chat/Responses的stream=false与application/json，完整JSON响应有8 MiB上限，
不进行自动重试；使用相同终态、错误和Usage投影。记忆附件只选择本地文件夹引用，
工具调用未实现时发送明确拒绝并保留草稿，不读取或外发记忆正文。

loopback真实HTTP验证请求路径/认证/参数、中文拆流、usage尾块、HTTP错误、重定向、
错误内容不回显、断流、取消、超时、FFI释放和无订阅关闭。UI验证真实两次探测与结果卡；
取消重启的完整页面操作与设备交互仍需追加验证，不把状态代次的源码审阅当作设备证据。
新增网络依赖必须通过Windows/Android构建；本机成功不等于设备TLS或供应商协议验收。
Chat基础批次无schema变化，可回退到e859ad7。池测试扩展会写安全payload v3，不能再仅回退
代码读取新凭据；恢复边界见ADR0006，不混同SQLite schema与payload版本。

## 官方依据

2026-10-05扩展：Messages流须message_stop且全部内容块闭合；Gemini须finishReason及完整
HTTP流结束，思考不混入正文。Gemini生成参数和搜索工具、Messages缓存TTL按旧源合同编译，
实际模型能力依供应商验证。base64 0.23.1（MIT OR Apache-2.0）仅用于固定媒体编码。
模型目录保持代理前缀，四个旧官方Messages路径作同主机精确转换，自定义主机不转发到默认主机。
官方依据：[Claude模型目录](https://platform.claude.com/docs/en/api/models/list)、
[Gemini模型目录](https://ai.google.dev/api/models)、
[智谱兼容端点与Token配置](https://docs.bigmodel.cn/cn/guide/develop/claude)。

2026-10-03核验：[OpenAI SSE说明](https://developers.openai.com/api/docs/guides/streaming-responses)、
[Chat delta与usage示例](https://developers.openai.com/cookbook/examples/how_to_stream_completions)、
[reqwest ClientBuilder](https://docs.rs/reqwest/0.13.5/reqwest/struct.ClientBuilder.html)。
依赖版本与许可证另由cargo info实查；不使用官方示例中的具体模型名作为产品默认值。
Responses另核验[DeepSeek端点契约](https://api-docs.deepseek.com/api/create-response/)与
[Responses指南](https://api-docs.deepseek.com/guides/responses_api/)。指定实测模型未替换旧产品默认值。
