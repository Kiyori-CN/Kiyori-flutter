# 当前实施状态

更新时间：2026-10-03（Asia/Shanghai）。本文件是当前实施进度唯一权威；
[路线图](roadmap.md)规定顺序，[历史记录](status-history.md)保留过往批次证据。

## 当前任务：设置全树与AI真实业务连续开发

当前正式Goal为active、无预算。开工实查main/HEAD及fetch后的origin/main均为
`4a69550bc5e2489c02d144b3a4eb45e5266870fa`，左右差异0/0，工作区与暂存区干净。
只读旧仓库HEAD为`6b03b03aa082803bb279db5e78773583e2d91154`且干净。
本任务授权范围内实现、验证、串行Android/Windows构建、精确提交与普通推送；不操作
设备、账号、私人收费端点、生产或CI，不启动自动化，不委派。日记local_only、Asia/Shanghai。

阶段A/B已完成设置UI的本地验收：12项及设置子树的映射、状态、弹层、返回和代表截图
以settings-replication-map及下述十一批证据为准。当前转入AI左抽屉及真实业务切片；
AI重要功能未实现时Goal保持未完成。设置业务写入与平台动作仍不计为已实现。
每周期按相关性合并有效实现，完成批次继续下一批。总验收包括源码映射、行为/截图、
静态/FFI/集成、双端构建、固定产物及远端一致；设备/供应商/Apple缺口单列。

AI第一批实施基线main/248d49a与origin/main同步；设置正式代码为450999b，
428b0ad误跟踪本机产物清单后已由248d49a普通提交移出索引，当前最终树与450999b相同。
产物继续保留本机忽略目录，不再强加索引。抽屉28项联合回归通过，6张最终捕获在
work/ai-drawer-capture-v3，analyze-v3无问题；320明暗/标题已审阅。
工作流已加入Rust SQLite目录存储、schema1、真实应用支持目录与桥接DTO，创建/编辑/
启用/删除及原子批量删除通过真实存储和跨桥验证。
范围与旧源见[AI映射](design/ai-replication-map.md)；节点/模板/执行/调度、扩展与记忆真实
业务尚未实现；本批定义切片已完成本机验证和双端构建，不能视为AI阶段完成。

工作流随后补入编辑/启用、来源Back、浮动菜单、多选/全选/清空/批量删除及更新时间投影。
最终完整verify-final-v2通过：53文档/4脚本、Rust fmt/Clippy/12测试、265 Dart格式/analyze、
Flutter470（10捕获跳过）、真实FFI7、Windows引擎3；日志work/workflow-verify-final-v2.log。
桥接Check五文件一致。工作流v5十三项及12PNG通过，work/workflow-capture-v5保留；
320明亮列表/错误及1280暗色列表已审阅。初轮类型、测试帧推进、未使用导入和花括号lint
失败均已修正，原失败日志保留，没有缩小断言或关闭检查。

双端Debug构建通过；首次固定产物20261003-073131审计发现path_provider的JNI传递依赖
混入非目标ABI，原目录保留且不作为最终交付。Gradle现按Flutter target-platform过滤
依赖JNI，split-per-abi仍交给Flutter；Android重建37.2s通过，Windows未受影响复用已验证
普通产品构建。最终固定artifacts/ui-preview/20261003-073852：APK91429003字节、SHA256
14C9EB99EE73876313056E857802C7617CA7817B4ECDA101AE64F7BBBF4426F0；Windows83文件129905521字节。
APK实际ARM64、身份/v2签名/ZIP16K/全部ELF LOAD对齐、Windows x64/DLL pin/native资产
及84个副本逐文件哈希通过。本机manifest及失败审计留在忽略目录，精确提交不包含产物。
本批交付后继续扩展和记忆根关联树，设备/Profile/供应商/Apple仍未执行。

AI第一批已交付`b1c354af826c1e4c17ac580d8616bd95d9e7346f`，普通推送后本地/远端一致，
0/0干净；44文件精确提交，491文件交付树审计无发现，固定manifest仅本机补提交。
第二批正在实现记忆库空间/目录与手工条目：将共享连接和迁移提取到core/storage，schema2
新增记忆空间、活跃空间、目录、条目及标签，schema1工作流数据保持。创建/编辑/归档/删除、
空间固定身份和删除级联、目录重命名/保正文删除、Rust分页搜索已通过18项Rust测试。
列表每页100条400字符摘要，详情按空间/ID读完整正文，105条跨页与长正文回读已测。
Flutter十六项定向v11通过；v10十四项及30PNG位于work/knowledge-capture-v10，已审阅
320明亮列表/暗色目录、844横屏编辑和1280暗色筛选。小屏双倍字空态按钮需滚动可达；
标题省略、目录折叠树/长按子目录菜单、标签单选与完整候选集仍需后续校准。
工作流和记忆共享迁移owner，目录与筛选已校准底部抽屉、编辑主题/目录下拉与详情菜单。
完整verify-v3通过：53文档/4脚本、Rust fmt/Clippy/18、270 Dart格式/analyze、Flutter486
（10捕获跳过）、真实FFI8、Windows引擎3。v1/v2花括号lint、v8错误Tooltip定位已修，
失败证据保留；v11补控制器替换释放和迟到详情错误隔离。桥Check五文件一致。
双端普通产品Debug构建通过，Android38.8s、Windows18.3s；固定产物为
artifacts/ui-preview/20261003-085102。APK112838380字节，SHA256
9800BCA9FD72F0881D4A1B26BF3FFBA716C643DC1E998CB46DD5B6F18C978911；Windows83文件130333977字节。
ARM64/身份/v2签名/ZIP16K/ELF LOAD、Windows x64/DLL pin/native资产与84份复制哈希通过。
包内Rust DLL时间为08:30:51，晚于最后Rust源码08:30:31，hook依赖包含knowledge/storage；
直接加载固定包DLL的8项FFI再次通过，未以时间戳推断陈旧产物。审计498文件无发现。
日记开篇/续写、文档导入/语义索引/图谱未实现，不能称记忆树完成。

