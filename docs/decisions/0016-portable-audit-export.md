# ADR 0016：旧格式审计导出与明确移植投影

日期：2026-10-06。状态：已采用；验收以[status](../status.md)为准。
替代[ADR0015](0015-audit-native-protection.md)的产品四文件导出选择，保持平台安全端口。

## 旧源与范围

来源为Kiyori-Android/6b03b03的ConversationAuditArchive、Hasher、Exporter、ArchiveMapper、
MarkdownRenderer、ExternalShareRedactor及Repository的portable验证。
旧左抽屉与详情没有导入入口；导入归备份模块，不为本任务在详情新增入口。
本决策处理现有详情的两种导出，不授权设备、供应商、文件导入或工具执行。

## 格式与事实边界

产品导出`.kiyori-audit`，ZIP内包含manifest.json、chat.json、audit.json、timeline.md、
events.jsonl、revisions.jsonl、projections.jsonl、integrity.json、redaction-report.json和
`payloads/<sha256>.txt`。archiveType为kiyori_conversation_audit、formatVersion/schemaVersion为1。
payload先遮蔽常见凭据再按明文字节SHA256去重；Base64正文、字节数和元数据符合旧合同。
事件哈希按旧19字段和排序后7字段payload引用，UTF-8字节长度前缀，无独立格式头。
初始前序hash为64个0；排序按Kotlin的UTF-16码元。P-256/SPKI/DER签名覆盖链头ASCII。

新工程原始八字段链继续保存、验证和加密，不在迁移中重新签名或改写源事件。
导出构造明确BASIC的可移植投影，正文保留nativeEventId、nativeEventSha256和真实Run；
messages快照按出现顺序恢复已观察修订并绑定MESSAGE_REVISED事件和payload。
原工程没有旧messageTimestamp，移植定位符采用首次审计观察时刻并在同一快照内消除
碰撞；manifest和正文明确它不是实际发送时间。已记录sentAt/model/usage/耗时按Run
投影，未知供应商、迁移前修订、未接入工具和附件不补造。日期文本使用UTC，无宿主
时区推断。当前variant和历史variant分别保存，当前编辑不被旧variant副本覆盖。

这是符合旧schema1字段与验证算法的导出投影，不能称为旧执行器的完整历史录制。
尚未执行旧Android进程导入；新备份模块的旧包导入亦不由此变更实现。
schema22只增加持久移植封印，复用同一AppStore，不建立第二数据库。
同源序号和链头导出必须匹配已保存签名与固定本机公钥，损坏拒绝重签替换；流式生成
期间当前投影可能变化，不同链头独立保存，不覆盖此前封印。
Markdown与ZIP均先封印快照，导出取消保留已有封印，不记录虚构保存成功。

## 诊断阅读投影

外部Markdown恢复旧64 KiB单payload/8 MiB总预算，失败和取消证据优先；相同正文只
展开一次，后续链接到首次SHA256锚点。当前及历史消息按首尾各32 Ki UTF-16单元展示，
Unicode边界无损，明确省略标记，源正文和ZIP完整保留。动态围栏避免正文反引号关闭
外层Markdown。账户邮件、username/userId/accountId/deviceId/serial和私有Windows、
Unix home、Android路径采用稳定SHA256前12位假名；重复处理保持稳定。
这不保证识别任意秘密或任意个人信息，ZIP为可读明文，本机存储保护不等于导出加密。

## 验证与回滚

验证独立Node中文/Emoji哈希向量、真实WindowsP256链头签名、正文hash、引用顺序、
修订指针/当前投影、签名损坏、重开复用、variant编辑、脱敏幂等/围栏/预算及源文保留。
完整verify、相关FFI/UI和两端构建按正式入口执行；设备Keystore、旧进程导入、SAF、
像素/触摸/Profile与Apple保持单列。schema22回滚需升级前一致数据备份。
