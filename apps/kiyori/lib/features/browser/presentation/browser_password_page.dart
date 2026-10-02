import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'browser_credentials_presentation.dart';
import 'browser_credential_dialog.dart';

class BrowserPasswordPage extends StatefulWidget {
  const BrowserPasswordPage({
    this.snapshot = const BrowserCredentialsPresentation(),
    super.key,
  });
  final BrowserCredentialsPresentation snapshot;
  @override
  State<BrowserPasswordPage> createState() => _BrowserPasswordPageState();
}

class _BrowserPasswordPageState extends State<BrowserPasswordPage> {
  final search = TextEditingController();
  late final presentation = ValueNotifier(widget.snapshot);
  final _identities = <String, Object>{};
  final _routes = <DialogRoute<CredentialAction>, String>{};
  List<BrowserCredentialSummary> filtered = [];
  BrowserCredentialsPresentation get snapshot => widget.snapshot;
  @override
  void initState() {
    super.initState();
    _reconcile();
    search.addListener(_search);
  }

  void _search() => setState(_filter);
  void _filter() {
    final query = search.text.trim().toLowerCase();
    filtered = snapshot.credentials
        .where(
          (item) =>
              query.isEmpty ||
              [
                item.host,
                item.origin,
                item.pageUrl,
                item.username,
              ].any((value) => value.toLowerCase().contains(query)),
        )
        .toList();
  }

  void _reconcile() {
    final ids = snapshot.credentials.map((item) => item.id).toSet();
    _identities.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      _identities.putIfAbsent(id, Object.new);
    }
    _filter();
  }

  @override
  void didUpdateWidget(covariant BrowserPasswordPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcile();
    final stale = _routes.entries
        .where(
          (entry) =>
              !snapshot.available ||
              snapshot.loading ||
              !_identities.containsKey(entry.value) ||
              !snapshot.details.containsKey(entry.value),
        )
        .map((entry) => entry.key)
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in stale.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
      if (mounted) presentation.value = snapshot;
    });
  }

  Future<void> _open(
    String id, [
    CredentialAction mode = CredentialAction.detail,
  ]) async {
    if (_routes.isNotEmpty ||
        !snapshot.available ||
        snapshot.loading ||
        !snapshot.details.containsKey(id) ||
        !_identities.containsKey(id)) {
      return;
    }
    final token = _identities[id];
    final initial = snapshot.details[id]!;
    final route = DialogRoute<CredentialAction>(
      context: context,
      builder: (_) => ValueListenableBuilder(
        valueListenable: presentation,
        builder: (_, value, _) => SettingsTheme(
          child: BrowserCredentialDialog(
            detail: value.details[id] ?? initial,
            mode: mode,
          ),
        ),
      ),
    );
    _routes[route] = id;
    final action = await Navigator.of(context).push(route);
    _routes.remove(route);
    if (!mounted ||
        action == null ||
        !identical(token, _identities[id]) ||
        !snapshot.available) {
      return;
    }
    await _open(id, action);
  }

  @override
  void dispose() {
    final routes = _routes.keys.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
      presentation.dispose();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    search.dispose();
    super.dispose();
  }

  Widget _message(String text, {bool error = false}) => Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 19 / 13,
          color: error
              ? Theme.of(context).colorScheme.error
              : PrimaryColors.of(context).secondary,
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '网站密码管理',
    children: [
      SettingsGroup(
        title: '保存与填充',
        description: '凭据仅保存在本机普通窗口；无痕窗口不会读取、保存或自动填充',
        children: [
          SettingsRow(
            title: '自动保存网站密码',
            description: '提交包含一个密码字段的登录表单时，安全保存或更新该网站账号',
            checked: snapshot.savingEnabled,
            enabled: snapshot.available || snapshot.savingEnabled,
          ),
          const SettingsDivider(),
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.loading
                        ? '正在解锁'
                        : snapshot.available
                        ? '本机加密'
                        : '保险库不可用',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: snapshot.loading || snapshot.available
                          ? null
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      snapshot.loading || snapshot.available
                          ? snapshot.securityDescription
                          : snapshot.error,
                      style: TextStyle(
                        fontSize: 12,
                        height: 17 / 12,
                        color: PrimaryColors.of(context).secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      SettingsGroup(
        title: '已保存的网站',
        description: snapshot.loading
            ? '正在解锁本机密码保险库'
            : snapshot.available
            ? '共 ${snapshot.credentials.length} 项；按网站或账号搜索，点击条目查看详情'
            : '密码保险库当前不可用，已保存内容不会以明文方式打开',
        children: [
          if (snapshot.loading)
            _message('正在解锁本机凭据…')
          else if (!snapshot.available)
            _message(snapshot.error, error: true)
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: KiyoriSearchField(controller: search, hint: '搜索网站或账号'),
            ),
            const SettingsDivider(),
            if (filtered.isEmpty)
              _message(
                search.text.trim().isEmpty
                    ? '暂无已保存的网站密码。开启自动保存后，在普通窗口提交登录表单即可建立记录。'
                    : '没有匹配的网站或账号',
              ),
            for (var i = 0; i < filtered.length; i++) ...[
              if (i > 0) const SettingsDivider(),
              SettingsRow(
                key: ValueKey(filtered[i].id),
                title: filtered[i].host,
                description: filtered[i].username,
                value: '查看',
                onTap: () => unawaited(_open(filtered[i].id)),
              ),
            ],
          ],
        ],
      ),
    ],
  );
}