记忆基础批次已交付2399b5ec014ceeb8d7ac168e930954f0150faeb3，普通推送后0/0干净。
下一批补目录惰性折叠树、长按/更多、新建子文件夹固定目标，以及完整查询范围标签候选。
候选由Rust在同一读事务按空间/类型/搜索/归档/目录计算，不受分页和主题/标签筛选截断；
筛选抽屉改为单选惰性列表，超过8项可搜索、重置清空输入、已选候选保留。
定向v5十八项与30PNG通过，代表目录明暗/横屏和暗色筛选已审阅；Rust18通过。
首轮Sliver菜单锚点错误改为行内Builder，标签测试文本重复定位改为真实RadioListTile，
失败日志保留。完整tree-verify-v1通过：Rust18、272 Dart格式/analyze、Flutter488
（10捕获跳过）、真实FFI8、Windows引擎3，桥Check五文件一致。串行双端Debug通过，
固定artifacts/ui-preview/20261003-091731：APK112846387字节，SHA256
7A63E4D54DF6E5BAEAB4BCB2327082C2BF2DC37B1F8112A7D37BD35720CCA7E9；Windows83文件130360809字节。
ARM64/签名/ZIP16K/ELF LOAD和Windows x64/DLL pin/native资产与84份复制哈希通过。
审计500文件无发现，无新依赖或schema变化；日记、图谱、导入及记忆设置继续实施。

目录/标签批次已交付be6a8d0bf76b7438c23c9e36f5372629db290f6d，远端一致0/0干净。
日记批次实施中：Rust正文阶段解析、开篇、原子追加、完结/恢复与列表摘要、状态筛选已接；
Flutter开篇阶段、时间线、续写/结束、全文编辑提示、日期组和状态筛选已投影。
diary-core-v5共22通过，含独立runtime并发追加和103条状态跨页。后续补真实日期校验、
全文编辑前续写确认、失败收尾总结保留/重试、状态徽章、日期计数和时间线连线。
最终diary-ui-v15六通过、17PNG，真实Native开篇→续写→全文编辑→状态筛选贯通；
记忆18项在v13通过，代表明暗/320/横屏/桌面、开篇/列表/筛选截图已审阅。
完整diary-verify-v2通过：Rust fmt/Clippy/22、276 Dart格式/analyze、Flutter494（10捕获
跳过）、真实FFI9、Windows引擎3；bridge-check-v1五文件一致。早期DTO漏字段、测试
定位/帧等待、小屏溢出与v1花括号lint均已修，失败证据保留。505文件交付树审计无发现。
串行Android/Windows普通产品Debug构建通过，分别72.0s/19.0s；固定产物
artifacts/ui-preview/20261003-102209。APK112881267字节，SHA256
B557FB0F433F5EF4B5AD3FF0F4490D2F7F49D9ED8896672ACAC686F773BFE605；Windows83文件130511265字节。
ARM64/身份/v2签名/ZIP16K/ELF LOAD和Windows x64/DLL pin/native资产与84份复制哈希通过。
本批24文件精确交付后继续图谱关系；没有依赖/schema变更。设备/Profile/Apple仍待验证，
全文单节超长布局和大规模状态扫描尚无Profile证据，日期分组只覆盖已加载页。

日记批次已交付19ee6acbfe8d174d2c1cfc2d263c686e5efb7427，远端一致0/0干净后继续图谱。
图谱关系实施中：schema3关系表与级联、同读事务200项查询、描述回读、去重/自环/跨空间
拒绝及原子批删已实现。graph-verify-v1完整通过：Rust fmt/Clippy/27、280 Dart格式/analyze、
Flutter498（10捕获跳过）、真实FFI10、Windows引擎3；桥Check五文件一致。
Flutter图谱、平移/缩放、两点连线、边详情/编辑删除、框选删除已接入；v4联合28通过、
57PNG，v6图谱五项和12PNG通过，真实SQLite连线→描述编辑→缩放→边删除→框选批删贯通。
末轮补空图谱新建入口、相同拓扑引用快速返回、长标题关系编辑器整体滚动，320/844双倍字
与键盘保存通过；代表键盘/边标签截图已审阅。首轮框选起点、异步帧等待、字体与lint失败
已修，原日志保留。布局采用有界隔离线程力导向、稳定初始位置和标签缓存，未作Profile
性能结论。图谱开关当前仅页面状态，按空间持久偏好随检索设置切片接入。
最终graph-ui-final联合29项、analyze和foundation通过；510文件审计无发现。串行普通产品
Android/Windows Debug构建47.9s/18.4s通过；固定artifacts/ui-preview/20261003-110631，
APK112937982字节，SHA256
91A3C4BE68C7FF647DAC7E0D69795D7D8DA9B3662C4353BED16A3316C6D320C1；Windows83文件130735385字节。
ARM64/身份/v2签名/ZIP16K/ELF LOAD、Windows x64/DLL pin/native资产和84份复制哈希通过。
本批本地实现验证闭环，下一批记忆检索设置与偏好，随后继续扩展和AI真实业务。

