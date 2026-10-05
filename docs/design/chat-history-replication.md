# 对话历史左抽屉复刻方案

本轮基线为2026-10-05 `main/c8dc3274`，旧源只读
`D:\10_Project\Kiyori-Android/6b03b03`。实现与验收状态以[status](../status.md)为准。

## 来源、范围与验收

逐段读取旧 `ChatHistorySelector.kt`（搜索、状态、三级目录、管理、编辑、设置、
删除、创建、拖排、快滚）、`ChatHistoryPresentation.kt`、`ChatHistoryDelegate.kt`、
`ChatViewModel.kt`相关调用及`strings.xml`。模态几何来自`KiyoriModalBottomDrawer`、
`KiyoriDraggableBottomDrawer`与`KiyoriDrawerScaffold`，面板边界沿既有ChatPanelRoute。
详情实际为`ConversationDetailsScreen`审计工作台，不能由元数据编辑框代替。

| 项目 | 旧源要求 | 实施与证据要求 |
| --- | --- | --- |
| 会话生存 | 删除当前会话后切换；目录删空后新建 | Rust同事务回退/创建并设置active；并发和重开核对 |
| 左面板 | 标题16/24、计数11/16、头6、40按钮、42搜索、40新建、16列表边距 | 保留共享宽度和顶64.5内容边界；明暗/窄屏/大字截图 |
| 列表 | 角色24头像、14/20名称、22导轨；分组48与18图标；会话52与两侧48、14/20标题 | 无数量后缀角色、选中配色、生成/置顶/锁/分支状态；相对时间60秒刷新 |
| 滑动 | start编辑/end删除、96dp、primary/error与对应前景、锁定禁左滑 | 定值阈值、跟手与回弹、反向/取消、释放不提前删除、重复触发守卫 |
| 设置 | 3项卡片单选、说明12/16、标题14/20、内10/14、间8、两开关卡片 | 即时持久化；保存中反馈，完成只收起；固定标题/底操作与滚动正文 |
| 会话管理 | 8项、20图标、20横内距、48高、16图文间、语义色 | 排序边界禁用，上/下按搜索可见桶，置底完整桶；锁定说明 |
| 元数据 | 编辑标题、新标题、绑定角色卡、未绑定/角色/群聊、12间距、保存/取消 | 原ID/revision、失败留草稿、退出二次确认、失效实体释放 |
| 分组 | 管理/重命名/新建；只解散或连同聊天删除 | 当前角色/群组作用域和成员快照；全或无事务、锁定/生成拒绝 |
| 拖排 | 手柄、跟随让位、松手一次提交、可改分组/角色、置顶顺序约束 | 不在每次位移写库；失败回真实目录，空/折叠桶与搜索边界 |
| 快滚 | 右16轨道、上下16×48/14图标、thumb8/min36、track2 | 不挡更多；首尾按真实extent、大字半行不当到底 |
| 搜索 | 标题/分组和正文并集，正文至少2字符、400ms防抖 | 迟到拒绝、失败仅标题、清空和占位动作、折叠状态保持 |
| 详情 | 时间线/对话/原始事件、注释/导出与消息编辑 | 独立审计owner，完整数据与错误可观察，不伪造旧审计事件 |

## 方案与风险

阶段顺序为事务根因与目录作用域、抽屉内容与手势、嵌套模态/详情，再进行真实FFI
回归、截图审阅、完整verify和Android/Windows Debug构建。只修改本轮历史相关路径；
回滚参考为上述Git基线，数据库兼容变动需保留原会话。无依赖升级、设备安装、供应商
请求、发布或Apple构建。用户已授权最终提交普通推送至main。

Rust Runtime/SQLite继续唯一持久owner，Dart只管理草稿与几何。错误路径必须保留输入，
忙碌禁止重复提交；弹层固定实体身份和原路由实例，迟到结果不能关闭底层页面。
同名分组按作用域操作；成员增删/改版导致拒绝旧请求。删除所有聊天仍保留一条新的空会话。
未授权设备实测，Flutter截图与Debug构建不等于同设备像素、触摸、Profile或Apple验收。

