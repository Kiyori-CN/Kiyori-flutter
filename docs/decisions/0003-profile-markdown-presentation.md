# ADR 0003：用户资料 Markdown 展示

状态：采纳；2026-10-02。限定静态用户资料 UI，不替代未来共享文档引擎或流式聊天渲染器。

## 背景与选择

旧用户资料编辑器对 Markdown 语法着色，预览使用旧 MarkdownTextComposable。
新工程尚无 Markdown 解析器。为了支持嵌套列表、转义、代码与表格，采用 Dart 官方维护的
`markdown` 7.3.1 解析静态 AST；渲染仍由 Flutter UI 组件控制，按旧字号/间距逐步复刻。
源码位置为 assistant/presentation/profile，未成熟前不扩张为公共 package 或业务服务。

编辑高亮直接映射旧 MarkdownSyntaxHighlighting 扫描规则，保留原文和 UTF-16 偏移；
行内前看上限512字符，文本不变时复用扫描结果，IME composing 下划线与颜色叠加。
预览只在文本变化时解析，顶层块使用惰性列表；网络图片、媒体、外链和保存不产生副作用。

## 取舍与验证

手写完整 Markdown parser 会重复标准语法并增加维护风险；直接采用默认主题的整套
Markdown widget 无法保证旧 UI。纯 Dart AST 依赖不引入原生插件，锁文件只新增此包；
依赖为 BSD-3-Clause，来源见[官方包页](https://pub.dev/packages/markdown)。

基础标题、段落、强调、引用、列表、任务项、代码、表格先实现；旧媒体/LaTeX/图表专用
渲染仍待后续能力接入，不将静态预览声称为完整旧渲染器。保留输入原文，不截断未知语法。
验证覆盖语法区间、畸形输入、光标/组合输入、宽窄屏、键盘、预览切换、取消/丢弃和超限。
回滚可独立撤销预览依赖与该 feature，原始草稿接口不依赖第三方 AST。