图谱批次已交付5cee6d164245a95176a301f32807cedede5d3950，普通推送后远端一致0/0干净。
记忆检索设置实施中：schema4保存空间权重、间隔、规则与图谱偏好；图谱独立列更新避免
设置草稿覆盖另一窗口显示选择。Rust本地模拟搜索逐条扫描完整正文，Jieba搜索分词、
词法/标签RRF、反向包含与范围内关系传播已实现；31项Rust、Clippy及analyze已通过。
最终memory-search-ui-v4四项通过，含真实SQLite保存/模拟/重开、切空间释放弹层及偏好隔离；
v3五张捕获已审阅代表模拟/暗色键盘/失败草稿。v1惰性列表定位改实际滚动，FFI-v1关闭后
同步异常改用closure断言，失败证据保留。完整memory-search-verify-v1通过：Rust31、283
Dart格式/analyze、Flutter503（10捕获跳过）、真实FFI11、Windows引擎3；桥Check五文件一致。
515文件审计无发现；双端普通产品Debug构建108.0s/18.2s通过。固定产物
artifacts/ui-preview/20261003-114143：APK112965836字节，SHA256
EECB605F9F155CA508AF24F4CAC952B0232D130C823126BBF742C47C6904D403；Windows83文件134181169字节。
ARM64/身份/v2签名/ZIP16K/ELF LOAD、Windows x64/DLL pin/native资产及84份复制哈希通过。
旧列表仍使用原字面
查询，模拟分数尚未替换列表或接AI召回。自动保存开关/执行、云配置/安全凭据、向量索引和
资料导入仍未实现；间隔/规则保存只代表偏好持久化，不代表调度已运行。

已确认一级12项顺序一致；AI虚拟形象入口已补接并覆盖模型空态/启用/预览/Mood/导入说明，
账号页已补已连接/失效状态，
角色与群组同源紧凑字段已归并，账号状态和设置映射已实施。当前批次已通过账号、形象、
应用设置及角色/群组44项定向测试、设置相关157项回归、形象15项极端状态测试通过。
形象动作菜单/自定义弹层在模型删除后释放，320px、横屏、桌面双倍字/160px键盘通过。
此前失败的极端用例完整保留并恢复原断言；修正双向滚动定位器，未降低命中警告。

本批完整`tools/verify.ps1`通过：脚本4项、Rust fmt/Clippy/6测试、Dart格式/analyze、
Flutter298项（8捕获套件按默认入口跳过）、真实FFI6项；日志
`work/settings-tree-verify-v3.log`。无Rust API、桥、依赖或lock变更，未重复Windows引擎测试。
账号/角色43张捕获见`work/settings-tree-first-capture/`，最终形象10张见
`work/settings-avatar-capture-final/`；明暗、空/非空、Mood、相机与编辑弹层代表图已审阅。

串行`tools/build.ps1 -Platform android/windows -NoPub`均通过，普通产品入口固定到
`artifacts/ui-preview/20261003-001934/`，旧包保留。APK 104677398字节，SHA256
`86AF870685F12EB02F3BD8C30FF05B03B95D7A980174705B109D2F05F0B1791B`；包名com.kiyori、
0.1.0/1、min24/target37、ARM64、v2签名、ZIP16K与ELF LOAD对齐通过。
Windows x64完整82文件117533806字节，Flutter DLL与pin一致，含kiyori_ffi.dll；逐文件
SHA256及来源状态在manifest，审计在`work/settings-tree-artifacts-20261003-001934/`。
第一批已交付`c738090d49cfc96182ee7352ba33c58b55093e2a`，推送后本地/远端一致，左右0/0。

第二批补入GitHub方式选择→全屏内嵌登录壳、B站已生成二维码/刷新/确认/过期投影；补入广告
拦截运行时五阶段、URL/元素/白名单目录、按域折叠、内置5条订阅、自定义订阅状态/编辑/删除。
账号登录6项测试与12张状态截图、广告规则/订阅18项测试与16张截图通过；分析无源码问题，
过程中的一次Dart线程创建错误仅保留日志，未作为成功证据。WebView/OAuth、二维码生成、广告
Store下载/编译执行仍为空操作，真实业务 owner 未接入。

