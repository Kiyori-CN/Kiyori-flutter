import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'browser_credentials_presentation.dart';

enum CredentialAction { detail, edit, delete }

class BrowserCredentialDialog extends StatefulWidget {
  const BrowserCredentialDialog({
    required this.detail,
    required this.mode,
    super.key,
  });
  final BrowserCredentialDetail detail;
  final CredentialAction mode;
  @override
  State<BrowserCredentialDialog> createState() =>
      _BrowserCredentialDialogState();
}

class _BrowserCredentialDialogState extends State<BrowserCredentialDialog> {
  late final username = TextEditingController(
    text: widget.detail.summary.username,
  );
  late final password = TextEditingController(text: widget.detail.password);
  bool visible = false;
  @override
  void didUpdateWidget(covariant BrowserCredentialDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.summary.username != widget.detail.summary.username) {
      username.text = widget.detail.summary.username;
    }
    if (oldWidget.detail.password != widget.detail.password) {
      password.text = widget.detail.password;
      visible = false;
    }
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Widget _visibility() => IconButton(
    onPressed: () => setState(() => visible = !visible),
    tooltip: visible ? '隐藏密码' : '显示密码',
    icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
  );
  Widget _value(
    BuildContext context,
    String label,
    String value, {
    bool secret = false,
  }) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
    ),
    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        if (secret) _visibility(),
        IconButton(
          onPressed: emptyAction,
          tooltip: '复制$label',
          icon: const Icon(Icons.copy_outlined),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final credential = widget.detail;
    final summary = credential.summary;
    if (widget.mode == CredentialAction.delete) {
      return AlertDialog(
        title: const Text('删除网站密码？'),
        scrollable: true,
        content: Text(
          '将删除 ${summary.origin} 中账号 ${summary.username} 的保存记录。该操作不会退出网站登录状态。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: emptyAction,
            child: Text(
              '删除',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    if (widget.mode == CredentialAction.edit) {
      return AlertDialog(
        title: const Text('编辑网站账号'),
        scrollable: true,
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.origin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: username,
                maxLines: 1,
                onChanged: (_) => setState(() {}),
                inputFormatters: [_bounded(512)],
                decoration: InputDecoration(
                  labelText: '账号',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                maxLines: 1,
                obscureText: !visible,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                onChanged: (_) => setState(() {}),
                inputFormatters: [_bounded(4096)],
                decoration: InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: _visibility(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed:
                username.text.trim().isNotEmpty &&
                    username.text.length <= 512 &&
                    password.text.isNotEmpty &&
                    password.text.length <= 4096
                ? emptyAction
                : null,
            child: const Text('保存'),
          ),
        ],
      );
    }
    return AlertDialog(
      scrollable: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.origin,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            summary.pageUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _value(context, '账号', summary.username),
            const SizedBox(height: 12),
            _value(
              context,
              '密码',
              visible
                  ? credential.password
                  : '•' * credential.password.length.clamp(8, 16),
              secret: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, CredentialAction.delete),
          child: Text(
            '删除',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, CredentialAction.edit),
          child: const Text('编辑'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  TextInputFormatter _bounded(int limit) => TextInputFormatter.withFunction(
    (oldValue, value) => value.text.length <= limit ? value : oldValue,
  );
}
