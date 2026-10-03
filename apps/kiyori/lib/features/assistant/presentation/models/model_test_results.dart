import 'package:flutter/material.dart';

import 'model_connection_test.dart';

class ModelTestResults extends StatelessWidget {
  const ModelTestResults(this.test, {super.key});
  final ModelConnectionTest test;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = test.results;
    if (items == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (test.model.isNotEmpty) ...[
            Text(
              '测试模型：${test.model}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final color = switch (item.outcome) {
                  ModelTestOutcome.passed => colors.primary,
                  ModelTestOutcome.unverified => colors.tertiary,
                  ModelTestOutcome.failed => colors.error,
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          switch (item.outcome) {
                            ModelTestOutcome.passed => Icons.check_circle,
                            ModelTestOutcome.unverified => Icons.info,
                            ModelTestOutcome.failed => Icons.warning,
                          },
                          size: 18,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
