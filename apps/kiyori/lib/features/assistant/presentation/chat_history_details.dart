import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';
import 'chat_panel_route.dart';
import 'chat_history_widgets.dart';
import 'chat_modal_session.dart';

Future<void> showHistoryDetails(
  BuildContext context,
  ChatController owner,
  Conversation item, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
  AuditExchange? exchange,
}) async {
  if (!await owner.select(item.id) || !context.mounted) return;
  final navigator = Navigator.of(context);
  final history = ModalRoute.of(context);
  final route = ChatPanelRoute(
    label: '关闭对话详情',
    builder: (context) {
      onRoute?.call(ModalRoute.of(context)!);
      return HistoryDetails(
        owner: owner,
        id: item.id,
        onRoute: onRoute,
        exchange: exchange ?? PlatformAuditExchange(),
      );
    },
  );
  if (history?.isActive == true) navigator.removeRoute(history!);
  await navigator.push(route);
}

/// 审计工作台位于AI内容区；事件、消息和修订由共享Rust存储提供。
class HistoryDetails extends StatefulWidget {
  const HistoryDetails({
    required this.owner,
    required this.id,
    required this.exchange,
    this.onRoute,
    super.key,
  });
  final ChatController owner;
  final String id;
  final AuditExchange exchange;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  @override
  State<HistoryDetails> createState() => _HistoryDetailsState();
}

