import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'app/kiyori_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    KiyoriApp(
      connect: NativeRuntimeClient.open,
      diagnostics: const bool.fromEnvironment('KIYORI_DIAGNOSTICS'),
    ),
  );
}
