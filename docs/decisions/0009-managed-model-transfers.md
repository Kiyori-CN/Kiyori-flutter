# ADR 0009：托管模型资源与前台传输

## 来源与选择

2026-10-05实施。旧MnnModelDownloadManager、MnnModelDownloadScreen来自6b03b03，
模型市场优先ModelScope仓库。旧续传只检查已有长度后追加，未检查206、Content-Range
或实体身份，改名结果也未可靠核对。新实现先交付应用私有模型包用例，复用Runtime、
HTTP client与SQLite，不在Dart建立下载器或第二模型文件目录。

ResourceRef保存稳定hex标识、workspace、来源、名称和MIME。当前来源为application_private，
不把Android SAF URI、Apple bookmark或用户授权路径强制转换成托管路径。托管目录只由
Application Support/resources/内部标识推导，上游模型名称与文件路径均不能指定绝对目标。

## 执行与文件契约

schema16增加resources、transfers、transfer_files和最后成功的local_model_market。
schema17增加restart_required：Range/实体/编码/大小/哈希失败记录损坏事实，
只有用户重试才重置本任务未验证文件及实体信息，已验证前缀继续复用。网络中断仍保留断点。
终态落库或快照读取失败经事件错误返回，不吞错、不报告完成。
Transfer保存冻结清单、每文件SHA256、大小、确认长度、实体校验器和阶段。OS独占文件锁
覆盖一次执行与删除，同任务跨Runtime/进程只有一个执行者；无锁的中断任务恢复为paused，
不自动外发请求。模型市场刷新失败保留旧目录，解析/数量/体积上限超出时拒绝完整结果。

当前提供前台Rust执行。离开本地模型页暂停其启动的任务；Runtime关闭取消网络与落盘后
释放锁。尚无Android前台服务、Windows后台传输或Apple URLSession移交实现，不能声称
应用退出后仍继续下载。后台adapter后续须沿同Transfer交接，不能启动第二执行者。

临时文件位于包内独立.partial树，避免上游文件名与临时后缀冲突。路径拒绝穿越、Windows
保留名、链接和大小写冲突。逐块写入有界缓冲，刷新并sync_data后保存确认进度；停止
等待worker结算。续传核对206、完整Content-Range、Content-Length、identity编码及已有
ETag/Last-Modified；无校验器时仍需冻结revision和完整SHA256才能交付。

完成前重新读取全文件SHA256及大小，校验失败保留失败状态，绝不把部分内容发布成模型。
校验通过后同盘rename，检查结果后标verified；崩溃在rename后、提交前重开会重新校验。
完成资源只有清单中的verified文件可交给推理adapter，不提供任意路径读写权限。

网络使用既有TLS根，无自动重试。下载不发送API凭据；重定向只允许原来源主机及其明确
ModelScope/HuggingFace资源域，限6跳并拒绝降级。失败消息不含URL、宿主路径或响应正文。
持久清单URL属于公开模型来源，不引入下载凭据存储；未来认证用例必须扩展安全引用契约。

## 依赖与回滚

直接声明已由TLS引入的ring0.17.14作增量SHA256，版本和许可证沿锁定依赖，未新增一套
密码算法。tokio启用fs/io-util用于文件异步I/O。[ring digest](https://docs.rs/ring/0.17.14/ring/digest/index.html)
提供增量Context，Range语义依据[RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#name-range)。

升级不改schema15的会话或摘要表。回滚须使用升级前一致数据库与二进制，不降低
user_version或让旧版本读取schema17；模型文件属于可重建托管资源，用户文档未参与删除。

## 验证边界

Rust真实loopback验证正常交付、错误Range/实体/哈希、路径、单执行者、停止和重开。
正式Dart/FFI页面使用合成目录与文件，验证暂停续传、重开、确认删除及刷新失败保留列表。
供应商聊天API不能证明模型下载或本地推理；公共模型目录、小文件与完整包实测分别记录
到status。最终全量验证、双端构建、设备后台/Profile与Apple证据不能互相替代。
