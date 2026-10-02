import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

enum AiDrawerEntryKind { quick, ai, plugin, settings }

class AiDrawerEntry {
  const AiDrawerEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.tone,
    required this.kind,
    this.badge,
  });
  final String id, label;
  final IconData icon;
  final IconTone tone;
  final AiDrawerEntryKind kind;
  final String? badge;
}

class AiDrawer extends StatefulWidget {
  const AiDrawer({
    required this.open,
    required this.selected,
    required this.onDismiss,
    required this.onSelect,
    required this.onClose,
    required this.toolboxCount,
    this.packageCount,
    this.workflowCount,
    this.networkAvailable,
    this.networkType = '...',
    this.plugins = const [],
    super.key,
  });
  final bool open;
  final int toolboxCount;
  final int? packageCount, workflowCount;
  final bool? networkAvailable;
  final String networkType;
  final String? selected;
  final List<AiDrawerEntry> plugins;
  final VoidCallback onDismiss, onClose;
  final ValueChanged<AiDrawerEntry> onSelect;

  static double widthFor(double windowWidth) => windowWidth < 600
      ? windowWidth * .75
      : windowWidth < 840
      ? 320
      : 360;

  @override
  State<AiDrawer> createState() => _AiDrawerState();
}

class _AiDrawerState extends State<AiDrawer>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void initState() {
    super.initState();
    if (widget.open) animation.value = 1;
  }

  @override
  void didUpdateWidget(covariant AiDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      if (widget.open) {
        animation.forward();
      } else {
        animation.reverse();
      }
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  List<AiDrawerEntry> get _quick => [
    AiDrawerEntry(
      id: 'main.packages',
      label: '扩展',
      icon: Icons.extension,
      tone: IconTone.extensionAccent,
      kind: AiDrawerEntryKind.quick,
      badge: widget.packageCount?.toString() ?? '...',
    ),
    AiDrawerEntry(
      id: 'main.toolbox',
      label: '工具箱',
      icon: Icons.apps,
      tone: IconTone.tools,
      kind: AiDrawerEntryKind.quick,
      badge: widget.toolboxCount.toString(),
    ),
    AiDrawerEntry(
      id: 'main.workflow',
      label: '工作流',
      icon: Icons.account_tree,
      tone: IconTone.automation,
      kind: AiDrawerEntryKind.quick,
      badge: widget.workflowCount?.toString() ?? '...',
    ),
  ];

  List<AiDrawerEntry> get _ai => const [
    AiDrawerEntry(
      id: 'main.ai_chat',
      label: 'AI 助手',
      icon: Icons.auto_awesome,
      tone: IconTone.ai,
      kind: AiDrawerEntryKind.ai,
    ),
    AiDrawerEntry(
      id: 'main.memory_base',
      label: '记忆库',
      icon: Icons.memory,
      tone: IconTone.memory,
      kind: AiDrawerEntryKind.ai,
    ),
  ];

  AiDrawerEntry get _settings => const AiDrawerEntry(
    id: 'main.settings',
    label: '设置',
    icon: Icons.settings_outlined,
    tone: IconTone.settings,
    kind: AiDrawerEntryKind.settings,
  );

  void _select(AiDrawerEntry entry) {
    if (!widget.open) return;
    widget.onSelect(entry);
  }

  @override
  Widget build(BuildContext context) {
    final width = AiDrawer.widthFor(MediaQuery.sizeOf(context).width);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        if (!widget.open && animation.isDismissed) {
          return const SizedBox.shrink();
        }
        final fraction = Curves.fastOutSlowIn.transform(animation.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              key: const ValueKey('ai-drawer-scrim'),
              onTap: widget.open ? widget.onDismiss : null,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .32 * fraction),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(-width * (1 - fraction), 0),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top,
                  ),
                  child: Material(
                    key: const ValueKey('ai-drawer-surface'),
                    elevation: 8,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(
                      top: false,
                      right: false,
                      child: SizedBox(
                        width: width,
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.only(right: 8),
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(20, 30, 20, 0),
                                    child: _DrawerTitle(),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      20,
                                      10,
                                      20,
                                      14,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _NetworkPill(
                                        available: widget.networkAvailable,
                                        type: widget.networkType,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        for (final (index, entry)
                                            in _quick.indexed)
                                          Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: index < 2 ? 6 : 0,
                                              ),
                                              child: _QuickEntry(
                                                entry: entry,
                                                selected:
                                                    widget.selected == entry.id,
                                                enabled: widget.open,
                                                onTap: () => _select(entry),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  for (final entry in _ai)
                                    _NavigationEntry(
                                      entry: entry,
                                      selected: widget.selected == entry.id,
                                      enabled: widget.open,
                                      onTap: () => _select(entry),
                                    ),
                                  if (widget.plugins.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        28,
                                        14,
                                        20,
                                        6,
                                      ),
                                      child: Text(
                                        '插件',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    for (final entry in widget.plugins)
                                      _NavigationEntry(
                                        entry: entry,
                                        selected: widget.selected == entry.id,
                                        enabled: widget.open,
                                        onTap: () => _select(entry),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            _DrawerFooter(
                              enabled: widget.open,
                              onCollapse: widget.onDismiss,
                              onClose: widget.onClose,
                              onSettings: () => _select(_settings),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DrawerTitle extends StatelessWidget {
  const _DrawerTitle();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const style = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);
      final text = TextPainter(
        text: TextSpan(
          text: 'Kiyori',
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final stacked =
          text.width + 8 + MediaQuery.textScalerOf(context).scale(52) >
          constraints.maxWidth;
      text.dispose();
      const title = Text('Kiyori', style: style);
      final section = Text(
        'AI 助手',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
      return stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 4), section],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                title,
                const SizedBox(width: 8),
                Expanded(child: section),
              ],
            );
    },
  );
}

class _NetworkPill extends StatelessWidget {
  const _NetworkPill({required this.available, required this.type});
  final bool? available;
  final String type;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: IconTone.automation.containerFor(context),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  (available == null
                          ? IconTone.neutral
                          : available!
                          ? IconTone.success
                          : IconTone.recycle)
                      .iconFor(context),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            available == false ? Icons.wifi_off : Icons.wifi,
            size: 14,
            color: IconTone.automation.iconFor(context),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              type,
              style: TextStyle(
                fontSize: 12,
                color: IconTone.automation.iconFor(context),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickEntry extends StatelessWidget {
  const _QuickEntry({
    required this.entry,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final AiDrawerEntry entry;
  final bool selected, enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey(entry.id),
    button: true,
    selected: selected,
    label: entry.label,
    child: Material(
      color: selected
          ? entry.tone.containerFor(context)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 6, bottom: 4),
                child: Align(
                  alignment: Alignment.topRight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: entry.tone.containerFor(context),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        entry.badge ?? '...',
                        style: TextStyle(
                          fontSize: 11,
                          color: entry.tone.iconFor(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ToneBadge(entry.icon, entry.tone, size: 30, iconSize: 18),
              const SizedBox(height: 3),
              Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NavigationEntry extends StatelessWidget {
  const _NavigationEntry({
    required this.entry,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final AiDrawerEntry entry;
  final bool selected, enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey(entry.id),
    button: true,
    selected: selected,
    label: entry.label,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? entry.tone.containerFor(context)
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  ToneBadge(
                    entry.icon,
                    entry.tone,
                    size: 30,
                    iconSize: 18,
                    glyph: entry.id == 'main.ai_chat'
                        ? AiSparkleIcon(
                            color: entry.tone.iconFor(context),
                            size: 18,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({
    required this.enabled,
    required this.onCollapse,
    required this.onClose,
    required this.onSettings,
  });
  final bool enabled;
  final VoidCallback onCollapse, onClose, onSettings;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Divider(height: 1, indent: 20, endIndent: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _FooterAction(
              label: '收起',
              tone: IconTone.neutral,
              enabled: enabled,
              onTap: onCollapse,
              glyph: 0,
            ),
            _FooterAction(
              label: '关闭AI对话并返回软件首页',
              tone: IconTone.exit,
              enabled: enabled,
              onTap: onClose,
              glyph: 1,
            ),
            _FooterAction(
              label: '设置',
              tone: IconTone.settings,
              enabled: enabled,
              onTap: onSettings,
              glyph: 2,
            ),
          ],
        ),
      ),
    ],
  );
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.label,
    required this.tone,
    required this.enabled,
    required this.onTap,
    required this.glyph,
  });
  final String label;
  final IconTone tone;
  final bool enabled;
  final VoidCallback onTap;
  final int glyph;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: enabled ? onTap : null,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    icon: Container(
      width: 46,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.containerFor(context),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Opacity(
        opacity: enabled ? 1 : .38,
        child: glyph == 2
            ? Image.asset(
                'assets/navigation/tool_settings.png',
                width: 22,
                height: 22,
                color: tone.iconFor(context),
              )
            : CustomPaint(
                size: const Size.square(22),
                painter: _FooterGlyph(tone.iconFor(context), glyph),
              ),
      ),
    ),
  );
}

class _FooterGlyph extends CustomPainter {
  const _FooterGlyph(this.color, this.glyph);
  final Color color;
  final int glyph;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    if (glyph == 0) {
      path
        ..moveTo(15, 6)
        ..lineTo(9, 12)
        ..lineTo(15, 18);
    } else {
      path
        ..moveTo(8, 5.5)
        ..relativeArcToPoint(
          const Offset(8, 0),
          radius: const Radius.circular(8),
          largeArc: true,
          clockwise: false,
        )
        ..moveTo(12, 3)
        ..lineTo(12, 12);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FooterGlyph oldDelegate) =>
      color != oldDelegate.color || glyph != oldDelegate.glyph;
}
