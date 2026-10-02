import 'package:flutter/material.dart';

import 'usage_presentation.dart';

class UsagePricingDialog extends StatefulWidget {
  const UsagePricingDialog({required this.model, super.key});
  final ModelUsagePresentation model;
  @override
  State<UsagePricingDialog> createState() => _UsagePricingDialogState();
}

class _UsagePricingDialogState extends State<UsagePricingDialog> {
  late var billing = widget.model.billing;
  late final input = TextEditingController(
    text: usageEditablePrice(widget.model.inputPriceCny),
  );
  late final output = TextEditingController(
    text: usageEditablePrice(widget.model.outputPriceCny),
  );
  late final cached = TextEditingController(
    text: usageEditablePrice(widget.model.cachedPriceCny),
  );
  late final request = TextEditingController(
    text: usageEditablePrice(widget.model.requestPriceCny),
  );
  @override
  void dispose() {
    for (final controller in [input, output, cached, request]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool valid(TextEditingController c) {
    final value = double.tryParse(c.text);
    return value != null && value.isFinite && value >= 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget field(TextEditingController controller, String name) => TextField(
      controller: controller,
      key: ValueKey(name),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: name,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    return AlertDialog(
      title: Text('编辑模型定价 - ${widget.model.name}'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '当前计价币种：CNY',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const Text(
              '计费方式',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in UsageBillingMode.values)
                  FilterChip(
                    showCheckmark: false,
                    selected: billing == mode,
                    onSelected: (_) => setState(() => billing = mode),
                    label: Text(
                      mode == UsageBillingMode.token ? '按Token计费' : '按次计费',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              billing == UsageBillingMode.token
                  ? '设置每百万Token价格（CNY）'
                  : '设置每次API请求价格（CNY）',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (billing == UsageBillingMode.token) ...[
              field(input, '输入价格（每百万Token） (CNY)'),
              const SizedBox(height: 16),
              field(cached, '缓存输入价格（每百万Token） (CNY)'),
              const SizedBox(height: 16),
              field(output, '输出价格（每百万Token） (CNY)'),
            ] else
              field(request, '单次请求价格（CNY）'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([input, output, cached, request]),
          builder: (context, _) => TextButton(
            onPressed:
                (billing == UsageBillingMode.token
                    ? [input, output, cached].every(valid)
                    : valid(request))
                ? () {}
                : null,
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }
}