第二批完整`tools/verify.ps1`通过：50文档、4脚本、Rust fmt/Clippy/6测试、Dart格式/analyze、
Flutter316项（10捕获套件跳过）、真实FFI6项。日志`work/settings-login-adblock-verify.log`，
最终截图28张在`work/settings-login-adblock-capture-final/`。未改变公共Rust API/桥或依赖。
串行Android/Windows Debug构建通过，固定`artifacts/ui-preview/20261003-011013/`：APK
104702293字节，SHA256`A47555DDF31EBBBD00E31EA8AC0C77D96E96413F8DB4AC3CA19B5B960C592FA4`，
ARM64/身份/v2签名/ZIP16K/ELF LOAD对齐通过；Windows x64共82文件117595494字节，DLL
与pin一致、native资产和复制哈希一致，逐文件manifest保留。本批按精确清单交付后继续代理。

第三批已实现并验证网络代理六层非空目录与运行状态：订阅编辑/删除、节点分组与排序、规则/
脚本选择、日志搜索/级别/清空。按实体存在期清理路由，当前订阅规则更新或切换释放旧
草稿，已打开弹层同步busy状态；未创建配置、核心或网络服务。修复横屏双倍字键盘下
输入区域被固定标题挤压的问题，标题与正文共同滚动。代理22项行为/视口检查通过，
48张截图在work/settings-proxy-capture-v2；全量verify为Flutter332项（10捕获跳过）、
Rust6/FFI6/脚本4、50文档和221 Dart格式/analyze通过。首次lint两处缺花括号已修复，
失败日志保留；最终日志work/settings-proxy-verify-v2.log。公共选择器消费者已全量回归。
串行Android/Windows Debug成功，固定artifacts/ui-preview/20261003-015123：APK
104751079字节，SHA256为42496172A4394D87F33B06424AB72223CEB3F7A98BC7249D86A26352500F9D5D；
Windows82文件117708422字节。APK身份/ARM64/v2/ZIP16K/ELF对齐、Windows x64/DLL pin/
native资产及逐文件复制哈希通过；无Rust API或依赖变动。本批精确提交推送后继续音乐。

代理已交付672333735d148b5f080d8900ad046a9f25db156c，本地/远端核对0/0、当时干净。
第四批音乐已交付：音源详情/链接修改/切换/移除、LX备份预览与导出/撤销状态已接入
可注入快照；偏好依赖、历史清理、播放速度与桌面歌词非默认投影已补入。音源/备份模态
随实体/页面释放，取消过的预览离屏不重弹。取消身份保存在页面会话，不保活离屏进度条，
修复忙碌组件持续请求帧。音乐19项状态/偏好/视口回归和36张捕获通过，证据在
work/settings-music-regression-v4.log及work/settings-music-capture-v4。完整verify通过：
Flutter345项（10捕获跳过）、Rust6/FFI6/脚本4、50文档及229 Dart格式/analyze。
日志work/settings-music-verify.log；未改变Rust API、桥和依赖。串行双端Debug成功，固定
artifacts/ui-preview/20261003-022730：APK104778774字节，SHA256
A0A390ED8123612717E7492ADA0756098E1C342B5C8396D18C9A612EA61957AD；Windows82文件117771694字节。
身份/ARM64/v2/ZIP16K/ELF、Windows x64/DLL pin/native资产与逐文件哈希通过。本批按精确
清单交付为266228c44d97ed81f607654efc7912916bef0d9a，已普通推送且manifest补入sourceCommit；
设备与真实音乐服务未运行。

第五批工具箱已实现自定义分组重命名/删除、清色确认、NFKC名称校验、稳定工具ID筛选与
批量移动、加载/保存/错误快照和实体弹层生命周期。保存中返回/遮罩/拖动/关闭统一拦截；
快照移除工具/分组时清理选择与路由，名称草稿重排保留、删除释放。未写布局或颜色，未执行工具。
原6视口回归及新增14项状态/视口通过；36张捕获在work/settings-toolbox-capture-v3，
代表横屏键盘与小屏双倍字图已审阅。日志work/settings-toolbox-regression-v2.log及
work/settings-toolbox-capture-v3.log；首次失败为测试定位同时命中透明路由底层同名文案，
已限定当前对话框/可点击项。完整verify-v2通过：51文档、4脚本、Rust fmt/Clippy/6测试、
234 Dart格式/analyze、Flutter359项（10捕获跳过）、真实FFI6项。首次完整验证一处截图测试
花括号lint已修，日志work/settings-toolbox-verify-v2.log。新增unorm_dart0.3.2和锁文件，
无Rust公共API或桥变动；未重复Windows引擎集成。串行双端Debug通过，固定
artifacts/ui-preview/20261003-025918：APK105036647字节，SHA256
C321A5E45E92DC5B8D8D48E5B0ABBE3ABAE4C31BF5D1170FC0820807C4D2B9CC；Windows82文件118469988字节。
APK身份/ARM64/v2/ZIP16K/ELF、Windows x64/DLL pin/native资产及复制哈希通过；审计457文件、
230 Dart、93资产，无warning/大文件/import循环。本批精确交付后进入外观媒体/九宫格状态。
工具箱已交付1de816a5b73db18632ee0b1b55716df64e3eb338，远端一致0/0，固定manifest已补提交。

