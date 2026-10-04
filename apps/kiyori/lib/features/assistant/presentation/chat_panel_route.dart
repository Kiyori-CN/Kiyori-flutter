import 'package:flutter/material.dart';

/// 旧 AIChatScreen 的内容宿主在主顶栏下方；面板和遮罩使用同一边界。
class ChatPanelRoute extends PopupRoute<void> {
  ChatPanelRoute({
    required this.builder,
    required this.label,
    this.fromTop = false,
  });
  final WidgetBuilder builder;
  final String label;
  final bool fromTop;

  @override
  Color get barrierColor => Colors.black.withValues(alpha: fromTop ? .4 : .32);
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => label;
  @override
  Duration get transitionDuration =>
      Duration(milliseconds: fromTop ? 300 : 260);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildModalBarrier() {
    final barrier = super.buildModalBarrier();
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 64.5),
        child: barrier,
      ),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Padding(
    // 窗口/安全区可在面板打开期间变化，不能保留打开时的 inset 快照。
    padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 64.5),
    child: ClipRect(
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Builder(builder: builder),
      ),
    ),
  );
}

Widget chatPanelTransition(
  BuildContext context,
  Widget child, {
  bool fromTop = false,
}) {
  final route = ModalRoute.of(context)!;
  return SlideTransition(
    position:
        Tween(
          begin: fromTop ? const Offset(0, -1) : const Offset(-1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: route.animation!,
            curve: fromTop ? Curves.easeOutCubic : Curves.fastOutSlowIn,
          ),
        ),
    child: child,
  );
}
