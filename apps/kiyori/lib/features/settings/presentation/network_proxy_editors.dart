import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class NetworkSubscriptionEditor extends StatefulWidget {
  const NetworkSubscriptionEditor({super.key});
  @override
  State<NetworkSubscriptionEditor> createState() =>
      _NetworkSubscriptionEditorState();
}

class _NetworkSubscriptionEditorState extends State<NetworkSubscriptionEditor> {
  final name = TextEditingController();
  final url = TextEditingController();
  bool visible = false;
  @override
  void dispose() {
    name.dispose();
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nameValid = name.text.trim().length <= 80;
    final urlValid = url.text.trim().startsWith('https://');
    return AlertDialog(
      title: const Text('添加订阅地址'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '名称（可选）',
                border: const OutlineInputBorder(),
                errorText: nameValid ? null : '名称不能超过 80 个字符',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.url,
              autocorrect: false,
              obscureText: !visible,
              decoration: InputDecoration(
                labelText: 'HTTPS 订阅 URL',
                border: const OutlineInputBorder(),
                errorText: url.text.trim().isNotEmpty && !urlValid ? '' : null,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => visible = !visible),
                  tooltip: visible ? '隐藏订阅地址' : '显示订阅地址',
                  icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: nameValid && urlValid ? emptyAction : null,
          child: const Text('导入'),
        ),
      ],
    );
  }
}

class NetworkRuleEditor extends StatefulWidget {
  const NetworkRuleEditor({super.key});
  @override
  State<NetworkRuleEditor> createState() => _NetworkRuleEditorState();
}

class _NetworkRuleEditorState extends State<NetworkRuleEditor> {
  final pattern = TextEditingController();
  String type = 'DOMAIN';
  bool proxy = true;
  static const types = [
    'DOMAIN',
    'DOMAIN-SUFFIX',
    'DOMAIN-KEYWORD',
    'DOMAIN-WILDCARD',
    'DOMAIN-REGEX',
    'IP-CIDR',
    'IP-CIDR6',
    'IP-SUFFIX',
    'SRC-IP-CIDR',
    'SRC-IP-SUFFIX',
    'DST-PORT',
    'SRC-PORT',
    'IN-PORT',
    'IN-TYPE',
    'IN-USER',
    'IN-NAME',
    'REMATCH-NAME',
    'PROCESS-PATH',
    'PROCESS-PATH-WILDCARD',
    'PROCESS-PATH-REGEX',
    'PROCESS-NAME',
    'PROCESS-NAME-WILDCARD',
    'PROCESS-NAME-REGEX',
    'UID',
    'NETWORK',
    'DSCP',
    'AND',
    'OR',
    'NOT',
  ];
  static String label(String type) => switch (type) {
    'DOMAIN' => '完整域名 · DOMAIN',
    'DOMAIN-SUFFIX' => '域名后缀 · DOMAIN-SUFFIX',
    'DOMAIN-KEYWORD' => '域名关键字 · DOMAIN-KEYWORD',
    'IP-CIDR' => 'IPv4 网段 · IP-CIDR',
    'IP-CIDR6' => 'IPv6 网段 · IP-CIDR6',
    _ => type,
  };
  String get description => switch (type) {
    'DOMAIN' => '仅匹配这个完整域名',
    'DOMAIN-SUFFIX' => '匹配该域名及其所有子域名',
    'DOMAIN-KEYWORD' => '域名中包含此关键字时命中',
    'IP-CIDR' || 'IP-CIDR6' || 'SRC-IP-CIDR' => '使用 CIDR 表示法，例如 203.0.113.0/24',
    _ => '填写 $type 的 Mihomo 匹配内容',
  };
  String get example => switch (type) {
    'DOMAIN' || 'DOMAIN-SUFFIX' => '例如 example.com',
    'DOMAIN-KEYWORD' => '例如 bilibili',
    'IP-CIDR' => '例如 203.0.113.0/24',
    'IP-CIDR6' => '例如 2001:db8::/32',
    _ => '输入匹配内容',
  };

