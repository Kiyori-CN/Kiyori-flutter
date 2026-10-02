import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'usage_components.dart';
import 'usage_presentation.dart';
import 'usage_pricing_dialog.dart';

class UsagePage extends StatefulWidget {
  const UsagePage({this.snapshot = const UsagePresentation(), super.key});
  final UsagePresentation snapshot;
  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  late final rate = TextEditingController(
    text: widget.snapshot.exchangeRate.toString(),
  );
  late List<ModelUsagePresentation> models = sortedModels();
  late List<ModelUsagePresentation> distribution = sortedDistribution();
  List<ModelUsagePresentation> sortedModels() =>
      List.of(widget.snapshot.models)..sort((a, b) => a.name.compareTo(b.name));
  List<ModelUsagePresentation> sortedDistribution() =>
      widget.snapshot.models
          .where((model) => model.input + model.output > 0)
          .toList()
        ..sort((a, b) => (b.input + b.output).compareTo(a.input + a.output));
  @override
  void didUpdateWidget(UsagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      models = sortedModels();
      distribution = sortedDistribution();
    }
  }

  @override
  void dispose() {
    rate.dispose();
    super.dispose();
  }

  Future<void> reset(BuildContext context, [String? model]) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(model == null ? '重置确认' : '重置模型确认'),
      content: Text(
        model == null
            ? '这将清除所有Token使用记录，此操作不可恢复。'
            : '这将清除 $model 的Token和请求次数统计，此操作不可恢复。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('重置'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: 'AI 用量与费用',
    onBack: () => Navigator.of(context).maybePop(),
    headerAction: Builder(
      builder: (context) => IconButton(
        tooltip: '重置所有计数',
        onPressed: () => reset(context),
        icon: Icon(
          Icons.restart_alt,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    ),
    body: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final intro = [
          UsageSummary(widget.snapshot),
          if (distribution.isNotEmpty) UsageDistribution(distribution),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              const Text(
                '模型详情',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '点击编辑定价和计费方式',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ];
        final modelCount = models.isEmpty ? 1 : models.length;
        return ListView.separated(
          key: const PageStorageKey('usage'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: intro.length + modelCount + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index < intro.length) return intro[index];
            if (index < intro.length + modelCount) {
              if (models.isEmpty) {
                return UsageCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.analytics,
                          size: 48,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无功能模块的Token使用记录。',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final model = models[index - intro.length];
              return UsageModelCard(
                key: ValueKey('usage-${model.name}'),
                model: model,
                onReset: () => reset(context, model.name),
                onEdit: () => showDialog<void>(
                  context: context,
                  builder: (_) => UsagePricingDialog(model: model),
                ),
              );
            }
            return UsageCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '汇率设置',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '美元计费模型会按此汇率折算为人民币总费用',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('usage-rate'),
                    controller: rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'USD → CNY 汇率',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
