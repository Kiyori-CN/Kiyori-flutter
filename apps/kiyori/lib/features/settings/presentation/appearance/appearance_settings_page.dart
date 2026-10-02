import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'appearance_background.dart';
import 'appearance_basic.dart';
import 'appearance_chat.dart';
import 'appearance_input.dart';
import 'appearance_interface.dart';
import 'appearance_media_presentation.dart';

/// 五标签的局部草稿均由各面板持有；不改变全局主题或角色卡事实。
class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({
    this.media = const AppearanceMediaPresentation(),
    super.key,
  });
  final AppearanceMediaPresentation media;
  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  int selected = 0;
  final visited = <int>{0};
  List<Widget> get panels => [
    const AppearanceBasic(),
    AppearanceBackground(snapshot: widget.media.background),
    AppearanceChat(snapshot: widget.media),
    const AppearanceInput(),
    const AppearanceInterface(),
  ];
  // 旧 ThemeSettingsTabs 使用语义色，区别于设置目录的 IconTone 角色色。
  static const tabs = [
    ('主题', Icons.brightness_6, Color(0xFF256DB0), Color(0xFF90CAF9)),
    ('背景', Icons.wallpaper, Color(0xFFAE3B6D), Color(0xFFF49AC0)),
    ('聊天', Icons.chat_bubble, Color(0xFF2B5FAF), Color(0xFF8CB5FF)),
    ('输入栏', Icons.keyboard, Color(0xFF17768B), Color(0xFF65D3E8)),
    ('AI 界面', Icons.tune, Color(0xFFA85A12), Color(0xFFFFB76A)),
  ];
  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '主题设置',
    onBack: () => Navigator.maybePop(context),
    body: LayoutBuilder(
      builder: (context, constraints) {
        // 横屏键盘可能仅留下不足一行正文的空间；默认窗口保持原标签几何。
        final compact = constraints.maxHeight < 100;
        return Column(
          children: [
            SizedBox(
              height: compact
                  ? 44
                  : 56 +
                        (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(
                          0,
                          70,
                        ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Semantics(
                        selected: i == selected,
                        button: true,
                        child: InkWell(
                          onTap: () => setState(() {
                            selected = i;
                            visited.add(i);
                          }),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 90),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: selected == i ? 2 : 1,
                                  color: selected == i
                                      ? PrimaryColors.of(context).accent
                                      : PrimaryColors.of(context).divider,
                                ),
                              ),
                            ),
                            child: Flex(
                              direction: compact
                                  ? Axis.horizontal
                                  : Axis.vertical,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  tabs[i].$2,
                                  size: 24,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? tabs[i].$4
                                      : tabs[i].$3,
                                ),
                                if (compact) const SizedBox(width: 8),
                                Text(
                                  tabs[i].$1,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: i == selected
                                        ? PrimaryColors.of(context).text
                                        : PrimaryColors.of(context).secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: selected,
                children: [
                  for (var i = 0; i < panels.length; i++)
                    if (!visited.contains(i))
                      const SizedBox.shrink()
                    else
                      TickerMode(
                        enabled: i == selected,
                        child: _AppearancePanel(
                          key: ValueKey(i),
                          active: i == selected,
                          child: panels[i],
                        ),
                      ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _AppearancePanel extends StatefulWidget {
  const _AppearancePanel({
    required this.active,
    required this.child,
    super.key,
  });
  final bool active;
  final Widget child;
  @override
  State<_AppearancePanel> createState() => _AppearancePanelState();
}

class _AppearancePanelState extends State<_AppearancePanel> {
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AppearancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.active) return;
        final primary = PrimaryScrollController.maybeOf(context);
        if (primary != null && primary.hasClients) primary.jumpTo(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: widget.active ? null : scroll,
    primary: widget.active,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.child,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: OutlinedButton(
            onPressed: emptyAction,
            child: const Text('重置为默认主题'),
          ),
        ),
      ],
    ),
  );
}
