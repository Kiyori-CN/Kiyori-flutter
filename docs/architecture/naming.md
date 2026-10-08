# 命名与应用身份

## 项目自有名称

| 对象 | 规范 |
| --- | --- |
| 产品、仓库、本地目录 | `Kiyori Flutter`、`Kiyori-flutter`；本机为 `D:\10_Project\Kiyori-flutter` |
| Dart package / Rust crate | `kiyori` 前缀，`lower_snake_case`，如 `kiyori_core` |
| Dart / Rust 文件与模块 | `lower_snake_case`；类/结构体用 `UpperCamelCase` |
| Kotlin 包 | 自有 Android runner 为 `com.kiyori.flutter`；类文件遵循 Kotlin 约定 |
| Swift / C++ | 类型按各自生态；自有 C ABI 符号以 `kiyori_` 前缀 |
| 文档与开发脚本文件 | `lower-kebab-case`；生态固定入口如 README、Cargo.toml 保持标准拼写 |
| TypeScript package | 规划 `@kiyori/sdk`；本地 private package，不代表已拥有 npm scope |
| 插件/工具 ID | 小写稳定标识，如 `kiyori.files.read`；显示名与内部 ID 分离 |
| 原生平台桥 | `kiyori/platform/<capability>`，接口方法使用语义名 |

不在所有内部类型前机械添加 Kiyori；`BrowserSession` 比 `KiyoriBrowserSessionManagerImpl` 更清楚。禁止 `new/old/v2/final/temp` 充当持久架构分类。标准协议 MCP、Agent Skills、Flutter 等准确技术名称保留。

## 文件归属与改名

- Dart 页面、controller、展示快照及测试遵循现有 `snake_case`；测试使用 `*_test.dart`，共享夹具进入 `test/support/`，不互相导入测试套件。
- Rust 小领域使用 `storage.rs` 等同名文件，大领域再拆目录；文件大小不是必须改名或拆层的理由。
- ADR 使用四位连续新增编号与主题名，既有编号不重排；历史证据用明确日期或月份，不使用“最终版”。
- 改名先核对大小写碰撞、导入、part/include、构建脚本、生成器和文档引用，同次修改闭合；生态入口、第三方协议和生成路径保留标准拼写。
- 平台包按能力命名：`inference/`、`scripts/`、`audit/`；共享构建源码归 `build_support/`，不新增发布 crate。系统钥匙环适配名为 `SystemSecretStore`，平台工厂留在 `secret_store.dart`。
- `Persistent*` 表示持久业务宿主，纯展示页面保留可注入快照；名称不能掩盖空实现或把草稿称为已保存。

## 新旧应用并存

2026-10-08 原生恢复唯一 Kiyori 主项目，本工程暂停功能开发并迁移外部身份。
M1 历史 APK `com.kiyori` 和 `Kiyori.exe` 仍是其观察日期的事实；本轮构建证据见
[当前状态](../status.md)。Apple/Linux 尚未在目标环境构建或注册，身份检查不能替代设备并存。

| 对象 | 新项目标识与约束 |
| --- | --- |
| Android applicationId / namespace | `com.kiyori.flutter`；原生主项目为 `com.kiyori` |
| Android Provider authority | 从 `${applicationId}` 派生，例如 `${applicationId}.files`，不写死旧包名 |
| Android 自定义权限与 Binder | `${applicationId}.permission.*`；导出接口按调用者和权限校验 |
| iOS / macOS bundle identifier | `com.kiyori.flutter`；测试为 `.RunnerTests`，实际注册/签名待 Apple 环境 |
| macOS 应用 / Linux 程序 | `Kiyori Flutter.app` / `kiyori-flutter`；Linux GTK application ID 为 `com.kiyori.flutter` |
| Windows 可执行文件 | `KiyoriFlutter.exe`，ProductName 为 `Kiyori Flutter`；MSIX 尚未实现 |
| 协议链接 | 预留 `kiyori-flutter://`，当前未注册；不为改名新增协议实现 |
| 用户数据 | path_provider 的独立 OS support 根；Windows 由 CompanyName/ProductName 派生，Apple/Android/Linux 取产品身份 |
| 终端 | 新应用私有 home、tmp、socket 和环境变量；不共用旧 terminal 服务 |
| 本地服务 | 默认不监听；必要时 loopback + 动态端口 + 每会话凭据，不占用固定公共端口 |
| 分享/下载目录 | 默认系统选择器授权目标；共享公共文件需用户显式选择 |

Android 安装包使用 `com.kiyori.flutter` 不意味着持有 `kiyori.com` 域名。对外域名、商店名称与 npm scope 需在实际使用时验证所有权。

旧项目历史与数据不自动搬入新应用。日后迁移采用用户触发的版本化导出/导入包，不直接读取另一应用私有数据。第三方代码如确需使用必须保留许可和归属，不为了统一品牌删除法律信息。

## 存储与保留标识

Android 安全存储 namespace 为 `kiyori_flutter_secrets_v1`，Apple account/service 为
`com.kiyori.flutter.secrets.v1`，不设置共享 access group；Linux 插件按 APPLICATION_ID
设置系统 keyring account；Windows DPAPI 文件取独立 support 根。
旧数据与凭据保留在原作用域，不自动读入或删除。未来恢复需要用户明确选择受支持的导出/导入，
并保证数据库与密钥匹配；本次不实现跨框架转换。

Dart package、Rust crate、FFI `kiyori_`、平台通道、内部 secret key 和私有子目录保持稳定，
其隔离由进程/安装身份/OS support 根持有，机械添加后缀没有额外隔离收益。
原生参考目录是 `D:\10_Project\Kiyori`，没有向 Flutter 添加 terminal 子模块。
