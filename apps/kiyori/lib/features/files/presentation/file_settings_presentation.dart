import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class FileSettingsPresentation {
  const FileSettingsPresentation({
    this.hiddenFiles = const [],
    this.hiddenLocations = const [],
    this.openDefaults = const {},
    this.searchCount = 0,
    this.finishedTaskCount = 0,
    this.confirmationBusy = false,
    this.confirmationError,
  });
  final List<String> hiddenFiles, hiddenLocations;
  final Map<String, String> openDefaults;
  final int searchCount, finishedTaskCount;
  final bool confirmationBusy;
  final String? confirmationError;
}

/// 页面只拥有模态路由与展示快照；恢复、保存和清理动作不写文件偏好。
class FileSettingsSession extends ValueNotifier<FileSettingsPresentation> {
  FileSettingsSession(super.value);
  final _routes = <ModalRoute<dynamic>, String?>{};
  bool _closed = false;
  void update(FileSettingsPresentation next) {
    final removed = _routes.entries
        .where(
          (entry) =>
              entry.value != null &&
              !next.openDefaults.containsKey(entry.value),
        )
        .map((entry) => entry.key)
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in removed.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
      if (!_closed) value = next;
    });
  }

  Future<void> show(
    BuildContext context,
    Widget Function(BuildContext, FileSettingsPresentation) builder, {
    String? existingFormat,
    bool confirmation = false,
  }) async {
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => ValueListenableBuilder(
        valueListenable: this,
        builder: (context, value, _) => PopScope(
          canPop: !confirmation || !value.confirmationBusy,
          child: SettingsTheme(child: builder(context, value)),
        ),
      ),
    );
    _routes[route] = existingFormat;
    try {
      await Navigator.of(context).push(route);
    } finally {
      _routes.remove(route);
    }
  }

  void track(ModalRoute<dynamic> route) {
    if (_closed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
      return;
    }
    _routes[route] = null;
    unawaited(route.popped.whenComplete(() => _routes.remove(route)));
  }

  @override
  void dispose() {
    _closed = true;
    final routes = _routes.keys.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
      super.dispose();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
