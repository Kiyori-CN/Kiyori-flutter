import 'package:flutter/material.dart';

import 'chat_controller.dart';

Future<List<String>?> showChatMemoryFolders(
  BuildContext context,
  ChatController owner, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showDialog<List<String>>(
  context: context,
  builder: (context) {
    onRoute?.call(ModalRoute.of(context)!);
    return _MemoryFolders(owner: owner);
  },
);

class _MemoryFolders extends StatefulWidget {
  const _MemoryFolders({required this.owner});
  final ChatController owner;
  @override
  State<_MemoryFolders> createState() => _MemoryFoldersState();
}

class _MemoryFoldersState extends State<_MemoryFolders> {
  List<String>? paths;
  final selected = <String>{}, expanded = <String>{};
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final snapshot = await (await widget.owner.connect()).knowledgeSnapshot();
      if (!mounted) return;
      final all = <String>{};
      for (final path in snapshot.folders.where((path) => path.isNotEmpty)) {
        final parts = path.split('/');
        for (var i = 1; i <= parts.length; i++) {
          all.add(parts.take(i).join('/'));
        }
      }
      setState(() => paths = all.toList()..sort());
    } catch (_) {
      if (mounted) setState(() => error = '加载文件夹失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        paths?.where((path) {
          final parts = path.split('/');
          for (var i = 1; i < parts.length; i++) {
            if (!expanded.contains(parts.take(i).join('/'))) return false;
          }
          return true;
        }).toList() ??
        [];
    return AlertDialog(
      title: const Text('选择记忆文件夹'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('选择一个或多个记忆文件夹作为消息附件'),
            const SizedBox(height: 16),
            Expanded(
              child: error != null
                  ? Center(child: Text(error!))
                  : paths == null
                  ? const Center(child: CircularProgressIndicator())
                  : paths!.isEmpty
                  ? const Center(child: Text('暂无记忆文件夹'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final path = visible[index];
                        final children = paths!
                            .where((p) => p.startsWith('$path/'))
                            .toList();
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            8 + (path.split('/').length - 1) * 20,
                            4,
                            8,
                            4,
                          ),
                          child: Row(
                            children: [
                              if (children.isNotEmpty)
                                SizedBox.square(
                                  dimension: 40,
                                  child: IconButton(
                                    tooltip: expanded.contains(path)
                                        ? '收起'
                                        : '展开',
                                    iconSize: 20,
                                    icon: Icon(
                                      expanded.contains(path)
                                          ? Icons.keyboard_arrow_down
                                          : Icons.chevron_right,
                                    ),
                                    onPressed: () => setState(() {
                                      if (!expanded.remove(path)) {
                                        expanded.add(path);
                                      }
                                    }),
                                  ),
                                )
                              else
                                const SizedBox(width: 24),
                              const SizedBox(width: 4),
                              SizedBox.square(
                                dimension: 20,
                                child: Checkbox(
                                  value: selected.contains(path),
                                  onChanged: (value) => setState(() {
                                    if (value == true) {
                                      selected.addAll([path, ...children]);
                                    } else {
                                      selected.removeAll([path, ...children]);
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.folder, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  path.split('/').last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
          onPressed: selected.isEmpty
              ? null
              : () => Navigator.pop(context, selected.toList()..sort()),
          child: Text('确定 (${selected.length})'),
        ),
      ],
    );
  }
}
