# 命名与应用身份

## 项目自有名称

| 对象 | 规范 |
| --- | --- |
| 产品、仓库、本地目录 | `Kiyori`；本机为 `D:\10_Project\Kiyori` |
| Dart package / Rust crate | `kiyori` 前缀，`lower_snake_case`，如 `kiyori_core` |
| Dart / Rust 文件与模块 | `lower_snake_case`；类/结构体用 `UpperCamelCase` |
| Kotlin 包 | `com.kiyori` 起，按领域分层；类文件遵循 Kotlin 约定 |
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
- `Persistent*` 表示持久业务宿主，纯展示页面保留可注入快照；名称不能掩盖空实现或把草稿称为已保存。

## 新旧应用并存

M1 已在 Android APK 中验证 `com.kiyori`，并生成 Windows `Kiyori.exe`；iOS runner 已配置 bundle ID，但尚未在 Apple 环境编译或注册。其余未实现能力仍为设计预留。身份检查不能替代新旧应用的设备并存验收。

| 对象 | 新项目标识与约束 |
| --- | --- |
| Android applicationId / namespace | `com.kiyori`；旧应用独立为 `com.kiyori.android` |
| Android Provider authority | 从 `${applicationId}` 派生，例如 `${applicationId}.files`，不写死旧包名 |
| Android 自定义权限与 Binder | `${applicationId}.permission.*`；导出接口按调用者和权限校验 |
| iOS bundle identifier | 预留 `com.kiyori`，Apple 账号与签名可用时确认是否可注册 |
| Windows 可执行文件 | `Kiyori.exe`；MSIX identity 预留 `Kiyori`，Publisher 由真实证书决定 |
| 协议链接 | 预留 `kiyori://`；注册前审计旧应用是否占用，避免同时注册产生歧义 |
| 用户数据 | OS 应用私有目录下 `Kiyori`；不可硬编码同一跨应用 home |
| 终端 | 新应用私有 home、tmp、socket 和环境变量；不共用旧 terminal 服务 |
| 本地服务 | 默认不监听；必要时 loopback + 动态端口 + 每会话凭据，不占用固定公共端口 |
| 分享/下载目录 | 默认系统选择器授权目标；共享公共文件需用户显式选择 |

Android 安装包使用 `com.kiyori` 不意味着持有 `kiyori.com` 域名。对外域名、商店名称与 npm scope 需在实际使用时验证所有权。

旧项目历史与数据不自动搬入新应用。日后迁移采用用户触发的版本化导出/导入包，不直接读取另一应用私有数据。第三方代码如确需使用必须保留许可和归属，不为了统一品牌删除法律信息。