第六批外观媒体已实现背景图/视频已选态、裁剪入口/静音/循环草稿、用户/AI源图九宫格
与`.9`拉伸/平铺渲染。图像从共享资源owner借用，界面不读取路径、不创建播放器；局部
切片按源图/裁剪区缓存并释放，着色器处理平铺，保持旧物理像素缩放与窄目标角区压缩。
同ID等值快照重建保留草稿，参数变更/媒体移除重置；气泡卡与预览暗色底色改为旧主题语义。
既有12项外观测试通过，新增5项像素/状态与6视口通过，30张最终捕获在
work/settings-appearance-capture-v5，日志work/settings-appearance-regression-v5.log。
已审阅明暗/横屏/双倍字背景、源图网格和两种预览。过程中的测试颜色常量误判及const长度
断言编译失败已修，失败日志保留。完整verify通过：51文档/4脚本、Rust fmt/Clippy/6测试、
238 Dart格式/analyze、Flutter370项（10捕获跳过）、真实FFI6项；日志work/settings-appearance-verify.log。
双端串行Debug通过，固定artifacts/ui-preview/20261003-032327：APK105052267字节，SHA256
E11324CC8530F649686CE1CCA4DCDC906CD3FE5F0A5B67670D3A815D2A4782CD；Windows82文件118503628字节。
身份/ARM64/v2/ZIP16K/ELF、Windows x64/DLL pin/native资产与复制哈希通过；无依赖/Rust API/桥变动。
审计461文件234 Dart93资产，无warning/大文件/import循环。自定义字体/头像非空态继续下一批。

第七批字体/头像与备份运行状态已实现并通过本机验证。字体family由资源owner
注册，角色/全局头像选择器独立、样例30px圆形回退；等值媒体更新保留名称与字体草稿。
备份独立操作进度/结果、聊天六种导入格式、记忆配置→策略、最近备份覆盖确认、恢复后
重启和模型导出安全提示均由快照投影。页面唯一管理模态路由，目录移除与宿主退出释放
所属选择/格式/策略/确认；未执行文件选择、导入导出、恢复、重启或偏好写入。
联合定向40项通过，96张捕获在work/settings-identity-backup-capture-v5；日志
work/settings-identity-backup-regression-v5.log。已审阅字体/头像、进度、最近备份、导入/
策略、横屏安全提示；离屏进度停止请求帧通过。首次测试const索引编译、动画捕获等待及
只向下滚动的测试定位器失败已修，日志保留；暗色安全确认按钮改用onPrimary前景。
完整tools/verify.ps1通过：51文档/4脚本、Rust fmt/Clippy/6测试、242 Dart格式/analyze、
Flutter391项（10捕获跳过）、真实FFI6项；日志work/settings-identity-backup-verify.log。
无依赖/Rust API/桥变动，未重复Windows引擎集成。串行双端Debug通过，固定
artifacts/ui-preview/20261003-040134：APK105080454字节，SHA256
FF85FD4FCBFE2418906F99629B309A16FBE1451D0D59B36FDEE2E9B250C25605；Windows82文件118572644字节。
身份/ARM64/v2/ZIP16K/ELF、Windows x64/DLL pin和逐文件复制哈希通过。交付树审计465文件、
238 Dart、93资产，无warning/大文件/import循环。设备/文件业务与Apple边界仍未验证。

这不是完整设置验收：角色标签批量导出、市场/生成等关联入口及其余非默认态仍需继续；
有效二维码服务、音乐/外观资源业务、形象导入/渲染和真实AI业务尚未实现。设备视觉、
触摸/Profile、真实账号/供应商、Apple构建没有执行，不能由本机Debug结果外推。

恢复入口：读取[设置映射](design/settings-replication-map.md)、当前Git差异和本机日记
`c3e66803-02cf-452e-aae6-a3ad0662dae0`，核对第七批Git交付后进入角色标签相关缺口。

第八批角色关联入口已实现：标签批量导出选择、旧13项标签市场与添加预填、人设生成工作台
的角色侧栏/八字段/消息/生成中/清空与上限状态，均复用PromptsPresentation并保持实体
代次隔离；设置页导航可进入市场和人设页，Back返回标签/角色来源。真实标签导入导出、
市场写入、角色创建删除、模型请求、消息历史、自动保存和工具执行仍未接入。
20项联合定向通过，48张明暗/320/844/1280/双倍字/键盘捕获在
work/settings-tags-persona-capture-v2，日志work/settings-tags-persona-capture-v2.log。
初次导出弹层惰性列表固有尺寸错误已改为有界滚动列；角色菜单命中警告已改为稳定选择器，
失败日志work/settings-tags-states-v1.log保留。市场正文来自旧TagMarketBilingualData，
人设入口/字段/上限来自旧PersonaCardGenerationScreen。
本批完整verify-v2通过：51文档、4脚本、Rust fmt/Clippy/6测试、Dart格式/analyze、
Flutter411项（10捕获跳过）、真实FFI6项。初轮花括号lint已修，DartWorker线程错误保留
失败日志。串行Android/Windows Debug通过，固定artifacts/ui-preview/20261003-043340：
APK105132790字节，SHA256 AA9A63CA70EC675D41892805DC4FA1D57AB96EC55890B4E3C24DE2F6C83C41E2；
Windows82文件118694020字节。身份/ARM64/v2/ZIP16K/ELF、x64/DLL pin/native资产与复制
哈希通过；审计473文件246Dart无发现，无Rust API、桥或依赖变动。本批精确交付后继续
人设空目录八字段/消息尾部定位及模型下载目的地核对，尚不宣布设置全树完成。
上一批固定产物`artifacts/ui-preview/20261002-171634/`保留。

