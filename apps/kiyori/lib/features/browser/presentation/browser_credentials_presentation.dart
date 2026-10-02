/// 保险库摘要和一次已授权读取的临时详情分离；列表搜索从不访问密码。
class BrowserCredentialsPresentation {
  const BrowserCredentialsPresentation({
    this.available = false,
    this.loading = false,
    this.savingEnabled = true,
    this.error = '本机凭据存储不可用',
    this.securityDescription = '',
    this.credentials = const [],
    this.details = const {},
  });
  final bool available, loading, savingEnabled;
  final String error, securityDescription;
  final List<BrowserCredentialSummary> credentials;
  final Map<String, BrowserCredentialDetail> details;
}

class BrowserCredentialSummary {
  const BrowserCredentialSummary({
    required this.id,
    required this.host,
    required this.origin,
    required this.pageUrl,
    required this.username,
  });
  final String id, host, origin, pageUrl, username;
}

/// 不提供toString或序列化；平台安全存储owner注入，UI不日志化、持久化或复制它。
class BrowserCredentialDetail {
  const BrowserCredentialDetail({
    required this.summary,
    required this.password,
  });
  final BrowserCredentialSummary summary;
  final String password;
}
