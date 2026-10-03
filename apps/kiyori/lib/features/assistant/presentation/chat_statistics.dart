import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';

Future<void> showChatStatistics(
  BuildContext context,
  ChatController owner, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showKiyoriModalDrawer<void>(
  context,
  onRoute: onRoute,
  builder: (context, dismiss) => _Statistics(owner: owner, dismiss: dismiss),
);

class _Statistics extends StatefulWidget {
  const _Statistics({required this.owner, required this.dismiss});
  final ChatController owner;
  final Future<void> Function() dismiss;
  @override
  State<_Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<_Statistics> {
  late final id = widget.owner.snapshot?.conversation.id;
  ConversationStatistics? value;
  bool recent = false, failed = false, loading = false, dirty = false;
  @override
  void initState() {
    super.initState();
    widget.owner.addListener(changed);
    load();
  }

  void changed() {
    if (loading) {
      dirty = true;
    } else {
      load();
    }
  }

  Future<void> load() async {
    if (!mounted || loading) return;
    if (id == null) {
      setState(
        () => value = const ConversationStatistics(
          requests: 0,
          reportedRequests: 0,
          recentModel: '',
        ),
      );
      return;
    }
    loading = true;
    try {
      final next = await (await widget.owner.connect()).conversationStatistics(
        id!,
      );
      if (mounted) {
        setState(() {
          value = next;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      loading = false;
      if (mounted && dirty) {
        dirty = false;
        load();
      }
    }
  }

  @override
  void dispose() {
    widget.owner.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    final input = recent
        ? v?.recentInputTokens?.toInt()
        : v?.inputTokens?.toInt();
    final output = recent
        ? v?.recentOutputTokens?.toInt()
        : v?.outputTokens?.toInt();
    String number(int? n) => n?.toString() ?? '未提供';
    String duration(int? n) =>
        n == null || n < 0 ? '未提供' : '${(n / 1000).toStringAsFixed(2)} 秒';
    final rows = [
      ('输入', number(input)),
      ('输出', number(output)),
      ('总用量', number(input == null || output == null ? null : input + output)),
      ('推理细分（若有）', '未提供'),
    ];
    final coverage = [
      ('模型请求数', v?.requests.toString() ?? '未提供'),
      (
        '用量覆盖',
        v == null || v.requests == 0
            ? '未提供'
            : '${v.reportedRequests} / ${v.requests}',
      ),
      ('缓存覆盖', '未提供'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '对话数据统计',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '当前对话 · token 用量与生成表现',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '复制统计摘要',
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: [
                      '对话数据统计',
                      recent ? '最近请求' : '对话累计',
                      for (final row in [...rows, ...coverage])
                        '${row.$1}: ${row.$2}',
                    ].join('\n'),
                  ),
                ),
                icon: const Icon(Icons.content_copy_outlined),
              ),
              IconButton(
                tooltip: '关闭统计',
                onPressed: widget.dismiss,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        if (failed)
          TextButton(onPressed: load, child: const Text('统计读取失败，点击重试')),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    selected: !recent,
                    onSelected: (_) => setState(() => recent = false),
                    label: const Text('对话累计'),
                  ),
                  FilterChip(
                    selected: recent,
                    onSelected: (_) => setState(() => recent = true),
                    label: const Text('最近请求'),
                  ),
                ],
              ),
              Text(
                recent ? '最近模型请求；未报告的用量显示未提供。' : '累计仅含已报告用量的请求，可能来自不同模型。',
                style: const TextStyle(fontSize: 12),
              ),
              if (recent && v?.recentModel.isNotEmpty == true)
                Text(v!.recentModel, style: const TextStyle(fontSize: 12)),
              _card(context, '提示词缓存', [
                ('输入 token 缓存读取率', '未提供'),
                ('缓存读取', '未提供'),
                ('缓存写入', '未提供'),
                ('普通 / 未分类输入', number(input)),
                ('可计量输入 · 读取率分母', '未提供'),
                ('缺少有效缓存指标的输入', number(input)),
              ], progress: true),
              _card(
                context,
                '上下文占用 · 估算',
                [('当前 / 上限', '未提供')],
                note: '最近一次请求的上下文估算 / 配置的上下文上限，与对话累计消耗不同。',
                progress: true,
              ),
              _card(context, '生成速度 · 当前 / 最近请求', [
                ('生成速度', '未提供'),
                ('首次输出等待', duration(v?.firstOutputMs?.toInt())),
                ('请求总耗时', duration(v?.durationMs?.toInt())),
              ], note: '客户端观测首次正文与结束；不是网络 RTT 或服务端纯推理耗时。历史请求不推算速度。'),
              _card(
                context,
                '供应商用量 · token',
                rows,
                note: '总用量 = 输入 + 输出；推理属于输出细分。未报告的数值显示未提供。',
              ),
              _card(
                context,
                '数据覆盖',
                coverage,
                note: v != null && v.reportedRequests < v.requests
                    ? '部分请求未提供用量，累计数值不代表完整消耗。'
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context,
    String title,
    List<(String, String)> rows, {
    String? note,
    bool progress = false,
  }) => Card(
    margin: const EdgeInsets.only(top: 16),
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          if (progress) ...[
            const SizedBox(height: 8),
            const Text('未提供', style: TextStyle(fontSize: 28)),
            const LinearProgressIndicator(value: 0),
          ],
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(row.$1, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                note,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
