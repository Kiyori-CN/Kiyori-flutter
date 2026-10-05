# ADR 0012：持久 TOOLPKG 提供方包与撤销

## 状态与问题

2026-10-05接受。执行器端口见[ADR 0011](0011-controlled-script-executor.md)。本决策
建立真实包生命周期与FFI能力，产品管理UI、受控HTTP与ChatRun接线继续实施。
旧源custom_ai_provider的schema_version/toolpkg_id/version/main/本地化元数据和
enabled_by_default是输入合同；全局小写provider ID覆盖会混淆来源，不能继续沿用。

## 所有者与身份

core/extensions复用Runtime、AppStore、ResourceRef和core/scripts。schema19在同SQLite
增加extension_packages和extension_installs，无第二数据库。包保存JS源和原始archive，
公开接口只接受1 MiB分片，不接受UI路径。资源ID为SQLite生成的32位hex；包ID只作身份，
锁文件名由摘要产生，不能形成宿主路径。

目录键为TOOLPKG:package_id:provider_id，调用还必须匹配包revision。启停、升级、卸载
推进revision；卸载保存墓碑，重装不复用旧代次。配置引用保持原值，后续产品执行必须对
撤销或缺失来源明确失败。升级保持已安装包启用状态，新装沿旧enabled_by_default。

## 包校验与原子发布

固定官方zip8.6.0，MIT，关闭默认feature，仅Stored/Deflated与纯Rust zlib-rs；
[官方API](https://docs.rs/zip/8.6.0/zip/read/struct.ZipFile.html)用于路径、链接、CRC与重叠检查。
上游索引会合并完全同名条目，先通过公开流式读取端口核对实际局部条目，再用中央目录
核对路径/大小/CRC和重叠；不直接extract，不自行解析ZIP结构。

首个合同只接受schema1 manifest.json和单JS入口，不支持HJSON/schema2、依赖、环境变量、
subpackage、wasm/native资源、工作流或workspace模板。ZIP局部头必须含真实大小和CRC，
data descriptor包当前明确拒绝；此兼容缺口需继续处理，不能称所有旧包可用。
限制：archive16 MiB、条目1024、解压总16 MiB、单文件4 MiB、manifest64 KiB、JS2 MiB、
压缩比200。所有路径复用files有效相对路径规则，拒绝链接、特殊文件、大小写别名、
dot目录/私密文件、加密、未知压缩、原生/bytecode。完整校验后在正式QuickJS运行注册，
必须获得合法非空四handler目录；注册阶段中间业务输出拒绝。

每次安装先写资源与pending账本，再落盘同步JS、同卷rename原包，最后事务切换目录和
资源引用。断电前后只能保留旧注册或完整新注册；未完成资源由账本恢复。不递归删除，
只回收该owner的source.js/archive.toolpkg；未知文件/链接拒绝回收，cleanup_pending
对FFI可见。已提交事实不因维护失败伪报未安装/未卸载。

## 取消与并发

Runtime内串行变更，OS全局变更锁防止多进程同时维护。调用持有包共享锁与取消token；
变更先阻止同包新调用，取消本运行时在途与排队调用，等待worker析构释放租约后取得
包独占锁。其他Runtime/进程仍使用时明确忙，不能强行删除其资源。

ScriptRun持租约直至adapter返回，终态不依赖事件消费者；Runtime.close等待同一scripts
worker。包入口每次读取验证摘要，篡改/缺失拒绝。安装Future丢弃取消内部任务，显式close
等待安装操作结束再释放暂存，不与在途解析/注册争删。文件读写与执行均在Rust/FFI侧，
大型校验进入blocking worker，Dart保持界面投影。

## 验证与剩余边界

core回归覆盖安装/升级/重开/启停/墓碑代次、四handler、取消等待、跨Runtime共享锁、
CRC/路径/未知native、入口篡改和pending恢复；真实FFI测试执行合成包的QuickJS、SQLite
及订阅/未消费关闭。当前验证结果见[status](../status.md)，不把计划写成实证。
依赖许可证随产品LicenseRegistry注册。生成公共桥，定向→完整verify、Windows集成及
Android/Windows构建；设备与Apple独立待验证。schema19禁止旧二进制打开新数据，回滚
使用一致备份与配套二进制，不改user_version或删除用户配置。
