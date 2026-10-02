# 验证与交付策略

## 按阶段选择检查

M1 已有真实工程。文档执行 `tools/check-foundation.ps1`；实现执行 `tools/verify.ps1`，需要 Windows 引擎实测时加 `-WindowsIntegration`。构建执行 `tools/build.ps1 -Platform android/windows`（二选一）。Gradle 入口在 `apps/kiyori/android`，不要使用旧工程根路径。

build/verify 先核对实际工具版本。`build.ps1 -Mode debug/profile/release` 显式选择模式，默认
Debug；性能测试用 Profile，Release 不配置 Debug 签名。帧性能入口与证据边界见
[性能契约](performance.md)，默认验证不安装设备、不自动运行性能 benchmark。

以下 Android/Windows 入口已在 M1 实际使用；iOS 命令仅可在 Mac 上执行，当前未验证。

| 范围 | M1 之后的检查 | 证明范围 |
| --- | --- | --- |
| Rust | `cargo fmt --check`、`cargo clippy --workspace --all-targets -- -D warnings`、`cargo test --workspace` | 格式、静态问题和纯核心/协议行为 |
| Dart/Flutter | `dart format --output=none --set-exit-if-changed`（指定源码目录）、`flutter analyze`、各 package 的 `flutter test` | UI 状态、组件、adapter 契约 |
| FFI | `tools/generate-bridge.ps1 -Check`，`tools/verify.ps1` 的真实 Dart 测试 | 类型映射、事件顺序、取消、释放和生成一致性 |
| Android | 在 `apps/kiyori` 执行 `flutter build apk --debug --target-platform android-arm64` | APK 与本机原生库打包；不等于已安装 |
| Windows | 在 `apps/kiyori` 执行 `flutter build windows --debug` | runner、DLL、资源完整打包 |
| iOS | Mac 上 `flutter build ios --no-codesign`、模拟器/真机运行 | Apple 编译与对应运行层；签名发布另验 |

## 高价值测试

页面迭代可从根目录运行 `tools/test-ui.ps1 -Test <name>_test.dart`；指定 `-Capture`
复用真实 app 资源和本机字体捕获。脚本不会替代完整 verify，详见
[复刻流程](ui-replication-workflow.md)。截图必须在可追溯源码版本上生成，不能在验证中修改输入。

核心优先覆盖权限撤销、流取消、提交结果未知、任务恢复、数据库迁移、资源 URI/路径差异、规则切换、Range 续传和扩展输入边界。测试行为与契约，不为每个 getter、目录存在或低风险文本修改写镜像测试。

UI 关注响应式布局、键盘/鼠标/触摸、大字体、可访问性和生命周期。原生能力采用真实平台集成测试，mock 只能验证调用约定，不能证明后台服务、权限弹窗、音频焦点或 WebView 行为。

## 设备矩阵

首轮 Android arm64 真机、Windows x64；Android x64 模拟器在需要时添加。iOS 没有 Mac/iPhone，明确保留待验证，后续先模拟器再真机。旧应用和新应用并存需查安装包标识、Provider、数据目录、终端 home/socket/端口，再测试同时启动。

## CI 与发布

本机脚本作为未来 CI 的共同入口；Git 提交推送授权不自动包含远端计算资源/工作流运行，
新增会在 push 时自动触发的 workflow 需对应授权。Windows + Android CI 接线单独推进，Apple runner
仍需资源授权，不宣称本地脚本已在 CI 验证。

产物保存在忽略的 `artifacts/` 或 CI artifacts，不提交 APK、EXE、DLL、SO、SDK 和私钥。记录源 revision、工具版本、目标 ABI、构建时间和 SHA-256。Debug 编译通过不表示 Release、签名、商店审核或用户设备验收完成。

## 基础检查器边界

`tools/check-foundation.ps1` 检查 UTF-8/LF、一个一级标题、标题层级、闭合代码围栏、本地文件链接、JSON 可解析、PowerShell 语法、工具链接线以及 feature 不反向 import app。它不访问外部链接、不解析复杂 Markdown、不验证锚点或完整架构正确性。文档事实、表格与命名需人工审阅，不为了显示“全绿”扩大脚本的能力声明。
