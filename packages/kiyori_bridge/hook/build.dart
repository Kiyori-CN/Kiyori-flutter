import 'dart:io';

import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // Cargo dep-info tracks Rust sources, while workspace manifests and the lock
    // also need to invalidate the Flutter build when dependency policy changes.
    for (final relative in [
      '../../Cargo.toml',
      '../../Cargo.lock',
      '../../rust-toolchain.toml',
      '../../crates/kiyori_core/Cargo.toml',
      '../../crates/kiyori_ffi/rust-toolchain.toml',
    ]) {
      final dependency = input.packageRoot.resolve(relative);
      if (!File.fromUri(dependency).existsSync()) {
        throw StateError('Required build input is missing: $relative');
      }
      output.dependencies.add(dependency);
    }
    await const FlutterRustBridgeNativeAssetsBuilder(
      assetName: 'src/generated/frb_generated.io.dart',
      cratePath: '../../crates/kiyori_ffi',
      extraCargoBuildArgs: ['--locked'],
    ).run(input: input, output: output);
  });
}
