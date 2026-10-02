import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'adblock_subscription_group.dart';
import 'adblock_editor_dialog.dart';

enum AdblockSection {
  overview('广告拦截器'),
  network('网址过滤'),
  elements('网页元素'),
  allowlist('站点白名单'),
  subscriptions('广告拦截订阅');

  const AdblockSection(this.title);
  final String title;
}

/// 原 BrowserAdBlockStore 尚未加载时的初始快照：5 个内置订阅、零本地规则。
/// 这里只复刻初始 UI，不发布“已就绪”或虚构拦截/同步结果。
class AdblockSettingsPage extends StatefulWidget {
  const AdblockSettingsPage({
    required this.section,
    required this.onOpen,
    super.key,
  });
  final AdblockSection section;
  final ValueChanged<AdblockSection> onOpen;
  @override
  State<AdblockSettingsPage> createState() => _AdblockSettingsPageState();
}

class _AdblockSettingsPageState extends State<AdblockSettingsPage> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  static const reading = '正在后台读取广告拦截设置，页面和浏览器请求不会等待';

  Widget _group(String title, String description, List<Widget> rows) =>
      SettingsGroup(
        title: title,
        description: description,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SettingsDivider(),
            rows[i],
          ],
        ],
      );
  Widget _nav(
    AdblockSection section,
    String description,
    String value, {
    String? title,
  }) => SettingsRow(
    title: title ?? section.title,
    description: description,
    value: value,
    onTap: () => widget.onOpen(section),
  );
  Widget _search(String description, AdblockEditorKind kind) => SettingsGroup(
    title: '查找与新增',
    description: description,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: KiyoriSearchField(
                controller: search,
                hint: '搜索',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => showAdblockEditor(context, kind),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 3),
                  Text('新增'),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: widget.section.title,
    children: switch (widget.section) {
      AdblockSection.overview => [
        _group('拦截状态', '用于 Kiyori 内置浏览器的网页广告过滤，不影响其他应用；网址过滤与元素隐藏共用此开关', [
          const SettingsRow(
            title: '启用广告拦截',
            description: reading,
            checked: true,
            enabled: false,
          ),
          const AdblockMetric('本地规则引擎', '读取中', reading),
          const AdblockMetric('当前进程已拦截', '0', '从本次应用进程启动后累计的请求数量'),
          const AdblockMetric('已启用的网址规则', '0', '阻断 0 条，例外 0 条；总开关关闭时不执行'),
          const AdblockMetric('已启用的元素规则', '0', '隐藏 0 条，例外 0 条；总开关关闭时不执行'),
          const AdblockMetric('内置订阅就绪', '0/5', '已完成本地同步；是否参与拦截仍由各组与单条开关决定'),
        ]),
        _group('规则与站点', '所有入口共同使用同一份规则；修改后会立即应用到现有浏览器窗口', [
          _nav(AdblockSection.network, '拦截广告脚本、图片、接口和其他请求地址', '0'),
          _nav(AdblockSection.elements, '按站点隐藏广告容器、浮层和干扰组件', '0'),
          _nav(AdblockSection.allowlist, '白名单站点不会执行请求拦截或元素隐藏', '0'),
        ]),
        _group('内置拦截方案', '两组规则共用同一运行时；已开启不等于已就绪，首次缺少本地规则时会立即同步', [
          _nav(
            AdblockSection.subscriptions,
            'My AdFilters、AdGuard 中文过滤器、AdRules Lite',
            '0/3 就绪',
            title: '广告拦截器 Pro',
          ),
          _nav(
            AdblockSection.subscriptions,
            'EasyList China + EasyList 与可接受广告例外规则',
            '0/2 就绪',
            title: 'Adblock Plus',
          ),
          _nav(
            AdblockSection.subscriptions,
            '自动更新、全部刷新、逐条状态和自定义订阅',
            '5',
            title: '订阅与更新',
          ),
        ]),
      ],
      AdblockSection.network => [
        _search(
          '普通文本为包含匹配，也支持 ||host^、|prefix、suffix|、*、^、正则和 @@ 例外规则',
          AdblockEditorKind.network,
        ),
        _group('自定义规则', '共 0 条，已启用 0 条', const [
          AdblockEmptyRow('没有符合条件的网址过滤规则'),
        ]),
      ],
      AdblockSection.elements => [
        _search(
          '每条规则由站点域名和 CSS selector 组成；浏览器“标记广告”也会写入这里',
          AdblockEditorKind.element,
        ),
        _group('按域名整理', '共 0 个域名、0 条规则', const [
          AdblockEmptyRow('没有符合条件的网页元素规则'),
        ]),
      ],
      AdblockSection.allowlist => [
        _search(
          '填写主机名，例如 example.com；其子域名会一并跳过广告拦截',
          AdblockEditorKind.allowlist,
        ),
        _group('已允许站点', '共 0 个站点', const [AdblockEmptyRow('没有符合条件的白名单站点')]),
      ],
      AdblockSection.subscriptions => [
        _group('订阅状态', '先看规则是否已就绪，再决定是否启用；开关开启但未同步时不会产生拦截效果', const [
          AdblockMetric('运行时状态', '读取中', reading),
          AdblockMetric('已启用订阅', '5/5', '参与统一广告拦截运行时的订阅数量'),
          AdblockMetric('已就绪订阅', '0/5', '已经完成下载、解析并拥有本地规则载荷'),
          AdblockMetric('当前生效规则', '0', '已启用订阅的阻断、例外和网页元素规则总数'),
        ]),
        _group('订阅更新', '首次缺少本地规则时自动同步；手动更新只在完整下载并解析后替换当前版本', const [
          SettingsRow(
            title: '自动更新内置订阅',
            description: '应用启动时检查已启用且到期的内置订阅，开启新订阅时立即同步',
            checked: true,
          ),
          SettingsRow(
            title: '更新已启用订阅',
            description: '按顺序下载并验证当前已启用的内置与自定义订阅',
            enabled: false,
          ),
        ]),
        _search(
          '搜索名称或地址；加号用于添加自定义 HTTP(S) 纯文本订阅',
          AdblockEditorKind.subscription,
        ),
        AdblockSubscriptionGroup(
          title: '广告拦截器 Pro',
          description: '三条高覆盖中文与通用过滤列表',
          query: search.text,
          pro: true,
        ),
        AdblockSubscriptionGroup(
          title: 'Adblock Plus',
          description: 'EasyList 中国规则与可接受广告例外规则',
          query: search.text,
          pro: false,
        ),
        _group('自定义订阅', '可添加、改名、换址、启停、刷新或删除', const [
          AdblockEmptyRow('没有符合条件的自定义订阅'),
        ]),
      ],
    },
  );
}

class AdblockMetric extends StatelessWidget {
  const AdblockMetric(this.title, this.value, this.description, {super.key});
  final String title, value, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3),
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
        const SizedBox(width: 12),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: PrimaryColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class AdblockEmptyRow extends StatelessWidget {
  const AdblockEmptyRow(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
    child: Text(
      message,
      style: const TextStyle(fontSize: 13, color: PrimaryColors.secondary),
    ),
  );
}
