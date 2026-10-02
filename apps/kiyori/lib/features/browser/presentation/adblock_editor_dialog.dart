import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

enum AdblockEditorKind { network, element, allowlist, subscription }

Future<void> showAdblockEditor(BuildContext context, AdblockEditorKind kind) =>
    showDialog<void>(
      context: context,
      builder: (_) => AdblockEditor(kind: kind),
    );

class AdblockEditor extends StatefulWidget {
  const AdblockEditor({
    required this.kind,
    this.editing = false,
    this.initialFirst = '',
    this.initialSecond = '',
    super.key,
  });
  final AdblockEditorKind kind;
  final bool editing;
  final String initialFirst, initialSecond;
  @override
  State<AdblockEditor> createState() => _AdblockEditorState();
}

class _AdblockEditorState extends State<AdblockEditor> {
  late final first = TextEditingController(text: widget.initialFirst);
  late final second = TextEditingController(text: widget.initialSecond);
  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (title, description, firstLabel, secondLabel) = switch (widget.kind) {
      AdblockEditorKind.network => (
        widget.editing ? '编辑网址过滤规则' : '新增网址过滤规则',
        '输入请求地址匹配规则。例外规则以 @@ 开头。',
        '规则',
        null,
      ),
      AdblockEditorKind.element => (
        widget.editing ? '编辑网页元素规则' : '新增网页元素规则',
        '域名决定规则作用范围，CSS selector 决定隐藏的页面节点。',
        '站点域名',
        'CSS selector',
      ),
      AdblockEditorKind.allowlist => (
        '添加站点白名单',
        '输入主机名，不需要协议和路径。',
        '站点域名',
        null,
      ),
      AdblockEditorKind.subscription => (
        widget.editing ? '编辑广告拦截订阅' : '新增广告拦截订阅',
        '保存只记录订阅地址；返回列表后点击刷新才会下载自定义规则。',
        '订阅名称',
        'HTTP(S) 订阅地址',
      ),
    };
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 312,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: PrimaryColors.of(context).secondary),
              ),
              TextField(
                controller: first,
                onChanged: (_) => setState(() {}),
                minLines: widget.kind == AdblockEditorKind.network ? 2 : 1,
                maxLines: widget.kind == AdblockEditorKind.network ? 5 : 1,
                decoration: settingsFieldDecoration(context, label: firstLabel),
              ),
              if (secondLabel != null)
                TextField(
                  controller: second,
                  onChanged: (_) => setState(() {}),
                  minLines: 2,
                  maxLines: widget.kind == AdblockEditorKind.element ? 5 : 4,
                  decoration: settingsFieldDecoration(
                    context,
                    label: secondLabel,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed:
              first.text.trim().isNotEmpty &&
                  (secondLabel == null || second.text.trim().isNotEmpty)
              ? emptyAction
              : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
