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
上游索引会合并完全同名条目，流式reader不能验证未知大小descriptor。因此读取公开
header_start/data_start/central_header_start，核对连续局部/中央条目、名称、标志、大小、
CRC与32/64位descriptor；缺项/重复项造成间隙或不一致，明确拒绝。解压/实际CRC和
ZIP64目录解析继续使用zip，不直接extract。布局字段依据[PKWARE规范](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT)。

清单合同支持schema1/2 JSON/HJSON和单JS入口，distribution.include只作构建元数据，
schema2要求非空，安装不执行glob。API缺键默认1.0.0，1.0.1复用相同已实现的窄宿主，
旧首批1/1.0别名继续可读；API版本声明不授予额外能力。版本缺键为空，有界文本保留
预发行版本。根HJSON/根JSON/嵌套HJSON/嵌套JSON按旧优先级、深度、名称选唯一清单，
失败不回退；JS入口相对选中清单父目录，大小写别名仍拒绝。
采用[serde-hjson1.1.0](https://docs.rs/serde-hjson/1.1.0/serde_hjson/)，关闭默认排序feature；
JSON/HJSON共享自定义visitor，在递归前限制32层、每容器1024项，拒绝重复键和尾部内容。
HJSON单/双引号和多行字符串按旧hjson-java3源码的转义/缩进规则进行有界词法归一化，
注释和无引号正文不参与替换；避免上游旧语法子集遗漏单引号、以及中文索引panic。
不支持依赖、环境变量、subpackage、wasm/native资源、工作流或workspace模板，不能称所有旧包可用。
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

AI抽屉的插件管理复用同一包目录与change_extension。详情端口按revision持包共享租约，
blocking worker有界核验原archive摘要并读取作者、分类和API版本；关闭取消并等待租约。
Windows/Android的TOOLPKG选择复用模型文件的句柄/SAF端口与1 MiB分片，只增加文件类型。
导入模态等待文件及Rust暂存释放；取消不写目录。启停不乐观修改事实，失败重新读取；
卸载确认绑定原revision，包变更/删除时精确关闭所属详情与确认。UI不获取路径或URI。

core回归覆盖安装/升级/重开/启停/墓碑代次、四handler、取消等待、跨Runtime共享锁、
CRC/路径/未知native、入口篡改和pending恢复；真实FFI测试执行合成包的QuickJS、SQLite
及订阅/未消费关闭。当前验证结果见[status](../status.md)，不把计划写成实证。
依赖许可证随产品LicenseRegistry注册。生成公共桥，定向→完整verify、Windows集成及
Android/Windows构建；设备与Apple独立待验证。schema19禁止旧二进制打开新数据，回滚
使用一致备份与配套二进制，不改user_version或删除用户配置。
