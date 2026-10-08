# Kiyori 核心语义

本文只保存跨模块高频术语、唯一所有者与不变量。领域细节见[运行契约](docs/architecture/runtime-contracts.md)，实际进度见[当前状态](docs/status.md)；未实现的目标设计不能当作可用能力。

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

## 状态所有权

| 事实 | 唯一所有者 | 其它层边界 |
| --- | --- | --- |
| 配置、会话、消息、知识、工作流定义与包目录 | Rust `Runtime` / `AppStore`，同一 SQLite 与迁移入口 | Dart 通过桥接取得快照、提交类型化命令 |
| 模型请求、取消、限流与用量 | 同一 Runtime 的请求链路 | UI 不建立 HTTP 客户端或第二凭据轮换器 |
| 凭据与审计保护密钥 | 平台安全存储 / 原生 adapter | SQLite 保存引用；正文保护不等于全库加密 |
| 系统视图、文件选择器、推理与脚本句柄 | 对应平台 adapter | 核心持有稳定身份与生命周期，FFI 负责装配 |
| 导航、动画、焦点、输入草稿 | Dart 宿主与页面控制器 | 草稿、加载快照和空点击不代表业务成功 |

## 不变量

1. 同一个业务事实只有一个权威来源。Rust 保存业务事实；Dart 显示订阅到的快照；原生引擎拥有不可序列化的真实句柄。
2. AI、插件与手动操作调用同一工具服务；网络内容、Skill 与 MCP 返回值均是数据，不能增加权限。
3. 本地资源不等于绝对路径，平台能力不等于授权，任务取消不等于已经撤销外部副作用。
4. 默认使用本地工作空间；凭据由系统安全存储持有。日志不记录密钥、完整私密提示词、浏览 Cookie 或令牌。
5. 不共享新旧应用的数据目录、签名外的身份、Provider authority、终端 home 或无鉴权服务端口。
6. 五平台共享 Dart/Rust 契约；当前实际构建验收目标为 Android/Windows。iOS/macOS/Linux 未在对应宿主构建的部分保持 `verification_pending`，共享测试不能替代平台测试。
7. 页面预热只准备 UI，不启动领域 I/O；每帧偏移与输入只更新对应展示子树。性能证据必须注明设备、模式与刷新率。
8. 产品 UI、布局、配色、文案、功能逻辑、交互、跳转、回退和弹层完全以 `D:\10_Project\Kiyori-Android` 为复刻基线。内部重构不授权重新设计产品。
9. 原文与审计事实保持完整；摘要、分页、列表摘录和检索索引均为投影，不能覆盖正文。
10. 已提交事实与迟到 UI 回填分开处理；revision、稳定 ID 与执行代次拒绝过期覆盖。生成器拥有桥接文件，不能手改。

## 权威入口

- [仓库布局](docs/architecture/repository-layout.md)：真实目录和依赖方向。
- [模块目录](docs/architecture/module-catalog.md)：已实现范围及后续领域归属。
- [运行契约](docs/architecture/runtime-contracts.md)：取消、事务、持久化及 UI 生命周期细节。
- [命名与应用身份](docs/architecture/naming.md)、[数据与权限](docs/design/data-and-security.md)。
- [文档中心](docs/README.md)：设计、ADR、开发、测试与历史证据。
- [平台矩阵](docs/design/platforms.md)：五平台宿主、实际接线、unsupported 与验证边界。
