import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';
import 'package:path_provider/path_provider.dart';

import 'app/kiyori_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerNativeInferenceLicenses();
  runApp(
    KiyoriApp(
      connect: () async {
        final directory = await getApplicationSupportDirectory();
        return NativeRuntimeClient.open(dataDirectory: directory.path);
      },
      diagnostics: const bool.fromEnvironment('KIYORI_DIAGNOSTICS'),
    ),
  );
}
