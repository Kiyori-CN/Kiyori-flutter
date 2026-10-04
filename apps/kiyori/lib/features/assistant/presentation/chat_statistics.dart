import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';

const _usageNote =
    '累计仅含输入和输出完整报告且已入账的请求，可能来自不同模型；进行中的回合稍后计入。总用量 = 输入 + 输出；推理属于输出细分。历史累计未区分推理、缓存写入的未提供和 0，没有正值时显示未提供。';
const _recentNote = '最近完成的单次模型调用，工具续轮分别计量；运行中尚无完整用量，重启后不推算历史样本。';
const _cacheNote =
    '读取率 = 缓存读取 token ÷ 可计量输入 token，按 token 加权，并非命中请求占比。写入不算命中；缓存读取、写入均已包含在输入中。异常或未提供的缓存分桶排除，输入总量仍保留。';
const _contextNote = '最近一次请求的上下文估算 / 配置的上下文上限，与对话累计消耗不同。';
const _speedNote =
    '单次模型请求的输出 token / 首个输出至流结束的秒数。排除首包等待及工具执行；流式期间为估算，非流式及历史请求不推算速度。';
const _timingNote =
    '当前 / 最近请求的客户端观测：从发起调用到首次内容及流结束，包含本地请求准备、网络、代理及服务端等待。首次内容可能是思考或工具数据；不是网络 RTT 或服务端纯推理耗时。';
const _coverageNote =
    '用量覆盖 = 已报告用量 / 模型请求数；缓存覆盖 = 已报告缓存指标 / 已报告用量。一次对话回合可能包含多次模型请求。';

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
    final requests = recent
        ? (v?.recentModel.isNotEmpty == true ? 1 : 0)
        : v?.requests;
    final reported = recent
        ? (input != null && output != null ? 1 : 0)
        : v?.reportedRequests;
    String number(int? n) =>
        n?.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        ) ??
        '未提供';
    String duration(int? n) =>
        n == null || n < 0 ? '未提供' : '${(n / 1000).toStringAsFixed(2)} s';
    final rows = [
      ('输入', number(input)),
      ('输出', number(output)),
      ('总用量', number(input == null || output == null ? null : input + output)),
      ('推理细分（若有）', '未提供'),
    ];
    final coverage = [
      ('模型请求数', number(requests)),
      ('用量覆盖', v == null ? '未提供' : '$reported/$requests'),
      ('缓存覆盖', '未提供'),
    ];
    final cache = [
      ('缓存读取', '未提供'),
      ('缓存写入', '未提供'),
      ('普通 / 未分类输入', number(input)),
      ('输入 token 缓存读取率', '未提供'),
      ('可计量输入 · 读取率分母', '未提供'),
      ('缺少有效缓存指标的输入', number(input)),
    ];
    final c = Theme.of(context).colorScheme;
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
                      if (recent && v?.recentModel.isNotEmpty == true)
                        v!.recentModel,
                      '上下文占用 · 估算: 未提供 (未提供 / 未提供 token)',
                      '生成速度 · 当前 / 最近请求: 未提供 · 暂无有效的流式计时数据',
                      '首次输出等待: ${duration(v?.firstOutputMs?.toInt())}',
                      '请求总耗时: ${duration(v?.durationMs?.toInt())}',
                      for (final row in [...rows, ...cache, ...coverage])
                        '${row.$1}: ${row.$2}',
                      _contextNote,
                      _speedNote,
                      _timingNote,
                      _usageNote,
                      _cacheNote,
                      _coverageNote,
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
                recent ? _recentNote : _usageNote,
                style: const TextStyle(fontSize: 12),
              ),
              if (recent && v?.recentModel.isNotEmpty == true)
                Text(v!.recentModel, style: const TextStyle(fontSize: 12)),
              _card(
                context,
                '提示词缓存',
                [
                  for (final row in cache)
                    if (row.$1 != '输入 token 缓存读取率') row,
                ],
                note: _cacheNote,
                leading: [
                  Text(
                    '未提供',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: c.primary,
                    ),
                  ),
                  const Text(
                    '输入 token 缓存读取率',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const LinearProgressIndicator(value: 0),
                ],
              ),
              _card(
                context,
                '上下文占用 · 估算',
                [],
                note: _contextNote,
                leading: [
                  Text(
                    '未提供',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: c.onSurfaceVariant,
                    ),
                  ),
                  const LinearProgressIndicator(value: 0),
                  const Text('未提供 / 未提供 token', style: TextStyle(fontSize: 14)),
                ],
              ),
              _card(
                context,
                '生成速度 · 当前 / 最近请求',
                [
                  ('首次输出等待', duration(v?.firstOutputMs?.toInt())),
                  ('请求总耗时', duration(v?.durationMs?.toInt())),
                ],
                note: _timingNote,
                leading: [
                  const Text(
                    '未提供',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '暂无有效的流式计时数据',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.primary,
                    ),
                  ),
                  _note(context, _speedNote),
                  const Divider(height: 1),
                ],
              ),
              _card(context, '供应商用量 · token', rows, note: _usageNote),
              _card(
                context,
                '数据覆盖',
                coverage,
                note: _coverageNote,
                trailing: [
                  if (reported != null &&
                      requests != null &&
                      reported < requests)
                    Text(
                      '部分请求未提供用量，累计数值不代表完整消耗。',
                      style: TextStyle(fontSize: 12, color: c.tertiary),
                    ),
                ],
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
    List<Widget> leading = const [],
    List<Widget> trailing = const [],
  }) => Card(
    margin: const EdgeInsets.only(top: 16),
    elevation: 0,
    color: Theme.of(context).colorScheme.surfaceContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          for (final child in leading)
            Padding(padding: const EdgeInsets.only(top: 10), child: child),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(14) / 14 > 1.3;
                  final label = Text(
                    row.$1,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                  final value = Text(
                    row.$2,
                    textAlign: stacked ? TextAlign.start : TextAlign.end,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: row.$1 == '总用量'
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                  return stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [label, const SizedBox(height: 4), value],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: label),
                            const SizedBox(width: 12),
                            Expanded(child: value),
                          ],
                        );
                },
              ),
            ),
          for (final child in trailing)
            Padding(padding: const EdgeInsets.only(top: 10), child: child),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _note(context, note),
            ),
        ],
      ),
    ),
  );

  Widget _note(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
