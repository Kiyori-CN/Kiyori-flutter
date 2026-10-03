import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart' show BridgeError;

import 'prompt_presentation.dart';

/// 一个编辑会话只拥有自己的模态路由，不接管页面导航或业务目录。
/// 目录删除后即使同 ID 重新加入，也不能复活旧输入或迟到的选择结果。
class PromptDialog extends StatefulWidget {
  const PromptDialog({
    required this.catalog,
    required this.exists,
    required this.builder,
    this.identityToken,
    super.key,
  });
  final ValueNotifier<PromptsPresentation> catalog;
  final bool Function(PromptsPresentation) exists;
  final Widget Function(BuildContext, PromptDialogState) builder;
  final Object? Function(String)? identityToken;
  @override
  State<PromptDialog> createState() => PromptDialogState();
}

class PromptDialogState extends State<PromptDialog> {
  bool saving = false;
  String? error;

  Future<void> submit(Future<void> Function()? operation) async {
    if (operation == null || saving || !valid) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await operation();
      if (!mounted || !valid) return;
      final route = ModalRoute.of(context);
      // 精确移除所属路由，迟到的保存不能 pop 新页面。
      if (route != null && route.isActive) route.navigator?.removeRoute(route);
    } catch (failure) {
      if (valid) {
        setState(() {
          error = failure is BridgeError
              ? (failure.message.contains('reload')
                    ? '内容已变化或已删除，请重新打开后再保存。'
                    : '保存失败，请检查名称、绑定和引用后重试。')
              : '操作失败，请重试。';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  final _children = <ModalRoute<dynamic>>[];
  bool _invalidated = false;
  bool get valid =>
      mounted && !_invalidated && widget.exists(widget.catalog.value);
  PromptsPresentation get snapshot => widget.catalog.value;
  Object? identity(String id) => widget.identityToken?.call(id);

  /// 下拉菜单同样属于本编辑会话；由菜单内容取得真实路由后登记，避免猜测栈顶。
  Future<T?> showPopup<T>(
    RelativeRect position,
    List<(T, String)> options,
  ) async {
    if (!valid) return null;
    FocusManager.instance.primaryFocus?.unfocus();
    ModalRoute<dynamic>? owned;
    try {
      final result = await showMenu<T>(
        context: context,
        position: position,
        items: [
          for (final option in options)
            PopupMenuItem<T>(
              value: option.$1,
              child: Builder(
                builder: (context) {
                  final route = ModalRoute.of(context);
                  if (route != null && owned == null) {
                    owned = route;
                    if (valid) {
                      _children.add(route);
                    } else {
                      // 菜单首帧前宿主就可能被替换，此时 dispose 已经取走旧路由清单。
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (route.isActive) route.navigator?.removeRoute(route);
                      });
                      WidgetsBinding.instance.ensureVisualUpdate();
                    }
                  }
                  return Text(option.$2, style: const TextStyle(fontSize: 12));
                },
              ),
            ),
        ],
      );
      return valid ? result : null;
    } finally {
      _children.remove(owned);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.catalog.addListener(_changed);
  }

  void _changed() {
    if (!widget.exists(snapshot)) _invalidated = true;
    // 宿主可能正在 didUpdateWidget 中发布新快照，不能在该帧中修改 Navigator。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_invalidated) {
        _removeChildren();
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      } else {
        setState(() {});
      }
    });
    // 目录本身在帧尾发布；若之后没有输入/动画，仍必须触发下一帧执行失效清理。
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<T?> showChild<T>(WidgetBuilder builder) async {
    if (!valid) return null;
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(context);
    final route = DialogRoute<Object?>(
      context: context,
      builder: (context) => SettingsTheme(child: builder(context)),
    );
    _children.add(route);
    final result = await navigator.push<Object?>(route);
    _children.remove(route);
    return valid ? result as T? : null;
  }

  void _removeChildren() {
    for (final route in _children.reversed.toList()) {
      if (route.isActive) route.navigator?.removeRoute(route);
    }
    _children.clear();
  }

  @override
  void dispose() {
    widget.catalog.removeListener(_changed);
    // 页面被外部替换时也精确撤销本会话的模态，不 pop 到其它页面。
    final routes = _children.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsTheme(
    child: PopScope(
      canPop: !saving,
      child: AbsorbPointer(
        absorbing: saving,
        child: Builder(builder: (context) => widget.builder(context, this)),
      ),
    ),
  );
}

/// 普通尺寸保持旧表单宽度；短视口把全部正文纳入有界滚动。
class PromptFormDialog extends StatelessWidget {
  const PromptFormDialog({
    required this.child,
    required this.actions,
    this.widthFraction = .95,
    super.key,
  });
  final Widget child, actions;
  final double widthFraction;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width * (1 - widthFraction) / 2,
      vertical: 12,
    ),
    constraints: const BoxConstraints(maxWidth: 840),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    backgroundColor: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: SingleChildScrollView(child: child)),
          const SizedBox(height: 12),
          actions,
        ],
      ),
    ),
  );
}

class PromptActions extends StatelessWidget {
  const PromptActions({this.onConfirm, this.label = '保存', super.key});
  final VoidCallback? onConfirm;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text('取消'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton(
          // 未接入持久 owner 时保留可点击外观，不关闭表单或伪造保存。
          onPressed: onConfirm ?? () {},
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(label),
        ),
      ),
    ],
  );
}

class PromptTextEditor extends StatefulWidget {
  const PromptTextEditor({required this.title, required this.value, super.key});
  final String title, value;
  @override
  State<PromptTextEditor> createState() => _PromptTextEditorState();
}

class _PromptTextEditorState extends State<PromptTextEditor> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(8),
    constraints: const BoxConstraints(maxWidth: double.infinity),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: '关闭',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              key: const ValueKey('expanded-prompt-input'),
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: '在此输入内容...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PromptActions(
            onConfirm: () => Navigator.pop(context, controller.text),
          ),
        ],
      ),
    ),
  );
}
