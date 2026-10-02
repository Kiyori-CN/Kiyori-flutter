import 'dart:async';

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
  final _routes = <DialogRoute<void>, String?>{};
  late final catalog = ValueNotifier(widget.snapshot.models);
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
    if (oldWidget.snapshot.exchangeRate != widget.snapshot.exchangeRate) {
      rate.text = widget.snapshot.exchangeRate.toString();
    }
    final names = widget.snapshot.models.map((model) => model.name).toSet();
    _removeRoutes(
      _routes.entries
          .where((entry) => entry.value != null && !names.contains(entry.value))
          .map((entry) => entry.key),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) catalog.value = widget.snapshot.models;
    });
  }

  void _removeRoutes(Iterable<DialogRoute<void>> values) {
    final routes = values.toList();
    if (routes.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _show(
    BuildContext context,
    WidgetBuilder builder, {
    String? model,
  }) async {
    if (_routes.isNotEmpty) return;
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => SettingsTheme(child: builder(context)),
    );
    _routes[route] = model;
    try {
      await Navigator.of(context).push(route);
    } finally {
      _routes.remove(route);
    }
  }

  void _edit(BuildContext context, ModelUsagePresentation model) => unawaited(
    _show(
      context,
      (_) => ValueListenableBuilder(
        valueListenable: catalog,
        builder: (_, values, _) => UsagePricingDialog(
          model:
              values.where((value) => value.name == model.name).firstOrNull ??
              model,
        ),
      ),
      model: model.name,
    ),
  );

  @override
  void dispose() {
    _removeRoutes(_routes.keys);
    WidgetsBinding.instance.addPostFrameCallback((_) => catalog.dispose());
    rate.dispose();
    super.dispose();
  }

  Future<void> reset(BuildContext context, [String? model]) => _show(
    context,
    (context) => AlertDialog(
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
    model: model,
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
                onEdit: () => _edit(context, model),
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
