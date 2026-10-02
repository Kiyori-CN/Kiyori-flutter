import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'music_settings_presentation.dart';

class MusicSourceLinkDialog extends StatefulWidget {
  const MusicSourceLinkDialog({
    this.editing = false,
    this.initialUrl = '',
    required this.working,
    required this.editable,
    this.error,
    super.key,
  });
  final bool editing, working, editable;
  final String initialUrl;
  final String? error;
  @override
  State<MusicSourceLinkDialog> createState() => _LinkState();
}

class _LinkState extends State<MusicSourceLinkDialog> {
  late final controller = TextEditingController(text: widget.initialUrl);
  bool visible = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.editing ? '更新音源链接' : '在线导入音源'),
    content: SizedBox(
      width: 312,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const Text('输入 HTTPS 脚本链接。链接与脚本加密保存在本机，更新失败会保留原版本。'),
          TextField(
            controller: controller,
            obscureText: !visible,
            enabled: !widget.working,
            autocorrect: false,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '音源链接',
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => visible = !visible),
              child: Text(visible ? '隐藏链接' : '显示链接'),
            ),
          ),
          if (widget.working) const LinearProgressIndicator(),
          if (widget.error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: widget.working ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: widget.editable && controller.text.trim().isNotEmpty
            ? emptyAction
            : null,
        child: Text(
          widget.working
              ? '正在校验'
              : widget.editing
              ? '更新'
              : '导入',
        ),
      ),
    ],
  );
}

class MusicSourceDetailDialog extends StatefulWidget {
  const MusicSourceDetailDialog({
    required this.source,
    required this.active,
    required this.working,
    required this.editable,
    required this.onEditLink,
    required this.onRemove,
    this.error,
    super.key,
  });
  final MusicSourcePresentation source;
  final bool active, working, editable;
  final String? error;
  final VoidCallback onEditLink, onRemove;
  @override
  State<MusicSourceDetailDialog> createState() => _DetailState();
}

class _DetailState extends State<MusicSourceDetailDialog> {
  bool visible = false;
  @override
  void didUpdateWidget(covariant MusicSourceDetailDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.url != widget.source.url) visible = false;
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final small = Theme.of(context).textTheme.bodySmall;
    return AlertDialog(
      scrollable: true,
      title: Text(source.name),
      content: SizedBox(
        width: 312,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(
              '版本：${source.version.isEmpty ? '未声明' : source.version}\n作者：${source.author.isEmpty ? '未声明' : source.author}\n状态：${widget.active ? '当前使用' : '未启用'}',
            ),
            if (source.description.isNotEmpty) Text(source.description),
            if (source.capabilities.isNotEmpty)
              Text(source.capabilities.join('\n'), style: small),
            if (source.url.isNotEmpty) ...[
              Text('导入链接保存在本机加密资料中，可能包含密钥。', style: small),
              TextButton(
                onPressed: () => setState(() => visible = !visible),
                child: Text(visible ? '隐藏链接' : '查看导入链接'),
              ),
              if (visible) SelectableText(source.url, style: small),
            ] else
              Text('本地导入的音源没有在线链接；可选择新文件更新。', style: small),
            if (source.importedLabel != null)
              Text(
                '导入：${source.importedLabel}\n更新：${source.updatedLabel ?? source.importedLabel}',
                style: small,
              ),
            Text('SHA-256：${source.fingerprint}', style: small),
            if (widget.working) const LinearProgressIndicator(),
            if (widget.error case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!widget.active)
              OutlinedButton(
                onPressed: widget.editable ? emptyAction : null,
                child: const Text('使用此音源'),
              ),
            OutlinedButton(
              onPressed: widget.editable ? emptyAction : null,
              child: Text(source.url.isEmpty ? '从文件更新' : '立即更新'),
            ),
            OutlinedButton(
              onPressed: widget.editable ? widget.onEditLink : null,
              child: const Text('修改链接并更新'),
            ),
            TextButton(
              onPressed: widget.editable ? widget.onRemove : null,
              child: Text(
                '移除此音源',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.working ? null : () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    );
  }
}
