# 仓库布局

## 设计原则

根目录表示工程角色，角色内部按语言生态和领域命名。初期采用模块化单体，不把每个页面拆成 package，也不预造几十个 crate。目录只有在承载真实实现、测试或文档时创建。

下图是**目标布局**；M1 已建立 `apps/kiyori`、`kiyori_ui`、`kiyori_bridge`、`kiyori_core`、`kiyori_ffi` 与根 Pub/Cargo workspace。当前尚无原生系统能力，`kiyori_platform` 随首个真实 adapter 创建；业务 feature、SDK、extensions 和 CI 也按实际需求建立，不放空 `.gitkeep` 或假实现。

```text
Kiyori/
├── apps/
│   └── kiyori/                    # 唯一 Flutter 产品入口
│       ├── lib/
│       │   ├── app/               # 启动、路由、依赖装配、外壳与 diagnostics
│       │   ├── features/          # 按用户功能组织 UI 和交互状态
│       │   │   ├── assistant/
│       │   │   ├── browser/
│       │   │   ├── toolbox/
│       │   │   ├── files/
│       │   │   ├── downloads/
│       │   │   ├── video/
│       │   │   ├── music/
│       │   │   ├── extensions/
│       │   │   ├── terminal/
│       │   │   └── settings/
│       │   └── l10n/              # 本地化资源
│       ├── android/              # 薄 runner、清单、签名接线
│       ├── windows/              # 薄 runner、窗口与打包接线
│       ├── ios/                  # 薄 runner、权限与签名接线
│       ├── assets/
│       ├── test/
│       ├── integration_test/
│       └── test_driver/           # Profile 基准结果回收入口
├── packages/
│   ├── kiyori_ui/                # 语义颜色、排版、组件与响应式原语
│   ├── kiyori_bridge/            # Dart FFI 外观和独立 generated/ 区
│   └── kiyori_platform/          # 类型化系统接口与原生实现
│       ├── lib/
│       ├── android/
│       ├── windows/
│       ├── ios/
│       └── test/
├── crates/
│   ├── kiyori_core/
│   │   ├── src/
│   │   │   ├── assistant/        # 会话、provider、执行编排
│   │   │   ├── tools/            # 工具注册与调用，非仓库开发脚本
│   │   │   ├── extensions/       # scripts/plugins/skills/mcp
│   │   │   ├── browser/          # 会话元数据与浏览策略
│   │   │   ├── files/            # ResourceRef 与文件操作契约
│   │   │   ├── downloads/        # 下载状态机与恢复
│   │   │   ├── media/            # 库、队列、播放命令
│   │   │   ├── network/          # 应用网络策略、代理配置
│   │   │   ├── adblock/          # 规则、编译快照、站点策略
│   │   │   ├── terminal/         # 进程会话策略与任务模型
│   │   │   ├── permissions/      # 授权判断与撤销
│   │   │   ├── tasks/            # 公共任务生命周期与取消
│   │   │   ├── storage/          # SQLite、迁移、仓储实现
│   │   │   └── platform/         # 宿主能力端口，不包含三端业务副本
│   │   └── tests/
│   └── kiyori_ffi/               # 对外 API、DTO、装配与代码生成边界
├── sdk/
│   └── typescript/               # 扩展作者 API/schema 类型及构建工具
├── extensions/                   # 随仓库维护的第一方扩展与可运行示例
│   ├── scripts/
│   ├── plugins/
│   └── skills/
├── tests/
│   └── fixtures/                 # 跨语言协议与场景夹具，不重复单元测试
├── tools/                        # 本仓库开发/检查脚本，非应用内脚本
├── docs/                         # 正式产品、架构、领域设计与证据
├── .github/workflows/            # 有实际构建入口后建立 CI
├── toolchains.json               # 审核后的工具版本及验证状态
├── rust-toolchain.toml           # rustup 精确版本选择
├── pubspec.yaml                  # M1 建立原生 Pub workspace
├── Cargo.toml                    # M1 建立 Cargo workspace
├── README.md
├── CONTEXT.md
└── AGENTS.md
```

## 模块内部布局

Dart feature 使用 `presentation/`、`application/`（交互控制）与局部 `widgets/`，按实际复杂度创建。不再放业务数据库、provider HTTP 客户端或第二套领域仓储。导入通过各包公共入口，禁止从外部导入别的 feature 私有实现。

Rust 小模块可从一个 `mod.rs` 开始，再自然拆成 `model.rs`、`service.rs`、`ports.rs`。不要求每个领域机械建立多层 `domain/application/infrastructure`。跨模块协调放在上层用例，不制造循环依赖。

原生代码主要在 `kiyori_platform` 内：浏览器、文件授权、后台传输、播放、凭据和终端各自拥有适配模块。runner 只做启动与注册。平台包膨胀后才按可独立构建/测试的能力拆成 federated packages。

## 依赖规则

- `apps/kiyori` → `kiyori_ui`、`kiyori_bridge`、`kiyori_platform`。
- `kiyori_ui` 不依赖业务核心或平台系统服务。
- `kiyori_bridge` → `kiyori_ffi` 的生成协议；不依赖应用 feature。
- `kiyori_ffi` → `kiyori_core`；核心不依赖 Flutter、Dart 或 UI 包。
- `kiyori_platform` 暴露原生接口；应用装配器将其绑定到核心平台端口，禁止平台包反向导入应用。
- `extensions` → 公开 `sdk`；不能直接链接内部数据库或 FFI 私有符号。
- 单元测试跟随所属语言包；跨边界共享夹具才放根 `tests/`。

## 拆包条件

只有出现独立发布、独立平台实现、明显的依赖隔离需求或独立性能/故障隔离价值时才拆包。文件行数或“看上去专业”不是理由。初期不建立 `services/` 微服务、`vendors/` 大型复制树或通用 `framework/`。

工作区统一保留应用 lockfile：根 Pub workspace lock、根 Cargo.lock、未来 SDK 的 pnpm-lock.yaml；原生 Wrapper、平台工程配置与必要生成注册文件按官方约定管理。SDK、编译产物、私钥和设备数据不进入仓库。