class _HistoryDetailsState extends State<HistoryDetails> {
  final children = ChatModalSession();
  final search = TextEditingController();
  final expanded = <String>{};
  final events = <Map<String, dynamic>>[];
  Map<String, dynamic>? audit;
  ConversationSnapshot? snapshot;
  int tab = 0, epoch = 0;
  int? revision;
  bool loading = false;
  String? error;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    widget.owner.addListener(changed);
    unawaited(load());
  }

  void changed() {
    final item = widget.owner.catalog?.conversations
        .where((c) => c.id == widget.id)
        .firstOrNull;
    if (item == null) {
      children.invalidate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route?.isActive == true) route!.navigator?.removeRoute(route);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    } else if (revision != item.revision && !loading) {
      unawaited(load());
    }
  }

  @override
  void dispose() {
    epoch++;
    children.dispose();
    debounce?.cancel();
    search.dispose();
    widget.owner.removeListener(changed);
    super.dispose();
  }

  Future<void> load({bool older = false}) async {
    final generation = ++epoch;
    setState(() => loading = true);
    try {
      final client = await widget.owner.connect();
      final values = await Future.wait<Object>([
        client.conversationAudit(
          widget.id,
          older && events.isNotEmpty ? events.first['sequence'] as int : 0,
          tab == 0 ? search.text : '',
        ),
        client.conversation(widget.id),
      ]);
      if (!mounted || generation != epoch) return;
      final next = jsonDecode(values[0] as String) as Map<String, dynamic>;
      setState(() {
        audit = next;
        snapshot = values[1] as ConversationSnapshot;
        revision = snapshot!.conversation.revision;
        if (!older) events.clear();
        events.insertAll(
          0,
          (next['events'] as List).cast<Map<String, dynamic>>(),
        );
        error = null;
        loading = false;
      });
    } catch (failure) {
      if (mounted && generation == epoch) {
        setState(() {
          loading = false;
          error = failure is BridgeError ? failure.message : '对话详情加载失败，可重新加载。';
        });
      }
    }
  }

  void queryChanged(String value) {
    setState(expanded.clear);
    debounce?.cancel();
    if (tab == 0) {
      // 立即使旧请求失效，防止防抖等待期间回填上一个查询。
      epoch++;
      debounce = Timer(const Duration(milliseconds: 400), () => load());
    }
  }

  void back() {
    if (expanded.isNotEmpty) {
      setState(expanded.clear);
      return;
    }
    if (search.text.isNotEmpty) {
      search.clear();
      queryChanged('');
      return;
    }
    final route = ModalRoute.of(context);
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  Future<void> dialog(Widget child) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        children.registration(children.epoch)(ModalRoute.of(context)!);
        widget.onRoute?.call(ModalRoute.of(context)!);
        return child;
      },
    );
    if (mounted) await load();
  }

  void toggle(String id) => setState(() {
    if (!expanded.remove(id)) expanded.add(id);
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final messages = snapshot?.messages ?? <ConversationMessage>[];
    final query = search.text.toLowerCase();
    final filteredMessages = messages
        .where(
          (m) => '${m.role} ${m.roleName} ${m.model} ${m.content}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
    final filteredEvents = tab == 2
        ? events
              .where((e) => jsonEncode(e).toLowerCase().contains(query))
              .toList()
        : events;
    final count = tab == 1 ? filteredMessages.length : filteredEvents.length;
    final total = tab == 1 ? messages.length : events.length;
    final ids = tab == 1
        ? filteredMessages.map((m) => m.id).toList()
        : filteredEvents.map((e) => e['eventId'] as String).toList();
    final allOpen = count > 0 && ids.every(expanded.contains);
    final older = tab != 1 && audit?['hasOlder'] == true;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Material(
        color: colors.surface,
        child: SafeArea(
          child: Column(
            children: [
              _header(context, messages.length),
              const Divider(height: 1),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Semantics(
                        selected: tab == i,
                        button: true,
                        child: InkWell(
                          onTap: () {
                            debounce?.cancel();
                            setState(() {
                              tab = i;
                              expanded.clear();
                              search.clear();
                            });
                            unawaited(load());
                          },
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 10,
                                ),
                                child: Text(
                                  ['时间线', '对话', '原始事件'][i],
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 20 / 14,
                                    fontWeight: FontWeight.w500,
                                    color: tab == i
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Container(
                                height: 3,
                                color: tab == i
                                    ? colors.primary
                                    : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 42,
                      child: TextField(
                        controller: search,
                        onChanged: queryChanged,
                        decoration: InputDecoration(
                          hintText: [
                            '搜索错误、工具结果、正文或 ID',
                            '搜索消息、角色、Provider 或模型',
                            '搜索已加载事件 JSON（正文请用时间线搜索）',
                          ][tab],
                          hintStyle: const TextStyle(fontSize: 14),
                          prefixIcon: const Icon(
                            Icons.search_outlined,
                            size: 18,
                          ),
                          suffixIcon: search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '清除',
                                  onPressed: () {
                                    search.clear();
                                    queryChanged('');
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${tab == 2 ? '已加载事件：' : ''}匹配 $count / $total',
                            style: TextStyle(
                              fontSize: 11,
                              height: 16 / 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: count == 0
                              ? null
                              : () => setState(() {
                                  if (allOpen) {
                                    expanded.removeAll(ids);
                                  } else {
                                    expanded.addAll(ids);
                                  }
                                }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                allOpen ? Icons.expand_less : Icons.expand_more,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(allOpen ? '全部收起' : '全部展开'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (loading) const LinearProgressIndicator(minHeight: 2),
              if (error != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                    TextButton(
                      onPressed: () => load(),
                      child: const Text('重新加载'),
                    ),
                  ],
                ),
              Expanded(
                child: count == 0 && !loading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            search.text.isNotEmpty
                                ? '当前搜索范围内没有匹配项'
                                : tab == 1
                                ? '当前对话还没有可显示的消息'
                                : '当前对话尚无审计事件',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 18),
                        itemCount: count + (older ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (older && index == 0) {
                            return TextButton(
                              onPressed: loading
                                  ? null
                                  : () => load(older: true),
                              child: Text(loading ? '正在加载更早事件' : '加载更早事件'),
                            );
                          }
                          final offset = index - (older ? 1 : 0);
                          if (tab == 1) {
                            final m = filteredMessages[offset];
                            return _MessageCard(
                              message: m,
                              open: expanded.contains(m.id),
                              onTap: () => toggle(m.id),
                              onEdit: widget.owner.busy
                                  ? null
                                  : () => dialog(
                                      _RevisionDialog(
                                        owner: widget.owner,
                                        item: snapshot!.conversation,
                                        message: m,
                                      ),
                                    ),
                            );
                          }
                          final e = filteredEvents[offset];
                          return _EventCard(
                            key: ValueKey(e['eventId']),
                            event: e,
                            raw: tab == 2,
                            open: expanded.contains(e['eventId']),
                            onTap: () => toggle(e['eventId'] as String),
                            owner: widget.owner,
                            id: widget.id,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, int messageCount) {
    final c = Theme.of(context).colorScheme;
    final running = audit?['status'] == 'IN_PROGRESS';
    final tone = running ? c.primary : historyTone(context, IconTone.tools);
    final head = audit?['chainHead'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '对话详情',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 22, height: 28 / 22),
                    ),
                    Text(
                      '可读、可搜索的执行诊断',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 16 / 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () => dialog(
                        _ExportDialog(
                          owner: widget.owner,
                          id: widget.id,
                          exchange: widget.exchange,
                        ),
                      ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.file_download_outlined, size: 18),
                    SizedBox(width: 4),
                    Text('导出'),
                  ],
                ),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () => dialog(
                        _NoteDialog(owner: widget.owner, id: widget.id),
                      ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.note_add_outlined, size: 18),
                    SizedBox(width: 4),
                    Text('备注'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      running ? Icons.storage : Icons.warning_amber,
                      size: 16,
                      color: tone,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      running ? '进行中' : '基础记录',
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        color: tone,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${audit?['eventCount'] ?? 0} 条事件 · $messageCount 条消息 · ${audit?['payloadBytes'] ?? 0} B',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '运行环境：${audit?['runtime'] ?? 'Provider / 模型尚未记录'} · 链头：${head == null || head.isEmpty ? '历史待重建' : head.substring(0, 12)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 16 / 11,
              fontFamily: 'monospace',
              color: c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: child,
        ),
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.open,
    required this.onTap,
    required this.onEdit,
  });
  final ConversationMessage message;
  final bool open;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => _DetailsCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.role == 'user'
                        ? '用户'
                        : 'AI · variant ${message.variant}',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '消息 timestamp=${message.sentAt ?? '未知'}',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 16 / 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            if (open)
              IconButton(
                tooltip: '编辑消息',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
          ],
        ),
        const SizedBox(height: 7),
        if (open)
          _PagedText(text: message.content)
        else
          Text(
            message.content.length > 1200
                ? message.content.substring(0, 1200)
                : message.content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              fontFamily: 'monospace',
            ),
          ),
        if (open) ...[
          const Divider(),
          Text(
            'timestamp=${message.sentAt ?? '未知'} · 历史实际 Token in=${message.inputTokens ?? '未知'}, out=${message.outputTokens ?? '未知'}',
            style: const TextStyle(fontSize: 11, height: 16 / 11),
          ),
          if (message.model.isNotEmpty)
            Text(
              message.model,
              style: const TextStyle(fontSize: 11, height: 16 / 11),
            ),
        ],
      ],
    ),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.open,
    required this.onTap,
    required this.owner,
    required this.id,
    required this.raw,
    super.key,
  });
  final Map<String, dynamic> event;
  final bool open, raw;
  final VoidCallback onTap;
  final ChatController owner;
  final String id;
  @override
  Widget build(BuildContext context) => _DetailsCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${event['category']} / ${event['eventType']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Text(
              '${event['sequence']}'.padLeft(5, '0'),
              style: const TextStyle(
                fontSize: 11,
                height: 16 / 11,
                fontFamily: 'monospace',
              ),
            ),
            Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          DateTime.fromMillisecondsSinceEpoch(event['recordedAt'] as int)
              .toString(),
          style: const TextStyle(fontSize: 11, height: 16 / 11),
        ),
        const SizedBox(height: 7),
        Text(
          raw ? jsonEncode(event) : event['summary'] as String,
          maxLines: raw ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, height: 20 / 14),
        ),
        if (open) ...[
          const Divider(),
          SelectionArea(
            child: Text(
              const JsonEncoder.withIndent('  ').convert(event),
              style: const TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (!raw) _AuditPayload(owner: owner, id: id, event: event),
        ],
      ],
    ),
  );
}

class _PagedText extends StatefulWidget {
  const _PagedText({required this.text});
  final String text;
  @override
  State<_PagedText> createState() => _PagedTextState();
}

class _PagedTextState extends State<_PagedText> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    // 按Unicode scalar分段，防止8192边界切断emoji代理对；全文不截断。
    final runes = widget.text.runes.toList();
    final total = (runes.length / 8192).ceil().clamp(1, 1 << 30);
    page = page.clamp(0, total - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectionArea(
          child: Text(
            String.fromCharCodes(runes.skip(page * 8192).take(8192)),
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (total > 1)
          _PageButtons(
            page: page,
            total: total,
            length: runes.length,
            previous: () => setState(() => page--),
            next: () => setState(() => page++),
          ),
      ],
    );
  }
}

class _PageButtons extends StatelessWidget {
  const _PageButtons({
    required this.page,
    required this.total,
    required this.length,
    required this.previous,
    required this.next,
  });
  final int page, total, length;
  final VoidCallback previous, next;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '第 ${page + 1} / $total 页 · 全文 $length 字符（导出保留全文）',
        style: const TextStyle(fontSize: 11, height: 16 / 11),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: page > 0 ? previous : null,
            child: const Text('上一页'),
          ),
          TextButton(
            onPressed: page + 1 < total ? next : null,
            child: const Text('下一页'),
          ),
        ],
      ),
    ],
  );
}

