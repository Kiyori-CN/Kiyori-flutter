import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

class ExtensionImportDialog extends StatefulWidget {
  const ExtensionImportDialog({
    required this.connect,
    required this.picker,
    super.key,
  });
  final Future<RuntimeClient> Function() connect;
  final ModelFilePicker picker;
  @override
  State<ExtensionImportDialog> createState() => _ExtensionImportDialogState();
}

class _ExtensionImportDialogState extends State<ExtensionImportDialog> {
  ModelFileSource? source;
  ExtensionImportRun? run;
  bool cancelled = false, done = false, committing = false;
  String status = '请选择 ToolPkg(.toolpkg) 文件';
  String? error;
  int bytes = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(import()));
  }

  Future<void> import() async {
    ExtensionPackage? installed;
    try {
      source = await widget.picker.select();
      if (source == null || cancelled || !mounted) return;
      final runtime = await widget.connect();
      if (cancelled || !mounted) return;
      run = await runtime.beginExtensionImport();
      if (cancelled || !mounted) return;
      setState(() => status = '正在导入 ${source!.name}');
      final update = Stopwatch()..start();
      while (!cancelled && mounted) {
        final chunk = await source!.read().timeout(const Duration(seconds: 60));
        if (cancelled || !mounted) return;
        if (chunk.isEmpty) break;
        bytes = (await run!.append(chunk)).toInt();
        if (update.elapsedMilliseconds >= 100 && mounted) {
          setState(() {});
          update.reset();
        }
      }
      if (cancelled || !mounted) return;
      setState(() {
        status = '正在校验并安装插件';
        committing = true;
      });
      installed = await run!.finish();
    } on BridgeError catch (failure) {
      error = failure.message;
    } on ModelFileException catch (failure) {
      error = switch (failure.code) {
        'unsupported' => '当前平台没有可用的插件文件选择器',
        'busy' => '已有文件选择或导入，请先结束后重试',
        'invalid_name' => '仅支持 ToolPkg(.toolpkg) 文件',
        _ => '插件文件读取失败，请重新选择',
      };
    } on TimeoutException {
      error = '插件文件读取超时，请取消后重新选择';
    } catch (_) {
      error = '插件导入未完成，请检查文件和可用空间';
    } finally {
      try {
        await source?.close();
      } catch (_) {
        error ??= '插件文件句柄释放失败';
      }
      try {
        await run?.close();
      } catch (_) {
        error ??= '插件暂存释放失败';
      }
      if (mounted) {
        if (installed != null ||
            cancelled ||
            (source == null && error == null)) {
          Navigator.of(context).pop(installed);
        } else {
          setState(() => done = true);
        }
      }
    }
  }

  void cancel() {
    if (committing && !done) return;
    if (done) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      cancelled = true;
      status = '正在取消并释放文件';
    });
    unawaited(
      source?.close().catchError((Object _) {}) ?? Future<void>.value(),
    );
  }

  @override
  void dispose() {
    cancelled = true;
    unawaited(
      source?.close().catchError((Object _) {}) ?? Future<void>.value(),
    );
    // 本import的finally等finish结束再close，Rust仍是安装及回收的唯一owner。
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: done,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) cancel();
    },
    child: AlertDialog(
      title: const Text('导入外部插件'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error ?? status),
          if (!done) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text('已读取 ${(bytes / 1024 / 1024).toStringAsFixed(1)} MiB'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: cancelled || (committing && !done) ? null : cancel,
          child: Text(done ? '关闭' : '取消'),
        ),
      ],
    ),
  );
}
