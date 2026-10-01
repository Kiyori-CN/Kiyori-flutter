import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class HomeBottomNavigation extends StatefulWidget {
  const HomeBottomNavigation({required this.onHome, super.key});
  final VoidCallback onHome;
  @override
  State<HomeBottomNavigation> createState() => _HomeBottomNavigationState();
}

class _HomeBottomNavigationState extends State<HomeBottomNavigation> {
  int selected = 0;
  int activation = 0;
  static const names = [
    'nav_home',
    'nav_globe',
    'nav_apps',
    'nav_folder',
    'tool_settings',
  ];
  static const labels = ['首页', '浏览器', '工具箱', '文件管理', '设置'];
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(
          key: const Key('five-icon-bar'),
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: labels[i],
                    selected: selected == i,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // 选择反馈属于界面；未接入目的地不执行导航或业务动作。
                        setState(() {
                          selected = i;
                          activation++;
                        });
                        if (i == 0) widget.onHome();
                      },
                      child: SizedBox.square(
                        key: Key('nav-$i'),
                        dimension: 44,
                        child: Center(
                          child: _NavigationGlyph(
                            index: i,
                            name: names[i],
                            selected: selected == i,
                            activation: selected == i ? activation : 0,
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
    ),
  );
}

class _NavigationGlyph extends StatefulWidget {
  const _NavigationGlyph({
    required this.index,
    required this.name,
    required this.selected,
    required this.activation,
  });
  final int index, activation;
  final String name;
  final bool selected;
  @override
  State<_NavigationGlyph> createState() => _NavigationGlyphState();
}

class _NavigationGlyphState extends State<_NavigationGlyph>
    with SingleTickerProviderStateMixin {
  double get start => widget.index == 4 ? .9 : 1;
  double get end => widget.index == 4
      ? 1
      : widget.index == 2
      ? 1.12
      : 1.1;
  late final AnimationController scale = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? end : start,
  );
  @override
  void didUpdateWidget(_NavigationGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selected) {
      scale.stop();
      scale.value = start;
    } else if (oldWidget.activation != widget.activation ||
        !oldWidget.selected) {
      unawaited(animateActivation());
    }
  }

  Future<void> animateActivation() async {
    try {
      await scale
          .animateTo(
            start,
            duration: const Duration(milliseconds: 70),
            curve: const Cubic(.4, 0, 1, 1),
          )
          .orCancel;
      await scale
          .animateWith(
            SpringSimulation(
              SpringDescription.withDampingRatio(
                mass: 1,
                stiffness: 420,
                ratio: widget.index == 4 ? .55 : .42,
              ),
              start,
              end,
              0,
            ),
          )
          .orCancel;
    } on TickerCanceled {
      /* 重复点击与卸载只取消旧动画，不影响最新选择。 */
    }
  }

  @override
  void dispose() {
    scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = widget.index == 2 ? 25.0 : 26.0;
    Widget image(String suffix, Color color) => Image.asset(
      'assets/navigation/${widget.name}$suffix.png',
      width: size,
      height: size,
      color: color,
      filterQuality: FilterQuality.high,
    );
    return SizedBox.square(
      dimension: size,
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 160),
        sizeCurve: Curves.linear,
        firstCurve: Curves.linear,
        secondCurve: Curves.linear,
        crossFadeState: widget.selected
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: image('', colors.onSurfaceVariant),
        secondChild: AnimatedBuilder(
          animation: scale,
          child: Stack(
            children: [
              image('_selected_fill', const Color(0xFFFFC153)),
              image(
                widget.index == 4 ? '_selected_detail' : '',
                colors.surface,
              ),
            ],
          ),
          builder: (context, child) =>
              Transform.scale(scale: scale.value, child: child),
        ),
        layoutBuilder: (top, topKey, bottom, bottomKey) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(key: bottomKey, child: bottom),
            KeyedSubtree(key: topKey, child: top),
          ],
        ),
      ),
    );
  }
}
