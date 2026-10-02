import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class BrowserHomePage extends StatefulWidget {
  const BrowserHomePage({super.key});
  @override
  State<BrowserHomePage> createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  bool custom = true;
  final url = TextEditingController(text: 'https://web.gotab.cn/');
  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '网页主页',
    children: [
      SettingsGroup(
        title: '打开方式',
        description: '主页按钮、新建标签页和冷启动入口使用这里的选择；切换不会打断当前网页',
        children: [
          _ModeRow(
            title: '自定义网址',
            description: '使用你指定的 HTTP/HTTPS 地址作为主页和新标签页入口',
            icon: Icons.language_outlined,
            selected: custom,
            onTap: () => setState(() => custom = true),
          ),
          const SettingsDivider(),
          _ModeRow(
            title: '纯空白页',
            description: '只保留浏览器地址栏、标签页和工具箱，不加载任何网页',
            icon: Icons.crop_square_outlined,
            selected: !custom,
            onTap: () => setState(() => custom = false),
          ),
        ],
      ),
      if (custom)
        SettingsGroup(
          title: '自定义网址',
          description: '仅在选择“自定义网址”时生效；修改后立即用于主页和新标签页',
          children: [
            SettingsRow(
              title: '当前网址',
              description: url.text,
              value: '修改',
              onTap: () async {
                await showDialog<void>(
                  context: context,
                  builder: (context) => const _HomeEditDialog(),
                );
              },
            ),
          ],
        ),
    ],
  );
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title, description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? PrimaryColors.accent : PrimaryColors.secondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 17 / 12,
                        color: PrimaryColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? PrimaryColors.accent : PrimaryColors.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeEditDialog extends StatefulWidget {
  const _HomeEditDialog();
  @override
  State<_HomeEditDialog> createState() => _HomeEditDialogState();
}

class _HomeEditDialogState extends State<_HomeEditDialog> {
  final input = TextEditingController(text: 'https://web.gotab.cn/');
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text(
      '自定义主页入口',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
    content: SingleChildScrollView(
      child: TextField(
        controller: input,
        maxLines: 1,
        decoration: settingsFieldDecoration(
          label: '网址',
          hint: '输入 HTTP/HTTPS 网址',
          helper: '可以输入完整网址、域名或搜索词；纯空白页请在上方选择对应模式。',
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      const TextButton(onPressed: emptyAction, child: Text('保存')),
    ],
  );
}
