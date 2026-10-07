# 文件、下载、媒体与终端

本文为目标领域契约。现有 files/downloads 已支持应用私有模型资源与前台传输，见[ADR 0009](../decisions/0009-managed-model-transfers.md)；通用文件、OS 后台传输、媒体与终端的实施状态见[当前状态](../status.md)。

## 资源与文件管理

`ResourceRef` 至少携带稳定 ID、来源种类、workspace、显示名称、MIME、可用能力与授权引用。绝对路径只是 Windows/应用私有文件的一种实现；Android SAF URI 与 iOS security-scoped bookmark 不能强制转换为可自由访问的路径。

文件服务定义 list、stat、read、write、copy、move、delete、import、export；能力通过 handle 查询，不假设所有资源可 seek、rename 或原子覆盖。写入尽可能使用临时文件和原子替换；不支持时向用户表达真实约束。删除和覆盖遵循明确的确认/回收策略，AI 不能把阅读授权当成删除授权。

元数据存数据库，大文件放 blob/用户授权位置。搜索索引、缩略图和音频波形是可重建缓存，与原始资源生命周期分开。外部文件变更后更新引用状态，不悄悄使用旧缓存冒充现存文件。

## 下载状态机

Transfer 保存 URL/请求摘要、凭据引用、目标 ResourceRef、ETag/Last-Modified、已确认长度、校验信息与原生任务 ID。敏感 headers 不明文写日志。

状态为 `queued → running → verifying → completed`；可经 `pausing → paused`、`cancelling → cancelled` 或 `failed`。Range 响应必须验证 206、Content-Range、实体校验器与长度；服务器改变实体或不支持断点时停止并提示重新下载，不盲目拼接数据。

前台传输可由 Rust 执行；后台传输按平台委托 Android 工作/服务机制、iOS background URLSession 或 Windows 适配。**同一 Transfer 同时只有一个执行者**，移交需先记录 lease/代次并停止旧执行；启动后查询 OS task 对账，不能两个引擎抢写同一文件。

网络错误、空间不足、失去文件授权、进程被杀、设备重启和目标冲突要有独立可恢复状态。完成需先校验再交付文件。若资源来源自浏览器，Cookie/认证仅按授权以有限方式转交，不复制整个浏览器 cookie jar。

## 音视频共用播放服务

视频与音乐是两个界面入口，共用媒体库、队列、播放命令、缓存和系统媒体会话。原生播放器拥有时钟/解码/缓冲事实；Rust 保存库、播放意图、进度持久化和队列；Dart 展示事件，不启动第二个播放器争用音频焦点。

候选路径优先评估成熟跨平台播放器封装，并核验其 Android、Windows、iOS 后端、许可证、硬解、字幕、后台和体积。平台原生方案（Android Media3、iOS AVPlayer、Windows 原生/成熟媒体引擎）是可比较候选；本阶段不无依据锁定 mpv/FFmpeg 或宣称其三端功能完全一致。

M4 的播放器 spike 决定具体依赖，产出格式/字幕/DRM/后台能力矩阵。协议不支持的资源返回明确原因，不偷偷下载成临时文件或切换引擎。缓存与下载共用资源服务，下载完成后可播放但不能制造第二下载任务。

验收包括暂停恢复、seek/拖动、切歌、音视频切换、音频焦点、耳机拔出、锁屏控制、字幕、播放结束、错误资源、旋转/窗口变化和释放纹理。视频帧走原生 texture/view，不走 FFI DTO。

## 终端与进程

Terminal 是独立平台能力，不等于 Script。Windows 可用 ConPTY/受控进程，工作目录、环境和输出明确记录；进程命令使用参数数组，不由未信任输入拼接 shell。输出有背压与保存上限，超限可导出日志，不持续耗尽内存。

Android 在应用沙箱内评估随包 runtime 与合法执行限制，不能假设 root、系统包管理器或已有终端。iOS 不承诺任意本地 shell；若未来提供用户显式配置的远程终端，它是独立功能，不可当作本地功能静默替代。

新项目不引入旧 terminal 子模块或复用其 socket/home。实现时验证独立 UID/应用目录、进程树取消、环境变量和服务发现。工具执行授权与交互终端授权区分，模型不能因终端存在就自动拥有任意命令执行权。
