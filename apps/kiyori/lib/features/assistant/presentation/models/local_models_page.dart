import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'local_model_presentation.dart';

class LocalModelsPage extends StatefulWidget {
  const LocalModelsPage({
    this.snapshot = const LocalModelsPresentation(),
    this.onRefresh,
    this.onDownload,
    this.onPause,
    this.onDelete,
    super.key,
  });
  final LocalModelsPresentation snapshot;
  final VoidCallback? onRefresh;
  final void Function(String)? onDownload, onPause, onDelete;
  @override
  State<LocalModelsPage> createState() => _LocalModelsPageState();
}

class _LocalModelsPageState extends State<LocalModelsPage> {
  final search = TextEditingController();
  List<LocalModelPresentation> filtered = [];
  DialogRoute<void>? _deleteRoute;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _filter();
    search.addListener(_search);
  }

  void _filter() {
    final query = search.text.toLowerCase().trim();
    filtered = widget.snapshot.models
        .where(
          (model) =>
              query.isEmpty ||
              [
                model.name,
                model.description,
                ...model.tags,
              ].any((text) => text.toLowerCase().contains(query)),
        )
        .toList();
  }

  void _search() => setState(_filter);
  @override
  void didUpdateWidget(covariant LocalModelsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _filter();
    if (_deletingId != null &&
        !widget.snapshot.models.any(
          (model) => model.id == _deletingId && model.canDelete,
        )) {
      _removeDelete();
    }
  }

  void _removeDelete() {
    final route = _deleteRoute;
    _deleteRoute = null;
    _deletingId = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _delete(LocalModelPresentation model) {
    if (_deleteRoute != null) return;
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => SettingsTheme(
        child: AlertDialog(
          title: const Text('删除模型'),
          content: const Text('确认删除此模型吗？'),
          scrollable: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onDelete?.call(model.id);
              },
              child: const Text('删除'),
            ),
          ],
        ),
      ),
    );
    _deleteRoute = route;
    _deletingId = model.id;
    unawaited(
      Navigator.of(context).push(route).whenComplete(() {
        if (identical(_deleteRoute, route)) {
          _deleteRoute = null;
          _deletingId = null;
        }
      }),
    );
  }

  @override
  void dispose() {
    _removeDelete();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '本地模型下载',
    onBack: () => Navigator.maybePop(context),
    headerAction: IconButton(
      onPressed: widget.snapshot.loading
          ? null
          : widget.onRefresh ?? emptyAction,
      tooltip: '刷新模型列表',
      icon: const Icon(Icons.refresh_outlined),
    ),
    body: Builder(
      builder: (context) {
        if (widget.snapshot.loading) {
          return const _ModelStatus(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('加载模型列表中...'),
            ],
          );
        }
        if (widget.snapshot.error) {
          return _ModelStatus(
            children: [
              Icon(
                Icons.error,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              const Text(
                '加载失败',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const Text('加载失败'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onRefresh ?? emptyAction,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          );
        }
        if (widget.snapshot.models.isEmpty) {
          return const _ModelStatus(children: [Text('暂无可用的本地模型')]);
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: KiyoriSearchField(
                controller: search,
                hint: '搜索模型...',
                showSearchIcon: true,
                showClear: true,
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _ModelStatus(
                      children: [
                        Icon(Icons.search_off, size: 64),
                        SizedBox(height: 16),
                        Text('没有找到匹配的模型'),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, index) => _ModelCard(
                        key: ValueKey(filtered[index].id),
                        model: filtered[index],
                        onDelete: () => _delete(filtered[index]),
                        onDownload: () =>
                            widget.onDownload?.call(filtered[index].id),
                        onPause: () => widget.onPause?.call(filtered[index].id),
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class _ModelStatus extends StatelessWidget {
  const _ModelStatus({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.onDelete,
    required this.onDownload,
    required this.onPause,
    super.key,
  });
  final LocalModelPresentation model;
  final VoidCallback onDelete;
  final VoidCallback onDownload, onPause;
  Widget _button(
    BuildContext context,
    String title,
    IconData icon, {
    bool enabled = true,
    double fontSize = 12,
  }) => FilledButton.icon(
    onPressed: enabled ? onDownload : null,
    icon: Icon(icon, size: 16),
    label: Text(title),
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      textStyle: Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontSize: fontSize),
    ),
  );
  Widget _delete(BuildContext context) => SizedBox(
    width: 40,
    height: 40,
    child: IconButton(
      onPressed: model.canDelete ? onDelete : null,
      tooltip: '删除模型',
      icon: Icon(
        Icons.delete_outline,
        size: 18,
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = model.boundedProgress;
    return Material(
      color: PrimaryColors.of(context).card,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    model.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (model.tags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      children: [
                        for (final tag in model.tags.take(2))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(
                                alpha: .7,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '模型大小: ${model.sizeGb.toStringAsFixed(2)} GB',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
            if (model.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                model.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurfaceVariant.withValues(alpha: .8),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (model.phase == LocalModelPhase.connecting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('正在连接...', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              )
            else if (model.phase == LocalModelPhase.downloading ||
                model.phase == LocalModelPhase.paused) ...[
              LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 6),
              if (model.phase == LocalModelPhase.downloading)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (model.totalFiles > 1)
                            Text(
                              '${model.currentFileIndex}/${model.totalFiles} · ${model.currentFile}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          Text(
                            '${(progress * 100).toInt()}% · ${model.transferred}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            model.speed,
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        onPressed: onPause,
                        tooltip: '暂停下载',
                        icon: const Icon(Icons.pause, size: 18),
                      ),
                    ),
                  ],
                ),
              if (model.phase == LocalModelPhase.paused)
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '进度: ${(progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 11),
                    ),
                    _button(context, '继续下载', Icons.play_arrow, fontSize: 11),
                    _delete(context),
                  ],
                ),
            ] else if (model.phase == LocalModelPhase.failed)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '下载失败: ${model.error}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.error),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _button(context, '重试', Icons.refresh, fontSize: 11),
                ],
              )
            else if (model.downloaded)
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: IconTone.success.iconFor(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '下载完成',
                      style: TextStyle(fontSize: 12, color: colors.primary),
                    ),
                  ),
                  _delete(context),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: _button(
                  context,
                  '开始下载',
                  Icons.download_outlined,
                  enabled: model.hasSource,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