  @override
  void dispose() {
    pattern.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _validPattern(pattern.text, type);
    return AlertDialog(
      title: const Text('添加自定义规则'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: pattern,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '匹配内容',
                hintText: example,
                border: const OutlineInputBorder(),
                helperText: description,
                helperMaxLines: 4,
                errorText: pattern.text.trim().isNotEmpty && !valid
                    ? description
                    : null,
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '规则类型',
              style: TextStyle(fontSize: 13, color: PrimaryColors.secondary),
            ),
            const SizedBox(height: 10),
            PopupMenuButton<String>(
              initialValue: type,
              onSelected: (value) => setState(() => type = value),
              itemBuilder: (_) => [
                for (final item in types)
                  PopupMenuItem(
                    value: item,
                    child: Row(
                      children: [
                        Expanded(child: Text(label(item))),
                        if (item == type)
                          const Icon(Icons.check, semanticLabel: '当前类型'),
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(label(type))),
                    const Icon(
                      Icons.more_vert_outlined,
                      semanticLabel: '选择规则类型',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '匹配动作',
              style: TextStyle(fontSize: 13, color: PrimaryColors.secondary),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => proxy = true),
                    child: _RuleActionLabel('代理', selected: proxy),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => proxy = false),
                    child: _RuleActionLabel('直连', selected: !proxy),
                  ),
                ),
              ],
            ),
          ],
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
  }
}

class _RuleActionLabel extends StatelessWidget {
  const _RuleActionLabel(this.text, {required this.selected});
  final String text;
  final bool selected;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (selected) ...[
        const Icon(Icons.check, size: 14, color: PrimaryColors.accent),
        const SizedBox(width: 4),
      ],
      Flexible(
        child: Text(
          text,
          style: TextStyle(
            color: selected ? PrimaryColors.accent : PrimaryColors.text,
          ),
        ),
      ),
    ],
  );
}

/// 仅镜像输入错误外观，不解析配置、不进行 DNS 查询或改变路由。
bool _validPattern(String input, String type) {
  final pattern = input.trim().toLowerCase();
  if (pattern.isEmpty || pattern.length > 4096) return false;
  final domain = RegExp(
    r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
  );
  switch (type) {
    case 'DOMAIN':
      return domain.hasMatch(pattern);
    case 'DOMAIN-SUFFIX':
      return domain.hasMatch(
        pattern
            .replaceFirst(RegExp(r'^\*\.'), '')
            .replaceFirst(RegExp(r'^\.'), ''),
      );
    case 'DOMAIN-KEYWORD':
      return RegExp(r'^[\p{L}\p{N}._-]+$', unicode: true).hasMatch(pattern) &&
          RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(pattern);
    case 'IP-CIDR':
    case 'IP-CIDR6':
    case 'SRC-IP-CIDR':
      final parts = pattern.split('/');
      if (parts.length != 2) return false;
      final address = InternetAddress.tryParse(parts.first);
      final prefix = int.tryParse(parts.last);
      return address != null &&
          prefix != null &&
          prefix >= 0 &&
          prefix <= (address.type == InternetAddressType.IPv6 ? 128 : 32);
    case 'IP-SUFFIX':
    case 'SRC-IP-SUFFIX':
      return RegExp(r'^[0-9a-f:.]+(?:/[0-9]{1,3})?$').hasMatch(pattern);
    case 'DST-PORT':
    case 'SRC-PORT':
    case 'IN-PORT':
    case 'UID':
      return RegExp(r'^[0-9]+(?:-[0-9]+)?$').hasMatch(pattern);
    default:
      if (pattern.codeUnits.any(
        (unit) => unit < 32 || (unit >= 127 && unit <= 159),
      )) {
        return false;
      }
      return !const {
            'NETWORK',
            'IN-TYPE',
            'IN-USER',
            'IN-NAME',
            'REMATCH-NAME',
          }.contains(type) ||
          !RegExp(r'\s').hasMatch(pattern);
  }
}
