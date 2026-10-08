# UI 复刻开发流程

## 来源与范围

产品基线是原生主项目 `D:\10_Project\Kiyori`，在 Flutter 功能恢复授权前仅作只读参考；下列历史来源 revision 为
`6b03b03aa082803bb279db5e78773583e2d91154`。目录名、文件名与类名只是检索入口，
不能据此判断页面已复刻。页面往往分散在宿主、组合组件、偏好、资源和非路由弹层。
总顺序见[实施方案](../design/ui-replication-plan.md)，当前缺口只写入[状态](../status.md)。

## 每个切片的工作顺序

1. 从可达入口追踪：Shell → 路由/回调 → 页面 → 子组件 → 弹层；同时查返回来源。
2. 读取状态来源：偏好初始化、默认配置、空值、加载/错误/禁用条件。静态 provider 目录
   不等于已请求结果；旧默认角色和首次初始化预设不能用空对象代替。
3. 记录视觉参数：尺寸、间距、圆角、字重、资源、明暗色、滚动/键盘/安全区与模态层级。
   中文文案从实际 resources 核对，保留图标变体；原资源先比摘要，再决定是否需要转换。
4. 先用 `kiyori_ui` 已核对的原语；领域页面和不可变展示快照放在对应 feature。
   `app/shell/settings_navigation.dart` 装配详情，`HomeShell` 只持有一级导航与 pager。
   不复制旧 Service/Manager、数据库、客户端或跨平台不可用原生句柄。
5. 先默认态，再非空、选择、编辑、错误和嵌套模态。无业务owner时保留安全空点击；
   进入真实业务切片后接通Rust命令和快照，不用假成功或开发提示替代实现，
   不把只读外部事实改成可随点击变化的本地状态。
6. 定向测试覆盖来源返回、草稿身份和释放、320宽/横屏/桌面、双倍文字与键盘；
   动态目录覆盖弹层未关闭时的重排/删除，缓存页覆盖焦点与 ticker。
   真实问题修复应有行为证据，不写只检查文件存在的镜像测试。
7. 捕获渲染、核对源参数，再执行完整验证和批次构建。设备并排视觉/触摸/Profile 与
   iOS 编译单列待验证；未取得证据不能把截图称为像素完全一致。

## 可重复入口

以下从仓库根运行，脚本自动进入 app 目录，确保图片资源和字体加载语境正确：

```powershell
. ./tools/activate.ps1
./tools/inspect-legacy.ps1 -Source D:/10_Project/Kiyori -Filter settings
./tools/test-ui.ps1 -Test tts_settings_test.dart,wakeup_settings_test.dart
./tools/test-ui.ps1 -Capture -Test profile_permissions_capture_test.dart -Output work/ui-review
./tools/verify.ps1
./tools/build.ps1 -Platform android
./tools/build.ps1 -Platform windows
```

`inspect-legacy.ps1` 只读 Git 跟踪文件、来源 revision 和九模块声明，输出 JSON；不要求
把旧工程复制入新仓库，也不把文件数充当页面覆盖率。`-Filter` 是路径子串筛选。
截图不传 `-Test` 时执行全部捕获套件；其它系统显式传 `-Font` 指向本机中文字库。
字体只用于本机渲染，不分发。公共 `test/support/ui_capture.dart` 负责字体、PNG 释放和
阴影状态恢复，并等待可见图片首帧，避免框架空闲但异步解码未完成时漏图标。
不同宿主字体的截图只能用于布局审阅，不能替代 Android 字形比较。
明暗表面与角色图标色由公共设置色表投影，颜色编辑器初始草稿与宿主渲染颜色分开核对；
本机主题截图不等于全局偏好已生效。共用夹具放 `test/support/`，不导入另一测试套件。

在依赖已解析且 pubspec/lock 未变化的同一批次，定向测试、截图和构建可使用 `-NoPub`；
首次检出或依赖变化继续使用默认 pub 解析。参数只消除重复解析，不关闭分析或行为检查。

小改先定向测试，批次结束运行完整 verify；命令失败检查具体阶段，不重复启动仍在运行的
Gradle/Flutter 构建。不在测试运行中修改其输入。保留构建缓存，不常规执行 clean。
Gradle 仅启用本地 task output cache；不配置远程缓存、build scan 或未验证的 configuration cache。
缓存机制依据 [Gradle 官方文档](https://docs.gradle.org/current/userguide/build_cache.html)，
字体证据边界依据 [Flutter 测试文档](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html)。

缓存页面不能只使用 `Offstage`：它仍会保留焦点与动画，需结合焦点排除和 `TickerMode`，
见 [Offstage](https://api.flutter.dev/flutter/widgets/Offstage-class.html) 与
[TickerMode](https://api.flutter.dev/flutter/widgets/TickerMode-class.html)。当前 Flutter 的
`Image` 会响应 TickerMode 停止监听图片流；惰性列表的缓存区仍可能保留图片，不能据此
声称每个完全离开可视像素的 GIF 都已经暂停。需要设备剖析后再决定是否增加可见性策略。

## 证据与清理

群组切片的成员选择是下拉菜单，不是带确认按钮的独立选择对话框；选择只回填待添加
项，再按添加才改变父草稿。模态会话必须跟踪它创建的 PopupRoute 与 DialogRoute；删除
实体时按路由实例移除，保留无关页面。帧尾发布目录后若再延迟一帧清理，应主动请求帧，
不能依赖用户下一次触摸才使旧弹层失效。目录更新测试需覆盖界面静止、重复引用、重排、
删除及同 ID 重入，保持完整原断言。

角色编辑切片补充：区分嵌套编辑“保存到父草稿”与最外层“写业务”。前者可以真实完成
局部交互，后者无 owner 时保留空动作和原外观。不能为了做出创建演示在 Dart 维护假目录。
惰性列表只有稳定 Key 还不够，重排需提供实体的新位置映射；回归应在菜单仍开着时更新
目录。跨路由 ValueNotifier 不在父级 build/didUpdateWidget 中同步发布，帧结束后通知；
删除实体时同时验证所有嵌套模态精确退出、焦点释放与同 ID 重新加入。截图审阅要检查
浮动标签的绘制边界和实际图标，不能用字体字符替代 Material 图标掩盖缺字。

进度文件只保留当前批次、交付边界、覆盖表和下一步；历史构建明细放在
[历史记录](../status-history.md)，不把历史授权当作新授权。设计文档不滚动追加每次 APK 摘要。
固定用户检查包位于 `artifacts/ui-preview/<时间>/`，后续默认构建不覆盖；日志和截图位于
忽略的 `work/`。原始测试夹具不放产品默认目录。

清理前区分源文件、原资源、缓存、证据和未知用户文件。移除确认空的无用途目录；
保留可重用构建缓存、正在检查的包和必要失败证据。不要为了目录整齐批量重命名原生标准
入口、生成文件或许可证。提交前核对精确暂存树、资源、凭据、链接、嵌套仓库和大文件。
