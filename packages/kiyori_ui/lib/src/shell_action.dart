import 'package:flutter/material.dart';

/// 未接入的业务动作保留点击反馈，不产生导航、弹窗或网络副作用。
void emptyAction() {}

/// 共享图标操作原语；功能页不得反向依赖应用装配层。
class ShellAction extends StatelessWidget {
  const ShellAction(
    this.icon,
    this.label, {
    this.onTap = emptyAction,
    this.size = 40,
    this.iconSize = 20,
    this.color,
    this.background,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size, iconSize;
  final Color? color, background;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: SizedBox.square(
      dimension: size,
      child: Material(
        color: background ?? Colors.transparent,
        borderRadius: BorderRadius.circular(size / 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ),
  );
}
