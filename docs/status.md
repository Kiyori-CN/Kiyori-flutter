# 当前实施状态

更新时间：2026-10-02（Asia/Shanghai）。本文件是当前实施进度唯一权威；
[路线图](roadmap.md)规定顺序，[历史记录](status-history.md)保留过往批次证据。

## 当前任务：第三轮角色卡与提示词垂直切片

基线 `main` / `ad815390401d656ed5f0f2a9ec3e1c174854d121`，开始时工作区干净，
fetch 后 main 与 origin/main 为0/0。旧源 `Kiyori-Android` /
`6b03b03aa082803bb279db5e78773583e2d91154` 保持只读。kiyori-ui 为 PAUSED。
正式 Goal 不设预算；日记 local_only，仅本机保存，不派子智能体或调用外部研究服务。

本批目标是一个可交互的角色编辑 UI 切片：设置入口、目录、八字段与嵌套编辑、绑定
选择、稳定实体身份及返回释放。非目标为 Rust 持久化、网络请求、设备安装、部署、
远端 CI、全局 SDK 变更或自动化恢复；最终仅审计后的本轮允许清单提交推送。
回滚基线为上述 HEAD，历史固定包不覆盖。本轮没有新增依赖、修改 Rust API 或生成桥。

当前状态：本轮角色编辑 UI 草稿切片、本地验证、20张截图、双端 Debug 构建与交付树
审计完成；本批精确清单提交推送，实际提交与远端 ref 以 Git 为准。设备视觉/触摸/Profile、
TalkBack、Apple 构建及真实业务接入保持 `verification_pending`。

## 本批实现与业务边界

| 范围 | 实际交付 | 未实现或待验证 |
| --- | --- | --- |
| 入口与返回 | 设置 → AI 助手 → 角色卡和提示词，弹层优先 Back，返回来源 | AI 抽屉其它来源随 U3 实现 |
| 角色目录 | 中文 Kiyori 默认快照、品牌头像、活跃徽章、三种排序、菜单和导入入口；显式空目录不虚构默认卡 | 数据初始化、激活、复制、删除、重置均无业务副作用 |
| 角色编辑 | 八文本字段、完整默认语音文本、标签选择、放大编辑确认/取消、头像与翻译外观 | 最外层保存/创建空操作；不发 AI 请求、不复制文件 |
| 高级绑定 | 复用模型摘要，配置/模型两层选择、记忆 ID 选择、四类工具筛选与局部确认，use_package 前置校验 | 不修改全局模型、记忆空间或权限；默认目录为空 |
| 标签 | 默认空目录、非空快照、三字段新建/编辑与删除确认 | 保存、导入、导出、市场不执行；批量导出选择未迁移 |
| 导出 | JSON/PNG/多维码三卡、多维码2/4/8/16色选择与返回 | 不生成二维码、不写文件、不伪造保存路径或成功 |
| 群组 | 三标签中的默认空态、原创建按钮空点击 | 非默认群组、成员编辑、规划参数、持久化待下一切片 |
| 生命周期 | 菜单和弹层绑定 ID/存在代次；重排保留，移除释放嵌套模态；重新加入不复用草稿 | 后续真实请求的超时/取消/错误由业务 owner 补齐 |

旧源读取深度、几何、行为与后续 owner 条件见[角色卡契约](design/character-prompts.md)。
CharacterCardDialog 与双语默认数据全文已读；主工作台按相关分支读取，未宣称完整 Tavern
编解码、全部群组编辑或所有角色服务逐行审计。当前产品仍中文/浅色预览，明暗由宿主
注入测试；不增加全局主题或语言偏好 owner。默认快照不等于真实业务初始化。

## 验证与发现

15项最终定向测试：`work/characters-tests-delivery.log`。覆盖实际设置入口、系统 Back、嵌套
编辑确认/取消、目录重排/删除/重新加入、菜单存在代次、模型/记忆目录更新、标签选择、
工具搜索/取消/确认/目录过滤、外部工具校验、空目录/排序/导出、宿主退出焦点释放、
844×320横屏、320×600双倍字与180px键盘的明暗布局。

首次9项测试3失败：入口测试漏文案空格；惰性列表缺新位置映射导致菜单State丢失；
父级构建阶段同步发布跨路由ValueNotifier。修复精确文案、findItemIndexCallback与帧后
通知后全部通过。扩展横屏测试首次点了屏外菜单，补充真实滚动后通过，不关闭命中警告。
失败证据保留 `work/characters-tests-initial.log`、`characters-tests-expanded.log`。
首轮截图发现浮动标签裁切与字体符号缺字，已留绘制空间并恢复 Material 图标。

20张本机 Flutter 捕获涵盖手机明暗、默认/空/非默认目录、编辑/高级/工具弹层、放大编辑、
模型选择、标签编辑、群组空态、桌面暗色、大字键盘和来源返回；复用 ui_capture.dart。
最终图片为 `work/characters-review-delivery/`，捕获日志为
`work/characters-capture-delivery.log`；已审阅代表图并修正浮动标签裁切、头像按钮图标。
本机字体截图不等于 Android 真机像素验收。

所有 Flutter/Dart/Rust 命令先执行 `./tools/activate.ps1`，使用 pin 工具链
Flutter 3.47.6 / Dart 3.13.5 / Rust 1.99.0。实际本地验证如下：

