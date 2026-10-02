import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'open_source_inventory.dart';

class OpenSourcePage extends StatefulWidget {
  const OpenSourcePage({super.key});
  @override
  State<OpenSourcePage> createState() => _OpenSourcePageState();
}

class _OpenSourcePageState extends State<OpenSourcePage> {
  final query = TextEditingController();
  List<OpenSourceEntry> filtered = openSourceEntries;
  static const categories = [
    ('界面与 Android', 'Compose、AndroidX 与应用界面基础组件'),
    ('媒体与图形', '视频播放、图像、3D 与实时渲染组件'),
    ('AI 与本地推理', '文字识别、语音识别和端侧模型运行时'),
    ('网络与数据', '网络连接、代理、序列化、数据库和安全组件'),
    ('文档与文件', '文档、压缩包、PDF 与 APK 处理组件'),
    ('开发工具', '脚本引擎、终端、日志与开发辅助组件'),
  ];
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void filter(String value) {
    final normalized = value.trim().toLowerCase();
    setState(
      () => filtered = normalized.isEmpty
          ? openSourceEntries
          : openSourceEntries
                .where(
                  (entry) => [
                    entry.name,
                    entry.description,
                    entry.license,
                    entry.website,
                    entry.licenseUrl,
                  ].any((text) => text.toLowerCase().contains(normalized)),
                )
                .toList(),
    );
  }

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '开源协议',
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, color: IconTone.code.icon),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Kiyori 开源组成',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '本清单覆盖当前可由 Gradle、源码模块、native source lock、随包许可证或运行时装载证据确认的开源组件。具体权利义务以组件随附的许可证正文为准。',
              style: TextStyle(
                fontSize: 12,
                height: 18 / 12,
                color: PrimaryColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '当前清单 ${filtered.length} / ${openSourceEntries.length} 项 · 清单基线 $openSourceInventoryVersion',
              style: const TextStyle(fontSize: 12, color: PrimaryColors.accent),
            ),
            const SizedBox(height: 8),
            KiyoriSearchField(
              controller: query,
              hint: '搜索组件、许可证或项目地址',
              showSearchIcon: true,
              onChanged: filter,
            ),
          ],
        ),
      ),
      for (final category in categories)
        if (filtered.any((entry) => entry.category == category.$1))
          SettingsGroup(
            title: category.$1,
            description: category.$2,
            children: [
              for (final entry
                  in filtered
                      .where((entry) => entry.category == category.$1)
                      .indexed) ...[
                if (entry.$1 > 0) const Divider(height: 1),
                _LicenseRow(entry.$2),
              ],
            ],
          ),
      if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '没有匹配的开源组件',
            style: TextStyle(color: PrimaryColors.secondary),
          ),
        ),
    ],
  );
}

class _LicenseRow extends StatelessWidget {
  const _LicenseRow(this.entry);
  final OpenSourceEntry entry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                entry.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: PrimaryColors.secondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '许可证：${entry.license}',
                style: const TextStyle(
                  fontSize: 12,
                  color: PrimaryColors.accent,
                ),
              ),
              const SizedBox(height: 3),
              InkWell(
                onTap: emptyAction,
                child: Text(
                  '项目地址：${entry.website}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: PrimaryColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: emptyAction,
          tooltip: '查看许可证正文',
          icon: Icon(Icons.policy, color: IconTone.security.icon),
        ),
        IconButton(
          onPressed: emptyAction,
          tooltip: '打开项目主页',
          icon: Icon(Icons.open_in_browser, color: IconTone.browser.icon),
        ),
      ],
    ),
  );
}
