# 输入响应与帧性能契约

## 问题与证据

Flutter 应用并非必然迟滞；UI 线程、栅格化、平台视图、手势仲裁和构建模式都可能造成
不同问题。不能凭框架名称定位，也不能以 Debug 观感或平均 FPS 证明性能。
官方建议在真实设备使用 Profile 分析 UI/raster 时间，见
[性能分析](https://docs.flutter.dev/perf/ui-performance)与
[构建优化](https://docs.flutter.dev/perf/best-practices)。

2026-10-02 的源码审查确认：旧首页首帧后预组合邻页；新首页原先首次滑动才构建邻页，
底栏 AnimatedBuilder 每像素创建完整五图标子树，AI 输入每次更改使整个聊天页 setState。
这些是可消除的额外工作，尚无真实设备 trace 证明它们各自占用户卡顿的比例。

本轮改为首帧后开启 PageView 相邻页缓存、固定页面 widget 身份、AnimatedBuilder.child
复用底栏与图标、底栏单个 RepaintBoundary、发送按钮局部监听草稿。页面默认的重绘边界
继续沿用，不给所有控件盲目加 layer。预热仅限这三个轻量 UI；将来接入业务时不得在 build
启动数据库扫描、WebView 或模型请求。

## 手势边界

- 唯一 PageController 拥有三页位置；页面子手势参加框架 gesture arena，不新增全屏 Listener
  抢先消费事件，不把 touch slop 设为零，不在 PlatformDispatcher 覆盖全局输入。
- `DragStartBehavior.down` 在横向识别胜出后计入按下到识别之间的位移；系统阈值仍防止
  小抖动被当拖动。是否更贴合具体设备手感需并排实测。
- `allowImplicitScrolling` 在首帧后开启，同时允许框架 showOnScreen/无障碍滚动；
  预缓存的输入不得主动抢焦点。键盘、Tab、TalkBack/VoiceOver 是单独验收项。
- 竖向内容滑动、TextField 选区、后续横向代码表格/图片缩放属于内容；新增此类组件时
  必须补充冲突用例，不能用全页面禁滑解决局部冲突。
- 透明底栏保持原 IgnorePointer/ExcludeSemantics；点击盒与几何保持旧值。
- 首滑、慢拖、快速甩动、未过半回弹、中途反向、按下打断动画、边界、多指、取消、
  输入法开关、系统边缘返回均需覆盖；widget 测试仅证明输入状态机与布局，不证明硬件时延。

## 开发约束

| 路径 | 约束与失败信号 |
| --- | --- |
| build/layout | 不做 I/O、同步 FFI、全量排序、JSON/Markdown 大文本解析；重复帧不得重建无关页面 |
| Rust / FFI | async 任务、有界事件与取消；CPU 密集工作进入有界阻塞池，async 关键字本身不使 CPU 工作离开执行线程 |
| 流式助手 | 增量解析、稳定块 ID、只更新变化节点；UI 按帧合并文字，终态/授权/工具事件可靠交付 |
| 大列表/文档 | 惰性列表、分段解析和虚拟画布；完整原文保留，有界缓存，不以截断原文换流畅 |
| 图像/原生视图 | 按显示尺寸解码，纹理传帧；首次解码/平台视图合成单独测，不能跨 FFI 搬像素数组 |
| 后台页 | 保留会话与草稿不意味着常驻动画/解码/高频订阅；离开页面暂停 UI ticker，服务生命周期独立 |
| 状态订阅 | 按实体/revision 订阅；偏移、播放位置和 token 不触发应用根树刷新；缓存要有容量与失效规则 |

## 可重复测量

使用同一真机、相同刷新率/电源/温度/字体/内容，旧版采用可比的优化构建。一次只改变一个
因素，至少运行三轮；分别保留第一次滑动和预热后的分布。60/90/120 Hz 的单帧预算分别约
16.67/11.11/8.33 ms。UI 和 raster 分开比较预算，不能相加后当作流水线的总帧耗时。

```powershell
. .\tools\activate.ps1
.\tools\build.ps1 -Platform android -Mode profile
# 下列命令会安装并运行，只在指定设备已获授权时执行。
Set-Location apps\kiyori
flutter drive --profile -d <device-id> --driver=test_driver/performance_driver.dart --target=integration_test/home_swipe_performance_test.dart
```

driver 写入被忽略的 `build/integration_response_data.json`（执行目录为 app），含
`first_swipes`、`warm_swipes` 和环境字段。首组为启动后首次四次分页，**不包含冷启动耗时**；
第二组为十轮、共四十次分页。它验证每次目标页，并采集真实 FrameTiming 摘要。
原始 trace、系统输入延迟与帧呈现需 DevTools/Perfetto 另录。脚本注入的手势不能代替真实
手指的触摸到显示延迟。Windows 可运行同入口作为桌面基线，不能外推 Android。

记录版本/commit、设备型号、OS、刷新率、模式、场景、UI/raster P50/P90/P99、超预算帧比例、
最差帧、内存/GC、触摸到首个可见位移、手势胜出方向。默认 integration_test 摘要有部分
90/99 分位和 60Hz missed-frame 字段；高刷要用原始帧时间重新统计，不把 60Hz 计数冒充
120Hz 通过。首轮先建立基线；同设备显著回退必须定位，禁止未经测量编造收益百分比。

在仓库根执行 `tools/summarize-performance.ps1`，读取实际报告中的刷新率和微秒数组，分别
输出 UI/raster 的 P50/P90/P99、最差帧与超预算比例。可用 `-RefreshRate 120` 做指定预算
的离线比较，但这不改变设备当时的运行刷新率。无数据/数组不完整会失败，不输出假零值。

2026-10-02 已在 Windows Profile 执行首四次 + 热四十次分页并生成原始报告，
实际显示器报告 240Hz。桌面数据只证明采集链可用；热滑栅格化曾出现 27.07ms 最差帧，
不能称为零掉帧或 240Hz 达标。历史测量见[历史记录](../status-history.md)，
当前后续要求见[状态](../status.md)。

## 当前验收边界

本轮本地自动测试与构建的实际结果在 [status](../status.md)。未授权设备安装，未采集
Android 真机输入/帧 trace；iOS 缺 Apple 主机。用户报告的旧新手感差异保持
`verification_pending`。增加浏览器平台视图、流式长对话、文档阅读前必须复跑相应场景，
性能是各里程碑的准入条件，不留到发布前集中补救。
