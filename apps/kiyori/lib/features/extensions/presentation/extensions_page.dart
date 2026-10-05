import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'extension_import_dialog.dart';
import 'extensions_controller.dart';

/// 旧PackageManager宿主：先保留四标签与空动作，模型插件沿真实Rust包生命周期。
class ExtensionsPage extends StatefulWidget {
  const ExtensionsPage({
    required this.controller,
    required this.onMenu,
    this.picker,
    super.key,
  });
  final ExtensionsController controller;
  final VoidCallback onMenu;
  final ModelFilePicker? picker;
  @override
  State<ExtensionsPage> createState() => _ExtensionsPageState();
}

class _ExtensionsPageState extends State<ExtensionsPage> {
  int tab = 0;
  final queries = List.generate(4, (_) => TextEditingController());
  DialogRoute<dynamic>? modal;
  bool importing = false;
  @override
  void initState() {
    super.initState();
    if (!widget.controller.loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(widget.controller.load());
      });
    }
  }

  @override
  void dispose() {
    final route = modal;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive ?? false) route!.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    for (final query in queries) {
      query.dispose();
    }
    super.dispose();
  }

  Future<T?> show<T>(Widget child, {bool dismissible = true}) async {
    if (modal != null) return null;
    final route = DialogRoute<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (_) => child,
    );
    modal = route;
    final result = await Navigator.of(context).push(route);
    if (identical(modal, route)) modal = null;
    return result;
  }

  Future<void> import() async {
    if (importing || widget.controller.busy || tab != 1) return;
    importing = true;
    try {
      final installed = await show<ExtensionPackage>(
        ExtensionImportDialog(
          connect: widget.controller.connect,
          picker: widget.picker ?? createExtensionFilePicker(),
        ),
        dismissible: false,
      );
      if (installed != null) await widget.controller.installed();
    } finally {
      importing = false;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final owner = widget.controller;
      final query = queries[tab].text.trim().toLowerCase();
      final packages = owner.packages
          .where(
            (p) =>
                query.isEmpty ||
                '${p.id} ${p.name} ${p.description}'.toLowerCase().contains(
                  query,
                ),
          )
          .toList();
      final colors = Theme.of(context).colorScheme;
      const labels = ['脚本', '插件', 'Skill', 'MCP'];
      const icons = [Icons.extension, Icons.apps, Icons.build, Icons.cloud];
      return PrimaryPage(
        title: '扩展',
        onMenu: widget.onMenu,
        actionWidth: 160,
        actions: [
          if (tab < 2) const ShellAction(Icons.settings_outlined, '脚本设置'),
          if (tab == 3) const ShellAction(Icons.play_arrow_outlined, '启动'),
          const ShellAction(Icons.store_outlined, '市场'),
          ShellAction(
            Icons.add,
            tab == 1 ? '导入外部插件' : '添加',
            onTap: tab == 1 ? () => unawaited(import()) : emptyAction,
          ),
          ShellAction(
            Icons.refresh,
            '刷新',
            onTap: () => unawaited(owner.load()),
          ),
        ],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: KiyoriSearchField(
                controller: queries[tab],
                hint: const ['搜索脚本包', '搜索插件', '搜索 Skill 或作者', '搜索 MCP'][tab],
                showSearchIcon: true,
                showClear: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  for (var index = 0; index < 4; index++)
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() => tab = index);
                        },
                        child: Semantics(
                          selected: tab == index,
                          button: true,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: tab == index
                                      ? _tone(context, index).$1
                                      : colors.outlineVariant,
                                  width: tab == index ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _tone(context, index).$2,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    icons[index],
                                    size: 15,
                                    color: _tone(context, index).$1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    labels[index],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tab == index
                                          ? _tone(context, index).$1
                                          : colors.onSurfaceVariant,
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
            if (tab < 2)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _tone(context, 0).$2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _tone(context, 0).$1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.apps, size: 14, color: _tone(context, 0).$1),
                        const SizedBox(width: 5),
                        Text(
                          '全部 ${tab == 1 ? owner.packages.length : 0}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _tone(context, 0).$1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (owner.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        owner.error!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                    TextButton(
                      onPressed: () => unawaited(owner.load()),
                      child: const Text('重新加载'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: owner.loading && !owner.loaded
                  ? const Center(child: CircularProgressIndicator())
                  : tab != 1 || packages.isEmpty
                  ? _empty(context, tab, query.isNotEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: packages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final package = packages[index];
                        return Material(
                          key: ValueKey('extension-${package.id}'),
                          color: Color.alphaBlend(
                            colors.surfaceContainerHighest.withValues(
                              alpha: .3,
                            ),
                            colors.surface,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => unawaited(
                              show<void>(
                                _DetailsDialog(
                                  controller: owner,
                                  package: package,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _tone(context, 1).$2,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(
                                      Icons.apps,
                                      color: _tone(context, 1).$1,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            package.name.isEmpty
                                                ? package.id
                                                : package.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            package.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                          Text(
                                            '子包数：0',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    height: 20,
                                    child: Transform.scale(
                                      scale: .65,
                                      child: Switch(
                                        key: ValueKey(
                                          'extension-toggle-${package.id}',
                                        ),
                                        value: package.enabled,
                                        onChanged: owner.busy
                                            ? null
                                            : (value) => unawaited(
                                                owner.change(
                                                  package,
                                                  enabled: value,
                                                ),
                                              ),
                                        activeThumbColor: _tone(context, 1).$1,
                                        activeTrackColor: _tone(context, 1).$2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}

(Color, Color) _tone(BuildContext context, int index) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (index) {
    0 =>
      dark
          ? (const Color(0xFF65D3E8), const Color(0xFF173942))
          : (const Color(0xFF17768B), const Color(0xFFE4F5F8)),
    1 =>
      dark
          ? (const Color(0xFF8CB5FF), const Color(0xFF26364F))
          : (const Color(0xFF2B5FAF), const Color(0xFFEAF1FF)),
    2 =>
      dark
          ? (const Color(0xFFFFB76A), const Color(0xFF432B16))
          : (const Color(0xFFA85A12), const Color(0xFFFFF0DF)),
    _ =>
      dark
          ? (const Color(0xFF90CAF9), const Color(0xFF163044))
          : (const Color(0xFF256DB0), const Color(0xFFE8F3FE)),
  };
}

Widget _empty(BuildContext context, int tab, bool searching) => Center(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _tone(context, 1).$2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.info, size: 28, color: _tone(context, 1).$1),
        ),
        const SizedBox(height: 16),
        Text(
          searching
              ? '未找到匹配的${const ['脚本', '插件', 'Skill', 'MCP'][tab]}'
              : const ['暂无可用的脚本包', '暂无可用插件', '暂无可用 Skill', '暂无可用 MCP'][tab],
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  ),
);

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({required this.controller, required this.package});
  final ExtensionsController controller;
  final ExtensionPackage package;
  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  ExtensionDetails? details;
  String? error;
  bool loading = true, deleting = false;
  DialogRoute<bool>? confirmation;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
    unawaited(load());
  }

  void changed() {
    if (!mounted) return;
    if (widget.controller.loaded &&
        !widget.controller.packages.any(
          (p) =>
              p.id == widget.package.id &&
              p.revision == widget.package.revision,
        )) {
      final route = ModalRoute.of(context);
      final confirm = confirmation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (confirm?.isActive ?? false) {
          confirm!.navigator?.removeRoute(confirm);
        }
        if (route?.isActive ?? false) route!.navigator?.removeRoute(route);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    } else {
      setState(() {});
    }
  }

  Future<void> load() async {
    try {
      final value = await (await widget.controller.connect()).extensionDetails(
        widget.package.id,
        widget.package.revision,
      );
      if (mounted) {
        setState(() {
          details = value;
          loading = false;
          error = null;
        });
      }
    } on BridgeError catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '详情加载失败，请重新加载。';
        });
      }
    }
  }

  Future<void> remove() async {
    if (deleting || widget.controller.busy) return;
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除包 "${widget.package.id}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    confirmation = route;
    final confirmed = await Navigator.of(context).push(route);
    confirmation = null;
    if (confirmed != true || !mounted) return;
    setState(() => deleting = true);
    final current = widget.controller.packages
        .where((p) => p.id == widget.package.id)
        .firstOrNull;
    final saved =
        current != null &&
        current.revision == widget.package.revision &&
        await widget.controller.change(widget.package);
    if (mounted) {
      setState(() {
        deleting = false;
        if (!saved) {
          error = widget.controller.error ?? '删除未完成，请重试或重新打开详情核对当前状态。';
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    final route = confirmation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive ?? false) route!.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final package = details?.package ?? widget.package;
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.extension, size: 24, color: _tone(context, 1).$1),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name.isEmpty ? package.id : package.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (details?.authors.isNotEmpty ?? false)
                          Text(
                            '作者：${details!.authors.join(', ')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        Text(
                          'ID: ${package.id}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '外部',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (error != null) ...[
                        Text(error!, style: TextStyle(color: colors.error)),
                        TextButton(
                          onPressed: () => unawaited(load()),
                          child: const Text('重新加载'),
                        ),
                      ],
                      if (package.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(package.description),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'ToolPkg 子包',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (details != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: .3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'ToolPkg API：${details!.apiVersion}\n版本：${package.version}\n资源数：0\nWASM 模块数：0\nUI 模块数：0\n工作流模板数：0\n工作区模板数：0',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (package.cleanupPending > 0)
                        Text(
                          '扩展维护未完成，请重新加载后核对',
                          style: TextStyle(color: colors.error),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: deleting || widget.controller.busy
                        ? null
                        : () => unawaited(remove()),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 16),
                        SizedBox(width: 4),
                        Text('删除'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: deleting ? null : () => Navigator.pop(context),
                    child: Text(deleting ? '正在删除…' : '关闭'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
