import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'lan_automation_presentation.dart';

class LanAutomationPage extends StatefulWidget {
  const LanAutomationPage({
    this.snapshot = const LanAutomationPresentation(),
    super.key,
  });
  final LanAutomationPresentation snapshot;
  @override
  State<LanAutomationPage> createState() => _LanAutomationPageState();
}

class _LanAutomationPageState extends State<LanAutomationPage> {
  late final port = TextEditingController(
    text: widget.snapshot.port.toString(),
  );
  late final token = TextEditingController(text: widget.snapshot.token);
  bool tokenVisible = false;
  @override
  void dispose() {
    port.dispose();
    token.dispose();
    super.dispose();
  }

  Future<void> resetToken(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('重置访问 Token？'),
      content: const Text('重置后，所有仍在使用旧 Token 的客户端会立即失效。新 Token 将复制到剪贴板。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('重置 Token'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '局域网与自动化',
    onBack: () => Navigator.of(context).maybePop(),
    body: Builder(
      builder: (context) {
        final snapshot = widget.snapshot;
        final colors = Theme.of(context).colorScheme;
        Widget small(String value) => Text(
          value,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        );
        Widget copy(String label, {IconData? icon}) => TextButton(
          onPressed: () {},
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 24),
              Flexible(child: Text(label)),
            ],
          ),
        );
        InputDecoration field(String label, {Widget? suffix}) =>
            InputDecoration(
              labelText: label,
              suffixIcon: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
            );
        return ListView(
          key: const PageStorageKey('lan-automation'),
          padding: const EdgeInsets.all(16),
          children: [
            _ServerCard(
              title: '启用外部 HTTP 服务',
              subtitle: '开启后会启动外部 HTTP 服务，实际监听 0.0.0.0；同一端口既提供 HTTP API，也提供可直接访问的网页聊天界面',
              icon: Icons.toggle_on,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        snapshot.enabled ? '服务已启用' : '服务已停用',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Switch(value: snapshot.enabled, onChanged: (_) {}),
                  ],
                ),
              ],
            ),
            _ServerCard(
              title: '监听端口',
              subtitle: '默认 18094。服务会监听 0.0.0.0:端口；保存后会在启用状态下自动重启服务',
              icon: Icons.router,
              children: [
                TextField(
                  key: const ValueKey('lan-port'),
                  controller: port,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    // 旧输入规则是 filter(isDigit).take(5)，粘贴替换时也截取新值。
                    TextInputFormatter.withFunction((_, value) {
                      if (value.text.length <= 5) return value;
                      return TextEditingValue(
                        text: value.text.substring(0, 5),
                        selection: TextSelection(
                          baseOffset: value.selection.baseOffset.clamp(0, 5),
                          extentOffset: value.selection.extentOffset.clamp(
                            0,
                            5,
                          ),
                        ),
                      );
                    }),
                  ],
                  decoration: field('监听端口'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('保存端口')),
                    if (snapshot.enabled) copy('重启服务', icon: Icons.refresh),
                  ],
                ),
              ],
            ),
            _ServerCard(
              title: 'Bearer Token',
              subtitle: '首次启用时自动生成。客户端需要在 Authorization 头中携带 Bearer Token',
              icon: Icons.key,
              children: [
                TextField(
                  key: const ValueKey('lan-token'),
                  controller: token,
                  obscureText: !tokenVisible,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: field(
                    'Bearer Token',
                    suffix: IconButton(
                      tooltip: tokenVisible ? '隐藏 Token' : '显示 Token',
                      onPressed: () =>
                          setState(() => tokenVisible = !tokenVisible),
                      icon: Icon(
                        tokenVisible ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('保存')),
                    copy('复制 Token', icon: Icons.copy),
                    TextButton(
                      onPressed: () => resetToken(context),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh),
                          Flexible(child: Text('重置 Token')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _ServerCard(
              title: '当前状态',
              icon: Icons.settings_ethernet,
              children: [
                Text(snapshot.status, style: const TextStyle(fontSize: 16)),
              ],
            ),
            _ServerCard(
              title: '网页聊天入口',
              subtitle: '同一端口同时提供网页聊天界面和 HTTP API。浏览器直接打开下方地址，首次进入时输入上面的 Bearer Token 即可。',
              icon: Icons.link,
              children: [
                SelectableText(
                  '${snapshot.baseUrl}/',
                  style: const TextStyle(fontSize: 16),
                ),
                small('网页入口使用根路径 /；HTTP API 仍然走 ${snapshot.baseUrl}/api/'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: copy('复制网页地址', icon: Icons.copy),
                ),
              ],
            ),
            _ServerCard(
              title: '当前检测到的局域网地址',
              icon: Icons.link,
              children: [
                small(
                  '服务实际监听 0.0.0.0:${snapshot.port}，表示会接收设备所有网络接口上的请求。下方仅列出当前检测到的局域网 IPv4，方便复制。',
                ),
                const SizedBox(height: 4),
                if (snapshot.addresses.isEmpty)
                  const Text(
                    '暂未检测到可用的局域网 IPv4 地址；这不影响服务监听 0.0.0.0，请确认设备已联网或改用其他可达地址',
                    style: TextStyle(fontSize: 14),
                  )
                else
                  for (final address in snapshot.addresses)
                    SelectableText(
                      'http://$address:${snapshot.port}',
                      style: const TextStyle(fontSize: 14),
                    ),
              ],
            ),
            _ServerCard(
              title: '同步调用示例',
              icon: Icons.link,
              children: [
                _Example(snapshot.syncExample),
                Align(alignment: Alignment.centerLeft, child: copy('复制示例')),
              ],
            ),
            _ServerCard(
              title: '异步回调示例',
              icon: Icons.link,
              children: [_Example(snapshot.asyncExample)],
            ),
            _ServerCard(
              title: '健康检查示例',
              icon: Icons.link,
              children: [_Example(snapshot.healthExample)],
            ),
            _ServerCard(
              title: 'Intent 调用说明',
              subtitle: '广播入口仍然保留，适合本机 App 集成、Tasker 或 adb 调试',
              icon: Icons.link,
              children: [
                SelectableText(
                  LanAutomationPresentation.intentOverview,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                const _Example(LanAutomationPresentation.intentExample),
                Align(alignment: Alignment.centerLeft, child: copy('复制示例')),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: colors.outlineVariant),
          for (final child in children) ...[const SizedBox(height: 8), child],
        ],
      ),
    );
  }
}

class _Example extends StatelessWidget {
  const _Example(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: .35),
      borderRadius: BorderRadius.circular(14),
    ),
    child: SelectableText(text, style: const TextStyle(fontSize: 12)),
  );
}
