part of 'function_models_page.dart';

class _FunctionModelCard extends StatefulWidget {
  const _FunctionModelCard({
    required this.function,
    required this.current,
    required this.modelIndex,
    required this.available,
    required this.onSelected,
    this.result,
    super.key,
  });
  final AssistantFunction function;
  final ModelConfigPresentation? current;
  final int modelIndex;
  final List<ModelConfigPresentation> available;
  final ValueChanged<FunctionModelSelection> onSelected;
  final FunctionTestPresentation? result;
  @override
  State<_FunctionModelCard> createState() => _FunctionModelCardState();
}

class _FunctionModelCardState extends State<_FunctionModelCard>
    with AutomaticKeepAliveClientMixin {
  bool expanded = false, fullStatus = false;
  String? expandedId;
  @override
  bool get wantKeepAlive => expanded || fullStatus;
  @override
  void didUpdateWidget(_FunctionModelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result?.message != widget.result?.message) {
      fullStatus = false;
    }
    if (!widget.available.any((config) => config.id == expandedId)) {
      expandedId = null;
    }
    updateKeepAlive();
  }

  String model(ModelConfigPresentation config, int index) =>
      config.models.isEmpty
      ? ''
      : config.models[index >= 0 && index < config.models.length ? index : 0];
  void choose(ModelConfigPresentation config, int index) {
    if (widget.function == AssistantFunction.chat &&
        model(config, index).toLowerCase().contains('autoglm')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '禁止使用autoglm作为对话主模型。对话模型和ui控制模型是分离的，请选择任意一个别的聪明的大模型。如有疑问，请仔细阅读文档学习软件的模型配置机制。',
          ),
        ),
      );
      return;
    }
    widget.onSelected(FunctionModelSelection(config.id, index));
    setState(() {
      expanded = false;
      expandedId = null;
    });
    updateKeepAlive();
  }

  String? get warning => switch (widget.function) {
    AssistantFunction.image when widget.current?.image == false =>
      '警告：当前所选模型未启用“支持识图”，图片识别可能不可用。请更换支持视觉的模型并开启“模型支持识图”。',
    AssistantFunction.audio when widget.current?.audio == false =>
      '警告：当前所选模型未启用“支持音频解析”，音频识别/转写可能不可用。请更换支持音频输入/转写的模型并开启“模型支持音频解析”。',
    AssistantFunction.video when widget.current?.video == false =>
      '警告：当前所选模型未启用“支持视频解析”，视频理解可能不可用。请更换支持视频/图像输入的模型并开启“模型支持视频解析”。',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    final result = widget.result;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          width: .5,
          color: colors.outlineVariant.withValues(alpha: .5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.function.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.function.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: PrimaryColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: colors.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: ValueKey('function-expand-${widget.function.name}'),
                    onTap: () {
                      setState(() => expanded = !expanded);
                      updateKeepAlive();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final description = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '当前配置: ${widget.current?.name ?? '默认配置'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (widget.current != null)
                                Text(
                                  '模型: ${model(widget.current!, widget.modelIndex)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: PrimaryColors.secondary,
                                  ),
                                ),
                              if (warning != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        size: 16,
                                        color: colors.error,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          warning!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (result != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Builder(
                                    builder: (context) {
                                      final color = switch (result.outcome) {
                                        FunctionTestOutcome.passed =>
                                          colors.primary,
                                        FunctionTestOutcome.unverified =>
                                          colors.tertiary,
                                        FunctionTestOutcome.failed =>
                                          colors.error,
                                      };
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            switch (result.outcome) {
                                              FunctionTestOutcome.passed =>
                                                Icons.check_circle,
                                              FunctionTestOutcome.unverified =>
                                                Icons.info,
                                              FunctionTestOutcome.failed =>
                                                Icons.warning,
                                            },
                                            size: 16,
                                            color: color,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: _FunctionStatus(
                                              message: result.message,
                                              color: color,
                                              expanded: fullStatus,
                                              onToggle: () {
                                                setState(
                                                  () =>
                                                      fullStatus = !fullStatus,
                                                );
                                                updateKeepAlive();
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                            ],
                          );
                          final actions = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: emptyAction,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.dns, size: 16),
                                    SizedBox(width: 4),
                                    Text('测试', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                expanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: colors.onSurfaceVariant,
                              ),
                            ],
                          );
                          if (constraints.maxWidth < 280 &&
                              MediaQuery.textScalerOf(context).scale(14) > 18) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                description,
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: actions,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: description),
                              actions,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '选择配置',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        for (final config in widget.available)
                          _config(context, config),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: .5,
              thickness: .5,
              color: colors.outlineVariant.withValues(alpha: .3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _config(BuildContext context, ModelConfigPresentation config) {
    final colors = Theme.of(context).colorScheme;
    final selected = config.id == (widget.current?.id ?? 'default');
    final multiple = config.models.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: selected ? colors.primaryContainer : colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: selected
                  ? BorderSide.none
                  : BorderSide(
                      width: .5,
                      color: colors.outlineVariant.withValues(alpha: .5),
                    ),
            ),
            child: InkWell(
              key: ValueKey(
                'function-config-${widget.function.name}-${config.id}',
              ),
              onTap: () => multiple
                  ? setState(
                      () => expandedId = expandedId == config.id
                          ? null
                          : config.id,
                    )
                  : choose(config, 0),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (selected && !multiple) ...[
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: PrimaryColors.accent,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selected
                                  ? colors.primary
                                  : colors.onSurface,
                            ),
                          ),
                          Text(
                            multiple
                                ? '${config.models.length}个模型'
                                : model(config, 0),
                            style: const TextStyle(
                              fontSize: 12,
                              color: PrimaryColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (multiple)
                      Icon(
                        expandedId == config.id
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (multiple && expandedId == config.id)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Column(
              children: [
                for (var i = 0; i < config.models.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Material(
                      color:
                          selected &&
                              model(config, widget.modelIndex) ==
                                  config.models[i]
                          ? colors.primary.withValues(alpha: .15)
                          : colors.surfaceContainerHighest.withValues(
                              alpha: .5,
                            ),
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        key: ValueKey(
                          'function-model-${widget.function.name}-${config.id}-$i',
                        ),
                        onTap: () => choose(config, i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              if (selected &&
                                  model(config, widget.modelIndex) ==
                                      config.models[i]) ...[
                                const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: PrimaryColors.accent,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  config.models[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        selected &&
                                            model(config, widget.modelIndex) ==
                                                config.models[i]
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color:
                                        selected &&
                                            model(config, widget.modelIndex) ==
                                                config.models[i]
                                        ? colors.primary
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FunctionStatus extends StatelessWidget {
  const _FunctionStatus({
    required this.message,
    required this.color,
    required this.expanded,
    required this.onToggle,
  });
  final String message;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = TextStyle(fontSize: 12, color: color);
      final painter = TextPainter(
        text: TextSpan(text: message, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflow = painter.didExceedMaxLines;
      painter.dispose();
      return Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: expanded ? null : 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (overflow || expanded)
            SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                tooltip: expanded ? '收起' : '展开',
                padding: EdgeInsets.zero,
                onPressed: onToggle,
                icon: Icon(Icons.more_horiz, size: 18, color: color),
              ),
            ),
        ],
      );
    },
  );
}
