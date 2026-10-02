import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'prompt_presentation.dart';

/// 一个编辑会话只拥有自己的模态路由，不接管页面导航或业务目录。
/// 目录删除后即使同 ID 重新加入，也不能复活旧输入或迟到的选择结果。
class PromptDialog extends StatefulWidget {
  const PromptDialog({
    required this.catalog,
    required this.exists,
    required this.builder,
    super.key,
  });
  final ValueNotifier<PromptsPresentation> catalog;
  final bool Function(PromptsPresentation) exists;
  final Widget Function(BuildContext, PromptDialogState) builder;
  @override
  State<PromptDialog> createState() => PromptDialogState();
}

class PromptDialogState extends State<PromptDialog> {
  final _children = <DialogRoute<Object?>>[];
  bool _invalidated = false;
  bool get valid =>
      mounted && !_invalidated && widget.exists(widget.catalog.value);
  PromptsPresentation get snapshot => widget.catalog.value;

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
    child: Builder(builder: (context) => widget.builder(context, this)),
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
