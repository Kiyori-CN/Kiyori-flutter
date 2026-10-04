# 聊天配置与交互复刻对照

唯一来源为只读 `Kiyori-Android` revision `6b03b03aa082803bb279db5e78773583e2d91154`。
旧路径以 `app/src/main/java/com/ai/assistance/operit/` 为根，新路径以
`apps/kiyori/lib/features/assistant/presentation/` 为根。当前进度与最终证据以
[状态](../status.md) 为准；以下是可逐项核对的来源、差异与验收要求，不代表已经全部实现。

## 来源、状态和修复契约

| 入口与状态 | 旧文件与符号 | 新实现及基线差异 | 修复与验收要求 |
| --- | --- | --- | --- |
| 模型/API协议当前值、选择 | settings/sections/ModelApiSettingsSection.SettingsSelectorRow、ApiProtocolSelectionSheet | models/model_api_connection 漏传协议summary，值排到右侧 | 复用summary分支，标题/值/说明左对齐3间距；保留无summary选择行；协议抽屉选择与返回 |
| 模型初始化、重开、保存、清理失败 | ModelConfigScreen snackbarHost；新ADR0006的安全存储协议 | models_controller将锁忙与清理失败混同；persistent_models_page在SafeArea外放ListTile | 同owner串行安全操作；区分锁忙与不可用；retired保留重试，active不删；错误用原反馈方式且不覆盖状态栏 |
| 顶栏下操作行 | chat/components/ChatHeader、ChatScreenContent | chat_page的历史、悬浮、角色、统计；统计和悬浮空动作 | 顺序与32/24/36几何；运行数≥2历史徽章；角色名称最大12字符；统计来自正式事实 |
| 历史空/非空/搜索/设置 | AIChatScreen历史遮罩、ChatScreenContent.ChatHistorySelectorPanel、ChatHistorySelector | chat_dialogs使用75%底部面板，缺搜索/设置 | 左抽屉共享宽度，小屏75%、600起320、840起360；右侧16圆角、遮罩、Back和收起 |
| 会话新建、选择、编辑、删除 | ChatHistorySelector manage drawer / metadata dialog / delete confirmation | 已接Rust基础CRUD，现有简单菜单非旧布局 | 从真实目录派生；操作失败保留弹层；实体移除和迟到回调隔离；分组/置顶等能力逐项记录边界 |
| 角色选择 | CharacterSelectorPanel及宿主回调 | chat_dialogs简单列表 | 核对标签/当前项/新对话语义、取消、删除与刷新；复用prompts owner |
| AGENT输入空/多行/键盘/生成 | style/input/agent/AgentChatInputSection | 现有输入大体几何，停止图标/色错误，模型宽无限 | min44/max6行、12×8外内距、模型max220、停止Close/error背景；保留取消部分正文 |
| 全屏输入 | FullscreenInputDialog | 通用AlertDialog误作全屏，取消丢草稿 | 全屏安全区/键盘、关闭/Back/确认均保留草稿，确认不发送；切会话和宿主释放 |
| 模型面板及嵌套 | AgentModelSelectorPopup、AgentThinkingSettingsItem、AgentModelSelectorItem | 60%底部选择器，缺思考/MAX/说明 | 输入上方右对齐300/max420弹出卡，bottom44/end12；真实模型稳定ID选择，说明和嵌套状态 |
| 设置选项及嵌套 | AgentExtraSettingsPopup、AgentToolsPermissionGroupItem、AgentBehaviorSettingsGroupItem | 错跳模型配置 | 本地面板及说明、记忆/工具/行为，管理页按原入口；未接能力不伪造执行 |
| 附件/语音 | AttachmentSelectorPopupPanel、AgentChatInputSection语音回调 | 空点击 | 完整一级/二级本地UI；设备、媒体抓取与执行明确能力边界，不自行操作设备 |
| CURSOR用户消息 | cursor/UserMessageComposable | 错用Markdown，标题带非旧more按钮 | 16横距、4纵距、8圆角、16内距、Prompt/8间距、14纯文本；原文完整 |
| CURSOR助手消息 | cursor/AiMessageComposable、StreamMarkdownRenderer | 标题错用model，缺Response/role；流中纯文本 | 默认Response/角色，模型/provider默认隐藏；流式与终态Markdown一致、长消息不截断 |
| BUBBLE与CLASSIC切换 | bubble/BubbleStyleChatMessage、classic/ClassicChatInputSection、UserPreferencesManager | 默认固定模式，主题编辑尚未接聊天偏好 | 核对真实偏好owner、切换后草稿保留与状态一致；不得新建平行偏好库 |
| 长按菜单、复制/选择 | ChatArea.MessageItem / MessageCopyPreviewBottomSheet | more菜单替代长按，直接复制 | 180宽/6圆角、13字/16图标/40最小行高；复制预览、原文/纯文本、可选择；操作顺序按旧源 |
| 编辑/重发/回退/删除/再生成 | ChatScreenContent、ChatArea、ChatViewModel | 已有Rust事务，弹窗和某些语义需复核 | 校验后事务替换；迟到结果不写新会话；确认/取消/失败与部分内容保留 |
| 消息其它入口 | ChatArea朗读、回复、摘要、分支、信息、多选 | 缺失 | 本地可操作UI与正式业务边界逐项验证；不以简单占位替代可复用业务 |
| 滚动与释放 | ChatArea跟随、消息选择身份、输入焦点 | ChatMessages局部流通知与跟随已有 | 用户上翻不跳走、返回末尾、尺寸变化、稳定ID、历史重开、关闭等待 |

