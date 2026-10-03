# ADR 0005：由既有 Runtime 持有 SQLite 存储

日期：2026-10-03。状态：已实施，Android/Windows 本机验证通过，Apple 待验证；具体证据以当前状态为准。

## 问题与选择

工作流目录开始需要真实创建、重开读取和删除；Dart 临时草稿不能承担业务持久化。
选用 rusqlite 0.40.2 的 bundled SQLite，由现有 Rust Runtime 唯一拥有连接与写入协调，
不增加 crate、全局 service locator 或第二 runtime。相比 Dart SQLite，业务状态仍留在
Rust；相比手写 JSON，多表事务与后续版本迁移不需要重新搭建存储协议。

应用装配通过 Flutter 官方 path_provider 2.1.6 取得 Application Support 目录，并将
绝对目录传给桥接创建函数。core 只访问新应用目录内的 `kiyori.sqlite3`，不读取旧库。
无目录的诊断 runtime 继续支持原集成探针，但持久化调用明确失败，不回退到内存假成功。

## 契约、失败与回滚

schema1 保存工作流定义元数据，user_version 在迁移事务提交；更高版本或损坏数据库拒绝
写入，禁止覆盖/重置。索引支持 updatedAt 降序，等时创建通过数据库事务取得递增时间和随机ID。
事务短且同步，FRB工作线程执行I/O；持锁期间无网络/UI等待。外部锁等待最多3秒，错误回传。
runtime关闭与存储操作串行：已有事务可完成，关闭后拒绝新操作并释放连接。

schema2追加空间、目录、条目与标签，core/storage统一连接与迁移，workflows/knowledge
共享该连接。迁移只添加新领域表，不重写工作流；schema1旧版本会拒绝schema2，代码回退
不能降级写入。需要回退时保留新库，恢复迁移前另存的库；不自动删除新写入记忆。
列表查询在Rust执行，每次最多100条摘要；全文按身份单读，不把整库正文传给Dart搜索。

UI投影只在目录读取成功后发布，写入后的读取失败单独提示已保存。局部页面退出不把
事务成功称为取消；迟到返回不重开页面。当前没有全库加密、凭据存储或自动旧库迁移。
批量删除合并为一个短事务，区别于旧JSON逐文件删除可能半成功；正常选择与确认外观保留。
回滚代码前保留应用私有目录；未来schema升级必须单独设计备份与回滚，旧版本不能降级写入。

## 依赖与平台

[rusqlite 官方项目](https://github.com/rusqlite/rusqlite)采用 MIT，bundled SQLite由
libsqlite3-sys编译，SQLite为public domain；避免依赖宿主系统SQLite版本。
[path_provider](https://pub.dev/packages/path_provider)为Flutter维护、BSD-3-Clause；
Android/iOS/Windows Application Support 均受支持。Android/Windows实际编译是本批门槛，
Apple无环境不宣称验证；传递原生包按lock和实际构建记录。未升级Flutter/Rust工具链。

## 验收

真实临时数据库验证首次迁移/重开/删除、损坏与未来版本不覆盖、并发身份与关闭后拒绝；
真实FFI验证DTO和异常，Flutter验证草稿/错误/导航与迟到结果，Windows引擎验证实际插件
和桥接打包，最后串行构建Android/Windows。具体执行与产物哈希只在status及本机manifest记录。