## 已实施与实际边界

目录、绑定、删除替代、分组事务、排序和两种自动切换已接入既有Rust owner。菜单按
当前可见桶计算上/下移动，置底使用完整桶；拖排使用局部目录/几何投影，移除原项后插入，
让位前验证归属和置顶约束。失败恢复真实目录，不提交每次跟手位移。列表折叠状态保存
在既有聊天宿主，搜索期间临时展开；正文查询400ms防抖并拒绝迟到结果。

搜索依赖query与目录记录值；等值目录重读、草稿/忙碌/偏好通知只刷新投影，不重启正文
防抖。异步SQLite结果与即时Unicode标题/分组命中取并集，失败保留即时命中。正文至少
两个UTF-16单元，沿旧Kotlin长度语义，单个补充平面Emoji可检索正文；BMP单字只查标题/
分组。正文继续沿旧SQLite大小写规则，百分号/下划线为字面文字，不扩展为Unicode折叠。
标题/分组按旧Kotlin单字符忽略大小写比较，先大写再小写，覆盖词尾sigma和土耳其I；
不把ß扩展为SS。输入与目录变化时计算，跟帧通知不重复处理全部标题。

会话和分组弹层登记独立实体路由。实体移除后精确释放编辑框和所属放弃确认，保留
历史抽屉；错误保留草稿，处理中拒绝重复提交。设置即时保存、单一单选/开关语义、
紧凑卡片与固定完成操作均已实施。源码色表/尺寸逐项核对，尚无同设备像素差分证据。

