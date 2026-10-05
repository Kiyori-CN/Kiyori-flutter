# ADR 0013：受控提供方 HTTP 与正式聊天

## 状态与问题

2026-10-05接受，承接[ADR 0012](0012-persistent-provider-packages.md)。旧示例使用
OkHttp builder与流式回调；执行器和包目录本身不能完成模型请求。实施验收见
[status](../status.md)，设备与Apple独立记录。

## 所有者与请求

Runtime复用同reqwest client、scripts/extensions Registry、AppStore及模型Gate。
Registry以Arc交给在途ChatRun，不复制Runtime或重新打开SQLite。正式请求冻结当前
启用provider和包revision；执行前取得包租约、检查revision及入口SHA256。撤销来源
明确失败并保留配置引用，不回退内置provider。

输入沿旧config/chatHistory/modelParameters/enableThinking/stream合同。消息kind映射
SYSTEM/USER/ASSISTANT，参数保留类型和值。会话、自动总结和手动总结沿同ChatRun、
Prelude及持久化owner；XML工具续答沿既有两次执行与独立凭据轮换。媒体和原生工具
合同尚未接入时明确拒绝，不根据选择开关伪造已执行。

## HTTP 能力与凭据

可信Rust模型owner才装配ScriptHttpHost，原始FFI startExtension和注册阶段无网络。
JS只有凭据/安全头引用，真实短期值由Rust在发送时注入。只允许GET精确models URL
及POST精确生成URL；目录地址遵循旧示例，从生成地址去chat/completions或responses
再加models。URL需HTTPS，本机回环允许HTTP，禁账号/query/fragment和第二主机。

继承共享client的TLS校验、不重定向、不重试和代理策略。脚本不能新增认证值；Host、
长度、连接和代理认证头拒绝。配置安全头可覆盖默认认证，脚本只引用冻结值或有限
JSON/流类型。引用不能放进正文；响应凭据回显在UTF8分片交付前拦截，包括跨片段。
该保护不识别任意编码后的秘密，执行器也不是OS安全沙箱。

请求正文1 MiB、响应8 MiB、HTTP最多16次、期限1–600000ms。UTF8安全流片段不超过
64 KiB，只在同VM线程调用JS，指针只同步借用。不跨线程移动JSValue，不允许HTTP
回调递归发HTTP。回调期间Rust不持Call别名借用；最终JSON在宿主栈返回后才由QuickJS
解析。C++异常/JS源码/原始网络错误不穿边界；宿主失败不能被JS捕获后伪装成功。
SDK只支持旧示例实际builder/request/execute/response窄合同。

## 取消、配额与结果

包租约在等待Gate前登记，撤销能停止排队调用；配置RPM/并发每handler调用获取一次
许可，不在HTTP宿主重复获取同槽造成自锁。多次HTTP受16次上限。许可保持到VM/HTTP
结束，ChatRun取消等待worker；释放不依赖UI读取。脚本期限含脚本槽排队，正式期限含
模型配额等待。Runtime.close等待同Registry活动worker。

目录限制20000项及身份/名称长度、控制字符和重复；正文8 MiB，流式终态全文必须与
片段一致，缺失/伪造终态失败。非流式缓冲后有界分事件交付完整正文。用量只接受非负
有界整数和旧别名，冲突/畸形拒绝；缺失报告不伪造成真实计数。摘要失败仍保留原文并
阻止后续聊天。

密钥池按旧testConnection独立handler，综合模型测试继续sendMessage；连接正文不穿过
FFI。发送前calculateInputTokens对最终投影history计数，接受旧number/string及
tokens/inputTokens/count别名，十进制按旧规则截断并夹到0–Int.MAX_VALUE，畸形明确失败。
计数和发送属于同一次模型请求，共用一个Gate许可与有界HTTP host；许可按Arc保持到全部
worker释放，不在单并发槽内重复获取。计数写入请求窗口观察，与实际Usage及输出速度
分开；超过当前会话上下文上限则保留原文并停止。扩展自动总结在输入计数后按配置阈值
或历史user消息数判断，不能被保守字节估算提前触发。未触发沿同许可继续发送；触发先
释放计数/聊天许可，再执行同Run的总结，最终history重新计数并核对上下文上限。
总结凭据轮换和用量行延迟到真实触发的短事务，复核配置/角色/偏好/运行身份；失败或
取消不发后续聊天。非扩展提供方的估算预算保持原合同。

## 验收与回滚

真实QuickJS/包/共享HTTP测试覆盖未改旧源四handler、URL/头/响应、UTF8、超时与取消，
以及捕获错误伪成功、正文指纹、非法用量。正式目录、流式/非流式、system、多轮、
自动/手动摘要、重开、活动与排队撤销均走产品owner。Dart抽屉验证动态选择和保存。
真实供应商仅用用户授权端点与合成输入，密钥不进源码、日志、截图和提交。

生成桥及Check、完整verify与Windows集成、双端普通产品串行构建和固定包审计。
设备像素/触摸/Profile、Apple和其他旧宿主能力独立待验证或待实现。本批不改schema19，
回滚使用兼容二进制及一致备份，保留包与模型配置。
