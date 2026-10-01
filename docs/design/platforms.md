# 平台能力与同步开发

## 支持基线

设计目标为 Android API 24+、Windows 10/11 x64、iOS 15+，这些是当前 Flutter 的基础候选下限，具体依赖可提高最低版本；首次 runner 和插件选择时必须复核。首轮设备重点 Android arm64 与 Windows x64，Android x64 用于后续模拟器。Windows arm64 与 Android 32 位不是首期交付目标。

没有 Mac 和 iPhone 是当前已确认环境事实。Windows 能维护共享代码和 iOS 源文件，但不能证明 Swift、Xcode 工程、签名、模拟器或真机运行正确。

## 能力差异

| 能力 | Android | Windows | iOS |
| --- | --- | --- | --- |
| Flutter UI / Rust 业务 | 优先实现与构建 | 优先实现与构建 | 同步接口/源集，待 Apple 编译 |
| 网页引擎 | 系统 WebView | WebView2 | WKWebView |
| 文件访问 | 沙箱 + SAF/媒体授权 | 用户授权路径与 OS 权限 | 沙箱 + 文件选择器/授权 bookmark |
| 后台下载 | 工作调度/前台服务等系统机制 | 后台传输或受控应用任务 | background URLSession，受系统调度 |
| 音视频后台 | 音频焦点与媒体服务 | 窗口/进程和系统媒体控制 | AVAudioSession 与合法后台模式 |
| 广告规则 | 受 WebView 拦截 API 限制 | 受 WebView2 API 与请求来源限制 | WKContentRuleList 的规则能力 |
| 应用内代理 | 分别核验 HTTP/WebView/媒体 | 分别核验 HTTP/WebView2/媒体 | 分别核验支持的 API，不承诺全流量 |
| 系统代理/VPN | 独立 VpnService 及用户许可 | 独立系统权限与恢复设计 | Network Extension 资格与分发条件待评估 |
| 插件/脚本 | 受限执行器，分发与平台限制 | 受限执行器，可做进程隔离 | 需遵守平台下载代码与分发规则，不能预承诺同等范围 |
| 本地 MCP stdio / 终端 | 特定随包 runtime 才可能支持 | 用户配置 runtime，受控进程 | 不作为通用可用能力 |
| 远程 MCP | 受控 HTTP | 受控 HTTP | 受控 HTTP，仍需平台验证 |

## 同步开发的具体含义

每个跨平台 feature 在设计时给出 iOS 输入输出、权限、资源生命周期和 unsupported 表达；共享 Rust/Dart 不硬编码 Android 路径。新增接口包含可用于三端的夹具，iOS 适配在对应任务里维护，禁止长期只留没有错误契约的空函数。

没有 Mac 时，iOS 代码状态最多为 `source_ready / verification_pending`（仅在真正写过源代码时才可标 source_ready）。M1 已生成并维护 iOS runner，配置 `com.kiyori` 和 iOS 15 下限；共享 Rust/Dart 与 Native Assets hook 已存在，Apple targets 已安装，但 Xcode 编译、链接、签名与运行均未验证。业务原生适配仍只有设计。拿到 Mac 后第一件事是完整构建与模拟器验证，而不是直接增加业务。

## Apple 环境补齐清单

1. 获取可运行所选稳定 Xcode 的 Mac；核验 [Apple 系统要求](https://developer.apple.com/xcode/system-requirements/)。本次观察为 Xcode 27、Swift 6.4、iOS SDK 27，需要 macOS Tahoe 26.6+。
2. 安装 Flutter 同版本、Rust 同版本、Xcode 命令行工具和模拟器；Rust 加 `aarch64-apple-ios` 与 `aarch64-apple-ios-sim`（Intel Mac 按需加 x86_64 模拟器）。
3. 跑共享测试、iOS 无签名构建与模拟器；涉及插件的依赖管理按实际 Swift Package Manager/CocoaPods 要求配置。
4. 真机与分发需要 Apple 身份、证书、Bundle ID 和设备条件；申请/购买/上传需另行授权。没有真机时后台、音频、文件提供器和权限 UX 保留待验收。

Apple 平台能力须在实际分发策略确定时复核其审核要求；官方对下载执行代码和网页引擎有明确规则及例外条件，不能以桌面行为直接外推。[Apple 官方审核指南](https://developer.apple.com/cn/app-store/review/guidelines/)