拖排由`chat_history_drag.dart`投影一次手势，Rust/SQLite仍为唯一业务owner。沿旧
[Reorderable2.5.1](https://github.com/Calvin-LL/Reorderable/tree/v2.5.1)核对Press二维跟手、
覆盖条目中点让位、48dp手柄边界、viewport*0.5基速、阈值0/边缘5/越界10倍率与源项
可见距离上限；源项让到可见边缘后再滚动。释放弹簧700/临界阻尼/1px、邻项1500/1px。
只在边缘可滚动或动画中请求帧。Flutter公开列表没有让位前验证入口，因此复用框架
gesture arena、惰性ListView、Overlay和SpringSimulation，领域投影不依赖SDK私有索引。
非法首项/置顶落点不挤动邻项，不发移动触觉；拖动代理使用surfaceContainerHighest与
elevation6，横滑动作为空。跨角色头落为该角色未分组，空桶和折叠桶保留正确归属。
代理借根Overlay绘制顺序，但仍裁剪在旧列表内容视口内，不能盖住搜索和标题区域。
折叠桶没有可见锚点时，用完整目录最近同桶邻项表达旧仓储保留的相对位置；锚点revision
仍由真实事务校验，不能把隐藏成员当空桶。松手只提交一次，busy与同顺序回流不截断返回。
开始反馈LongPress，有效让位TextHandleMove；Android使用原生TEXT_HANDLE_MOVE(9)，
API<27不支持、不替换CLOCK_TICK(4)，拒绝与channel不可用返回事实；不强制系统设置。
iOS沿标准selectionClick，桌面无移动触觉；mock只验证合同，Android编译和设备另验。
旧库Cancel也调用onDragStopped，旧宿主因而可能提交草稿；本次将PointerCancel、搜索/
外部目录变化和宿主释放定为撤销不写库，第二指不接管首指，作为误操作修复。回归覆盖
这些边界及空/折叠桶、代理关闭横滑、释放动画和空闲无持续帧；设备手感仍待验收。

续批按旧AIChatScreen和ChatGroupTarget核对默认角色作用域：current同时显示默认
绑定与未绑定，character分别显示；列表、菜单、拖排和Rust排序桶一致。分组的
include_unbound请求值在打开时冻结，仅默认角色允许true，旧请求默认false；编辑器
initState读取成员版本，不能用直到保存才求值的late初始化掩盖并发变化。自动选择默认
角色沿既有select_latest包含未绑定，不再产生无必要的新会话。

分支时间与父标题采用旧同一行和AccountTree图标；角色/分组读屏标签带已展开/已收起，
会话带当前/置顶/锁定/生成状态，管理和拖动说明包含标题。滑动取消只回位；已触发
动作背景保留到400ms回位结束。背景越阈值和反向采用旧animateColorAsState的Oklab
临界阻尼弹簧（stiffness1500、dampingRatio1、位移阈值0.01），不改变600ms涟漪。
参数经本机Compose1.11.4 AAR/javap核对，色空间与连续速度算法参照
[AndroidX颜色转换](https://github.com/androidx/androidx/blob/androidx-main/compose/animation/animation/src/commonMain/kotlin/androidx/compose/animation/ColorVectorConverter.kt)及
[弹簧实现](https://github.com/androidx/androidx/blob/androidx-main/compose/animation/animation-core/src/commonMain/kotlin/androidx/compose/animation/core/SpringSimulation.kt)。
动画回归检查阈值中间帧、反向连续、回位背景、PointerCancel及结束后无持续请求帧；
五窗口捕获额外包含手机明暗的左右滑动背景，实际设备帧/像素仍待授权验收。

详情页已有时间线/对话/原始事件、搜索、展开、消息编辑与修订、追加备注、Markdown
及签名ZIP导出。真实基础记录由schema20保存，正文分页保留原文。旧版工具完整事件、
附件尚未接入；原始事件搜索仅覆盖已加载元数据。当前运行时未提供的完整工具执行
事实不补造，不能称为完整旧审计工作台。基础数据与回滚限制见[ADR0014](../decisions/0014-conversation-history-and-audit.md)。

续批按旧`SaveableStateProvider(tab.name)`保留各标签查询与滚动；非saveable的展开集
按旧`remember`在离开标签时释放。已加载目录和
时间线正文检索使用独立游标。旧`AuditRaw.loadedOnly=true`是原行为，搜索无匹配仍
提供“加载更早事件”，不是需要改成全记录搜索的缺陷。原始事件行采用12/5内距、
左侧空格补齐序号、12/16等宽JSON与18图标；时间线序号/类型/短时间同一行，首次和
查看底部时定位最新，上看时累计新事件入口。已加载页切标签不会缩回最近100条。

既有EventSender接入同Run的请求审计：真正发送前原子保存最终语义体和尝试开始，
HTTP响应只记录状态/协议，终态先等待在途写入/执行资源。HTTP、扩展最终handler、
本地推理最终输入以及自动/手动总结共用owner；失败阻止继续外发，不引入自动重试。
请求审计正文先遮蔽认证/自定义header值及常见凭据；原始聊天仍按既有契约保存。
旧工具执行事件尚未接入；请求钩子只能证明实际记录的请求与终态，不代表完整旧执行器。
产品原生正文保护与持久签名已接入，详见下述ADR0015/0016。

详情采用旧KiyoriSettingsTheme的页面/卡片/文字/弱化图标色表；卡片16、状态12、
输入14圆角，消息编辑220高、备注180高及8间距。对话标签只投影用户/AI消息，搜索
包含原消息时间戳；备注修剪首尾空白，消息修订允许空正文并保留消息身份/原文/用量。
正文展示按旧12000个UTF-16单元分页，相邻代理对边界同向调整；搜索展开从首个命中页
开始。传输仍是8192个SQLite字符的有界片段，缓存只随可见展开行存在。事件展开显示
旧元数据布局，已记录Run/终态由同一次SQLite分页查询投影，未知Provider身份不补造。
空闲弹窗允许遮罩关闭，写入中由PopScope拒绝退出与重复提交。

详情续核对恢复旧事件头各项8dp间距、展开分隔线前后7dp、正文组8dp。摘要允许长按
选择复制，同时保留单击展开；Flutter选择区域会消费tap，因此在文本内层保持同一展开
回调，长按仍由框架选择仲裁。正文加载中只显示20dp/2dp进度，失败显示旧错误文案、
异常类型与独立“重新加载详情”；不提前显示正文元数据，不回显异常中的路径或认证值。
重试成功后显示元数据和完整正文，收起等待中的正文停止后续分片与迟到回填，重开重新
读取同SQLite；不改变审计事实、schema、公开FFI或未接入的工具/附件业务边界。

安全增量按[ADR0015](../decisions/0015-audit-native-protection.md)把产品审计payload保护
及持久P-256签名接到同AppStore；schema21元数据不需要逐行解密正文。导出选项按旧
14圆角/页面背景/3间距，现有3间距已正确，修正剩余背景与圆角。安全端口本身不证明
归档格式兼容，产品格式以ADR0016为准。Android真实Keystore与Apple仍待验证。

产品导出已经按[ADR0016](../decisions/0016-portable-audit-export.md)改为旧schema1的
BASIC移植投影、链头ASCII封印与九类文件；原始源链和未知覆盖标记继续保留。
旧导入不在抽屉/详情入口，设备与旧Android进程兼容测试仍未运行。

## 完整工具与附件的后续实施条件

旧`ToolExecutionManager`1254–1394记录REQUESTED、STARTED、COMPLETED/FAILED/REUSED；
请求actor为PROVIDER，执行actor为KIYORI，绑定providerCallId。规范化arguments与
tool_result为独立payload，完整输出另保存为附件。旧`ConversationAuditSavedOutput`
仅支持linux_ssh/windows_control的显式输出文件，校验根目录、前缀、log类型与8MiB
边界；拒绝/丢失/超限保留捕获状态，使审计为PARTIAL并记录附件不可用原因。
新`core/chat/tool_probe`仅为无副作用echo模型探测，`core/files`只实现托管模型资源；
当前不能从这两者推导实际工具权限、执行或用户附件事实。

补齐应按依赖分四步，属于超出抽屉投影的M2业务范围，尚未实施：

1. 在同Runtime建立统一tools契约，手动与AI共用schema验证、权限裁决、撤销、超时和
   取消；引用既有ResourceRef与native句柄。先交付一个真实可授权用例，禁止第二文件
   数据库、独立聊天工具执行器或从结果文本读取任意路径。
2. 由实际执行owner在副作用前保存请求/开始事实，失败阻止执行；终态等待worker与
   资源释放，不把结果未知当成功或自动重试。事件固定Run、call和parent/source引用，
   工具输出通过明确ResourceRef进入审计，同一事务写事件/多payload引用与链。
3. 多payload保存label、ordinal、role、mediaType、encoding和字节数；保留现有已签名
   源链，采用版本化增量迁移，导出同时验证引用、全文哈希、捕获状态与封印。备份与
   回滚需覆盖数据库和平台密钥，不能改写旧签名或用COMPLETE冒充未知历史。
4. 详情按旧事件展开逐项呈现文本/二进制元数据、重试和分页；本地合成服务验证拒绝、
   撤权、取消、失败、重复调用、并发删除、重开、坏附件和导出篡改。真实供应商及
   设备SAF/Keystore/并排像素/Profile须另获对应授权；通过这些证据才关闭完整功能缺口。

回归入口为`chat_history_states_test.dart`和`chat_history_parity_test.dart`，使用真实
FFI/SQLite。`chat_history_drawer_capture_test.dart`覆盖390明/暗、320双倍字/180键盘、
844横屏和1280桌面的历史、设置、菜单、删除、编辑、分组、详情、备注及导出。
旧设置历史管理的`chat_history_capture_test.dart`完整保留。实际命令、结果和下一验收
门槛只记录到[status](../status.md)，失败日志保存在忽略的work。
