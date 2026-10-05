import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

/// 只传文件名与有界字节；选择器/资源/会话各自负责自己的生命周期。
class GgufImportDialog extends StatefulWidget {
  const GgufImportDialog({
    required this.connect,
    required this.picker,
    super.key,
  });
  final Future<RuntimeClient> Function() connect;
  final ModelFilePicker picker;
  @override
  State<GgufImportDialog> createState() => _GgufImportDialogState();
}

class _GgufImportDialogState extends State<GgufImportDialog> {
  ModelFileSource? source;
  ModelImportRun? run;
  bool cancelled = false, done = false, committing = false;
  String status = '请选择 GGUF 模型文件';
  String? error;
  int bytes = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(import()));
  }

  Future<void> import() async {
    String? imported;
    try {
      source = await widget.picker.select();
      if (source == null || cancelled || !mounted) return;
      final runtime = await widget.connect();
      if (cancelled || !mounted) return;
      run = await runtime.beginModelImport(source!.name);
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
        status = '正在校验并保存模型';
        committing = true;
      });
      imported = await run!.finish();
    } on BridgeError catch (failure) {
      error = failure.message;
    } on ModelFileException catch (failure) {
      error = switch (failure.code) {
        'unsupported' => '当前平台没有可用的模型文件选择器',
        'busy' => '已有文件选择或导入，请先结束后重试',
        'invalid_name' => '请选择有效名称的 GGUF 文件',
        _ => '模型文件读取失败，请重新选择并检查可用空间',
      };
    } on TimeoutException {
      error = '模型文件读取超时，请取消后重新选择';
    } catch (_) {
      error = '模型导入失败，请检查文件与可用空间后重试';
    } finally {
      try {
        await source?.close();
      } catch (_) {
        error ??= '模型文件句柄释放失败';
      }
      try {
        await run?.close();
      } catch (_) {
        error ??= '模型暂存释放失败';
      }
      if (mounted) {
        if (imported != null ||
            cancelled ||
            (source == null && error == null)) {
          Navigator.of(context).pop(imported);
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
    // Android关闭句柄解除provider读取；Windows等待在途文件I/O结算后关闭。
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
    // import的finally等待在途append/finish，然后关闭Rust句柄。
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: done,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) cancel();
    },
    child: AlertDialog(
      title: const Text('导入 GGUF 模型'),
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
