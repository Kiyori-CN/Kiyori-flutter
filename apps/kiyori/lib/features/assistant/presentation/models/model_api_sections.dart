import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'model_settings_components.dart';

class ModelApiContextCards extends StatefulWidget {
  const ModelApiContextCards({super.key});
  @override
  State<ModelApiContextCards> createState() => _ModelApiContextCardsState();
}

class _ModelApiContextCardsState extends State<ModelApiContextCards> {
  bool contextExpanded = false,
      summaryExpanded = false,
      summary = true,
      byCount = true;
  final length = TextEditingController(text: '64');
  final maximum = TextEditingController(text: '200');
  final threshold = TextEditingController(text: '0.7');
  final count = TextEditingController(text: '16');
  final contextError = ValueNotifier<String?>(null),
      summaryError = ValueNotifier<String?>(null);
  @override
  void dispose() {
    for (final controller in [length, maximum, threshold, count]) {
      controller.dispose();
    }
    contextError.dispose();
    summaryError.dispose();
    super.dispose();
  }

  void validateContext(String _) {
    final a = double.tryParse(length.text), b = double.tryParse(maximum.text);
    contextError.value = a == null || !a.isFinite || a <= 0
        ? '请输入有效的上下文长度'
        : b == null || !b.isFinite || b <= 0
        ? '请输入有效的最大上下文长度'
        : null;
  }

  void validateSummary([String? _]) {
    final t = double.tryParse(threshold.text), c = int.tryParse(count.text);
    summaryError.value = !summary
        ? null
        : t == null || !t.isFinite || t <= 0 || t >= 1
        ? '请输入0-1之间的总结触发阈值'
        : byCount && (c == null || c <= 0)
        ? '请输入有效的消息数量阈值'
        : null;
  }

  Widget error(ValueNotifier<String?> value) => ValueListenableBuilder(
    valueListenable: value,
    builder: (context, text, _) => text == null
        ? const SizedBox.shrink()
        : Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ModelSettingsCard(
        children: [
          ModelSettingsExpansion(
            '上下文设置',
            Icons.analytics,
            IconTone.automation,
            expanded: contextExpanded,
            onTap: () => setState(() => contextExpanded = !contextExpanded),
          ),
          if (contextExpanded) ...[
            const ModelSettingsBanner(
              '· 上下文长度: 建议设为您日常使用的最大值。\n· 最大上下文长度: 建议设为模型API支持的最大值。\n软件会在上下文达到阈值时自动压缩，以防超限。请注意，上下文并非越大越好，需用户与软件协同配合。',
            ),
            ModelSettingsField(
              '上下文长度',
              length,
              subtitle: '模型记忆对话长度(k tokens)',
              unit: 'K',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: validateContext,
            ),
            ModelSettingsField(
              '最大上下文长度',
              maximum,
              subtitle: '模型API支持的最大上下文长度(k tokens)',
              unit: 'K',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: validateContext,
            ),
            error(contextError),
          ],
        ],
      ),
      ModelSettingsCard(
        children: [
          ModelSettingsExpansion(
            '总结设置',
            Icons.summarize,
            IconTone.link,
            expanded: summaryExpanded,
            onTap: () => setState(() => summaryExpanded = !summaryExpanded),
          ),
          if (summaryExpanded) ...[
            ModelSettingsSwitch(
              '启用对话总结',
              '当上下文过长时自动生成对话总结，节省Token消耗',
              summary,
              onChanged: (value) {
                setState(() => summary = value);
                validateSummary();
              },
            ),
            ModelSettingsField(
              '上下文使用比例阈值',
              threshold,
              subtitle: '当上下文使用超过此比例时触发总结(0.1-0.95)',
              enabled: summary,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: validateSummary,
            ),
            ModelSettingsSwitch(
              '按消息条数触发总结',
              '当新消息数量达到阈值时触发总结',
              byCount,
              enabled: summary,
              onChanged: (value) {
                setState(() => byCount = value);
                validateSummary();
              },
            ),
            ModelSettingsField(
              '消息条数阈值',
              count,
              subtitle: '触发总结的新消息数量(1-20条)',
              unit: '条',
              enabled: summary && byCount,
              keyboardType: TextInputType.number,
              onChanged: validateSummary,
            ),
            error(summaryError),
          ],
        ],
      ),
    ],
  );
}

class ModelHeadersCard extends StatefulWidget {
  const ModelHeadersCard({super.key});
  @override
  State<ModelHeadersCard> createState() => _ModelHeadersCardState();
}

