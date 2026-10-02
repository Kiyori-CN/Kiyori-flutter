# Kiyori 文档中心

本目录是项目方案的正式入口。先了解产品范围与技术决策，再阅读目录和模块设计；实施证据始终查看当前状态。

## 产品与决策

- [产品范围](product/scope.md)：目标用户、能力范围和非目标。
- [ADR 0001：语言与框架](decisions/0001-technology-stack.md)：候选方案、选择、成本与重新评估条件。
- [ADR 0002：交互与边界](decisions/0002-interaction-and-module-boundaries.md)：分页性能、模块化单体与原生方案的取舍。
- [ADR 0003：资料 Markdown](decisions/0003-profile-markdown-presentation.md)：编辑高亮、静态解析、展示与资源边界。

## 架构

- [整体架构](architecture/overview.md)：层次、状态所有权、依赖与调用流。
- [仓库布局](architecture/repository-layout.md)：目标目录树、模块拆分门槛和工作区规则。
- [命名规范](architecture/naming.md)：目录、符号、包名、应用身份与并存隔离。
- [模块目录](architecture/module-catalog.md)：各功能的所有者、输入输出、依赖和验收。
- [旧项目模块地图](architecture/legacy-module-map.md)：九个 Android 模块、领域所有者、迁移细节与审查范围。

## 领域设计

- [全页面 UI 复刻方案](design/ui-replication-plan.md)：分层顺序、组件复用、页面保真与持续验收。
- [UI 复刻契约](design/ui-parity.md)：原项目依据、首页三页、图标与底栏、空点击及验证范围。
- [角色卡与提示词](design/character-prompts.md)：旧源码深度、角色/群组成员草稿、目录身份、嵌套弹层与业务接入边界。
- [AI 与扩展](design/ai-and-extensions.md)：助手、脚本、插件、Skill、MCP 与工具执行。
- [浏览器与网络](design/browser-and-network.md)：会话、广告拦截、应用代理与系统代理边界。
- [文件、下载与媒体](design/files-downloads-and-media.md)：资源引用、后台任务、音视频与终端。
- [数据与权限](design/data-and-security.md)：存储、安全、权限、迁移、日志与依赖来源。
- [平台能力矩阵](design/platforms.md)：Android、Windows、iOS 的差异与验收缺口。
- [文档、知识与工作流](design/documents-knowledge-and-workflows.md)：文档/记忆/工作流、账号内容、语音形象与系统能力。

## 开发与交付

- [M1 工程骨架实施计划](development/m1-foundation.md)：正式 Goal、阶段任务与验收边界。
- [工具链基线](development/toolchains.md)：稳定版本、激活、安装与更新规则。
- [本机环境报告](development/environment-report.md)：实际探测、安装、构建与剩余缺口。
- [验证策略](development/testing.md)：哪些检查能证明什么，以及何时执行。
- [代码与语言约定](development/coding-conventions.md)：真实目录、依赖方向和各语言职责。
- [UI 复刻开发流程](development/ui-replication-workflow.md)：来源追踪、定向验证、截图与交付复用。
- [输入响应与帧性能](development/performance.md)：滑动优化、Profile 入口、真机指标与未验证边界。
- [路线图](roadmap.md)：各里程碑的输入、交付和完成信号。
- [当前状态](status.md)：唯一实施进度与下一任务入口。
- [历史实施记录](status-history.md)：保留历史批次证据，不代表当前授权或最新产物。
- [资料来源](references.md)：官方资料与核验日期。

## 文档约定

方案使用稳定英文路径和中文说明。`计划`表示尚未实现；`已实现`不自动表示设备验收通过；`待验证`必须写明缺少的环境或证据。ADR 决策可以随证据调整，但须记录取舍和影响面。
