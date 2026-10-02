import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

part 'context_summary_fields.dart';

/// 旧模型默认值的 UI 快照；不初始化或写入模型配置。
class ContextSummaryPresentation {
  const ContextSummaryPresentation({
    this.configName = '默认配置',
    this.contextLength = '64',
    this.maxContextLength = '200',
    this.enableSummary = true,
    this.threshold = '0.7',
    this.byMessageCount = true,
    this.messageCount = '16',
    this.rules = '',
    this.imageTurns = '2',
    this.mediaTurns = '1',
  });
  final String configName, contextLength, maxContextLength, threshold;
  final String messageCount, rules, imageTurns, mediaTurns;
  final bool enableSummary, byMessageCount;
}

class ContextSummaryPage extends StatefulWidget {
  const ContextSummaryPage({
    this.snapshot = const ContextSummaryPresentation(),
    super.key,
  });
  final ContextSummaryPresentation snapshot;
  @override
  State<ContextSummaryPage> createState() => _ContextSummaryPageState();
}

class _ContextSummaryPageState extends State<ContextSummaryPage> {
  late final length = TextEditingController(
    text: widget.snapshot.contextLength,
  );
  late final maximum = TextEditingController(
    text: widget.snapshot.maxContextLength,
  );
  late final threshold = TextEditingController(text: widget.snapshot.threshold);
  late final count = TextEditingController(text: widget.snapshot.messageCount);
  late final rules = TextEditingController(text: widget.snapshot.rules);
  late final images = TextEditingController(text: widget.snapshot.imageTurns);
  late final media = TextEditingController(text: widget.snapshot.mediaTurns);
  late bool summary = widget.snapshot.enableSummary;
  late bool byCount = widget.snapshot.byMessageCount;
  final contextError = ValueNotifier<String?>(null);
  final summaryError = ValueNotifier<String?>(null);

  @override
  void dispose() {
    for (final controller in [
      length,
      maximum,
      threshold,
      count,
      rules,
      images,
      media,
    ]) {
      controller.dispose();
    }
    contextError.dispose();
    summaryError.dispose();
    super.dispose();
  }

  void validateContext() {
    final a = double.tryParse(length.text), b = double.tryParse(maximum.text);
    contextError.value = a == null || !a.isFinite || a <= 0
        ? '请输入有效的上下文长度'
        : b == null || !b.isFinite || b <= 0
        ? '请输入有效的最大上下文长度'
        : null;
  }

  void validateSummary() {
    final value = double.tryParse(threshold.text);
    final messages = int.tryParse(count.text);
    summaryError.value = !summary
        ? null
        : value == null || !value.isFinite || value <= 0 || value >= 1
        ? '请输入0-1之间的总结触发阈值'
        : byCount && (messages == null || messages <= 0)
        ? '请输入有效的消息数量阈值'
        : null;
  }

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '上下文与总结',
    onBack: () => Navigator.of(context).maybePop(),
    body: SingleChildScrollView(
      key: const PageStorageKey('context-summary'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ContextBanner(
            '文件读取限制与文本结果截断已改为固定系统常量。此页可直接调整当前绑定模型配置的上下文与总结参数，以及历史图片和音视频保留回合数。',
          ),
          const SizedBox(height: 12),
          const _ContextTitle('模型配置', Icons.link, IconTone.link),
          _ContextSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前绑定模型配置：${widget.snapshot.configName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PrimaryColors.accent,
                  ),
                ),
                const SizedBox(height: 2),
                const _ContextDescription('此页面的上下文与总结设置会直接写回当前对话绑定的模型配置。'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _ContextTitle('上下文设置', Icons.analytics, IconTone.automation),
          const _ContextBanner(
            '· 上下文长度: 建议设为您日常使用的最大值。\n· 最大上下文长度: 建议设为模型API支持的最大值。\n软件会在上下文达到阈值时自动压缩，以防超限。请注意，上下文并非越大越好，需用户与软件协同配合。',
          ),
          _ContextNumber(
            '上下文长度',
            '模型记忆对话长度(k tokens)',
            length,
            decimal: true,
            unit: 'K',
            onChanged: validateContext,
          ),
          _ContextNumber(
            '最大上下文长度',
            '模型API支持的最大上下文长度(k tokens)',
            maximum,
            decimal: true,
            unit: 'K',
            onChanged: validateContext,
          ),
          _ContextError(contextError),
          const SizedBox(height: 8),
          const _ContextTitle('总结设置', Icons.summarize, IconTone.neutral),
          _ContextSwitch(
            '启用对话总结',
            '当上下文过长时自动生成对话总结，节省Token消耗',
            summary,
            onChanged: (value) => setState(() {
              summary = value;
              validateSummary();
            }),
          ),
          _ContextNumber(
            '上下文使用比例阈值',
            '当上下文使用超过此比例时触发总结(0.1-0.95)',
            threshold,
            decimal: true,
            enabled: summary,
            onChanged: validateSummary,
          ),
          _ContextSwitch(
            '按消息条数触发总结',
            '当新消息数量达到阈值时触发总结',
            byCount,
            enabled: summary,
            onChanged: (value) => setState(() {
              byCount = value;
              validateSummary();
            }),
          ),
          _ContextNumber(
            '消息条数阈值',
            '触发总结的新消息数量(1-20条)',
            count,
            unit: '条',
            enabled: summary && byCount,
            onChanged: validateSummary,
          ),
          _ContextError(summaryError),
          const SizedBox(height: 8),
          _ContextSurface(
            child: Opacity(
              opacity: summary ? 1 : .38,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '自定义总结规则',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const _ContextDescription('总结对话时发送的额外规则，留空为不添加'),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(minHeight: 80),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextField(
                      key: const ValueKey('summary-rules'),
                      controller: rules,
                      enabled: summary,
                      maxLines: null,
                      style: const TextStyle(
                        fontSize: 13,
                        color: PrimaryColors.accent,
                      ),
                      decoration: InputDecoration(
                        hintText: '总结对话时发送的额外规则，留空为不添加',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: PrimaryColors.secondary.withValues(alpha: .5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _ContextTitle('历史媒体保留设置', Icons.history, IconTone.browser),
          _ContextNumber(
            '历史图片保留回合数',
            '仅保留最近 N 次用户对话中的图片，避免历史图片重复发送',
            images,
            unit: '次',
          ),
          _ContextNumber(
            '历史音视频保留回合数',
            '仅保留最近 N 次用户对话中的音频/视频，避免历史音视频重复发送',
            media,
            unit: '次',
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('恢复历史媒体默认值？'),
                scrollable: true,
                content: const Text(
                  '仅恢复历史图片、音频和视频的保留回合数；上下文窗口、总结开关和自定义规则不会改变。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      images.text = '2';
                      media.text = '1';
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      '恢复默认',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restart_alt, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text('恢复历史媒体默认值', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
