import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 旧 BrowserAdBlockSubscriptionCatalog 的公开内置来源；UI 不请求这些 URL。
class AdblockSubscriptionGroup extends StatelessWidget {
  const AdblockSubscriptionGroup({
    required this.title,
    required this.description,
    required this.query,
    required this.pro,
    super.key,
  });
  final String title, description, query;
  final bool pro;
  static const subscriptions = [
    ('My AdFilters', 'https://cdn.jsdelivr.net/gh/xun404/adblock@main/ad.txt'),
    (
      'AdGuard 中文过滤器',
      'https://filters.adtidy.org/extension/chromium/filters/224.txt',
    ),
    ('AdRules Lite', 'https://adrules.top/adblock_lite.txt'),
    (
      'EasyList China + EasyList',
      'https://easylist-downloads.adblockplus.org/easylistchina+easylist.txt',
    ),
    (
      '可接受广告例外规则',
      'https://easylist-downloads.adblockplus.org/exceptionrules.txt',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final group = pro ? subscriptions.take(3) : subscriptions.skip(3);
    final visible = group
        .where(
          (item) =>
              item.$1.toLowerCase().contains(query.trim().toLowerCase()) ||
              item.$2.toLowerCase().contains(query.trim().toLowerCase()),
        )
        .toList();
    return SettingsGroup(
      title: title,
      description: description,
      children: [
        SettingsRow(
          title: '启用整组',
          description:
              '已开启 ${group.length} / ${group.length} · 已就绪 0 / ${group.length}',
          checked: true,
          enabled: false,
        ),
        const SettingsDivider(),
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0) const SettingsDivider(),
          _SubscriptionRow(
            key: ValueKey(visible[index].$2),
            name: visible[index].$1,
            url: visible[index].$2,
          ),
        ],
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              '没有符合条件的内置订阅',
              style: TextStyle(fontSize: 13, color: PrimaryColors.secondary),
            ),
          ),
      ],
    );
  }
}

class _SubscriptionRow extends StatefulWidget {
  const _SubscriptionRow({required this.name, required this.url, super.key});
  final String name, url;
  @override
  State<_SubscriptionRow> createState() => _SubscriptionRowState();
}

class _SubscriptionRowState extends State<_SubscriptionRow> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => expanded = !expanded),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Row(
                          children: [
                            Icon(
                              Icons.hourglass_empty,
                              size: 16,
                              color: PrimaryColors.secondary,
                            ),
                            SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '等待首次同步',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 16 / 12,
                                  color: PrimaryColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 48,
              child: Switch(value: true, onChanged: null),
            ),
            IconButton(
              onPressed: null,
              tooltip: '更新订阅',
              icon: const Icon(Icons.refresh, color: PrimaryColors.muted),
            ),
            IconButton(
              onPressed: () => setState(() => expanded = !expanded),
              tooltip: expanded ? '收起详情' : '展开详情',
              icon: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: PrimaryColors.muted,
              ),
            ),
          ],
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Text(
                      '订阅地址',
                      style: TextStyle(
                        fontSize: 11,
                        color: PrimaryColors.secondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Text(
                      widget.url,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 17 / 12,
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  Row(children: [_stat('网址阻断'), _stat('网址例外')]),
                  Row(children: [_stat('元素隐藏'), _stat('元素例外')]),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      '忽略 0 行 · 尚未成功更新',
                      style: TextStyle(
                        fontSize: 11,
                        color: PrimaryColors.secondary,
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 17),
                          SizedBox(width: 3),
                          Text('立即更新'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  Widget _stat(String title) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: PrimaryColors.secondary,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '0',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}
