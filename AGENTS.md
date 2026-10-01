# Kiyori 开发协作准则

本文件约束全新跨平台仓库的开发方式。全局准则继续适用；本仓库没有旧 Android 工程的 Gradle 根入口、terminal 子模块或旧文档检查器。

## 开始工作

1. 阅读本文件、[CONTEXT](CONTEXT.md)、[当前状态](docs/status.md)，再按任务阅读领域设计。
2. 检查 Git 分支、HEAD、暂存区、未暂存与未跟踪文件，保留已有工作。目标分支为 `main`；未经当前任务授权不提交、推送或发布。
3. 非简单任务维护可验证目标、范围、非目标、风险与验收方式。阶段进度仅以 `docs/status.md` 为准，长期顺序以 `docs/roadmap.md` 为准。

## 结构与实现

- 重构保留旧 Kiyori Android 的 UI 与交互。先核对旧源码的尺寸、资源、颜色、状态和手势，再迁移内部实现；未经用户要求不得重新设计界面。未接入功能保留原按钮外观与空点击，不替换为提示页、禁用灰态或开发说明。
- 遵循[仓库布局](docs/architecture/repository-layout.md)与[模块目录](docs/architecture/module-catalog.md)。功能按实际交付创建，不生成空实现、无用途 package 或重复 `common/utils/helpers` 层。
- 实施功能前按[旧模块地图](docs/architecture/legacy-module-map.md)核对来源；遵循[语言与代码约定](docs/development/coding-conventions.md)。feature 不反向依赖 app，公共 UI 不依赖业务。
- UI、流式内容与平台视图变更遵守[性能契约](docs/development/performance.md)：先消除主线程重复工作，Profile 真机测量；Debug 测试不能宣称触摸延迟或帧性能通过。
- Dart 管界面投影和交互；Rust 管共享业务、持久化和策略；原生适配管理系统句柄与生命周期。不得为 AI 再建一套浏览器、下载器或文件数据库。
- 平台不可用能力返回明确原因；不得静默回退、假成功或把未编译 iOS 代码称为已验证。
- 官方协议、语言标准库与第三方依赖保留其准确名称和许可证；项目自有命名使用 Kiyori，不复制其它产品品牌或代码布局。
- 跨 FFI、平台通道和扩展的公共契约变化需考虑取消、超时、错误、资源释放、权限与兼容性。
- 修改文件用补丁或明确 UTF-8 的编辑工具；禁用 PowerShell 文本替换来编辑代码。搜索优先 `rg`。
- 默认不派子智能体。外部 skill 使用其指定绝对运行时；仓库若引入 Python，必须先建立本项目独立虚拟环境。

## 文档职责

- README 面向使用者和开发上手；CONTEXT 保存高频术语与不变量；AGENTS 保存工作规则；docs 保存正式设计与验收证据。
- 中文正文、稳定英文路径；UTF-8 无 BOM、LF、末尾换行。新文档加入 `docs/README.md`，不再维护第二套自动目录。
- 变更技术决策时新增或替代 ADR；文档中明确计划、已实现与已验证，不能混写。

## 验证和交付

- 文档变更执行 `tools/check-foundation.ps1`；实现变更执行 `tools/verify.ps1`，涉及打包/桥接时追加 Windows 集成和相关平台构建。
- 公共 Rust API 变化后执行 `tools/generate-bridge.ps1`，再用 `-Check` 核对再生成一致性。不能手改生成文件；生成脚本最终统一 Cargo edition 下的格式。
- 按[验证策略](docs/development/testing.md)执行相关静态检查、测试及 Android/Windows 构建。iOS 仅在 Apple 环境运行真实构建。
- 工具版本来自 `toolchains.json`；升级先查官方稳定渠道，再验证相关最小工程和实际工程。不能仅靠版本号或 doctor 判定构建通过。
- 交付报告包含范围、实际文件、命令与产物、未验证边界、Git 状态、下一步。设备安装、远端 CI、发布与云资源需对应授权。
