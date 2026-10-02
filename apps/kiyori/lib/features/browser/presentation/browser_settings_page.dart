import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// BrowserSettingsPage mirrors KiyoriBrowserSettingsPage's group and row contracts.
/// Values are local display state until WebSessionBrowserSettings has a Dart owner.
class BrowserSettingsPage extends StatelessWidget {
  const BrowserSettingsPage({required this.onOpen, super.key});
  final ValueChanged<String> onOpen;
  static const _values = <String, bool>{
    '允许用户脚本': false,
    '返回不重载': true,
    '滑屏前进后退': false,
    '搜索引擎切换条': true,
    '恢复上次的搜索结果': false,
    '询问是否恢复页面': false,
    '保留多窗口': false,
    '强制页面缩放': true,
    '长按网页元素菜单': true,
    '允许网页打开应用': true,
    '允许网页获取位置': true,
    '自动保存和填充网站密码': true,
    '搜索栏嗅探入口': true,
    '自动悬浮播放': true,
  };

  static const _groups = [
    (
      '网页扩展与脚本',
      '管理网页扩展、用户脚本授权、声明权限与运行诊断',
      [
        ('允许用户脚本', '允许已启用脚本在匹配网页中运行；关闭后保留脚本和启用状态', null),
        ('扩展中心', '查看当前页面的扩展提供者与已安装扩展', 'browser.plugins'),
        ('扩展权限与网站范围', '查看每个脚本声明的 GM 权限、联网范围和页面规则', 'browser.permissions'),
        ('脚本诊断与日志', '查看当前页命中、执行异常、排除规则和保留日志', 'browser.diagnostics'),
      ],
    ),
    (
      '主页与导航',
      '管理主页入口、网页历史返回方式和屏幕边缘前进后退手势',
      [
        ('网页主页', '选择自定义网址或纯空白页', 'browser.home'),
        ('返回不重载', '网页后退时使用历史缓存，减少重新请求和页面状态丢失', null),
        ('滑屏前进后退', '开启后从屏幕左右边缘滑动可在当前网页历史中前进或后退', null),
        ('搜索引擎切换条', '在搜索结果页顶栏下方显示搜索引擎快速切换条', null),
      ],
    ),
    (
      '启动与窗口',
      '控制浏览器冷启动恢复和普通窗口保留方式',
      [
        ('恢复上次的搜索结果', '开启后打开浏览器会自动打开上次未关闭的搜索结果页', null),
        ('询问是否恢复页面', '开启后打开浏览器会先询问是否打开上次未关闭的页面', null),
        ('保留多窗口', '开启后保留上次未关闭的普通窗口；无痕窗口不会写入恢复记录', null),
      ],
    ),
    (
      '网页显示',
      '控制网页缩放限制和站点正文的显示比例',
      [
        ('强制页面缩放', '忽略网页禁止缩放声明，始终允许双指缩放页面', null),
        ('网页文字大小', '调整所有网页正文的文字缩放比例并实时预览', 'browser.text-size'),
      ],
    ),
    (
      '网页交互',
      '管理网页内容长按、元素操作与系统原生文字选择的边界',
      [('长按网页元素菜单', '长按链接、图片和普通元素时显示适配菜单；输入框仍使用系统原生选区', null)],
    ),
    (
      '网站权限与数据',
      '管理网页外部能力、网站凭据和普通浏览数据',
      [
        ('允许网页打开应用', '允许网页通过外部链接唤起已安装应用', null),
        ('允许网页获取位置', '允许网页在系统授权后请求设备位置', null),
        ('自动保存和填充网站密码', '允许普通窗口安全保存并自动填充当前网站的账号密码', null),
        ('网站密码管理', '管理普通窗口中安全保存并自动填充的网站账号密码', 'browser.passwords'),
        (
          '清除网站 Cookie',
          '清除搜索工具、网页访问和内置浏览器保存的普通网站 Cookie',
          'browser.clear-cookies',
        ),
      ],
    ),
    (
      '音视频嗅探',
      '控制资源嗅探入口、自动悬浮视频播放和音视频识别策略',
      [
        ('搜索栏嗅探入口', '发现音视频资源后，在搜索栏右侧显示资源嗅探入口', null),
        ('自动悬浮播放', '已允许悬浮窗权限时，发现推荐视频后自动打开可在桌面播放的小窗', null),
        ('自动悬浮最小时长', '短于该时长的视频不会自动打开小窗；直播不受此限制', 'browser.floating-duration'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '网页浏览器',
    children: [
      for (final group in _groups)
        SettingsGroup(
          title: group.$1,
          description: group.$2,
          children: [
            for (var index = 0; index < group.$3.length; index++) ...[
              if (index > 0) const SettingsDivider(),
              _BrowserRow(
                title: group.$3[index].$1,
                description: group.$3[index].$2,
                route: group.$3[index].$3,
                checked: _values[group.$3[index].$1],
                onToggle: emptyAction,
                onOpen: onOpen,
              ),
            ],
          ],
        ),
    ],
  );
}

class _BrowserRow extends StatelessWidget {
  const _BrowserRow({
    required this.title,
    required this.description,
    required this.route,
    required this.checked,
    required this.onToggle,
    required this.onOpen,
  });
  final String title, description;
  final String? route;
  final bool? checked;
  final VoidCallback onToggle;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => SettingsRow(
    title: title,
    description: description,
    checked: checked,
    enabled: title != '允许用户脚本',
    value: switch (route) {
      'browser.home' => '自定义网址 · web.gotab.cn',
      'browser.text-size' => '默认 · 100%',
      'browser.permissions' => '暂无已安装脚本',
      'browser.diagnostics' => '运行环境不可用 · 0 条保留日志',
      'browser.passwords' => '不可用',
      'browser.floating-duration' => '1 分钟',
      _ => null,
    },
    onTap: () async {
      if (route != null) {
        if (route == 'browser.floating-duration') {
          final choice = await showSettingsSelection(
            context,
            title: title,
            current: '1 分钟',
            options: [
              for (final label in [
                '30 秒',
                '1 分钟',
                '3 分钟',
                '5 分钟',
                '10 分钟',
                '30 分钟',
                '1 小时',
              ])
                SettingsOption(
                  label,
                  description: '视频时长达到此值后才允许自动打开小窗',
                  selected: label == '1 分钟',
                ),
              const SettingsOption(
                '自定义时长',
                description: '输入 1–86400 秒，可精确到 1 秒',
              ),
            ],
          );
          if (choice == 7 && context.mounted) {
            await showDialog<void>(
              context: context,
              builder: (_) => const _DurationDialog(),
            );
          }
        } else if (route == 'browser.clear-cookies') {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('清除 Cookie？'),
              content: const Text(
                '将清除搜索工具、Browser 包和内置浏览器保存的 Cookie，已打开的网页可能需要重新登录。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(onPressed: emptyAction, child: const Text('清除')),
              ],
            ),
          );
        } else {
          onOpen(route!);
        }
      } else {
        onToggle();
      }
    },
  );
}

class _DurationDialog extends StatefulWidget {
  const _DurationDialog();
  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  final input = TextEditingController(text: '60');
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: input,
    builder: (context, value, _) {
      final seconds = int.tryParse(value.text);
      final valid = seconds != null && seconds >= 1 && seconds <= 86400;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('自定义自动悬浮时长'),
        content: TextField(
          controller: input,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          decoration:
              settingsFieldDecoration(
                context,
                label: '最小时长',
                helper: value.text.isNotEmpty && !valid
                    ? '请输入 1–86400 秒'
                    : '可精确到 1 秒，最长 24 小时',
              ).copyWith(
                suffixText: '秒',
                errorText: value.text.isNotEmpty && !valid
                    ? '请输入 1–86400 秒'
                    : null,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: valid ? emptyAction : null,
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
}
