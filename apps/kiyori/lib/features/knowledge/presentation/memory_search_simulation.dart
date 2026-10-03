import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'knowledge_controller.dart';

class MemorySearchSimulation extends StatefulWidget {
  const MemorySearchSimulation({
    required this.controller,
    required this.space,
    required this.scope,
    super.key,
  });
  final KnowledgeController controller;
  final String space;
  final MemoryQuery scope;
  @override
  State<MemorySearchSimulation> createState() => _MemorySearchSimulationState();
}

class _MemorySearchSimulationState extends State<MemorySearchSimulation> {
  late final query = TextEditingController(text: widget.scope.text);
  bool running = false;
  String? error;
  MemorySearchReport? report;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> run() async {
    if (running) return;
    if (query.text.length > 2048) {
      setState(() => error = '查询不能超过 2048 个字符。');
      return;
    }
    setState(() {
      running = true;
      error = null;
    });
    try {
      final scope = widget.scope;
      final value = await widget.controller.simulateSearch(
        widget.space,
        MemoryQuery(
          kind: scope.kind,
          folder: scope.folder,
          text: query.text,
          archived: scope.archived,
          category: scope.category,
          tag: scope.tag,
          sortTitle: false,
          offset: 0,
          diaryClosed: scope.diaryClosed,
        ),
      );
      if (mounted) setState(() => report = value);
    } catch (_) {
      if (mounted) setState(() => error = '无法执行搜索，请重试。');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  Widget card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          ...children,
        ],
      ),
    ),
  );
  String score(double value) => value.toStringAsFixed(4);
  @override
  Widget build(BuildContext context) {
    final value = report;
    return AlertDialog(
      title: const Text('模拟搜索'),
      content: SizedBox(
        width: 640,
        height: MediaQuery.sizeOf(context).height * .65,
        child: ListView(
          children: [
            TextField(
              controller: query,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '模拟查询'),
            ),
            if (running) const LinearProgressIndicator(),
            if (error case final String message)
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (value != null) ...[
              card('搜索摘要', [
                Text('范围内记忆: ${value.scopeCount}'),
                Text(
                  '命中数 关键词:${value.keywordMatches} 标签:${value.tagMatches} 反向包含:${value.reverseMatches}',
                ),
                Text(
                  '过阈值:${value.passedCount} 阈值:0.0250 关系遍历:${value.edgesTraversed}',
                ),
                Text(
                  '权重 keyword:${score(value.keywordWeight)} tag:${score(value.tagWeight)} edge:${score(value.edgeWeight)}',
                ),
                if (value.vectorUnavailable) const Text('云端嵌入未配置，本次仅包含本地检索得分。'),
              ]),
              card('关键词切片', [
                Text(
                  '词法分片(${value.tokens.length}): ${value.tokens.join(' | ')}',
                ),
              ]),
              Text(
                '候选结果（显示 ${value.candidates.length} 条${value.hasMore ? '，还有更多' : ''}）',
              ),
              ...value.candidates.map(
                (row) => card(row.title, [
                  Text(row.folder.isEmpty ? '根目录' : row.folder),
                  Text(
                    'k:${score(row.keywordScore)} t:${score(row.tagScore)} r:${score(row.reverseScore)} e:${score(row.edgeScore)}',
                  ),
                  Text(
                    'total:${score(row.totalScore)} token:${row.matchedTokens} ${row.passed ? '通过阈值' : '低于阈值'}',
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: running ? null : () => unawaited(run()),
          child: const Text('执行模拟'),
        ),
      ],
    );
  }
}
