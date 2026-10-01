# Kiyori 核心语义

本文保存跨模块共同使用的定义。M1 已实现运行时与工程骨架，其余领域仍为设计契约，实施状态以 [docs/status.md](docs/status.md) 为准。

## 术语

| 名称 | 定义与唯一职责 |
| --- | --- |
| Workspace | 用户工作空间，隔离会话、资源引用、配置与授权；不是操作系统目录的别名 |
| Assistant / Run | AI 交互入口 / 一次可取消、可审计的助手执行 |
| Tool | 带输入输出 schema 和能力要求的单个操作；人类和 AI 调用同一应用服务 |
| Capability | 平台能力及授权范围；可用性、用户授权、运行状态分别建模 |
| Script | 受限执行器内运行的程序，通过宿主 API 调用工具 |
| Plugin | 可安装、可启停、带 manifest 与版本的扩展包，不等同于 Flutter 原生插件 |
| Skill | 遵循 Agent Skills 格式的知识与工作流包；其文字不会授予权限 |
| MCP connection | MCP 客户端连接，工具与资源映射进入统一执行和授权系统 |
| ResourceRef | 稳定资源标识；可对应文件路径、Android URI、iOS 授权 bookmark 或托管 blob |
| BrowserSession | 一份浏览会话模型与一个明确拥有者管理的原生视图实例 |
| Transfer | 可持久化下载任务；任务状态与 OS 后台传输句柄通过 adapter 对账 |
| PlaybackSession | 音视频共用的队列、播放控制与设备状态；只有一个活跃控制所有者 |
| Native adapter | 项目编译时接入的平台系统能力，区别于用户安装的 Plugin |
| DocumentSession | 同一文档的 revision、草稿、保存状态与阅读位置；资源访问复用 files |
| Knowledge space | workspace/角色内的记忆、日记、知识与关系范围；向量为可重建索引 |
| WorkflowRun | 固定定义版本的一次节点执行；复用 tools 与授权，不拥有平行执行器 |

## 不变量

UI 以旧 Kiyori Android 为保真基线；跨平台重构调整代码与目录，不改变已经确定的产品设计。首页为负一屏 / 首页 / AI 对话三页横向布局，首页底栏仅五个图标，无文字标签。未接入动作不创建业务副作用，具体尺寸与状态见 [UI 复刻契约](docs/design/ui-parity.md)。

`HomeShell` 唯一持有一级目的地与浏览器返回来源。四个一级页面属于 Dart UI 投影，
不是可用业务能力；浏览器默认空白窗口外观不建立 BrowserSession，文件统计不伪造数据。
按访问保留轻量页面的滚动/折叠状态，隐藏页暂停 ticker，不产生 I/O；首页 pager 和 AI
草稿在页面往返时继续保留。设置入口不打开开发诊断。

1. 同一个业务事实只有一个权威来源。Rust 保存业务事实；Dart 显示订阅到的快照；原生引擎拥有不可序列化的真实句柄。
2. AI、插件与手动操作调用同一工具服务；网络内容、Skill 与 MCP 返回值均是数据，不能增加权限。
3. 本地资源不等于绝对路径，平台能力不等于授权，任务取消不等于已经撤销外部副作用。
4. 默认使用本地工作空间；凭据由系统安全存储持有。日志不记录密钥、完整私密提示词、浏览 Cookie 或令牌。
5. 不共享新旧应用的数据目录、签名外的身份、Provider authority、终端 home 或无鉴权服务端口。
6. iOS 未在 Mac 上编译的部分保持 `verification_pending`；共享测试通过不能替代平台测试。
7. 页面预热只准备 UI，不启动领域 I/O；每帧偏移与输入只更新对应展示子树。性能证据必须注明设备、模式与刷新率。

## 权威入口

M1 运行时由 Rust `Runtime` 拥有；`RuntimeHandle`/`TaskHandle` 是 FFI 句柄。`NativeRuntimeClient` 提供 Dart 外观，按需拉取任务事件并投影为单订阅 Stream。诊断任务不是助手/下载任务，不保存用户数据。关闭会话取消其任务，取消订阅释放任务句柄；不可用产品能力返回 `not_implemented`，不伪装为可用。

- [架构与状态流](docs/architecture/overview.md)
- [命名与应用身份](docs/architecture/naming.md)
- [模块职责](docs/architecture/module-catalog.md)
- [数据与权限](docs/design/data-and-security.md)
