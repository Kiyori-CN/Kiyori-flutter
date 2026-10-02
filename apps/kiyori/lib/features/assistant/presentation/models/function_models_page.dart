import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'function_model_presentation.dart';

part 'function_model_card.dart';

class FunctionModelsPage extends StatefulWidget {
  const FunctionModelsPage({
    this.snapshot = const FunctionModelsPresentation(),
    this.onManage = emptyAction,
    super.key,
  });
  final FunctionModelsPresentation snapshot;
  final VoidCallback onManage;
  @override
  State<FunctionModelsPage> createState() => _FunctionModelsPageState();
}

class _FunctionModelsPageState extends State<FunctionModelsPage> {
  late final selections = Map<AssistantFunction, FunctionModelSelection>.of(
    widget.snapshot.selections,
  );
  late Map<String, ModelConfigPresentation> configs = {
    for (final config in widget.snapshot.configs) config.id: config,
  };
  @override
  void didUpdateWidget(FunctionModelsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      configs = {
        for (final config in widget.snapshot.configs) config.id: config,
      };
      selections.removeWhere(
        (_, selection) => !configs.containsKey(selection.configId),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '功能模型分配',
    onBack: () => Navigator.of(context).maybePop(),
    body: switch (widget.snapshot.loading) {
      FunctionModelLoadState.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      FunctionModelLoadState.failed => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              const Text('功能模型配置加载失败', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
      FunctionModelLoadState.ready => ListView.builder(
        key: const PageStorageKey('function-models'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: AssistantFunction.values.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: 24,
                            color: PrimaryColors.of(context).accent,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '功能模型配置设置',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '为不同功能设置单独的模型配置，使每个功能都能使用最适合的API设置。',
                        style: TextStyle(fontSize: 14),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outline
                              .withValues(alpha: .2),
                        ),
                      ),
                      InkWell(
                        onTap: widget.onManage,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '管理所有模型配置',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward,
                                color: PrimaryColors.of(context).accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (index == AssistantFunction.values.length + 1) {
            return OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('恢复全部功能模型分配？'),
                  scrollable: true,
                  content: const Text('所有功能将重新绑定到默认模型配置；当前各功能的自定义分配会被清除。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: emptyAction,
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
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重置所有功能至默认配置'),
            );
          }
          final function = AssistantFunction.values[index - 1];
          final selection =
              selections[function] ?? const FunctionModelSelection('default');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FunctionModelCard(
              key: ValueKey(function),
              function: function,
              current: configs[selection.configId],
              modelIndex: selection.modelIndex,
              available: widget.snapshot.configs,
              result: widget.snapshot.results[function],
              onSelected: (selection) =>
                  setState(() => selections[function] = selection),
            ),
          );
        },
      ),
    },
  );
}
