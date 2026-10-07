# ADR 0004：设置输入预览使用完整 Unicode 归一

状态：已采用。日期：2026-10-03。

## 背景

旧`ToolboxLayout.kt`使用Java Normalizer的NFKC及Locale.ROOT小写比较分组名称。
全角字符、组合重音和兼容字符必须正确判重，单纯trim或手写有限替换表不满足原行为。
Dart标准字符串API没有NFKC；当前只做设置输入预览，不应为此新增native通道或持久化owner。

## 决策

app直接依赖`unorm_dart 0.3.2`，固定锁文件，使用其`nfkc`后执行小写比较。
该包为MIT、Unicode 17.0规范化实现，2026-10-03核对
[发布页](https://pub.dev/packages/unorm_dart)与[API](https://pub.dev/documentation/unorm_dart/latest/unorm_dart/)。
依赖只服务输入预览；未来Rust布局owner接入时仍须在业务边界独立验证，不将UI验证当存储保证。

## 影响与验证

保持旧空白归一、控制字符拒绝、UTF-16长度上限及排除自身ID的自定义组判重。
测试覆盖全角/组合重音/大小写同名、emoji长度、控制字符与保留名。
Unicode版本可能高于旧Android运行环境；新分配字符的规范化以当前依赖表为准，不宣称所有
Android版本的Unicode表逐字节相同。回退本决策需同时恢复pubspec/锁文件与名称校验实现。
