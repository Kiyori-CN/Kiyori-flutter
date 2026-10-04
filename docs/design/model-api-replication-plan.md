# 模型与 API 复刻实施方案

## 目标与证据基线

本轮目标为设置 → AI助手 → 模型与 API 的全部界面与实际功能。旧源为只读
`D:/10_Project/Kiyori-Android` / `6b03b03aa082803bb279db5e78773583e2d91154`，
新源基线 `main` / `dcc5fbb5f5050e4a659510be652275694a74f82f`，开始时干净。
允许本轮代码、文档、本机测试/构建及提交推送。2026-10-05 用户另授权所提供的
DeepSeek / deepseek-flash 与指定中转 / gpt-6.1-sol 两个端点的真实合成测试；凭据只在
测试进程内存中，结果保留脱敏信息。设备安装、发布和部署不包含在该授权内。
既有界面与业务逐项核实后复用，不以代码数量替代完成标准。

## 来源与完整行为矩阵

旧文件均相对 `app/src/main/java/com/ai/assistance/operit/`。

| 分组 | 权威旧源 | 现状与本轮验收 |
| --- | --- | --- |
| 配置选择/新建/重命名/删除 | `ui/features/settings/screens/ModelConfigScreen.kt`、`data/preferences/ModelConfigManager.kt` | 已有 Rust/SQLite 与 Dart 接入；核对默认配置保护、引用、保存失败和返回刷写 |
| API/协议/端点/密钥/本地参数 | `ui/features/settings/sections/ModelApiSettingsSection.kt`、`ModelApiProviderPresentation.kt` | 既有提供方目录、协议抽屉和持久化；核对自定义端点保留、实际地址、遮蔽和参数 |
| 模型标签/排序/复制/删除/清空 | `ui/features/settings/components/ModelNameTagEditor.kt`、上述 section | 复制、删除和清空原为空动作；接实际剪贴板、引用事务、失败回滚和撤销 |
| 上游模型目录 | `api/chat/llmprovider/ModelListFetcher.kt`、`ui/features/settings/components/UpstreamModelPickerSheet.kt` | 获取原为空动作；复刻搜索、筛选全选、当前/将移除、增删统计、刷新、取消和应用 |
| 上下文与总结 | `ModelConfigScreen.kt` | 已持久化；继续核对校验、总结执行及其依赖，保存成功不证明总结执行 |
| 参数四页/自定义类型 | `ui/features/settings/sections/ModelParametersSection.kt` | 已有完整草稿与持久化，核对启用值进入实际请求、JSON 与核心保留字段 |
| 请求头六预设 | `ModelConfigScreen.kt` | 已有安全 payload 持久化；核对新增条目输入触发保存、键去空白、重复键及请求使用 |
| 队列与密钥池 | `ui/features/settings/sections/AdvancedSettingsSection.kt`、`ApiKeyProvider` | 已接配置级 RPM/并发门控，保存限制唤醒既有等待者；工具续答逐次轮换，目录共用持久游标 |
| 综合模型测试 | `ModelConfigConnectionTester.kt` | 已接聊天/system、原生与XML工具两步随机结果续答、启用媒体和当前流式/思考偏好；供应商分项结果见 status |
| 协议与原生能力 | 各旧 `llmprovider`、`:mnn`、`:llama` | 四种网络协议接同一请求核心；本地推理/下载、扩展 provider 仍是实际缺口，不能称全功能 |

## 实施顺序与架构选择

1. 深度审计：入口 → 配置 → section → manager → 请求编译 → provider → 原生 adapter；
   从资源核对文案、尺寸、主题、图标、空态及层级，建立可追溯矩阵。
2. 模型目录完整切片：沿用 Runtime 的单 HTTP client、取消树和有界 ChatRun 事件通道。
   Rust 负责 URL 派生、认证、分页、去重和错误脱敏；FFI 提供类型化 ModelEntry，
   Dart 只持有当前选择和可取消请求。避免在 UI 新建 HTTP client 或配置存储。
3. 配置事务与生命周期：删除已绑定模型必须显式替代，移除最后绑定模型拒绝；失败保留
   原目录。清空仅用于无引用配置。撤销需保留实际影响的绑定与 revision，不能覆盖随后
   修改的功能/角色。端点/密钥/协议变化、切配置、宿主退出使目录结果失效。
4. 请求行为切片：同一核心补协议、流式/思考测试、速率/并发队列及工具闭合；协议端点
   不支持时返回明确原因，不用假的通过标记。新公共契约覆盖超时、取消和释放。
5. 原生切片：本地模型下载必须复用 Transfer/ResourceRef；推理 adapter 单独持有模型和
   线程/GPU生命周期。未建立的共享下载与资源服务是实际前置依赖，不能用 Dart 临时下载器。
6. 最终复核：相关定向、全量 verify、生成一致性、Windows 集成、双端串行构建、固定包、
   最终暂存树与远端 ref；设备并排像素/键盘/触摸/Profile 和 Apple 编译独立验收。

## UI 与错误契约

上游抽屉沿用旧 360–720 内容范围、20px头部/搜索边距、44px圆形图标与刷新、
56px搜索、48px筛选行、16px列表边距/6px行距、0.7px边线、10×7行内边距、
46px底部按钮与14px圆角。手机/桌面共用既有 KiyoriModalDrawer；矮屏与大字优先保留
列表滚动和底部按钮可达，不截正文。真实 Android 字形需同设备截图核对。

