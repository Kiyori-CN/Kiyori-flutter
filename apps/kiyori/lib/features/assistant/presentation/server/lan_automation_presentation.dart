/// 领域服务后续注入的只读状态；页面不会探测网卡、创建令牌或启动监听。
class LanAutomationPresentation {
  const LanAutomationPresentation({
    this.enabled = false,
    this.port = 18094,
    this.token = '',
    this.running = false,
    this.activePort,
    this.lastError,
    this.addresses = const [],
  });
  final bool enabled, running;
  final int port;
  final String token;
  final int? activePort;
  final String? lastError;
  final List<String> addresses;

  String get baseUrl => 'http://127.0.0.1:$port';
  String get status => running
      ? activePort == null
            ? '服务报告正在运行，但未提供监听端口；请重启服务并检查日志。'
            : '服务运行中，监听 0.0.0.0:$activePort'
      : lastError?.trim().isNotEmpty == true
      ? '服务异常：$lastError'
      : '服务未运行';

  String get _exampleToken => token.trim().isEmpty ? '<bearer-token>' : token;
  String get syncExample =>
      '''curl -X POST "$baseUrl/api/external-chat" \\
  -H "Authorization: Bearer $_exampleToken" \\
  -H "Content-Type: application/json; charset=utf-8" \\
  -d '{"message":"你好","response_mode":"sync","show_floating":true,"initial_mode":"WINDOW","return_tool_status":false}' '''
          .trimRight();
  String get asyncExample =>
      '''curl -X POST "$baseUrl/api/external-chat" \\
  -H "Authorization: Bearer $_exampleToken" \\
  -H "Content-Type: application/json; charset=utf-8" \\
  -d '{"message":"你好","response_mode":"async_callback","callback_url":"http://YOUR_PC:8080/callback"}' '''
          .trimRight();
  String get healthExample =>
      'curl -H "Authorization: Bearer $_exampleToken" "$baseUrl/api/health"';

  // 旧 Android 协议的展示文字；不是新应用已注册的广播接口。
  static const intentOverview =
      'HTTP 与 Intent 参数语义一致，仅入口不同。\n\n请求 Action：com.kiyori.flutter.EXTERNAL_CHAT\n默认回传 Action：com.kiyori.flutter.EXTERNAL_CHAT_RESULT\n\n常用 extras：message、request_id、group、create_new_chat、chat_id、create_if_none、show_floating、return_tool_status、initial_mode、auto_exit_after_ms、stop_after、reply_action、reply_package\n\n处理完成后会通过广播回传 success、chat_id、ai_response、error；如果只希望回传给指定 App，请设置 reply_package。';
  static const intentExample = r'''adb shell am broadcast \
  -a com.kiyori.flutter.EXTERNAL_CHAT \
  --es request_id "req-001" \
  --es message "你好" \
  --ez show_floating true \
  --ez return_tool_status false \
  --es initial_mode "WINDOW" \
  --es reply_package "YOUR.APP.PACKAGE"''';
}
