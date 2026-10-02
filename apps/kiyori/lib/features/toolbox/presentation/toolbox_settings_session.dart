import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'toolbox_settings_presentation.dart';

/// 仅拥有页面模态路由；快照变更不会变成第二份布局存储。
class ToolboxSettingsSession extends ChangeNotifier {
  ToolboxSettingsSession(this.snapshot) {
    _reconcile();
  }
  ToolboxSettingsPresentation snapshot;
  final _routes = <ModalRoute<dynamic>, String?>{};
  final _menus = <ModalRoute<dynamic>>{};
  final _identities = <String, Object>{};
  Object? identity(String id) => _identities[id];
  void _reconcile() {
    _identities.removeWhere((id, _) => snapshot.group(id) == null);
    for (final group in snapshot.orderedGroups) {
      _identities.putIfAbsent(group.id, Object.new);
    }
  }

  void registerMenu(BuildContext context, String id) {
    final route = ModalRoute.of(context)!;
    _register(route, id);
    _menus.add(route);
  }

  bool _disposed = false;
  bool dragging = false;
  bool get canDismiss => !snapshot.saving && !dragging;

  void update(ToolboxSettingsPresentation next) {
    snapshot = next;
    _reconcile();
    if (!next.enabled) _remove(_menus);
    _remove(
      _routes.entries
          .where((e) => e.value != null && next.group(e.value!) == null)
          .map((e) => e.key),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  void _remove(Iterable<ModalRoute<dynamic>> routes) {
    final removed = routes.toList().reversed.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in removed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _register(ModalRoute<dynamic> route, String? id) {
    if (_disposed || (id != null && snapshot.group(id) == null)) {
      _remove([route]);
      return;
    }
    if (_routes.containsKey(route)) return;
    _routes[route] = id;
    route.popped.whenComplete(() {
      _routes.remove(route);
      _menus.remove(route);
    });
  }

  Future<void> drawer(
    BuildContext context,
    KiyoriDrawerBuilder<void> builder, {
    String? id,
  }) => showKiyoriModalDrawer<void>(
    context,
    canDismiss: () => canDismiss,
    onRoute: (route) => _register(route, id),
    builder: (context, dismiss) => ListenableBuilder(
      listenable: this,
      builder: (context, _) => SettingsTheme(child: builder(context, dismiss)),
    ),
  );

  Future<void> dialog(
    BuildContext context,
    WidgetBuilder builder, {
    String? id,
  }) async {
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: this,
        builder: (context, _) => PopScope(
          canPop: canDismiss,
          child: SettingsTheme(child: builder(context)),
        ),
      ),
    );
    _register(route, id);
    await Navigator.of(context).push(route);
  }

  @override
  void dispose() {
    _disposed = true;
    _remove(_routes.keys);
    super.dispose();
  }
}

class ToolboxPreferenceNotice extends StatelessWidget {
  const ToolboxPreferenceNotice(this.snapshot, {super.key});
  final ToolboxSettingsPresentation snapshot;
  @override
  Widget build(BuildContext context) => snapshot.error != null
      ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  snapshot.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: snapshot.saving ? null : emptyAction,
                child: Text(snapshot.loaded ? '关闭提示' : '重新读取'),
              ),
            ],
          ),
        )
      : !snapshot.loaded
      ? const LinearProgressIndicator()
      : const SizedBox.shrink();
}