目录整次请求有超时，正文/条目/分页有上限；超限或格式异常明确报错，不发布截断目录。
保留代理路径前缀，以当前配置协议决定认证；不凭提供方名称把用户密钥转送到另一主机。
刷新失败保留最后成功目录和选择。取消不报告“空目录成功”，请求不自动重试或跟随重定向。
旧源记录端点和异常正文的日志风险不照搬。模型名是来自上游的不可信显示文字，
不允许其成为 URL、路径、脚本或凭据发送指令。

## 验证与完成条件

先 Rust loopback 验证目录 URL、认证、分页、重复、畸形、上限、HTTP/超时/取消及重定向；
再真实 FFI/SQLite/DPAPI 与页面测试复制、删除/引用保护、清空/撤销、刷新失败和迟到结果。
捕获明暗、320宽/双倍字/键盘、横屏及桌面，审阅默认态与选择/确认/错误态。
执行 `tools/generate-bridge.ps1` 与 `-Check`、`tools/verify.ps1 -WindowsIntegration`，
随后 `tools/build.ps1 -Platform android/windows -NoPub` 串行构建普通产品入口。

所有矩阵项目的实际执行与必需验收满足后才能关闭“全部 UI 与功能”目标。构建通过、
本机 Flutter 捕获和供应商单协议成功均不能替代全功能或像素级验收。
回滚点为上述基线及一致用户数据备份；本切片不主动降低 SQLite schema、清库或覆盖凭据。

## 剩余功能的依赖与完成信号

这些属于原任务范围，不能因网络切片交付而删除，也不能标为仅待设备验收。

| 顺序 | 范围与实现位置 | 不变量与风险 | 完成信号 |
| --- | --- | --- | --- |
| 1 | 总结执行：`core/conversations` 协调 `summary` 功能绑定与安全凭据租约 | 现有 UI 只保存阈值/规则；需要继承旧摘要、计数/比例触发、取消、失败保留全文、修订冲突保护；不得在 SQLite 事务中等待网络 | 同一会话长历史真实压缩、重开恢复、自定义规则、关闭总结、失败/取消/编辑后失效测试通过 |
| 2 | 共享资源/传输：首个 `core/files` ResourceRef 与 `core/downloads` Transfer 用例 | 应用私有模型资源和用户授权引用区分；持久任务只有一个执行者，Range/ETag/大小校验与原子交付；Dart 无临时下载器 | 本地模型页真实刷新/开始/暂停/续传/取消/删除，重启对账、断流/空间不足/实体变化通过 |
| 3 | MNN / llama.cpp 原生 adapter，`kiyori_platform` 拥有句柄与线程/GPU生命周期 | 旧源 CMake 分别 pin MNN ea44a3e、llama.cpp 885c5bb；不能复制旧 JNI/预编译库伪装跨平台实现；新增依赖先审许可证与正式构建 | Android/Windows 能加载对应资源，设置参数真实传入，流式/取消/卸载与错误测试；Apple 实际编译独立验收 |
| 4 | TOOLPKG 模型提供方，统一扩展目录/manifest/执行与授权 | 旧 ModelApiProviderPresentation 的 TOOLPKG 是动态目录；现有内置提供方列表不能替代它；执行器不得获得任意文件/网络权限 | 安装/启停/卸载目录更新、配置身份与撤权、协议/模型列表/请求、超时取消/恶意结果有真实宿主测试 |
| 5 | 同设备 UI 与性能验收 | 本机字体 PNG 只能证明布局，两个供应商不能证明 Gemini 或本地能力；保持旧尺寸、层级、资源与返回语义 | 用户指定并授权设备后，旧新同机截图差异、键盘/触摸/Profile及可访问性有记录 |

网络阶段真实测试至少覆盖目录、Chat/Responses/Messages×流式/非流式、系统口令、
原生及XML工具续答、图片，并如实记录音频/视频拒绝或未验证。默认整体验证跳过真实
供应商套件；只有显式注入进程凭据才运行，单次套件退出成功不表示矩阵全部通过。

## 思考参数的旧源与当前协议合同

旧ModelCapabilityProfile在6b03b03版本只覆盖5.4/5.5/5.6及6 Astra，缺少用户指定的
Sol6.1。2026-10-05核对[官方GPT-6说明](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6.1-sol)，
Sol6.1支持low/medium/high/xhigh/max，不支持none/minimal；自动映射五档且关闭时报明确
原因。显式reasoning或reasoning_effort配置保留用户控制，中转接受none不能证明真正关闭思考。
工具官方使用Responses，中转另外的Chat/Messages成功只能代表该代理的兼容能力。
测试通过KIYORI_LIVE_THINKING_LEVELS显式切换实际偏好，移除原none测试参数，避免跳过编译器。

DeepSeek仍沿旧DeepSeekModelContract的low/high/max映射，UI后三档都映射max；真实验证
覆盖三个不同请求值和流式/非流式，不用重复等价请求增加通过数量。原生Chat工具探测的
reasoning_content只存于有界执行对象、在工具结果续答中回放；不发送给Dart或落入会话表。
