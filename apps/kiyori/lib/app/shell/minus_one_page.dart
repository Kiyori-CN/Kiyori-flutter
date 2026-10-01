import 'package:flutter/material.dart';

import 'package:kiyori_ui/kiyori_ui.dart';

class MinusOnePage extends StatelessWidget {
  const MinusOnePage({required this.onClose, super.key});
  final VoidCallback onClose;
  static const data = [
    ('收藏', Icons.favorite, 0xFFD64F73, 0xFFFDEBF0),
    ('书签', Icons.bookmarks_outlined, 0xFF566EF0, 0xFFF0F2FE),
    ('历史', Icons.history, 0xFF2584E9, 0xFFEBF4FD),
    ('下载', Icons.download_outlined, 0xFF079770, 0xFFE9F6F2),
  ];
  static const tools = [
    ('新版', Icons.system_update, 0xFFB65F0B, 0xFFFFF1DD),
    ('手册', Icons.menu_book_outlined, 0xFF40937D, 0xFFEEF5F3),
    ('版本', Icons.info_outline, 0xFF7D7DAE, 0xFFF3F3F8),
    ('搜索', Icons.search, 0xFF2584E9, 0xFFEBF4FD),
    ('工具箱', Icons.business_center_outlined, 0xFFC76E2E, 0xFFFAF2EC),
    ('清理', Icons.delete_sweep_outlined, 0xFFE45160, 0xFFFDEFF1),
    ('备份', Icons.backup_outlined, 0xFF676FDF, 0xFFF1F2FC),
    ('退出', Icons.exit_to_app, 0xFFC95181, 0xFFFAEFF4),
  ];
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '负一屏',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ShellAction(
                    Icons.close,
                    '关闭负一屏',
                    iconSize: 18,
                    onTap: onClose,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '我的数据',
                      style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < data.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          Material(
                            color: Colors.transparent,
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    Color(data[i].$4),
                                    c.surfaceContainerLow,
                                  ],
                                ),
                              ),
                              child: InkWell(
                                onTap: emptyAction,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      _badge(data[i], 38, 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        data[i].$1,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '0',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Color.lerp(
                                            Color(data[i].$3),
                                            Colors.black,
                                            .24,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '快捷工具',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_right,
                                size: 18,
                                color: c.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (var row = 0; row < 2; row++) ...[
                          if (row > 0) const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (var j = 0; j < 4; j++)
                                Opacity(
                                  opacity: .58,
                                  child: SizedBox(
                                    width: 64,
                                    child: InkWell(
                                      onTap: emptyAction,
                                      child: Column(
                                        children: [
                                          _badge(tools[row * 4 + j], 40, 24),
                                          const SizedBox(height: 6),
                                          Text(
                                            tools[row * 4 + j].$1,
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(
    (String, IconData, int, int) item,
    double size,
    double iconSize,
  ) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Color(item.$4),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(item.$2, size: iconSize, color: Color(item.$3)),
  );
}