第八批已交付d46ad85e0505c53de29a11f3fcff9866dadec9ae，本地/远端一致0/0，manifest
已补sourceCommit。第九批继续补设置边界：本地模型下载目的地、目录加载/失败/空态、
六种下载状态、搜索和删除确认已投影；设置及功能模型管理入口共享同一路由并准确返回。
人设空目录仍显示八字段，未绑定草稿不回填新角色；首次和切卡定位历史末尾，尺寸变更
继续校准惰性列表估算，用户上翻后停止跟随。真实下载、模型执行和人设业务仍未接入。
本批22项联合检查通过，90张捕获位于work/settings-local-models-capture-v2；模型配置
既有回归在regression-v1通过，唯一失败为新测试将RawTooltip强转IconButton，已修复
为按真实控件属性定位，失败日志保留。完整verify-v2通过：51文档/4脚本、Rust6与fmt/
Clippy、253 Dart格式/analyze、Flutter423（10捕获跳过）及真实FFI6；初轮三处测试
花括号lint已补齐。串行双端Debug通过，固定artifacts/ui-preview/20261003-045532：
APK105141756字节，SHA256 E4629904CD71940BEEF32019D6B4DE45E00E4D02890F84165A854BED6474E44D；
Windows82文件118717244字节。APK身份/签名/16K/ELF及Windows架构/DLL pin/native资产/
复制哈希通过，无Rust API或依赖变化。下一批补浏览器密码/脚本授权和文件隐藏/格式目录
非空分支；仍未宣布设置全树闭环。

第九批已交付9b06b6b04c73a3c72643921d6f60749dc06c53a7，普通推送后HEAD/远端相同、
0/0干净，manifest已补提交。第十批已实现浏览器凭据加载/可用/错误、摘要搜索、详情遮蔽、
编辑/删除确认及实体/宿主释放；脚本声明目录和四种运行标签按旧优先级显示，非总授权
开关。文件隐藏/格式规则目录、当前默认/MIME推荐、嵌套失效释放、清理计数/busy/错误
确认已补。最终保存、恢复、复制和清理仍为空业务动作，不接触真实密码、剪贴板或文件。
浏览器10项、文件9项联合通过，54PNG在work/settings-browser-files-capture-v2；此前
文档文件6项回归通过。新测试的语义选中定位和未先滚动已修，失败日志file-states-v1保留。
完整verify通过：51文档/4脚本、Rust fmt/Clippy/6、259 Dart格式/analyze、Flutter442
（10捕获跳过）及真实FFI6。串行双端Debug通过，固定artifacts/ui-preview/20261003-052526：
APK105170556字节，SHA256 E35A9420BCB91E8FFB7D9F2FE2E9EB449ACB832539701AA5F9B34853FED0874C；
Windows82文件118786796字节。APK身份/签名/16K/ELF与Windows x64/DLL pin/native资产/
复制哈希通过；482文件255人工Dart审计无发现。无Rust API或依赖变化。后续收口用量定价、
局域网、上下文及语音实体的权威值更新/弹层释放，设置关闭条件继续按映射核对。

第十批已交付77af2994cfedd11f953c0cce31d6cf12d4fe018b，manifest已补提交。第十一批
收口资料加载/干净刷新与未保存草稿、上下文configId及字段刷新、LAN Token重遮蔽、
用量定价目录和语音实体存在期。统一音色选择器失效结果守卫，配置/目录更新或宿主退出
释放所属弹层，controller延后到旧控件卸载后释放。系统默认音色空ID保留合法选择。
联合既有六组页面回归54项通过，最终生命周期8项通过，9张PNG位于
work/settings-lifecycle-capture-v3；代表定价/资料/系统音色截图已审阅。
全量初轮发现旧治理测试的弹层移除同帧迟到点击会误pop底层页面；TtsOptionDialog现校验
当前有效路由再返回，保留原迟到点击步骤后治理+生命周期16项通过，失败日志完整保留。
本批完整verify-v2通过：51文档/4脚本、Rust fmt/Clippy/6、260 Dart格式/analyze、
Flutter450（10捕获跳过）及真实FFI6。串行双端Debug通过，固定
artifacts/ui-preview/20261003-060325：APK105188296字节，SHA256
4A11C4FC61EDE7E1AF0AC81397EFB8AAB97AB7E1AD4A9CDCCC48476C4DFCE401；Windows82文件
118824940字节。APK身份/签名/16K/ELF及Windows x64/DLL pin/native资产/复制哈希通过；
审计483文件256人工Dart无发现。没有Rust API/桥/依赖变化，不重复Windows引擎集成。
本地UI验收按S01–S12累计证据关闭；后续从KiyoriAiDrawer、ScreenRouteRegistry和
OperitNavigationStackPolicy继续AI主阶段，保持HomeShell唯一一级导航owner与既有草稿。
真实设置持久化、系统动作、设备/Profile/Apple及供应商验收仍单列，不能称业务完成。