## 默认值及证据层级

UserPreferencesManager 的 `chatStyle` / `inputStyle` 默认是 CURSOR / AGENT；
AiMessageComposable 的模型提供方与模型名称默认隐藏、角色默认显示。
不把历史文档中的“已实现基本聊天”当作这些状态已经复刻的证明。

验收分别记录源码几何、widget行为与截图、真实FFI/SQLite/DPAPI、Windows引擎、
指定供应商合成请求、Android实机与Profile。没有同环境并排证据不声称像素完全一致。
真实请求只允许用户指定端点和模型；密钥不得进入任何证据。设备/Apple/Profile独立列项。

## 2026-10-04 精确几何复核

历史宿主源为AIChatScreen的Scaffold内容Box，边界是状态栏+主栏64及分隔线0.5；
角色选择在同一边界内向下60、横20。新ChatPanelRoute同时限制遮罩与面板，历史
动画距离取面板自身宽度。输入默认不透明/非浮动：AgentChatInputSection的
outerDiffuseShadow用五层、spread6、alpha0.025递减，暗色topEdgeHighlight为line1、
alpha0.05、glow2/0.015；不能替换成普通14模糊阴影。玻璃与浮动偏好仍属待接入分支。

AgentInfoPopup为右下220宽、bottom52/end12、16内距、16粗标题、14/20正文，
没有确定按钮。模型/设置/附件卡使用KiyoriSurfaceTokens的popupElevation3和
surfaceContainerHigh。ChatStatisticsSheet的说明全文来自values/strings.xml，
StatisticsCard圆角16/内16/间10，行宽不足300或字比例大于1.3时纵排；统计事实来源
尚缺缓存/推理与上下文估算，字段保持未知。消息信息的durationMs已由核心使用
finished_at-first_output_at计算，UI不能再次扣除等待；统计durationMs则为请求总耗时。

## 阶段预览交付边界（2026-10-04）

用户要求收住本轮开发，先构建并推送供手动安装检查。当前实现不作为全部入口复刻完成证据。
本批补充了CLASSIC设置及模型嵌套、两种模式的回复预览、历史手势与同角色排序、
批量删除事务和Back退出、消息统计元数据、非流式请求、回复版本切换/删除/分支复制。
单条重新生成使用目标运行的角色身份；缺失旧身份快照时明确拒绝，原历史不变。
Markdown普通闭合段落增量保留，复杂尾部及跨段引用/HTML保守求值，完整原文保留。

仍需后续源码及设备核对：历史文件夹在角色模式下的作用域和组删除选项、精确拖拽/滑动反馈、
CLASSIC附件内联形态、角色排序持久化、消息图片分享、摘要生成和编辑修订审计。
相机/图片/文件等设备附件、语音、悬浮窗、记忆查询/提取、工具包及插件执行尚未接通；
已实现的入口明确反馈能力边界，不报告执行成功。记忆文件夹可从真实目录联选、预览和移除，
未接查询工具时阻止携带附件发送并保留输入。外部Markdown图片与链接的交互仍需接入。
同环境旧新并排、Android实际键盘/触摸/安全存储、Profile和Apple构建未验证。
