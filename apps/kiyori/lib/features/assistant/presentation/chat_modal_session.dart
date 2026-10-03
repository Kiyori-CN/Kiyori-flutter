import 'package:flutter/material.dart';

/// 聊天宿主的模态租期；只移除登记过的路由，不猜测当前栈顶。
class ChatModalSession {
  final _routes = <ModalRoute<dynamic>>{};
  int _epoch = 0;
  bool _disposed = false;
  int get epoch => _epoch;
  bool valid(int epoch) => !_disposed && epoch == _epoch;

  ValueChanged<ModalRoute<dynamic>> registration(int epoch) => (route) {
    if (valid(epoch)) {
      if (_routes.add(route)) {
        route.popped.whenComplete(() => _routes.remove(route));
      }
    } else {
      _remove([route]);
    }
  };

  void invalidate() {
    _epoch++;
    final routes = _routes.toList().reversed.toList();
    _routes.clear();
    _remove(routes);
  }

  void _remove(List<ModalRoute<dynamic>> routes) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }
}