## 历史交付：第四轮群组卡草稿垂直切片

基线为 main / b2ded4b0f7b60e82acc0a6e452e48611699ed556，原任务开始时干净、与
origin/main为0/0。中断恢复时保留原17个未提交文件，暂存区为空；复核后接续交付。
旧源 Kiyori-Android / 6b03b03aa082803bb279db5e78773583e2d91154 保持只读且干净。
kiyori-ui仍为PAUSED。正式Goal不设预算，日记local_only、Asia/Shanghai；没有子智能体、
外部研究、设备操作、部署、远端CI或全局工具链变更。

目标是群组列表与编辑草稿的完整UI切片，复用角色工作台的实体身份、模态生命周期、
设置入口与返回来源。非目标是Rust持久化、真实创建/保存/删除/复制/激活、会话关联、
网络请求和虚拟形象。回滚参考为上述基线，固定包和失败证据均保留。

本批群组UI实现、回归、截图、Android/Windows Debug构建和产物审计已经完成。
本轮按精确允许清单交付到main，实际提交与远端ref以Git为准。设备视觉/触摸/Profile、
TalkBack、Apple构建及真实业务接入保持 verification_pending，全产品复刻尚未完成。

## 实际实现与旧源结论

| 范围 | 已实现 | 边界 |
| --- | --- | --- |
| 入口与目录 | 群组标签、默认空态、注入列表、更新时间降序、成员数/摘要、活跃徽章 | 产品默认仍空目录，不注入测试群组；群组活跃时抑制角色徽章 |
| 菜单 | 编辑与删除确认、复制/激活入口，40px菜单区域 | 最终创建、复制、激活、删除为空动作；无重置或导出 |
| 编辑 | 48px头像外观及添加/重置按钮、名称、可选描述、成员列表 | 头像及字段展开沿用旧空回调；最终保存不写业务事实 |
| 成员 | 按orderIndex初始化，下拉选择后添加、尾部追加、单项移除，排除已有ID | 无拖排、默认成员、数量上限、规划参数或群组模型绑定 |
| 异常引用 | 初始缺失显示ID，重复引用按出现项隔离，曾存在角色被移除时过滤草稿 | 同ID新代次不恢复旧成员；真实引用完整性归后续owner |
| 生命周期 | ID/存在代次隔离，重排保留，删除/宿主替换释放会话和所属菜单，Back逐层取消 | 返回按当前角色ID/代次验证，不误关无关页面 |
| 视口与主题 | 明暗、小屏、大字/键盘、横屏、桌面，取消/保存可达 | 本机Flutter证据，不等于Android像素或触摸验收 |

指定旧源没有规划参数、默认群组、手动排序或重置流程，这些建议项判为不适用。
成员选择不是独立确认对话框：选择只回填待添加项，再点击添加才改变草稿。旧空白名称
保存直接返回，无错误提示；新最外层保存保持空动作，不补造成功、错误或禁用外观。

来源深度、几何、持久化键和后续owner条件见[角色卡契约](design/character-prompts.md)。
群组组件/模型/Manager/ActivePrompt已完整核对；聊天绑定仅定向读取调用方，未宣称
群聊执行器、完整历史服务或整个settings文件逐行审计。Rust公共API、桥、依赖及lock
均无变化，没有重新生成或手改生成代码。

## 验证与修复证据

最终定向33项通过（原15项角色回归及18项群组用例），见work/group-prompts-tests-resumed.log。
覆盖来源返回、空目录/活跃互斥、名称/描述隔离、保存空动作、下拉取消/选择/添加、
顺序/重复项移除、重排/删除/同ID重入、过期角色选项拒绝、控制器/焦点释放、无关路由
保留、小屏双倍字/180px键盘及横屏滚动。宿主替换覆盖菜单首帧之前和之后。

初轮28项中2项发现真实生命周期问题：目录帧尾发布后再延迟一帧清理，却未请求新帧，
静止界面残留旧弹层。PromptDialog增加ensureVisualUpdate，保留断言复跑通过。
后续扩展的返回定位器按ShellAction真实结构修正，没有降低断言或关闭命中警告。
菜单首帧前宿主替换需在内容首次构建时登记/撤销真实路由，现有回归覆盖。
初始/扩展失败日志保留在work/group-prompts-tests-initial.log及对应failed日志。

捕获套件1项通过，35 PNG（既有20张及新增群组15张）在work/group-prompts-review-delivery/，
日志为work/group-prompts-capture-delivery.log。审阅手机明暗、下拉/添加、菜单/删除、
桌面、横屏、大字键盘代表图，修正下拉左侧下方锚点和40px菜单点击区；初轮图保留在
work/group-prompts-review-initial/。最终捕获之后仅补路由释放与测试，没有改变几何，
恢复时再次审阅代表图。本机字体与Debug截图不能充当Android像素或性能验收。

所有构建/验证先执行tools/activate.ps1，使用Flutter3.47.6 / Dart3.13.5 / Rust1.99.0。
恢复后完整复跑最终源码，不以旧日志结束状态推定最后新增分支已执行。