class _AuditPayload extends StatefulWidget {
  const _AuditPayload({
    required this.owner,
    required this.id,
    required this.event,
  });
  final ChatController owner;
  final String id;
  final Map<String, dynamic> event;
  @override
  State<_AuditPayload> createState() => _AuditPayloadState();
}

class _AuditPayloadState extends State<_AuditPayload> {
  int page = 0, epoch = 0;
  String? text, error;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    epoch++;
    super.dispose();
  }

  Future<void> load() async {
    final generation = ++epoch;
    setState(() {
      text = null;
      error = null;
    });
    try {
      final value = await (await widget.owner.connect())
          .conversationAuditPayload(widget.id, eventSequence, page);
      if (mounted && generation == epoch) setState(() => text = value);
    } catch (_) {
      if (mounted && generation == epoch) {
        setState(() => error = '读取 payload 失败，可再次展开重试');
      }
    }
  }

  int get eventSequence => widget.event['sequence'] as int;
  @override
  Widget build(BuildContext context) {
    final length = widget.event['characters'] as int;
    final total = (length / 8192).ceil().clamp(1, 1 << 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 7),
        Text(
          '[0] 正文（application/json，字节：${widget.event['bytes']}）',
          style: const TextStyle(fontSize: 11, height: 16 / 11),
        ),
        if (error != null)
          TextButton(onPressed: load, child: Text(error!))
        else if (text == null)
          const LinearProgressIndicator()
        else
          SelectionArea(
            child: Text(
              text!,
              style: const TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        if (total > 1)
          _PageButtons(
            page: page,
            total: total,
            length: length,
            previous: () {
              page--;
              unawaited(load());
            },
            next: () {
              page++;
              unawaited(load());
            },
          ),
      ],
    );
  }
}

