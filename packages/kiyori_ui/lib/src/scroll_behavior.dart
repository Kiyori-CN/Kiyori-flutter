import 'package:flutter/material.dart';

/// 惯性/程序滚动不吞掉第一次点击。拖动仍由 Scrollable 的手势仲裁处理。
class KiyoriScrollBehavior extends MaterialScrollBehavior {
  const KiyoriScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      final source = notification.context;
      final position = source == null
          ? null
          : Scrollable.maybeOf(source)?.position;
      // 不能等到惯性的首次位移才解除：手指刚释放、首个动画帧之前也可点击。
      // 已胜出的拖动仍会取消同一指针的 tap；新的按下通过框架 hold 停止滚动。
      // 不截获/重发指针，也不改变 slop、速度或物理模拟。
      position?.context.setIgnorePointer(false);
      return false;
    },
    child: super.buildOverscrollIndicator(context, child, details),
  );
}
