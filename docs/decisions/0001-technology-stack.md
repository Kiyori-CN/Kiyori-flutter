# ADR 0001：语言与框架

- 日期：2026-10-02。
- 状态：采用为工程基线；业务集成与 iOS 编译尚待验证。
- 决策范围：Android、Windows、iOS 客户端及扩展开发工具。

## 约束与候选

项目同时包含复杂交互、网页原生视图、文件/后台任务、音视频和可编程工具。个人项目应共享主要业务，避免三套产品长期分叉；同时必须保留必要原生入口。

| 方案 | 优势 | 本项目成本与失败模式 | 判断 |
| --- | --- | --- | --- |
| Flutter / Dart 为主 | 一份 UI 与领域代码，初期工具链简单 | 系统服务、原生库与独立执行器后期仍需桥接，跨宿主核心复用受限 | 可行的较轻方案 |
| Flutter / Dart + Rust | UI 跨端，核心可独立测试，网络/任务/扩展策略统一，适合接入原生库 | 双语言、FFI 代码生成、取消和打包更复杂，必须严格限制跨边界粒度 | 本项目采用 |
| Kotlin Multiplatform + Compose Multiplatform | Android 生态亲和，共享 Kotlin；Android/iOS/桌面均有稳定支持 | Windows 桌面 JVM 与各端原生视图/媒体适配仍需投入；不能直接复用所有 Android API | 可行，非本次首选 |
| Tauri 2 + TypeScript / Rust | Web UI 与 Rust 核心搭配自然，系统 WebView 复用 | 应用 Web UI 与产品浏览器需分开安全域；移动原生交互、媒体视图与后台服务要大量适配 | 可行，项目适配收益不占优 |
| 三端原生独立实现 | 平台能力直接、交互自然 | UI 和领域维护成本最高，个人项目易出现行为分叉 | 不采用 |

这里的选择是针对本项目的工程判断，不声称某框架在所有场景中“最先进”。官方平台支持与机制来源见[资料](../references.md)。

## 决定

1. **Flutter / Dart**：统一 UI、路由、设计系统、可访问性和交互状态。适配手机/桌面布局，不复制三套业务页面。
2. **Rust**：共享业务核心，负责 AI 执行、任务、权限策略、数据、下载调度、扩展管理与协议适配。初期单一核心 crate 内按领域模块组织。
3. **flutter_rust_bridge**：类型化异步 FFI；独立 bridge 包和 FFI crate 隔离生成代码。生成器、Rust crate 和 Dart 包锁同一稳定版。
4. **Kotlin、Swift、C++**：只用于 Android、iOS、Windows 必需的宿主生命周期、系统 API、原生视图和插件适配。可复用稳定第三方插件，但要审核能力与维护情况。
5. **TypeScript**：扩展 SDK 与作者工具；发布的脚本是受约束的 JavaScript，手机不依赖系统 Node.js。嵌入执行器需单独验证，不把 JS 引擎当成天然安全沙箱。

## 依赖管理

Dart 用原生 Pub workspace；Rust 用 Cargo workspace；TypeScript SDK 实现时再引入 pnpm workspace。M1 已建立两个 workspace 与根锁文件，生成代码唯一入口为 `tools/generate-bridge.ps1`。Native Assets 自动打包 Rust，详见 [M1 记录](../development/m1-foundation.md)。

数据库基线选择 SQLite（Rust 单一迁移/连接所有者），凭据走平台安全存储。具体 SQLite、HTTP、异步、UI 状态管理与媒体依赖在首个切片按最新兼容稳定版评估后锁定，避免先装大量不会用的包。

## 代价与复审

UI 不能频繁以 FFI 读取零散字段；使用命令、快照和有界事件流。文件与媒体数据走资源句柄/流，避免大块 Base64 过桥。FFI 必须处理失效句柄、取消、背压、panic 隔离和退出顺序。

M1 必须验证 Windows 与 Android 的 Flutter → Rust → 异步事件完整路径。若双语言的打包/调试成本明显超过收益，应在业务膨胀前复审是否暂以 Dart 实现简单领域；任何调整用新 ADR 记录，不私下复制双份状态。
