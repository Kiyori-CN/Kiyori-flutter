# ADR 0019：五平台工程基础与原生边界

状态：接受；Android/Windows 为本轮构建目标，iOS/macOS/Linux 源集与平台运行待验证。

## 问题

现有三端工程无法直接开始 macOS/Linux 验证；凭据工厂拒绝这两个平台，原生构建重复维护工具发现和 ABI 配置，Android 的 Ninja 路径带 Windows 后缀。推理目录 native 无法准确表达职责，Rust target 清单未覆盖桌面目标。文档把三端计划与真实平台能力混合，难以判断下一步。

## 决策

使用锁定 Flutter 模板建立 macOS/Linux runner，保持同一产品入口和已有品牌资产。接入已有系统安全存储插件，保持 Android/iOS 键与命名空间、Windows DPAPI 格式，不引入迁移、明文回退或新依赖。macOS 使用不共享的 Keychain，Linux 使用插件既定 libsecret 后端；缺失钥匙环按操作失败报告。

平台工厂与 SystemSecretStore 分离；native 更名 inference，Cargo crate 名不变。两个原生 adapter 共用 build_support/cmake.rs，保持各自依赖、缓存、链接及编译开关。该目录不是新增 runtime/crate，不改变核心状态所有权。Rust pin 同步五平台 target 清单；实际验证发现 native_toolchain_rust 1.0.7 要求显式 targets 且必须包含当前目标，因此保留 root/crate-local 完整一致列表，不通过修改第三方依赖或关闭校验绕过。标准库安装不代表 SDK/链接支持。公共 FFI API 不变，无需重新生成桥接协议。

build.ps1 增加 macos/linux，并在访问 SDK 前校验宿主；对应纯路由纳入工具测试。没有接入的文件选择、推理、脚本、审计仍明确 unsupported；完整五平台业务不是本轮承诺。产品 UI 和旧源行为不变。

## 取舍与兼容

没有另建 federated packages 或能力服务，因为目前没有独立发布需要；也不在 Windows 推测性移植未验证的 Apple/Linux 原生引擎。先保留可靠错误边界，未来能力以垂直切片实现并实测。

文件改名同步 Cargo 路径、Native Assets hook、文档和测试。推理缓存改为 target/inference，首次重建开销换取正确的 CMake 源路径绑定；旧忽略缓存保留。仓库尚未发布，MobileSecretStore 的内部消费者同步更名，不改变持久存储 schema、键或引用格式。

## 验证与后续

本机需通过工具路由、凭据契约、原生目标/错误边界测试及完整 verify、Windows 引擎集成、Android/Windows 构建。macOS/Linux runner 工程检查与 mock 不是本机编译证据。下一阶段在对应宿主核对插件注册、Native Assets、启动、存储、审计与资源生命周期，再推进新平台业务。实际命令和结果归当前状态，长期缺口归[平台矩阵](../design/platforms.md)。