| 入口 | 结果 | 本机证据 |
| --- | --- | --- |
| tools/verify.ps1 -WindowsIntegration | 文档49份、脚本4项、Rust fmt/Clippy/6测试、Dart格式/analyze、Flutter279项、FFI6项、Windows引擎2项通过 | work/group-prompts-verify-resumed.log |
| tools/test-ui.ps1 -NoPub -Test character_prompts_test.dart | 33项通过 | work/group-prompts-tests-resumed.log |
| tools/test-ui.ps1 -NoPub -Capture -Test character_prompts_capture_test.dart -Output work/group-prompts-review-delivery | 1套件、35 PNG | work/group-prompts-capture-delivery.log |
| tools/build.ps1 -Platform android -NoPub | ARM64 Debug通过 | work/group-prompts-android.log |
| tools/build.ps1 -Platform windows -NoPub | x64 Debug通过，引擎测试后恢复普通产品入口 | work/group-prompts-windows.log、work/group-prompts-windows-restored.log |
| tools/check-foundation.ps1、git diff --check | 最终文档和差异核验 | work/group-prompts-foundation-final.log |

完整验证按设计跳过6个捕获套件，本批相关捕获单独执行。工具提示7个传递依赖有更高
但不兼容当前约束的版本，本轮未升级。交付树审计415文件、194 Dart：无人工源码依赖环、
失效相对/本地package导入、feature→app、公用UI→业务/bridge或测试互导问题；FRB生成
内部循环单列且本轮未改。无新增依赖、异常大文件、链接、子模块、嵌套Git或高置信敏感
内容发现，结果见work/group-prompts-full-audit-reviewed.json。产物、截图、日志、临时
脚本仅保留忽略目录，不进入精确提交清单。

## 本机固定产物

最终目录artifacts/ui-preview/20261002-171634/：APK1个、Windows完整目录82文件，
共222,050,445字节；Windows为117,420,950字节。83个文件副本与构建源逐一核对SHA256。
manifest保存pin、来源基线/最终提交、时间、路径、大小及完整哈希；固定二进制不因
后续构建覆盖。证据在work/group-prompts-artifacts-20261002-171634/，同时记录367个源码及
构建输入哈希。首次固定目录20261002-170727保留；恢复产品入口后kernel哈希改变，
因此新建最终目录并再次审计，83文件与最后构建源一致，没有覆盖旧固定包。

| 产物（相对固定目录） | 字节 | 修改时间（2026-10-02，Asia/Shanghai） | SHA256 |
| --- | ---: | --- | --- |
| Kiyori-ui-preview-arm64-debug.apk | 104629495 | 17:06:11.169 | D34054104BB46FD3BD9978012C0637B850A671E67FA3CF9834261BB14942D17C |
| windows-debug/Kiyori.exe | 1281024 | 02:33:25.021 | 221590339BBEA871886F8C98D01B227D4603B7E605AEEDD29D4E5F4E1C2D1475 |
| windows-debug/data/flutter_assets/kernel_blob.bin | 53880952 | 17:12:26.301 | A385BC6D1FA8A7155B06DF857C53B7224F24F9EAE5F36EC91B8A130540E228CB |
| windows-debug/kiyori_ffi.dll | 553984 | 13:45:55.575 | 8A64AB530621EF8CA05C1519A8094EDE586834FB62F7ED1FB4919C5E66FD7FAA |

APK为com.kiyori / 0.1.0(1)、min24/target37、ARM64、Debug v2签名，ZIP16KB及3个原生库
ELF LOAD对齐通过，含53个默认表情。Windows PE为x64，Flutter DLL与pin SDK一致，
运行时NativeAssetsManifest引用随包kiyori_ffi.dll；根native_assets.json绝对路径只为
构建期记录。EXE原生runner未改变而增量复用，新Dart内容由kernel证实。
上一轮固定包20261002-161431及更早包保留，上一轮APK SHA256仍为
32121CDCD6DFE6E764A17D23A30BE5FA00724D0D91DB21480A2FD0020A26DDB0。

## 上一批证据与衔接

M1运行时已实现，业务M2尚未开始；UI轨道U2/U6新增群组草稿切片。性能只落实源码
工作边界：目录/成员变化时计算候选集、列表惰性构建、复用角色ID到名称索引，无服务
订阅或后台I/O；没有同设备前后Profile，不能声称帧/触摸/内存目标达标。

上一批遗留标签批量导出、市场、人设生成与虚拟形象入口纳入当前设置/AI关联矩阵。
真实群组owner需定义持久化/引用完整性、取消/错误和会话关联契约，不能由Dart草稿承担；
本次长期任务已授权实施真实业务。当前优先级和授权以本文顶部为准。

最短本机复核：先激活工具链，再运行tools/test-ui.ps1 -NoPub -Test character_prompts_test.dart。
产品默认群组仍为空，非空群组/编辑由测试注入快照验证，可查看35张捕获；固定包不代表
真实群组业务可用。第四轮日记已经关闭，本次使用新的长期任务段，不改写其历史。
第四轮本地UI验收已闭环；真实业务未实现与设备/Apple待验证分别记录。