| 命令/入口 | 结果 | 本机证据 |
| --- | --- | --- |
| `./tools/verify.ps1 -WindowsIntegration` | 基础文档49份、脚本4项、Rust fmt/Clippy/6测试、Dart格式/analyze、Flutter 261项、真实FFI 6项、Windows引擎2项通过；6捕获套件按设计跳过 | `work/characters-verify.log` |
| `./tools/test-ui.ps1 -NoPub -Test character_prompts_test.dart` | 最后视觉修正后15项通过 | `work/characters-tests-delivery.log` |
| `./tools/test-ui.ps1 -NoPub -Capture -Test character_prompts_capture_test.dart -Output work/characters-review-delivery` | 1套件通过、20 PNG | `work/characters-capture-delivery.log` |
| `flutter analyze`（app目录） | 最后视觉修正后无问题 | `work/characters-analyze-delivery.log` |
| `./tools/build.ps1 -Platform android -NoPub` | ARM64 Debug通过 | `work/characters-android.log` |
| `./tools/build.ps1 -Platform windows -NoPub` | x64 Debug通过，已重建正常产品入口 | `work/characters-windows.log` |

完整 verify 在最后浮动标签 `Stack.clipBehavior` 修正之前；该绘制修正后重新运行定向测试、
捕获、analyze与串行双端构建，不将更早的完整验证冒充最后代码的全量复跑。无Rust公共
API或生成文件变动，未重复生成 bridge。最终文档另执行 foundation 和 `git diff --check`。

交付树审计413文件、192 Dart（含生成代码），人工源码无失效相对/本地package import、
循环依赖、feature→app、公用UI→业务/bridge、测试互导或高置信敏感内容问题。
FRB生成内部循环单独列出，核对本轮未修改；未手改生成文件。未新增依赖、lock变化、
重复资源、异常大文件、链接、子模块或嵌套Git；`work/characters-full-audit-reviewed.json`
保存结果。构建、截图、失败日志和临时审计脚本仅留忽略目录，未清理旧包或缓存。

## 本机固定产物

固定目录 `artifacts/ui-preview/20261002-161431/`：APK 1个、Windows目录82文件，
共221,980,682字节；Windows完整目录117,370,198字节。83文件逐一核对构建源与副本
SHA256一致。`manifest.json` 保存完整清单；提交后仅补来源提交元数据，不重写二进制。

| 产物（相对固定目录） | 字节 | 修改时间（2026-10-02，Asia/Shanghai） | SHA256 |
| --- | ---: | --- | --- |
| `Kiyori-ui-preview-arm64-debug.apk` | 104610484 | 16:10:41.005 | `32121CDCD6DFE6E764A17D23A30BE5FA00724D0D91DB21480A2FD0020A26DDB0` |
| `windows-debug/Kiyori.exe` | 1281024 | 02:33:25.021 | `221590339BBEA871886F8C98D01B227D4603B7E605AEEDD29D4E5F4E1C2D1475` |
| `windows-debug/data/flutter_assets/kernel_blob.bin` | 53830200 | 16:12:33.165 | `3B04A9DFCB48421E1E9BB9FAD0EF1B3399FD3FC8432B4B8B19C147E3E56494B5` |
| `windows-debug/kiyori_ffi.dll` | 553984 | 13:45:55.575 | `8A64AB530621EF8CA05C1519A8094EDE586834FB62F7ED1FB4919C5E66FD7FAA` |

EXE为未变化原生runner的增量复用，本轮Dart内容以新kernel为证；不能用EXE时间称本轮
未构建。Windows PE为x64，Flutter DLL与pin SDK一致，运行时NativeAssets manifest引用
随包`kiyori_ffi.dll`；根目录native_assets.json保留构建期路径，不充当可移植运行证据。
APK `com.kiyori` / 0.1.0(1)、min24/target37、ARM64、Debug签名v2、ZIP 16KB对齐及
3个原生库ELF LOAD对齐通过，包含53个默认表情。证据在
`work/characters-artifacts-20261002-161431/`。固定包20261002-141807与20261002-124054
保留，前者SHA仍为`7ED53295DA96DE4FDFA5F6F1BFB1F1EFBB5C29F161EAB50BC0451117EA1DBC3A`。

性能只落实工作边界：角色/标签排序在目录或排序选择变化时计算，角色列表惰性构建；
不会因每次文本输入重新排序目录，没有服务订阅或后台任务。无前后 Profile 对照，
不声称帧、延迟或内存目标已达标。

## 长期进度与下一入口

M1运行时已实现，业务M2仍未开始；U2/U6本轮新增角色编辑展示切片。既有壳、一级页、
设置、模型/语音等范围保留，明细见历史与UI契约。全产品复刻尚未完成。

下一优先级是旧 `ModelPromptsSettingsScreen.kt` 的 `GroupCardDialog` / `GroupCardItem`：
逐项核对成员身份、顺序、规划参数、默认/非默认状态及保存边界；复用本轮目录身份和
模态释放约束，补行为测试、明暗小屏截图与批次构建，再接标签批量导出/市场、人设生成。
之后角色到虚拟形象入口 → U3轻量抽屉 → U4工作台 → U5深工具 → U6剩余 → U7入口复查。

最短验证启动：`. ./tools/activate.ps1` 后运行
`./tools/test-ui.ps1 -NoPub -Test character_prompts_test.dart`；开发先读本文件与角色卡契约，
再核对实时Git和旧源。真实owner与设备验收需另行授权对应操作，本轮授权不延伸到后续任务。
