# 浏览器与网络设计

## 浏览会话

三端使用系统网页引擎：Android WebView、Windows WebView2、iOS WKWebView。应用持有统一标签、历史、收藏和权限模型，原生 adapter 持有实际页面、渲染与 Cookie 存储。普通与隐私会话的数据目录/存储模式明确分开，销毁视图与清理持久数据是不同操作。

人工与 AI 操作同一个 BrowserSession。AI 读页面、截图或执行受支持动作需绑定 session ID、导航代次和域名授权，导航后旧元素引用失效。跨源 iframe、下载页面、支付/登录等敏感动作不得因页面文本要求而自动扩大权限。

原生页面通过受限消息桥请求应用能力，检查 frame、origin、导航代次和 schema；外部网页不获得扩展或文件 API。弹窗、外部协议、证书错误、文件选择、媒体权限与下载回调均经过显式策略。

## 代理与广告拦截是不同职责

`network` 决定连接如何建立、代理如何认证及诊断；`adblock` 决定哪些资源/页面规则被允许或阻止。二者由浏览器适配应用到引擎可控制的边界，不以代理实现代替规则管理，也不把请求拦截当作完整网络代理。

应用 Rust HTTP 客户端、WebView、OS 后台下载器、原生播放器是不同流量来源。统一配置模型不代表所有来源自动支持相同代理方式；每条请求或会话应能查询实际 route 与 unsupported reason。不能静默绕过代理后继续敏感请求。

## 平台实现策略

| 平台 | 浏览器与规则 | 网络边界 |
| --- | --- | --- |
| Android | WebView 原生视图；请求拦截与可支持的 Service Worker API；页面规则受源与时机限制 | WebView 代理能力按 AndroidX WebKit feature 检查；系统流量需要独立 VpnService 设计 |
| Windows | WebView2 Evergreen 优先；专属 user-data folder；资源请求过滤可按来源能力处理 | WebView2 environment/进程参数和 Rust client 分别验证；系统代理是额外权限与恢复问题 |
| iOS | WKWebView 与 WKContentRuleList；规则转换和 Cookie 生命周期按 WebKit 设计 | 不承诺逐请求任意拦截或透明全局代理；系统级网络能力另行评估 entitlement 和分发条件 |

规则格式先选有限且可测试的交集。订阅下载有大小限制、编码校验、编译诊断、版本/来源和更新时间；通过后原子切换快照。平台不支持的规则显式统计，不能报告“全部已生效”。规则匹配缓存键包括规则版本、站点与上下文。

## 后续 spike 与验收

浏览器接入前评估 Flutter 插件能否覆盖全部三端所需能力；不足部分在同一原生 adapter 扩展，避免同时加载两套 WebView 封装。Windows 初期选择系统 Evergreen Runtime，安装器需检测与引导，离线分发是否用 Fixed Version 再做体积/维护决策。

测试导航重定向、SPA、iframe、Service Worker、弹窗、下载、页面崩溃、站点权限、无痕清理与窗口销毁。广告拦截测试规则更新失败、豁免、域名边界、误拦诊断；网络测试代理掉线、认证错误、DNS 解析位置、TLS 和流量来源差异。系统代理未进入首轮交付，不改变开发机代理配置。
