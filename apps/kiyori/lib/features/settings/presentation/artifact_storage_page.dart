import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'storage_paths_page.dart';

/// 仅编辑展示草稿；保存、选择目录、检查写入、复制不触发系统操作。
class ArtifactStoragePage extends StatefulWidget {
  const ArtifactStoragePage({super.key});
  @override
  State<ArtifactStoragePage> createState() => _ArtifactStoragePageState();
}

class _ArtifactStoragePageState extends State<ArtifactStoragePage> {
  final android = TextEditingController(text: StoragePathPresentation.android);
  final linux = TextEditingController(text: StoragePathPresentation.linux);
  bool allowLeave = false;
  bool leaveDialog = false;
  bool get dirty =>
      android.text != StoragePathPresentation.android ||
      linux.text != StoragePathPresentation.linux;

  @override
  void dispose() {
    android.dispose();
    linux.dispose();
    super.dispose();
  }

  Future<void> back() async {
    if (leaveDialog) return;
    if (!dirty) {
      Navigator.pop(context);
      return;
    }
    leaveDialog = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存更改？'),
        content: const Text('更改尚未生效。可以保存后离开、放弃更改或继续编辑。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃更改'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed:
                _preview(android.text, true) != null &&
                    _preview(linux.text, false) != null
                ? emptyAction
                : null,
            child: const Text('保存'),
          ),
        ],
      ),
    );
    leaveDialog = false;
    if (discard == true && mounted) {
      setState(() => allowLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([android, linux]),
    builder: (context, _) {
      final androidPath = _preview(android.text, true);
      final linuxPath = _preview(linux.text, false);
      return PopScope(
        canPop: allowLeave || !dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) back();
        },
        child: SettingsWorkspacePage(
          title: 'AI 产物保存位置',
          onBack: back,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  '设置 AI 文档、媒体与脚本的默认保存目录。明确指定的目标或已绑定工作区优先。',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              SettingsGroup(
                title: 'Android 目录',
                description: '手机上可直接访问的共享存储目录，用于文档、媒体、下载与浏览器导出。可选择文件夹或输入绝对路径。',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PathField(
                          controller: android,
                          error: androidPath == null
                              ? '请选择共享存储中的专用子目录，不能使用存储根、Download 根、Android 私有目录、..、反斜杠或控制字符。'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: emptyAction,
                              icon: Icon(
                                Icons.folder_open_outlined,
                                size: 18,
                                color: IconTone.folder.iconFor(context),
                              ),
                              label: const Text('选择文件夹'),
                            ),
                            TextButton(
                              onPressed: androidPath != null
                                  ? emptyAction
                                  : null,
                              child: const Text('检查写入'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '检查会创建此目录并读写一个临时文件，随后移除临时文件。选择文件夹不代表已获得直接存储权限。',
                          style: TextStyle(
                            fontSize: 12,
                            color: PrimaryColors.of(context).secondary,
                          ),
                        ),
                        if (androidPath != null)
                          _PathPreview(
                            '$androidPath/office/…/report.pdf\n$androidPath/bilibili/…\n$androidPath/browser/…',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: 'Ubuntu 目录',
                description:
                    '本地 Ubuntu 内的独立目录，用于代码运行和 Linux 产物。与手机目录不互通，也不适用于远端 SSH。',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PathField(
                          controller: linux,
                          error: linuxPath == null
                              ? '请填写专用绝对目录，例如 /workspace；不能使用系统根、虚拟文件系统、..、反斜杠或控制字符。'
                              : null,
                        ),
                        if (linuxPath != null)
                          _PathPreview(
                            '$linuxPath/code-runner/…\n$linuxPath/office/…/report.pdf',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  '保存后用于新产物请求和新建的本地 AI 终端会话，不移动已有文件和会话。Android 与 Ubuntu 是独立文件系统，仍需对应存储权限。环境依赖保持原管理目录；外部工具需显式传入输出路径。',
                  style: TextStyle(
                    fontSize: 12,
                    color: PrimaryColors.of(context).secondary,
                  ),
                ),
              ),
            ],
          ),
          footer: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dirty ? '有未保存的更改' : '当前保存的设置',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: dirty
                          ? () {
                              android.text = StoragePathPresentation.android;
                              linux.text = StoragePathPresentation.linux;
                            }
                          : null,
                      child: const Text('恢复默认'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            dirty && androidPath != null && linuxPath != null
                            ? emptyAction
                            : null,
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _PathField extends StatelessWidget {
  const _PathField({required this.controller, required this.error});
  final TextEditingController controller;
  final String? error;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: 1,
    keyboardType: TextInputType.url,
    autocorrect: false,
    decoration: InputDecoration(
      labelText: '保存目录',
      border: const OutlineInputBorder(),
      errorText: error,
      errorMaxLines: 8,
      suffixIcon: IconButton(
        onPressed: controller.text.trim().isEmpty ? null : emptyAction,
        tooltip: '复制路径',
        icon: const Icon(Icons.content_copy_outlined),
      ),
    ),
  );
}

class _PathPreview extends StatelessWidget {
  const _PathPreview(this.paths);
  final String paths;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '默认输出示例',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SelectableText(
          paths,
          style: TextStyle(
            fontSize: 12,
            color: PrimaryColors.of(context).secondary,
          ),
        ),
      ],
    ),
  );
}

/// ArtifactPathRules 的输入外观校验，仅决定预览与按钮状态。
/// 未来持久化必须由 Rust storage owner 再验证，不可作为访问授权。
String? _preview(String input, bool android) {
  if (input.codeUnits.any((unit) => unit < 32 || unit == 127) ||
      input.contains('\\') ||
      input.split('/').contains('..')) {
    return null;
  }
  var path = input.trim();
  if (path.isEmpty) {
    path = android
        ? StoragePathPresentation.android
        : StoragePathPresentation.linux;
  }
  if (android) {
    if (RegExp(r'[:*?"<>|]').hasMatch(path)) return null;
    if (path == '/sdcard' || path.startsWith('/sdcard/')) {
      path = '/storage/emulated/0${path.substring(7)}';
    }
    if (!path.startsWith('/')) {
      path = path == 'Download' || path.startsWith('Download/')
          ? '/storage/emulated/0/$path'
          : '/storage/emulated/0/Download/$path';
    }
  }
  if (!path.startsWith('/')) return null;
  path =
      '/${path.split('/').where((part) => part.isNotEmpty && part != '.').join('/')}';
  if (android) {
    if (!path.startsWith('/storage/emulated/0/') ||
        path == '/storage/emulated/0/Download' ||
        path == '/storage/emulated/0/Android' ||
        path.startsWith('/storage/emulated/0/Android/')) {
      return null;
    }
  } else {
    if (const {
          '/',
          '/root',
          '/home',
          '/tmp',
          '/usr',
          '/var',
          '/etc',
          '/bin',
          '/opt',
          '/boot',
          '/dev',
          '/proc',
          '/sys',
          '/run',
          '/sbin',
          '/lib',
          '/lib64',
          '/mnt',
          '/media',
          '/srv',
        }.contains(path) ||
        ['/dev/', '/proc/', '/sys/'].any(path.startsWith)) {
      return null;
    }
  }
  return path;
}
