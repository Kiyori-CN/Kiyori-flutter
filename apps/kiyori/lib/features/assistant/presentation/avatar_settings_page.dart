import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'avatar/avatar_guides.dart';
import 'avatar/avatar_model_editor.dart';
import 'avatar/avatar_presentation.dart';

export 'avatar/avatar_presentation.dart';

/// KiyoriAvatarSettingsPage 的展示层；不构造渲染器或导入本机资源。
class AvatarSettingsPage extends StatefulWidget {
  const AvatarSettingsPage({
    this.snapshot = const AvatarPresentation(),
    super.key,
  });
  final AvatarPresentation snapshot;
  @override
  State<AvatarSettingsPage> createState() => _AvatarSettingsPageState();
}

class _AvatarSettingsPageState extends State<AvatarSettingsPage> {
  late bool enabled = widget.snapshot.enabled;
  bool collapsed = false;
  String? selected;
  final drafts = <String, AvatarDraft>{};

  @override
  void initState() {
    super.initState();
    selected = widget.snapshot.currentId;
    reconcile();
  }

  void reconcile() {
    final ids = widget.snapshot.models.map((m) => m.id).toSet();
    drafts.removeWhere((id, _) => !ids.contains(id));
    for (final model in widget.snapshot.models) {
      drafts.putIfAbsent(model.id, () => AvatarDraft(model));
    }
    if (!ids.contains(selected)) selected = null;
  }

  @override
  void didUpdateWidget(covariant AvatarSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.currentId != widget.snapshot.currentId) {
      selected = widget.snapshot.currentId;
    }
    reconcile();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final current = snapshot.models.where((m) => m.id == selected).firstOrNull;
    return Stack(
      children: [
        SettingsDetailPage(
          title: '虚拟形象',
          children: [
            Column(
              children: [
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: PrimaryColors.of(context).card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: PrimaryColors.of(context).divider,
                          width: .8,
                        ),
                      ),
                      child: Text(
                        current == null
                            ? (snapshot.models.isEmpty ? '没有可用的模型' : '请选择一个模型')
                            : '不支持的模型类型: ${current.type.label}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: collapsed ? '展开' : '收起',
                  onPressed: () => setState(() => collapsed = !collapsed),
                  icon: Icon(collapsed ? Icons.expand_more : Icons.expand_less),
                ),
              ],
            ),
            SettingsGroup(
              title: '虚拟形象配置',
              description: '选择形象模型，调整显示位置，并管理动作与情绪映射',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '虚拟形象是否启用',
                                  style: TextStyle(fontSize: 14),
                                ),
                                Text(
                                  '启用后，语音通话界面会使用虚拟形象，并根据返回的 <mood> 标签播放情绪动作。',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Switch(
                            value: enabled,
                            onChanged: (v) => setState(() => enabled = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AvatarModelEditor(
                        key: ObjectKey(
                          current == null ? null : drafts[current.id],
                        ),
                        snapshot: snapshot,
                        current: current,
                        draft: current == null ? null : drafts[current.id],
                        onSelect: (id) => setState(() => selected = id),
                      ),
                      const SizedBox(height: 8),
                      const AvatarGuides(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        if (snapshot.loading || snapshot.importing)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: .78),
              child: AbsorbPointer(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(snapshot.importing ? '正在导入模型...' : '处理中...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
