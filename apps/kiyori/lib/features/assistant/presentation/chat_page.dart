import 'package:flutter/material.dart';

import 'package:kiyori_ui/kiyori_ui.dart';

/// 未接入模型前只保存 UI 草稿，发送和工具按钮不产生业务副作用。
class ChatPage extends StatefulWidget {
  const ChatPage({this.onOpenDrawer = emptyAction, super.key});
  final VoidCallback onOpenDrawer;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with AutomaticKeepAliveClientMixin {
  final draft = TextEditingController();
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 4),
                ShellAction(
                  Icons.menu,
                  '菜单',
                  onTap: widget.onOpenDrawer,
                  size: 48,
                  iconSize: 21,
                ),
                const Expanded(
                  child: Text(
                    'AI 对话',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const ShellAction(
                  Icons.language,
                  '浏览器',
                  size: 48,
                  iconSize: 21,
                  color: Color(0xFF2584E9),
                ),
                const ShellAction(
                  Icons.folder_outlined,
                  '文件管理器',
                  size: 48,
                  iconSize: 21,
                  color: Color(0xFFB07C07),
                ),
                const ShellAction(
                  Icons.terminal,
                  'AI 电脑',
                  size: 48,
                  iconSize: 21,
                  color: Color(0xFF657CA8),
                ),
                const ShellAction(
                  Icons.article_outlined,
                  '对话详情',
                  size: 48,
                  iconSize: 21,
                  color: Color(0xFF427FEB),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Divider(height: .5, thickness: .5, color: c.outlineVariant),
          ColoredBox(
            color: c.surfaceContainerHighest.withValues(alpha: .2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  const ShellAction(
                    Icons.history,
                    '显示历史',
                    size: 32,
                    color: Color(0xFF2584E9),
                  ),
                  const SizedBox(width: 8),
                  const ShellAction(
                    Icons.picture_in_picture_alt_rounded,
                    '打开悬浮窗',
                    size: 32,
                    color: Color(0xFF607080),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: emptyAction,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEDF6EF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: Color(0xFF34974E),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('Kiyori', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: '对话统计',
                    child: SizedBox.square(
                      dimension: 36,
                      child: InkWell(
                        onTap: emptyAction,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 28,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: 0,
                                  strokeWidth: 2.5,
                                  backgroundColor: c.surfaceContainerHighest,
                                ),
                                Icon(
                                  Icons.bar_chart_outlined,
                                  size: 15,
                                  color: c.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Expanded(
            child: SizedBox.expand(key: Key('empty-conversation')),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .08),
                  blurRadius: 14,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('chat-draft'),
                  controller: draft,
                  style: const TextStyle(fontSize: 14, height: 20 / 14),
                  minLines: 1,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: '请输入您的问题...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: c.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: const ShellAction(
                      Icons.fullscreen,
                      '全屏输入',
                      size: 48,
                      iconSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: emptyAction,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: c.outline.withValues(alpha: .2),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '未选择',
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: c.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const ShellAction(Icons.tune, '设置选项'),
                    const SizedBox(width: 8),
                    const ShellAction(Icons.add, '添加附件', iconSize: 24),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: draft,
                      builder: (context, value, _) {
                        final empty = value.text.trim().isEmpty;
                        return ShellAction(
                          empty ? Icons.mic_none : Icons.send_outlined,
                          empty ? '语音输入' : '发送',
                          iconSize: 18,
                          color: empty ? c.onSurfaceVariant : c.onPrimary,
                          background: empty ? null : c.primary,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
