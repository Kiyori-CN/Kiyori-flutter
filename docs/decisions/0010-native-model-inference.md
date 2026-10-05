# 本地模型推理端口

## 决策与范围

状态：CPU文字推理与GGUF导入已实现并通过Windows本机验收；其余能力未接入或待验证。
旧源为 `6b03b03` 的 MNNProvider、LlamaProvider、MNNLlmSession、
LlamaSession 与对应 CMake。保留设置 UI、计算类型、线程与 llama 上下文等字段；
Rust Runtime / ChatRun / SQLite 仍唯一管理请求、历史、总结和取消。

平台实现放在 `packages/kiyori_platform/native`，为有独立 C++ 链接和测试需求的 Rust
adapter crate。依赖 core 的窄推理端口，由 FFI 装配；core 不依赖平台实现或 Flutter。
选择静态 C++ adapter，避免 Dart 再建执行器、网络服务或模型数据库。模型实例归单个
worker，完成、失败或取消后 RAII 卸载。此阶段不保留跨请求 KV/模型缓存，避免陈旧
配置或会话相互污染；后续缓存只能在实测收益及等价隔离证据后加入。

## 构建和供应链

MNN 固定 `ea44a3ebd5dd6348eea501047b17c43aa3ecccb6`，Apache-2.0；llama.cpp 固定
`885c5bbe8e04dc78db25beb911a2715312ad7b54`，MIT。CMake FetchContent 的官方 archive
必须通过 SHA256，源码与编译缓存只进入 target，不提交上游大树或预编译库。
可以使用 `KIYORI_NATIVE_ARCHIVES` 指定同 hash 的本机 archive，以复用已下载内容。
按target在`target/native-inference`共享C++缓存并以OS锁串行构建；
`KIYORI_NATIVE_BUILD_DIR`可指定同目标的已有构建目录，仍重跑固定配置和链接。
Cargo / Flutter hook 都构建真实静态 adapter，不能用独立 smoke 的预编译库冒充产品。
当前先建立 CPU 后端；请求未编译或运行环境不可用的 GPU 后端必须明确拒绝，
不接受引擎静默降到 CPU。GPU、Apple 实际能力分别记录验收缺口。

## 资源和执行契约

模型名解析到同库 completed Transfer / ResourceRef，取得与下载、删除共用的 OS 锁。
锁覆盖配置验证、加载、推理和析构，不允许任意宿主绝对路径。MNN 配置及模型信息
在有界读取、清单 hash 和相对路径验证后合并成内存配置，adapter 不先读取未验证
配置；缓存目录由 core 在私有目录生成。llama 只加载该资源中的 verified GGUF。
MNN内部HTTP资源功能关闭。Omni承担纯文本mrope位置编码，不能替换成基类；用户文字
或模板中的img/audio资源标签在受控媒体接入前明确拒绝，避免隐式读取宿主文件。
附属文件字段也必须在清单中；context.json先有界校验并合入内存，load额外读入的文件
固定为空对象，避免覆盖本次thinking。模型包不能占用.inference-cache目录。

原生调用在 blocking worker；最多 8 个输出分片背压、UTF-8 跨 token 拼接和有界全文。
取消、超时、UI 退订和 Runtime 关闭会通知 worker，ChatRun 的 finished 必须等待所有
原生 worker 析构结束，随后才释放资源锁。MNN 逐 token 停止；不可中断的加载/prefill
等待原生调用返回，因此超时是停止请求后的资源收尾，不是假称立即杀死 C++。
llama 在 load progress、decode abort 与逐 token 间检查停止。
用量来自真实 tokenizer / 输出 token，stop 与 length 分别处理；异常不回显路径或正文。
思考模板与采样参数沿固定源码映射，不向引擎传任意文件或缓存参数。

## 验收与回滚

端口夹具验证跨 token UTF-8、队列背压、停止等待析构、超时、资源删除互斥、配置路径
穿越、未下载资源和参数拒绝；真实 MNN/GGUF 经正式 FFI / 会话 / SQLite 测试。
随后完整 verify、生成一致性、Android/Windows 构建与静态包审计。CPU 本机运行不能
证明 Android 设备、GPU、媒体、原生工具模板或 Apple；这些保持待验证或未接入。
本批不改变 schema；回滚代码保留已下载资源和已有历史，不自动重新执行请求。

## GGUF 用户导入

保留llama说明卡、线程/上下文/GPU字段的布局；说明卡点击打开系统文件选择器，文案投影
新宿主的应用私有资源，不能继续指向旧Android目录。Windows COM普通文件与Android SAF
按1 MiB读取，不把路径/URI交给Dart UI或核心，不保留SAF权限。读取60秒超时及取消触发关闭。
Rust ModelImport句柄持独占OS锁，hash随有界分片计算；头部检查magic/version/tensor数量，
引擎加载进一步校验完整GGUF格式。fsync后原子移入同Transfer/ResourceRef，并事务完成状态。
完成资源保留实际SHA256；选择并导入用户文件不表示取得外部供应链签名。相同名称/hash
允许重选，不同内容拒绝覆盖，必须删除旧资源后重新导入。导入source不走网络续传。
重选也核对completed资源完整hash；缺失时从本次已校验暂存补回，篡改时拒绝覆盖。
rename后事务前中断用同一hash对账。提交期间等待原子交付完成，不报告伪取消；
重复关闭共享同一Future，调用者等待真实文件释放后退出。
未完成、取消、Runtime关闭和句柄析构清理暂存；崩溃残留在下次取得独占锁时回收。

MNN采样沿固定引擎mixed penalty/topK?/topP/greedy或temperature；top_k=0不添加Top-K。
seed、负presence/frequency与repetition<1被上游忽略，因此adapter明确拒绝。非流式回复
保留全文并按UTF-8边界分事件，每事件不超过1 MiB；总输出超过8 MiB明确失败，不能静默截断。