class _HeaderDraft {
  _HeaderDraft(String key, String value)
    : name = TextEditingController(text: key),
      value = TextEditingController(text: value);
  final TextEditingController name, value;
  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _ModelHeadersCardState extends State<ModelHeadersCard> {
  bool expanded = false;
  final headers = <_HeaderDraft>[];
  static const presets = <(String, Map<String, String>)>[
    (
      '伪装成安卓浏览器',
      {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
      },
    ),
    (
      '伪装成桌面浏览器 (Win)',
      {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36',
      },
    ),
    ('设置语言为中文', {'Accept-Language': 'zh-CN,zh;q=0.9'}),
    ('设置语言为英文', {'Accept-Language': 'en-US,en;q=0.9'}),
    ('模拟中国移动网关', {'X-Forwarded-For': '211.136.1.10', 'Via': 'CMNET'}),
    (
      '模拟美国洛杉矶 (需配合)',
      {'Accept-Language': 'en-US,en;q=0.9', 'X-Forwarded-For': '38.107.226.5'},
    ),
  ];
  void load(int index) => setState(() {
    for (final entry in presets[index].$2.entries) {
      final matches = headers.where((header) => header.name.text == entry.key);
      if (matches.isEmpty) {
        headers.add(_HeaderDraft(entry.key, entry.value));
      } else {
        matches.first.value.text = entry.value;
      }
    }
  });
  @override
  void dispose() {
    for (final header in headers) {
      header.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ModelSettingsCard(
    children: [
      ModelSettingsExpansion(
        '自定义请求头',
        Icons.list,
        IconTone.link,
        subtitle: 'API请求头字段配置',
        expanded: expanded,
        onTap: () => setState(() => expanded = !expanded),
      ),
      if (expanded) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PopupMenuButton<int>(
              tooltip: '加载预设',
              onSelected: load,
              itemBuilder: (_) => [
                for (var i = 0; i < presets.length; i++)
                  PopupMenuItem(value: i, child: Text(presets[i].$1)),
              ],
              child: const _HeaderAction(Icons.list, '加载预设'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => headers.add(_HeaderDraft('', ''))),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加请求头'),
            ),
          ],
        ),
        for (final header in headers)
          Row(
            key: ObjectKey(header),
            children: [
              Expanded(
                child: TextField(
                  controller: header.name,
                  decoration: const InputDecoration(
                    labelText: '键',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: header.value,
                  decoration: const InputDecoration(
                    labelText: '值',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: '删除请求头',
                onPressed: () {
                  setState(() => headers.remove(header));
                  // 输入子树先卸载，随后释放控制器，避免当前帧仍引用已释放监听器。
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => header.dispose(),
                  );
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
      ],
    ],
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(text)],
    ),
  );
}

class ModelAdvancedCard extends StatefulWidget {
  const ModelAdvancedCard({super.key});
  @override
  State<ModelAdvancedCard> createState() => _ModelAdvancedCardState();
}

class _ModelAdvancedCardState extends State<ModelAdvancedCard> {
  bool queue = false, pool = false;
  final limit = TextEditingController(text: '0'),
      concurrent = TextEditingController(text: '0');
  @override
  void dispose() {
    limit.dispose();
    concurrent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ModelSettingsCard(
    children: [
      const ModelSettingsHeading(
        '高级设置',
        Icons.settings_outlined,
        IconTone.link,
      ),
      Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: .35),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => queue = !queue),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '请求队列控制',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '默认折叠。用于限制请求频率和并发，超限会排队等待。',
                            style: TextStyle(
                              fontSize: 12,
                              color: PrimaryColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      queue
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: PrimaryColors.accent,
                    ),
                  ],
                ),
              ),
              if (queue) ...[
                const SizedBox(height: 12),
                ModelSettingsField(
                  '每分钟请求次数',
                  limit,
                  subtitle: '超过该阈值会进入排队等待。填 0 或留空表示不限流。',
                  keyboardType: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                ModelSettingsField(
                  '最大并发请求数',
                  concurrent,
                  subtitle: '超过该阈值会排队等待。填 0 或留空表示不限制。',
                  keyboardType: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ],
          ),
        ),
      ),
      InkWell(
        onTap: () => setState(() => pool = !pool),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('使用API密钥池', style: TextStyle(fontSize: 16)),
                    Text(
                      '启用后可管理多个API密钥，系统将自动轮换使用',
                      style: TextStyle(
                        fontSize: 12,
                        color: PrimaryColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: pool,
                onChanged: (value) => setState(() => pool = value),
              ),
            ],
          ),
        ),
      ),
      if (pool) ...[
        const Divider(height: 32),
        const Text(
          'API密钥池为空，点击下方按钮添加密钥',
          style: TextStyle(fontSize: 14, color: PrimaryColors.secondary),
        ),
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _PoolKeyDialog(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('添加API密钥'),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: () {}, child: const Text('批量导入密钥')),
            OutlinedButton(onPressed: () {}, child: const Text('导出密钥')),
          ],
        ),
        const Text(
          '请选择包含API密钥的文本文件，每行一个密钥',
          style: TextStyle(fontSize: 12, color: PrimaryColors.secondary),
        ),
      ],
    ],
  );
}

class _PoolKeyDialog extends StatefulWidget {
  const _PoolKeyDialog();
  @override
  State<_PoolKeyDialog> createState() => _PoolKeyDialogState();
}

class _PoolKeyDialogState extends State<_PoolKeyDialog> {
  final value = TextEditingController();
  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('添加API密钥'),
    content: TextField(
      controller: value,
      minLines: 1,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'API密钥',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      TextButton(onPressed: () {}, child: const Text('保存')),
    ],
  );
}
