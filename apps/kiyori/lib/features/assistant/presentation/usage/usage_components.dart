import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'usage_presentation.dart';

class UsageCard extends StatelessWidget {
  const UsageCard({required this.child, this.onTap, super.key});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

class UsageLine extends StatelessWidget {
  const UsageLine(this.label, this.value, {this.color, super.key});
  final String label, value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    ],
  );
}

class UsageSummary extends StatelessWidget {
  const UsageSummary(this.snapshot, {super.key});
  final UsagePresentation snapshot;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget stat(String label, String value, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
      ],
    );
    return UsageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '使用统计',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <
                  MediaQuery.textScalerOf(context).scale(280)) {
                return Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    stat(
                      '总Token数',
                      '${snapshot.input + snapshot.output}',
                      CrossAxisAlignment.start,
                    ),
                    stat(
                      '总请求次数',
                      '${snapshot.requests}',
                      CrossAxisAlignment.start,
                    ),
                    stat(
                      '总费用',
                      usageMoney(snapshot.costCny),
                      CrossAxisAlignment.start,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: stat(
                      '总Token数',
                      '${snapshot.input + snapshot.output}',
                      CrossAxisAlignment.start,
                    ),
                  ),
                  Expanded(
                    child: stat(
                      '总请求次数',
                      '${snapshot.requests}',
                      CrossAxisAlignment.center,
                    ),
                  ),
                  Expanded(
                    child: stat(
                      '总费用',
                      usageMoney(snapshot.costCny),
                      CrossAxisAlignment.end,
                    ),
                  ),
                ],
              );
            },
          ),
          if (snapshot.hasUsdCost) ...[
            const SizedBox(height: 8),
            Text(
              '总费用按 1 USD = ${snapshot.exchangeRate.toStringAsFixed(4)} CNY 折算',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          UsageLine('对话', '${snapshot.chats}'),
          UsageLine('消息', '${snapshot.messages}'),
          const SizedBox(height: 12),
          UsageLine('输入Token', '${snapshot.input}'),
          const SizedBox(height: 4),
          UsageLine('输出Token', '${snapshot.output}'),
          if (snapshot.cached > 0) ...[
            const SizedBox(height: 4),
            UsageLine('缓存Token', '${snapshot.cached}', color: colors.tertiary),
          ],
        ],
      ),
    );
  }
}

class UsageModelCard extends StatelessWidget {
  const UsageModelCard({
    required this.model,
    required this.onEdit,
    required this.onReset,
    super.key,
  });
  final ModelUsagePresentation model;
  final VoidCallback onEdit, onReset;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final token = model.billing == UsageBillingMode.token;
    Widget small(String value, {Color? color}) => Text(
      value,
      style: TextStyle(fontSize: 12, color: color ?? colors.onSurfaceVariant),
    );
    Widget metric(
      String title,
      String value,
      List<Widget> detail,
      CrossAxisAlignment alignment,
    ) => Column(
      crossAxisAlignment: alignment,
      children: [
        small(title),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: title == '总费用' ? colors.primary : colors.onSurface,
          ),
        ),
        ...detail,
      ],
    );
    return UsageCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: token
                            ? colors.secondaryContainer
                            : colors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        token ? '按Token计费' : '按次计费',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '重置该模型',
                onPressed: onReset,
                icon: Icon(Icons.restart_alt, size: 18, color: colors.error),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          UsageLine('请求次数', '${model.requests}'),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth <
                  MediaQuery.textScalerOf(context).scale(290);
              final stats = [
                metric('输入Token', '${model.input}', [
                  if (model.cached > 0)
                    small('(缓存: ${model.cached})', color: colors.tertiary),
                  if (token) small('${usageMoney(model.inputPriceCny)}/1M'),
                ], CrossAxisAlignment.start),
                metric(
                  '输出Token',
                  '${model.output}',
                  [if (token) small('${usageMoney(model.outputPriceCny)}/1M')],
                  compact
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                ),
                metric('总费用', usageMoney(model.costCny), [
                  if (!token)
                    small('每次 ¥${model.requestPriceCny.toStringAsFixed(4)}'),
                ], compact ? CrossAxisAlignment.start : CrossAxisAlignment.end),
              ];
              return compact
                  ? Wrap(spacing: 20, runSpacing: 12, children: stats)
                  : Row(
                      children: [
                        for (final stat in stats) Expanded(child: stat),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class UsageDistribution extends StatelessWidget {
  const UsageDistribution(this.models, {super.key});
  final List<ModelUsagePresentation> models;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
    ];
    final total = models.fold<int>(
      0,
      (sum, model) => sum + model.input + model.output,
    );
    final pie = SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(painter: _UsagePie(models, colors, total)),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < math.min(8, models.length); i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i < math.min(8, models.length) - 1 ? 8 : 0,
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  color: colors[i % colors.length],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    models[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${((models[i].input + models[i].output) / total * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '模型使用分布',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        UsageCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 保留180px饼图，窄屏或大字时将图例移到下方，完整图例不挤出卡片。
              if (constraints.maxWidth <
                  180 + 16 + MediaQuery.textScalerOf(context).scale(100)) {
                return Column(
                  children: [pie, const SizedBox(height: 16), legend],
                );
              }
              return SizedBox(
                height: math.max(
                  188,
                  MediaQuery.textScalerOf(context).scale(16) *
                          math.min(8, models.length) +
                      math.max(0, math.min(8, models.length) - 1) * 8,
                ),
                child: Row(
                  children: [
                    pie,
                    const SizedBox(width: 16),
                    Expanded(child: legend),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UsagePie extends CustomPainter {
  const _UsagePie(this.models, this.colors, this.total);
  final List<ModelUsagePresentation> models;
  final List<Color> colors;
  final int total;
  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    var start = -math.pi / 2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2,
    );
    for (var i = 0; i < models.length; i++) {
      final angle = (models[i].input + models[i].output) / total * math.pi * 2;
      if (angle <= 0) continue;
      canvas.drawArc(
        rect,
        start,
        angle,
        true,
        Paint()..color = colors[i % colors.length],
      );
      start += angle;
    }
  }

  @override
  bool shouldRepaint(_UsagePie oldDelegate) =>
      oldDelegate.models != models ||
      oldDelegate.colors != colors ||
      oldDelegate.total != total;
}
