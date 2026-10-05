import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'chat_modal_session.dart';

/// 每个实体弹层拥有独立租期；失效只移除自身与所属确认，不影响历史目录或底层页面。
Future<void> withHistoryEntity(
  ChatController owner,
  bool Function() alive,
  Future<void> Function(ValueChanged<ModalRoute<dynamic>>) show,
  ValueChanged<ModalRoute<dynamic>>? outer,
) async {
  final session = ChatModalSession();
  final register = session.registration(session.epoch);
  void changed() {
    if (!alive()) session.invalidate();
  }

  owner.addListener(changed);
  try {
    if (alive()) {
      await show((route) {
        register(route);
        outer?.call(route);
        if (!alive()) session.invalidate();
      });
    }
  } finally {
    owner.removeListener(changed);
    session.dispose();
  }
}
