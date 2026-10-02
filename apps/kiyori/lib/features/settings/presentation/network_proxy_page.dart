import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'network_proxy_editors.dart';

enum NetworkProxySection { overview, node, subscriptions, rules, scripts, logs }

/// 旧 KiyoriNetworkProxySettingsPage 的空配置快照，不加载或启动 Mihomo。
class NetworkProxyPage extends StatefulWidget {
  const NetworkProxyPage({
    this.section = NetworkProxySection.overview,
    required this.onOpen,
    super.key,
  });
  final NetworkProxySection section;
  final ValueChanged<NetworkProxySection> onOpen;
  @override
  State<NetworkProxyPage> createState() => _NetworkProxyPageState();
}

class _NetworkProxyPageState extends State<NetworkProxyPage> {
  final search = TextEditingController();
  int filter = 0;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String get title => switch (widget.section) {
    NetworkProxySection.overview => '网络代理',
    NetworkProxySection.node => '节点选择',
    NetworkProxySection.subscriptions => '订阅管理',
    NetworkProxySection.rules => '规则管理',
    NetworkProxySection.scripts => '脚本规则',
    NetworkProxySection.logs => '代理日志',
  };

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: title,
    actionWidth: 96,
    actions: widget.section == NetworkProxySection.logs
        ? const Row(
            children: [
              IconButton(
                onPressed: null,
                tooltip: '复制全部代理日志',
                icon: Icon(Icons.content_copy_outlined),
              ),
              IconButton(
                onPressed: null,
                tooltip: '导出全部代理日志',
                icon: Icon(Icons.save_alt_outlined),
              ),
            ],
          )
        : widget.section == NetworkProxySection.scripts
        ? const Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: emptyAction,
              tooltip: '刷新脚本',
              icon: Icon(Icons.refresh_outlined),
            ),
          )
        : null,
    children: switch (widget.section) {
      NetworkProxySection.overview => _overview(),
      NetworkProxySection.node => const [
        SettingsGroup(
          title: '节点选择',
          description: '请先在订阅管理中导入并切换一份 Clash / Mihomo 订阅。',
          children: [NetworkProxyNote('当前没有可用订阅。')],
        ),
      ],
      NetworkProxySection.subscriptions => [_subscriptions()],
      NetworkProxySection.rules => _rules(),
      NetworkProxySection.scripts => const [
        SettingsGroup(
          title: '脚本规则',
          description: '只显示已安装的传统 JsEngine 脚本，启用状态不影响识别；ToolPkg 统一归入 AI 工具。',
          children: [NetworkProxyNote('当前没有已安装的传统脚本。')],
        ),
      ],
      NetworkProxySection.logs => [_logs()],
    },
  );

  List<Widget> _overview() => [
    SettingsGroup(
      title: '应用内代理',
      description: '只影响 Kiyori 进程内已接入模块；不会改变其他应用的网络。',
      children: [
        const SettingsRow(
          title: '启用应用内代理',
          description: '请先导入并选择有效订阅，才能启用应用内代理',
          checked: false,
          enabled: false,
        ),
        const SettingsDivider(),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Text(
            '代理模式',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, 0),
          child: Text(
            '规则按域名细分；全局让 Kiyori 请求统一进入当前策略组；直连不经过内嵌 Mihomo。',
            style: TextStyle(
              fontSize: 12,
              height: 17 / 12,
              color: PrimaryColors.secondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final label in ['规则', '全局', '直连']) ...[
                if (label != '规则') const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: label == '直连'
                        ? PrimaryColors.accent
                        : PrimaryColors.background,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: emptyAction,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: label == '直连'
                                  ? Colors.white
                                  : PrimaryColors.text,
                              fontWeight: label == '直连'
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
    SettingsGroup(
      title: '连接范围',
      description: '进入对应子页面管理节点选择、订阅、规则和脚本规则。',
      children: [
        _nav('节点选择', '选择当前订阅中的策略组和节点', NetworkProxySection.node),
        const SettingsDivider(),
        _nav(
          '订阅管理',
          '尚未导入 Clash / Mihomo 订阅',
          NetworkProxySection.subscriptions,
        ),
        const SettingsDivider(),
        _nav('规则管理', '自定义规则 0 条；导入订阅后读取订阅规则', NetworkProxySection.rules),
        const SettingsDivider(),
        _nav('脚本规则', '当前没有已安装的传统脚本', NetworkProxySection.scripts),
      ],
    ),
    SettingsGroup(
      title: '网络选项',
      description: '系统 VPN 或 Android HTTP/PAC 代理接管时暂停内嵌代理；外部路由关闭后自动恢复。',
      children: [
        _nav('代理日志', '当前进程暂无代理日志', NetworkProxySection.logs),
        const SettingsDivider(),
        const SettingsRow(
          title: '代理局域网地址',
          description: '私有地址不再直连，交由内嵌核心按当前模式处理',
          checked: false,
        ),
        const SettingsDivider(),
        const NetworkProxyNote(
          '当系统 VPN 实际作用于 Kiyori，或 Android 配置 HTTP/PAC 代理时，应用会自动暂停内嵌代理并使用系统路由；所有外部路由关闭后自动恢复。按应用分流且排除 Kiyori 的 VPN 不会触发暂停。',
          small: true,
        ),
        const SettingsDivider(),
        SettingsRow(
          title: '重置网络代理',
          description: '停止核心并删除订阅、模块规则和加密配置',
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('重置网络代理？'),
              content: const Text('这会停止内嵌 Mihomo，并删除全部订阅、脚本规则、自定义规则和加密代理配置。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const FilledButton(onPressed: emptyAction, child: Text('重置')),
              ],
            ),
          ),
        ),
      ],
    ),
  ];

  Widget _subscriptions() => SettingsGroup(
    title: '订阅管理',
    description: '保存多份 Clash / Mihomo 订阅；点击订阅行立即切换当前配置，右侧菜单管理条目。',
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final buttons = [
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const NetworkSubscriptionEditor(),
                ),
                icon: const Icon(Icons.add_outlined, size: 18),
                label: const Text('添加订阅地址', style: TextStyle(fontSize: 12)),
              ),
              OutlinedButton.icon(
                onPressed: emptyAction,
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('导入订阅文件', style: TextStyle(fontSize: 12)),
              ),
            ];
            if (constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(12) > 18) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buttons.first,
                  const SizedBox(height: 8),
                  buttons.last,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: buttons.first),
                const SizedBox(width: 8),
                Expanded(child: buttons.last),
              ],
            );
          },
        ),
      ),
      const NetworkProxyNote(
        '还没有订阅。支持 Clash/Mihomo YAML、Base64 和 URI 节点列表；请添加地址或导入本地文件。',
      ),
    ],
  );

  List<Widget> _rules() => [
    SettingsGroup(
      title: '规则管理',
      description: '自定义规则优先于当前订阅规则；订阅更新会覆盖订阅规则编辑，不影响自定义规则。',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: KiyoriSearchField(
            controller: search,
            hint: '搜索规则类型、匹配内容或目标',
            showSearchIcon: true,
            showClear: true,
          ),
        ),
      ],
    ),
    SettingsGroup(
      title: '自定义规则',
      description: '由你创建并单独加密保存，始终排在订阅规则前。',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const NetworkRuleEditor(),
            ),
            icon: const Icon(Icons.add_outlined, size: 18),
            label: const Text('添加自定义规则', style: TextStyle(fontSize: 12)),
          ),
        ),
        const NetworkProxyNote('暂无自定义规则。'),
      ],
    ),
    const SettingsGroup(
      title: '当前订阅规则',
      description: '尚未选择订阅。',
      children: [NetworkProxyNote('当前订阅没有可执行规则。')],
    ),
  ];

  Widget _logs() => SettingsGroup(
    title: '当前进程日志',
    description: '显示 0/0 条，最新记录在前；已淘汰 0 条旧记录。最多保留 1000 条，核心重复输出按一秒窗口合并，请求失败逐条保留。顶部复制和导出包含全部记录，按发生顺序排列，不受筛选影响。凭据、私有路径和订阅地址已遮蔽。',
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: KiyoriSearchField(
          controller: search,
          hint: '搜索日志',
          showSearchIcon: true,
          showClear: true,
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          spacing: 8,
          children: [
            for (var index = 0; index < 3; index++)
              FilterChip(
                selected: filter == index,
                onSelected: (_) => setState(() => filter = index),
                label: Text(['全部', '警告与错误', '仅错误'][index]),
              ),
          ],
        ),
      ),
      const NetworkProxyNote('暂无日志。导入、启用代理、切换节点或测速后，相关状态会显示在这里。'),
    ],
  );

  SettingsRow _nav(
    String title,
    String description,
    NetworkProxySection section,
  ) => SettingsRow(
    title: title,
    description: description,
    onTap: () => widget.onOpen(section),
  );
}

class NetworkProxyNote extends StatelessWidget {
  const NetworkProxyNote(this.text, {this.small = false, super.key});
  final String text;
  final bool small;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 18, vertical: small ? 12 : 18),
    child: Text(
      text,
      style: TextStyle(
        fontSize: small ? 12 : 13,
        height: small ? 17 / 12 : 19 / 13,
        color: PrimaryColors.secondary,
      ),
    ),
  );
}
