# ADR 0018：独立对话标题生成

日期：2026-10-06。状态：已采用；实际验证见[status](../status.md)。

## 旧源与行为

只读Kiyori-Android/6b03b03：MessageProcessingDelegate219–243、1317–1325、1499–1515
在首次有效user前保存回退，再独立启动标题；ConversationService74–93、476–535
使用TITLE_GENERATION、stream=false、enableRetry=false；FunctionalPrompts249–306
保留1200 UTF16正文上限、中文系统/用户提示及输出要求。ChatDao99更新标题和updatedAt。
标题实际用量沿独立provider/model路径，未加进EnhancedAIService的聊天aggregate。

当前真实发送仅文字，因此回退为“新对话”，附件名为“无”。首轮发送事务复用同
Runtime保存源消息与原始输入，引用标签不进入标题提示。没有user的预先手工标题
也按旧行为先变回回退；请求开始后的手动改名保留。第二轮普通聊天不重复生成。

## 所有权与执行

schema24追加conversations.title_revision和conversation_title_requests。辅助表保存
源消息、原始输入、回退、版本、模型配置、时间、结果、真实用量和状态；不创建可见
assistant或聊天Run。复用既有HTTP client、select_credentials、model_limits、native
adapter、start_observed、ProviderAudit及chat::persist，不建立第二请求执行器。

标题准备持短凭据租约和独立title执行锁；Dart等待短租约释放再开放下一轮，网络响应
继续独立。标题与聊天共享单并发配额时由原队列安排，不保持聊天槽位等待标题。
停止/释放先同时撤销两个准备窗口，再等待native取消；删会话或整组删除取消所属标题。
准备失败/取消保存无Provider请求事实，已启动失败/取消保存唯一终态；无自动重试。
实际Provider请求快照先持久化，审计失败阻止外发；凭据不写入事件。

完成只接受完整非空回复，thinking/search/meta清洗、首非空行、Markdown/控制字符/
引号/标点和40 UTF16上限遵循旧顺序。原字符串单次范围投影避免反复复制；混合
think/thinking闭合和meta负向嵌套遵循旧正则非递归替换。Rust无法保存孤立UTF16代理，
截中补充字符时保留替换字符；测试显式记录此跨语言表示边界。

标题更新要求回退文字、标题版本、源消息仍存在及最新工作同时匹配；改名或源消息
改走再改回仍失效。更新updated_at与专属标题版本，消息revision保持独立，避免后台
结果使打开的消息编辑/重发失效。失败、空输出或不完整终态保留回退与聊天消息。
回复超过8MiB记录失败并取消上游，不能静默截断为正常标题。

## 恢复、计量与兼容

Runtime持自己的精确OS生命周期锁；pending仅由原活跃owner准备。其它Runtime读取
不会中断活工作；原owner退出后pending与无执行锁的running转interrupted，不重发。
正常释放清理自身生命周期锁；崩溃残留仅作为恢复证明，不按年龄猜测存活。

标题用量保存在辅助表和TITLE_FINISHED，审计详情进行中状态包含标题。沿旧路径不
混入conversation_statistics。全局provider累计页面、文件多附件和完整工具运行事实
仍属后续业务，当前不宣称完成。标题请求复用平台adapter，Apple未编译不能称已验证。

schema23原数据、消息、审计、密文和签名不改写；升级事务失败全部回滚。旧程序不能
读写schema24，回滚需恢复升级前一致数据库与平台密钥备份，不能删除新表冒充无损
降级。本轮无新增依赖、真实供应商调用、设备操作或发布。

## 验收

核心与真实FFI用合成loopback核对JSON请求、独立凭据/模型、实际用量、取消/失败/
删除/切会话、迟到CAS、准备无外发、重开不重发；既有聊天/总结/用量联合回归。
正式桥生成及Check、完整verify、五窗口截图、Android/Windows Debug和固定包审计
按项目入口执行。真实供应商、设备像素/字体/触摸/Profile、SAF/Keystore和Apple仍
独立待验证，完整任务状态只在status维护。
