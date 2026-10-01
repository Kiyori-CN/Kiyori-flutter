import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kiyori_ui/kiyori_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.openAi, super.key});
  final VoidCallback openAi;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  bool ai = false;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final padding = w >= 840
                ? 72.0
                : w >= 600
                ? 48.0
                : 24.0;
            final maxWidth = w >= 840
                ? 624.0
                : w >= 600
                ? 584.0
                : 544.0;
            final short = constraints.maxHeight < 440;
            final frameTop = math.max(constraints.maxHeight * .382, 60.0);
            final contentWidth = math.min(w - padding * 2, maxWidth);
            return Stack(
              children: [
                Positioned(
                  top: short ? 0 : 6,
                  left: padding,
                  right: padding,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const ShellAction(
                        Icons.location_off,
                        '天气定位权限',
                        size: 48,
                        iconSize: 21,
                        color: Color(0xFFBA3A42),
                      ),
                      Semantics(
                        button: true,
                        label: '浏览器窗口，0 个',
                        child: SizedBox.square(
                          dimension: 48,
                          child: InkWell(
                            onTap: emptyAction,
                            borderRadius: BorderRadius.circular(24),
                            child: Center(
                              child: Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: colors.onSurface,
                                    width: 1.75,
                                  ),
                                  borderRadius: BorderRadius.circular(1.75),
                                ),
                                child: Text(
                                  '0',
                                  style: TextStyle(
                                    fontSize: 9,
                                    height: 1,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: frameTop - (short ? 8 : 16) - 44,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          'Kiyori',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 36,
                            height: 44 / 36,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Transform.translate(
                        offset: const Offset(0, -4),
                        child: Image.asset(
                          'assets/branding/kiyori-app-icon.png',
                          width: 18,
                          height: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: frameTop,
                  left: (w - contentWidth) / 2,
                  width: contentWidth,
                  child: CustomPaint(
                    painter: const _SearchBorder(),
                    child: SizedBox(
                      key: const Key('home-search-frame'),
                      height: short ? 96 : 114,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: short ? 8 : 10,
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: ai ? widget.openAi : emptyAction,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      child: Text(
                                        ai ? '把问题和任务发给AI' : '搜索网页或输入网址',
                                        key: ValueKey(ai),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: colors.onSurfaceVariant
                                              .withValues(alpha: .62),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 120,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: colors.outline.withValues(
                                        alpha: .5,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _mode(false, Icons.search, '搜索'),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 18,
                                        color: colors.outline.withValues(
                                          alpha: .35,
                                        ),
                                      ),
                                      Expanded(
                                        child: _mode(
                                          true,
                                          Icons.auto_awesome,
                                          'AI',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Row(
                                  children: [
                                    ShellAction(
                                      Icons.add,
                                      '添加附件',
                                      iconSize: 24,
                                    ),
                                    ShellAction(Icons.mic_none, '语音输入'),
                                    ShellAction(
                                      Icons.photo_camera_outlined,
                                      '拍照',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _mode(bool value, IconData icon, String label) {
    final colors = Theme.of(context).colorScheme;
    final selected = ai == value;
    final color = selected ? const Color(0xFF2F6FED) : colors.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AnimatedContainer(
          height: double.infinity,
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => ai = value),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, height: 1, color: color),
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

class _SearchBorder extends CustomPainter {
  const _SearchBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF54C878),
          Color(0xFF45B9D4),
          Color(0xFF8277DA),
          Color(0xFFF09A6C),
          Color(0xFF54C878),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(.5), const Radius.circular(17.5)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SearchBorder oldDelegate) => false;
}
