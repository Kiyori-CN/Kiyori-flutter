import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Color historyTone(BuildContext context, IconTone tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final (light, night) = switch (tone) {
    IconTone.folder => (0xFFB07C07, 0xFFFFD16A),
    IconTone.tools => (0xFFA85A12, 0xFFFFB76A),
    IconTone.memory => (0xFF2B5FAF, 0xFF8CB5FF),
    IconTone.success => (0xFF16734F, 0xFF67D7A5),
    IconTone.code => (0xFF17768B, 0xFF65D3E8),
    IconTone.audio => (0xFFAE3B6D, 0xFFF49AC0),
    _ => (0xFF256DB0, 0xFF90CAF9),
  };
  return Color(dark ? night : light);
}

String historyTime(int timestamp, [DateTime? clock]) {
  final now = clock ?? DateTime.now();
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final diff = now.millisecondsSinceEpoch - timestamp;
  if (diff < 60000) return '刚刚';
  if (diff < 3600000) return '${diff ~/ 60000} 分钟前';
  if (diff < 86400000) return '${diff ~/ 3600000} 小时前';
  if (diff < 604800000) return '${diff ~/ 86400000} 天前';
  final short =
      '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return date.year == now.year ? short : '${date.year}-$short';
}

class HistoryInlineBanner extends StatelessWidget {
  const HistoryInlineBanner({
    required this.message,
    required this.dismiss,
    super.key,
  });
  final String message;
  final VoidCallback dismiss;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: c.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 16,
                color: c.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 11,
                    height: 16 / 11,
                    color: c.onErrorContainer,
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: dismiss,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.close, size: 16, color: c.onErrorContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 旧DrawerScaffold：标题和底操作固定，只有正文滚动，系统/键盘inset归共享宿主。
class HistoryDrawer extends StatelessWidget {
  const HistoryDrawer({
    required this.title,
    required this.close,
    required this.children,
    this.footer,
    super.key,
  });
  final String title;
  final VoidCallback close;
  final List<Widget> children;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 20, right: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 22, height: 28 / 22),
              ),
            ),
            IconButton(
              tooltip: '关闭',
              onPressed: close,
              icon: const Icon(Icons.close, size: 24),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: children),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: footer ?? const SizedBox.shrink(),
      ),
    ],
  );
}

class HistoryActionRow extends StatelessWidget {
  const HistoryActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = IconTone.ai,
    this.supporting,
    this.destructive = false,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final IconTone tone;
  final String? supporting;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: (destructive ? c.error : historyTone(context, tone))
                      .withValues(alpha: enabled ? 1 : .38),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          height: 24 / 16,
                          color: !enabled
                              ? c.onSurface.withValues(alpha: .38)
                              : destructive
                              ? c.error
                              : c.onSurface,
                        ),
                      ),
                      if (supporting != null)
                        Text(
                          supporting!,
                          style: TextStyle(
                            fontSize: 11,
                            height: 16 / 11,
                            color: enabled
                                ? c.onSurfaceVariant
                                : c.onSurface.withValues(alpha: .38),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// AlertDialog默认宽度与Compose不同：旧平台边距24、最大560；正文/按钮保持M3排版。
class HistoryAlert extends StatelessWidget {
  const HistoryAlert({
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    super.key,
  });
  final String title;
  final Widget content;
  final List<Widget> actions;
  final Widget? icon;
  @override
  Widget build(BuildContext context) => AlertDialog(
    constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    icon: icon,
    title: Text(title, style: const TextStyle(fontSize: 24, height: 32 / 24)),
    scrollable: true,
    content: content,
    actions: actions,
  );
}
