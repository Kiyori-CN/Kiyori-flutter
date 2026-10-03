# AI 抽屉、关联页面与业务复刻映射

产品来源固定为只读 Kiyori-Android revision
`6b03b03aa082803bb279db5e78773583e2d91154`。下列旧路径相对
`app/src/main/java/`，新路径相对仓库根。实现证据和当前进度只在
[status](../status.md)更新；本表定义来源、范围及验收契约，不能把入口存在视为业务完成。

## 抽屉与根目的地

旧 `com/kiyori/app/shell/KiyoriAiDrawer.kt`、`com/kiyori/design/theme/KiyoriDrawerGeometry.kt`、
`com/ai/assistance/operit/ui/main/screens/ScreenRouteRegistry.kt` 和
`com/kiyori/integration/operit/navigation/OperitNavigationStackPolicy.kt` 共同决定根目录。
新 `apps/kiyori/lib/features/assistant/presentation/ai_drawer.dart` 只投影目录和状态，
`app/shell/home_shell.dart` 唯一持有根导航；同项仅关闭，换项保留已访问根内容。

| ID / 入口 | 旧来源 / 子树 | 新 owner 与验收 |
| --- | --- | --- |
| main.ai_chat | AIChatScreen、ChatHistorySelector、聊天详情及角色选择 | assistant；草稿跨抽屉切换保留，后续会话/消息由 Rust 持久化 |
| main.packages | PackageManagerScreen，PACKAGES、PLUGINS、SKILLS、MCP 四标签 | extensions；包环境、市场、增删/刷新、MCP启动和错误；尚未接入 |
| main.toolbox | ToolboxCatalog 及对应 ScreenRouteRegistry 工具目录 | 复用 toolbox 一级页，AI 内部导航保持原来源，不能跳底栏 |
| main.workflow | WorkflowListScreen、WorkflowDetailScreen、WorkflowViewModel、WorkflowRepository | workflows；定义目录→创建→详情→删除，模板/节点/执行/调度另按旧源推进 |
| main.memory_base | MemoryScreen、空间/文件夹导航和导入目标身份 | knowledge；空间、目录、手工记忆/笔记、归档与删除接入同一SQLite；日记/导入/图谱另行推进 |
| 动态插件 | KiyoriNavigationDrawerContent、plugin keepAlive 策略 | 只消费正式插件目录，不注入产品演示插件 |
| main.settings | KiyoriDrawerFooter → 设置主目录 | SettingsNavigation，压栈后返回准确 AI 根目的地 |

抽屉宽度：小于600为75%，600–839为320，840及以上360；280ms fastOutSlowIn、
0.32遮罩、右侧16圆角、elevation8、状态栏内边距。头部上边30来自24+6，
快捷项最小80、导航行最小44/横16纵7、图标30/18、footer胶囊46×36且点击48。
大字可增长；窄屏标题无法同排时上下排列，不省略产品名。扩展粉色、退出粉色分别按旧语义。
未知网络与未连接目录显示省略号，不以零或“有网络”伪造事实。折叠屏分区仍需专项补齐。

## 工作流定义存储切片

旧 WorkflowRepository.getAllWorkflows 按 updatedAt 降序；WorkflowViewModel.createWorkflow
分配稳定身份与时间；CreateWorkflowDialog 名称单行、描述3–5行、间距12，名称非空才允许创建。
新 core/workflows 持有 SQLite 定义，runtime 管关闭与唯一写入入口；bridge仅做类型映射，
feature/workflows/presentation 的 WorkflowController 只保存不可变投影。

空目录依据 WorkflowListScreen：72/38图标，24标题间距、8描述间距、32按钮间距、
按钮最小48；列表横纵20、卡间12、卡内18。详情空画布依据 WorkflowDetailScreen，
创建成功进入新实体；删除必须确认并在成功后回到列表。旧没有名称长度上限，不补造限制。
列表只显示节点数及更新时间，不补造连接数；名称单行省略，启用开关按橙色0.82缩放。
右下浮动菜单承载新建、模板、多选和详情操作；模板/节点/执行日志仍保留未接入边界。
编辑名称/描述/启用状态提交后读取权威快照；多选提供全选/清空/退出，确认批量删除时
冻结ID列表，Rust以一个事务原子删除。重复ID不重复计数，失效ID不删除其它实体。

业务错误必须可见；写入失败保留输入，重复提交互斥。提交成功而刷新失败明确区分，
不诱导用户重新创建。并发读取只有最新请求能发布；写入撤销旧读取发布资格。
关闭 runtime 等待已开始的短事务结束并释放连接，随后操作拒绝；关闭页面不撤销已提交数据。
本切片不包含节点、连接、执行日志、调度、工具授权或外部副作用，空节点数仅描述空白定义。

## 后续 AI 垂直切片边界

记忆根切片来源为MemoryLibraryContent、FolderNavigator、MemoryFolderBrowsePolicy、
EditMemoryDialog与MemoryInfoDialog。空间默认ID为default，禁止删除；删除其它空间在
事务内回到default并级联删除所属条目/标签/目录。编辑固定space+id，不能以当前空间替换。
新建手工记忆与知识笔记保持标题/正文必填、主题六类、目录、标签、来源、高级可信度0.8/
重要性0.5默认；退出脏草稿确认，保存中拒绝退出。正文只在列表投影400字符摘要，完整
内容按身份读取与保存；页面和Rust均不能以列表摘要覆盖正文。查询在Rust执行、每页100，
更多结果显式加载；目录直接子级和筛选子树分开，路径%/_按字面处理。
目录重命名同时移动子目录和条目；删除目录只把正文移到根，不删除条目。
日记类型需要阶段和追加记录语义，本切片不把普通文本CRUD包装成日记；导入资料、图谱、
语义检索及云设置动作仍保持未接入边界。存储及迁移只在core/storage统一维护。

会话/消息及流式请求沿 AIChatScreen 的实际调用链继续清点，至少追踪历史、模型配置、
取消/错误、角色/群组/提示词、上下文、附件和工具授权的真实 owner；不凭功能名称生成假实现。
数据与权限遵守[存储设计](data-and-security.md)，所有工具共用一个执行与授权边界；
浏览器、下载、文件、记忆不因 AI 再建立平行服务。供应商请求需要独立凭据与本任务授权边界。

## 验收证据入口

`apps/kiyori/test/ai_drawer_test.dart` 覆盖尺寸/明暗/大字、返回/遮罩/同项、工具箱/设置来源、
草稿保持和动态列表。`workflow_test.dart` 覆盖投影竞争、提交/错误和页面交互。
Rust workflows tests 覆盖真实数据库重开、中文、schema拒绝、损坏保留、并发与关闭；
`packages/kiyori_bridge/test/native_runtime_test.dart` 补真实 DTO、持久化、删除和关闭证据。
截图、完整verify、Windows引擎及双端构建结果以status实际记录为准，设备/Profile/Apple单列。