/// 操作尚未结束时Back、遮罩与按钮不能销毁等待者；错误保留原草稿。
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.owner, required this.id});
  final ChatController owner;
  final String id;
  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final input = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || input.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await (await widget.owner.connect()).appendConversationNote(
        widget.id,
        input.text,
      );
      if (mounted) _remove(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = _writeFailure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: HistoryAlert(
      title: '添加诊断备注',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '记录复现步骤、网络变化或预期结果，便于之后排查。备注会永久追加到审计和导出中，不发送给 AI，也不改变消息或工具结果。',
            style: TextStyle(fontSize: 12, height: 16 / 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: TextField(
              controller: input,
              enabled: !busy,
              expands: true,
              maxLines: null,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '注释内容',
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => _remove(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: busy || input.text.trim().isEmpty ? null : save,
          child: Text(busy ? '处理中…' : '追加注释'),
        ),
      ],
    ),
  );
}

class _RevisionDialog extends StatefulWidget {
  const _RevisionDialog({
    required this.owner,
    required this.item,
    required this.message,
  });
  final ChatController owner;
  final Conversation item;
  final ConversationMessage message;
  @override
  State<_RevisionDialog> createState() => _RevisionDialogState();
}

class _RevisionDialogState extends State<_RevisionDialog> {
  late final input = TextEditingController(text: widget.message.content);
  bool busy = false, failed = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() => busy = true);
    final ok = await widget.owner.changeMessage(
      widget.item,
      widget.message,
      'edit',
      input.text,
    );
    if (!mounted) return;
    if (ok) {
      _remove(context);
    } else {
      setState(() {
        busy = false;
        failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: HistoryAlert(
      title: '编辑消息',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '保存后更新当前消息，影响后续发送给 AI 的上下文与缓存前缀。原文和修订永久保留；不会重新生成后续回答、撤销已执行工具或改写历史用量。编辑工具标记可能使历史无法重放。',
            style: TextStyle(fontSize: 12, height: 16 / 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: TextField(
              controller: input,
              enabled: !busy,
              expands: true,
              maxLines: null,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '当前版本',
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (failed)
            Text(
              _writeFailure,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => _remove(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed:
              busy ||
                  input.text == widget.message.content ||
                  input.text.trim().isEmpty
              ? null
              : save,
          child: Text(busy ? '处理中…' : '保存修订'),
        ),
      ],
    ),
  );
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({
    required this.owner,
    required this.id,
    required this.exchange,
  });
  final ChatController owner;
  final String id;
  final AuditExchange exchange;
  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  bool busy = false;
  String? error;
  Future<void> save(String format) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final bytes = await (await widget.owner.connect())
          .exportConversationAudit(widget.id, format);
      try {
        if (!mounted) return;
        final ok = await widget.exchange.save(
          bytes,
          name:
              'kiyori-conversation-${DateTime.now().millisecondsSinceEpoch}.${format == 'zip' ? 'zip' : 'md'}',
          mime: format == 'zip' ? 'application/zip' : 'text/markdown',
        );
        if (!mounted) return;
        if (ok) {
          _remove(context);
        } else {
          setState(() => busy = false);
        }
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          busy = false;
          final reason = switch (failure) {
            BridgeError() => failure.message,
            TextExchangeException(code: 'unsupported') => '当前平台不支持文件导出。',
            TextExchangeException(code: 'too_large') => '导出超过64 MiB边界，原始记录未截断。',
            TextExchangeException(code: 'busy') => '另一个文件操作尚未结束，请稍后重试。',
            TextExchangeException(code: 'detached') => '文件选择器已退出，请重新打开后重试。',
            TextExchangeException(code: 'invalid_name') => '导出文件名或格式无效。',
            _ => '无法写入所选位置，请检查可用空间和访问权限后重试。',
          };
          error = '导出未完成：$reason';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: HistoryAlert(
      title: '导出对话详情',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择保存位置。包含导出时已落盘的全部记录，不受搜索和分页影响；正在生成的内容可能尚未记录。',
            style: TextStyle(fontSize: 12, height: 16 / 12),
          ),
          const SizedBox(height: 8),
          _option(
            '导出 AI 诊断（明文 Markdown）',
            'UTF-8 明文，包含消息、事件和可读 payload，适合直接交给 AI 分析；常见凭据已遮蔽，不加密。',
            'markdown',
          ),
          const SizedBox(height: 8),
          _option(
            '导出完整审计包（签名 ZIP）',
            '保留事件链和历史修订，用于验证。签名用于检查完整性，ZIP 本身不加密；分享前请检查内容。',
            'zip',
          ),
          if (busy)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(),
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => _remove(context),
          child: const Text('取消'),
        ),
      ],
    ),
  );
  Widget _option(String title, String description, String format) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: busy ? null : () => save(format),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

const _writeFailure = '保存未完成，输入内容已保留。请查看错误提示；若原消息已更新，请复制修改内容后重新打开编辑。';
void _remove(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route?.isActive == true) route!.navigator?.removeRoute(route);
}
