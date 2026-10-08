# 仓库布局

<!-- doc-toc:start -->
- [设计原则](#设计原则)
- [当前目录](#当前目录)
- [尚未创建的规划](#尚未创建的规划)
- [模块内部布局](#模块内部布局)
- [依赖规则](#依赖规则)
- [拆包条件](#拆包条件)
<!-- doc-toc:end -->

## 设计原则

当前详情装配集中在 `apps/kiyori/lib/app/shell/settings_navigation.dart`，只借用现有
Navigator；`home_shell.dart` 管一级目的地、返回来源、pager和缓存生命周期。feature仅接收
回调，不反向 import app。测试辅助集中在 `apps/kiyori/test/support/`：`ui_capture.dart`
管理渲染，`fake_runtime.dart`、`ui_test_helpers.dart`、`assistant_fixtures.dart` 提供已有
测试的共用夹具；测试套件不再互相导入其它 `*_test.dart`。
工具入口在 `tools/`，临时脚本、日志、图片在忽略的 `work/`，不形成第二正式工具目录。

根目录表示工程角色，角色内部按语言生态和领域命名。初期采用模块化单体，不把每个页面拆成 package，也不预造几十个 crate。目录只有在承载真实实现、测试或文档时创建。

## 当前目录

以下按当前源码的实际目录整理，仅省略同类文件，不列尚未建立的目标目录。Pub workspace
有四个成员，Cargo workspace 有五个成员；成员清单以根 manifest 为准。

```text
Kiyori/
├── apps/kiyori/                 # Flutter 产品入口
│   ├── lib/app/                 # 启动、装配、路由与 diagnostics
│   ├── lib/features/            # 用户功能的界面与交互
│   ├── android/                 # Android runner 与平台通道
│   ├── windows/                 # Windows runner
│   ├── ios/                     # iOS 源集，Apple 构建待验证
│   ├── macos/                   # macOS runner，Apple 构建待验证
│   ├── linux/                   # Linux runner，Linux 构建待验证
│   ├── assets/                  # 品牌、旧源素材及许可证
│   ├── test/                    # 组件与行为测试，support/ 为共享夹具
│   ├── integration_test/        # 引擎集成与性能场景
│   └── test_driver/             # Profile 结果回收
├── packages/
│   ├── kiyori_ui/lib/           # 公共 UI，包入口显式导出
│   ├── kiyori_bridge/           # Dart 外观、hook、test、src/generated/
│   └── kiyori_platform/
│       ├── lib/                 # 平台能力的 Dart 接口
│       ├── test/                # 平台通道与接口测试
│       ├── assets/              # 平台能力使用的静态资源
│       ├── inference/           # 本地推理 Rust/C++ adapter
│       ├── build_support/       # 原生 adapter 共用 CMake 查找与目标配置
│       ├── scripts/             # QuickJS-NG Rust/C++ adapter
│       └── audit/               # 审计保护 Rust/原生 adapter
├── crates/
│   ├── kiyori_core/src/         # lib.rs 导出领域，storage.rs 统一迁移
│   │   ├── chat/               # 请求协议、流式、观测与推理端口
│   │   └── extensions/         # 持久包、清单、校验及受控 HTTP
│   └── kiyori_ffi/              # API、句柄、DTO 与生成边界
├── tools/                      # PowerShell 开发与验证入口
├── docs/                       # 用户指南、架构、设计、决策及证据
├── pubspec.yaml                # Pub workspace；根 pubspec.lock
├── Cargo.toml                  # Cargo workspace；根 Cargo.lock
├── toolchains.json             # 版本与验证状态
├── rust-toolchain.toml          # rustup 版本选择
├── README.md                   # 概览和上手
├── CONTEXT.md                  # 高频语义
└── AGENTS.md                   # 协作规则
```

现有 feature 为 accounts、assistant、browser、documents、downloads、extensions、files、knowledge、
music、onboarding、player、settings、speech、toolbox、video、workflows。目录存在不代表业务完成，
实现位置与空动作边界见[模块实现](module-implementation.md)。

## 尚未创建的规划

`sdk/typescript`、根 `extensions/`、根 `tests/fixtures/` 和 `.github/workflows/`
在当前基线尚未建立。只有真实用例需要时才创建；CI 与远端资源另需授权。新增 browser、
tools、permissions、media、terminal 等核心领域时优先接现有 Runtime，不照目标树生成空实现。
平台专属源码按实际接线管理，不预建平台包的 android/windows/ios 空目录。

## 模块内部布局

Dart feature 使用 `presentation/`、`application/`（交互控制）与局部 `widgets/`，按实际复杂度创建。不再放业务数据库、provider HTTP 客户端或第二套领域仓储。导入通过各包公共入口，禁止从外部导入别的 feature 私有实现。

Rust 小模块从领域同名 `.rs` 文件开始，出现内聚子模块时再使用目录与 `mod.rs`，再自然拆成 `model.rs`、`service.rs`、`ports.rs`。不要求每个领域机械建立多层 `domain/application/infrastructure`。跨模块协调放在上层用例，不制造循环依赖。

现有跨 feature 的公开展示复用保持单向：聊天历史复用设置的 BackupCard/BackupText，
引导复用协议正文/阅读组件和权限展示类型；均不访问领域状态或服务。它们是已有同源
展示契约，不为消除路径差异复制一份数据。真实权限/协议持久能力接入时由 app 注入，
不能让这些展示引用扩展成跨 feature 的业务状态所有权。

已实现的推理、脚本、审计与安全存储适配归 `kiyori_platform`；当前部分 Android 系统选择器与通道位于 app runner。后续浏览器、后台传输、播放和终端仍按能力建立 adapter，避免在 runner 增加领域规则。平台包膨胀后才按可独立构建/测试的能力拆成 federated packages。

## 依赖规则

- `apps/kiyori` → `kiyori_ui`、`kiyori_bridge`、`kiyori_platform`。
- `kiyori_ui` 不依赖业务核心或平台系统服务。
- `kiyori_bridge` → `kiyori_ffi` 的生成协议；不依赖应用 feature。
- `kiyori_ffi` → `kiyori_core`；核心不依赖 Flutter、Dart 或 UI 包。
- `kiyori_platform/inference` 的 Rust/C++ 推理adapter依赖core窄端口，FFI装配并静态链接；
  core不反向依赖adapter。源archive和编译缓存不进入发布树。
- `kiyori_platform/scripts` 的Rust/C++受限执行器同样依赖core/scripts窄端口，
  仅静态链接qjs；源码archive与target/native-scripts缓存不提交。
- `kiyori_platform/audit` 独立平台安全adapter依赖core审计窄端口，FFI装配；
  Android JNI/Keystore与Windows DPAPI句柄不进入core，平台密钥文件不进发布树。
- `kiyori_platform` 暴露原生接口；应用装配器将其绑定到核心平台端口，禁止平台包反向导入应用。
- `extensions` → 公开 `sdk`；不能直接链接内部数据库或 FFI 私有符号。
- 单元测试跟随所属语言包；跨边界共享夹具才放根 `tests/`。

## 拆包条件

只有出现独立发布、独立平台实现、明显的依赖隔离需求或独立性能/故障隔离价值时才拆包。文件行数或“看上去专业”不是理由。初期不建立 `services/` 微服务、`vendors/` 大型复制树或通用 `framework/`。

工作区统一保留应用 lockfile：根 Pub workspace lock、根 Cargo.lock、未来 SDK 的 pnpm-lock.yaml；原生 Wrapper、平台工程配置与必要生成注册文件按官方约定管理。SDK、编译产物、私钥和设备数据不进入仓库。
