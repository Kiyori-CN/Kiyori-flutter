# ADR 0015：审计正文保护与平台持久签名

日期：2026-10-06。状态：已采用；平台验收边界以[status](../status.md)为准。
本决策替代[ADR0014](0014-conversation-history-and-audit.md)中产品使用临时Ed25519密钥
的实现选择；独立事件哈希格式与旧包尚不兼容的事实继续适用。

## 来源与职责

旧`ConversationAuditCrypto.kt`使用Android Keystore的AES/GCM/NoPadding和P-256
SHA256withECDSA，正文与签名不同用途的密钥分别管理。新`core/audit_crypto`只定义
正文保护、解保护与签名端口，`platform/audit`持有平台句柄，FFI在Runtime发布前装配。
业务、迁移、事件链与封印仍归同一个AppStore，没有第二数据库或Dart审计存储。

Android沿用旧alias，AES256/GCM随机12字节nonce与128位tag；P-256私钥不导出，公钥
为X.509/SPKI、签名为ASN.1 DER。宿主启动先绑定app类，blocking worker使用JNI调用，
不持有Activity；异常映射为不含正文和密钥的错误。Windows采用ring AES256/GCM与
P-256；AES和ECDSA为不同密钥，密钥包只经当前用户DPAPI加密后保存。系统保护不代表
硬件身份，也不证明作者可信。固定密钥由OS锁串行创建，损坏或已初始化后缺失拒绝替换。

选择现有锁文件中的jni0.22.4和windows-sys0.61.2作为直接平台依赖，不升级其版本。
JNI是接入Keystore句柄的必要桥，Windows绑定用于DPAPI及系统内存释放；许可证随包
保存。rusqlite增加functions功能以在同连接内执行受控保护/解保护，不开放脚本SQL入口。
安全函数标记DIRECTONLY，不能由数据库视图或触发器间接调用。

## 存储与回滚

schema21增加正文字符/字节数、Run与终态投影、不可更新封印和安全公钥记录。
事件payload保存`kiyori-audit-encrypted-v1:`加Base64封套，nonce置于密文前；链仍绑定
原始明文字节。升级把旧明文payload一次事务转为密文，失败恢复原schema、正文和不可
更新触发器。secure_delete清理被SQLite释放的旧页内容，但不保证OS、旧备份或历史日志
中的副本擦除。会话原文和其他业务表仍遵循原存储合同，不能称全库加密。

安全公钥固定到同一SQLite；重开核对实际签名和公钥，并验证已有密文可解。密钥损坏、
丢失或替换均拒绝继续写入，不能用新身份掩盖旧记录不可读。数据库与平台安全存储必须
共同保留；复制数据库不等于跨设备迁移。schema21不能由旧程序读取，程序回滚须恢复
升级前的一致数据备份，不能删除新列或清理密钥冒充安全回滚。

普通列表直接读取大小与Run元数据，不为每条记录解密正文；正文搜索、展示和导出按
实际需要解密。正文分页仍8192字符，读取和导出边界不变；当前单payload解密需要完整
正文内存，不能以有界FFI分片声称整条正文始终只有一个分片的内存。

## 签名与兼容范围

当前产品ZIP仍是独立kiyori-audit-v1四文件包。SHA256withECDSA签名覆盖含事件/消息
文件哈希的seal.json，按会话与事件序号持久保存；同一快照重复导出复用已保存封印并
验证真实签名。它还不是旧版对链头ASCII签名的portable audit schema1，不能宣称旧包
可导入。旧payload refs、修订/投影、附件和完整旧归档的合同按下一切片接入。

未装配native的Rust参考构造器保留旧合成测试行为；产品FFI固定选择native端口，失败
不会回退。参考构造器拒绝打开已标记安全身份的库。尚未实现的Apple审计端口返回明确
失败，不以明文继续执行审计，其他无审计业务仍可初始化。Apple编译尚未验证。

## 依据与验收

2026-10-06核对[Android Keystore](https://developer.android.com/privacy-and-security/keystore)
与[KeyGenParameterSpec](https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec)、
[Microsoft DPAPI](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata)，
同时读取实际锁定的ring、jni、rusqlite和windows-sys源码。

自动验证需覆盖真实DPAPI/AES/P256、随机nonce、篡改拒绝、同身份重开、schema20
迁移、失败回滚、缺失/损坏密钥拒绝及封印复用；再执行真实FFI/Windows引擎集成和
Android普通构建并核对JNI符号。Android Keystore实际设备调用与进程重启、同设备
像素/触摸/Profile、Apple验收仍独立记录，编译不能替代这些证据。
