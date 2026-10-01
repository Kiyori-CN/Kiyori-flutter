# 代码组织与语言约定

## 依赖与目录

采用模块化单体和按领域纵向组织；只有独立生命周期、可复用 API 或独立构建确有收益时
提取 package/crate。现阶段维持 app、UI、bridge、core、FFI 五个实际边界，不预建空层。

- `app` 装配 feature、路由与生命周期；feature 不 import app。共享 UI 放 `kiyori_ui`，
  跨功能命令由装配层注入，不能通过全局 service locator 绕回 Shell。
- `features/<domain>/presentation` 保存页面和短暂交互；controller 只在异步状态/生命周期
  需要测试时提取。不为简单静态页添加 repository/use-case/view-model 三件套。
- `kiyori_ui/lib/src` 保存组件，入口显式 export；不 import bridge 或业务 feature。
- `kiyori_bridge` 是 Dart 稳定边界，生成文件在 `src/generated`；应用不直接 import generated。
- `kiyori_core` 不依赖 FFI、Flutter、UI 或具体 Android API；`kiyori_ffi` 仅做句柄与 DTO 映射。
- 运行检查属于 `app/diagnostics`，不占产品 settings。实际业务目录创建时同步模块目录。

## 各语言职责

| 语言 | 约定 |
| --- | --- |
| Dart | `dart format` + Flutter lints；类型化不可变快照，局部 Listenable；Future 要 await 或明确 unawaited 并保证错误可见；dispose 释放 controller/subscription |
| Rust | edition 2024、rustfmt、Clippy；公开错误类型、无业务路径 unwrap/panic；资源 RAII、取消传播；runtime 拥有后台任务，不在 UI 等待锁 |
| Kotlin | 薄 Android adapter，协程生命周期和主线程 View 约束显式；不建立第二业务数据库 |
| Swift | 薄 Apple adapter，明确 MainActor/任务取消与安全访问范围；未编译不标已验证 |
| C++ | 薄 Windows runner/原生绑定，RAII、错误码和明确句柄所有权；不把领域规则写进 runner |
| PowerShell | 7+、参数化、原生退出码检查、try/finally 恢复位置/环境；不拼接用户输入成命令，不强改机器全局工具 |

文件名、标识和稳定协议见[命名规范](../architecture/naming.md)。测试与源文件按领域对应，
测试名描述用户行为和失败路径。生成代码使用生成器格式，不手工维护副本。
自有文档/脚本使用 UTF-8 无 BOM、LF；生态 runner 固定名称及二进制资源不机械改名。

## 新功能最小交付单元

一个真实用例应同时给出：旧源码来源、唯一状态 owner、输入输出、错误/取消、权限边界、
平台差异、UI 契约、性能场景和验证证据。新增依赖先查官方稳定版本及许可证；锁文件提交，
不写 dependency_overrides 强行破坏 Flutter SDK 的测试依赖组合。

以测试证明行为，不用“文件必须存在”的镜像测试替代功能验收。基础检查只守住版本接线和
实际已发生的依赖反向问题，避免维护大规模脆弱哈希门禁。测试/构建/人工检查以
[验证策略](testing.md)为入口。
