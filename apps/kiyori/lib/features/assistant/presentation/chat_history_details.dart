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
  final tabQueries = List.filled(3, '');
  final tabOffsets = List.filled(3, 0.0);
  late final List<ScrollController> scrolls = List.generate(
    3,
    (index) => ScrollController(
      onAttach: (position) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !position.hasContentDimensions ||
              !scrolls[index].positions.contains(position)) {
            return;
          }
          position.jumpTo(tabOffsets[index].clamp(0, position.maxScrollExtent));
        });
      },
    ),
  );
  final loaded = _HistoryAuditPage();
  final timelineSearch = _HistoryAuditPage();
  ScrollController get scroll => scrolls[tab];
  _HistoryAuditPage get page =>
      tab == 0 && search.text.trim().isNotEmpty ? timelineSearch : loaded;
  List<Map<String, dynamic>> get events => page.events;
  Map<String, dynamic>? audit;
  ConversationSnapshot? snapshot;
  int tab = 0, epoch = 0;
  int? revision;
  bool loading = false;
  int lastSequence = 0, unread = 0;
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
    for (final controller in scrolls) {
      controller.dispose();
    }
    widget.owner.removeListener(changed);
    super.dispose();
  }

  Future<void> load({bool older = false}) async {
    final generation = ++epoch;
    final target = page;
    final query = identical(target, timelineSearch) ? search.text.trim() : '';
    // 搜索页与已加载目录使用独立游标；刷新保留用户已加载的更早页。
    final first = !older && target.query == query && target.events.isNotEmpty
        ? target.events.first['sequence'] as int
        : null;
    final before = older && target.events.isNotEmpty
        ? target.events.first['sequence'] as int
        : identical(target, timelineSearch)
        ? target.cutoff ?? 0
        : 0;
    final atBottom =
        !scrolls[0].hasClients || scrolls[0].position.extentAfter < 80;
    setState(() => loading = true);
    try {
      final client = await widget.owner.connect();
      final values = await Future.wait<Object>([
        client.conversationAudit(widget.id, before, query),
        client.conversation(widget.id),
      ]);
      if (!mounted || generation != epoch) return;
      final next = jsonDecode(values[0] as String) as Map<String, dynamic>;
      final fetched = (next['events'] as List)
          .cast<Map<String, dynamic>>()
          .toList();
      var hasOlder = next['hasOlder'] == true;
      while (first != null &&
          hasOlder &&
          fetched.isNotEmpty &&
          (fetched.first['sequence'] as int) > first) {
        final previous = jsonDecode(
          await client.conversationAudit(
            widget.id,
            fetched.first['sequence'] as int,
            query,
          ),
        ) as Map<String, dynamic>;
        if (!mounted || generation != epoch) return;
        fetched.insertAll(
          0,
          (previous['events'] as List).cast<Map<String, dynamic>>(),
        );
        hasOlder = previous['hasOlder'] == true;
      }
      setState(() {
        audit = next;
        snapshot = values[1] as ConversationSnapshot;
        revision = snapshot!.conversation.revision;
        if (!older) target.events.clear();
        target.events.insertAll(0, fetched);
        target.query = query;
        target.hasOlder = hasOlder;
        target.revision = revision;
        if (identical(target, timelineSearch)) {
          target.cutoff ??= (next['eventCount'] as int) + 1;
        }
        error = null;
        loading = false;
        if (identical(target, loaded) && !older && target.events.isNotEmpty) {
          final latest = target.events.last['sequence'] as int;
          final added = target.events
              .where((e) => (e['sequence'] as int) > lastSequence)
              .length;
          if (tab == 0 &&
              search.text.trim().isEmpty &&
              (lastSequence == 0 || added > 0 && atBottom)) {
            unread = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) => jumpLatest());
          } else if (lastSequence > 0 && added > 0) {
            unread += added;
          }
          lastSequence = latest;
        }
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

  void jumpLatest() {
    if (!mounted || tab != 0 || !scrolls[0].hasClients) return;
    scrolls[0].jumpTo(scrolls[0].position.maxScrollExtent);
    tabOffsets[0] = scrolls[0].offset;
    if (unread != 0) setState(() => unread = 0);
  }

  void queryChanged(String value) {
    tabQueries[tab] = value;
    setState(() {});
    debounce?.cancel();
    if (tab == 0) {
      // 立即使旧请求失效，防止防抖等待期间回填上一个查询。
      epoch++;
      timelineSearch.events.clear();
      timelineSearch.hasOlder = false;
      timelineSearch.cutoff = null;
      loading = value.trim().isNotEmpty;
      if (value.trim().isNotEmpty) {
        debounce = Timer(const Duration(milliseconds: 400), () => load());
      } else {
        unawaited(load());
      }
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
      // ModalBarrier使用maybePop；各弹窗PopScope在保存中拒绝，空闲沿旧遮罩退出。
      barrierDismissible: true,
      builder: (context) {
        children.registration(children.epoch)(ModalRoute.of(context)!);
        widget.onRoute?.call(ModalRoute.of(context)!);
        return SettingsTheme(child: child);
      },
    );
    if (mounted) await load();
  }

  void toggle(String id) => setState(() {
    if (!expanded.remove(id)) expanded.add(id);
  });
  void selectTab(int next) {
    if (next == tab) return;
    debounce?.cancel();
    tabQueries[tab] = search.text;
    if (scroll.hasClients) tabOffsets[tab] = scroll.offset;
    setState(() {
      tab = next;
      // 旧SaveableStateProvider恢复查询和列表；remember展开集随标签离开释放。
      expanded.clear();
      search.text = tabQueries[next];
      epoch++;
      loading = false;
    });
    final item = widget.owner.catalog?.conversations
        .where((c) => c.id == widget.id)
        .firstOrNull;
    if (audit == null ||
        item?.revision != page.revision ||
        identical(page, timelineSearch) && page.query != search.text.trim()) {
      unawaited(load());
    }
  }

  @override
  Widget build(BuildContext context) =>
      SettingsTheme(child: Builder(builder: buildDetails));

  Widget buildDetails(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final messages = (snapshot?.messages ?? <ConversationMessage>[])
        .where(
          (message) => message.role == 'user' || message.role == 'assistant',
        )
        .toList();
    final query = search.text.trim().toLowerCase();
    final filteredMessages = messages
        .where(
          (m) =>
              '${m.role == 'assistant' ? 'ai' : m.role} ${m.roleName} ${m.model} ${m.content} ${m.sentAt}'
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
    final older = tab != 1 && page.hasOlder;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Material(
        color: PrimaryColors.of(context).background,
        child: SafeArea(
          child: Column(
            children: [
              _header(context, messages.length),
              const Divider(height: 1),
              Material(
                color: colors.surface,
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: Semantics(
                          selected: tab == i,
                          button: true,
                          child: InkWell(
                            onTap: () => selectTab(i),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
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
                                    decoration: BoxDecoration(
                                      color: tab == i
                                          ? colors.primary
                                          : Colors.transparent,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3),
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
                ),
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
                            '${tab == 2 || tab == 0 && search.text.trim().isEmpty ? '已加载事件：' : ''}匹配 $count / $total',
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
              if (tab == 0 && search.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    error != null
                        ? '搜索未完成，已找到的结果保留；请重试，不能将此状态视为没有匹配。'
                        : '搜索全部已记录事件与文本附件；空格分隔多个关键词。结果为搜索开始时的历史，清空后可重新搜索。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: error != null
                          ? colors.error
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
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
                ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    count == 0 && !loading && !older
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                search.text.isNotEmpty
                                    ? '当前搜索范围内没有匹配项'
                                    : tab == 1
                                    ? '当前对话还没有可显示的消息'
                                    : '当前对话尚无审计事件',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            key: ValueKey('history-details-list-$tab'),
                            controller: scroll,
                            padding: const EdgeInsets.only(bottom: 18),
                            itemCount:
                                count + (older ? 1 : 0) + (count == 0 ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (count == 0 && index == 0) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('已加载的事件中没有匹配结果，可继续加载更早的事件。'),
                                );
                              }
                              if (older && index == (count == 0 ? 1 : 0)) {
                                return TextButton(
                                  onPressed: loading
                                      ? null
                                      : () => load(older: true),
                                  child: Text(
                                    loading
                                        ? '正在加载更早事件'
                                        : identical(page, timelineSearch)
                                        ? '继续搜索'
                                        : '加载更早事件',
                                  ),
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
                                query: tab == 0 ? search.text.trim() : '',
                              );
                            },
                          ),
                    if (tab == 0 && search.text.trim().isEmpty && unread > 0)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Material(
                            color: colors.primary,
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: jumpLatest,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 18,
                                      color: colors.onPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$unread 条新事件',
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 20 / 14,
                                        fontWeight: FontWeight.w500,
                                        color: colors.onPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '对话详情',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 22, height: 28 / 22),
                    ),
                    Text(
                      '可读、可搜索的执行诊断',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
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
              const SizedBox(width: 4),
              TextButton(
                onPressed: loading
                    ? null
                    : () => dialog(
                        _NoteDialog(owner: widget.owner, id: widget.id),
                      ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.note_add,
                      size: 18,
                      color: PrimaryColors.of(context).muted,
                    ),
                    const SizedBox(width: 4),
                    const Text('备注'),
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
                  borderRadius: BorderRadius.circular(12),
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
                  '${audit?['eventCount'] ?? 0} 条事件 · $messageCount 条消息 · ${_payloadSize(audit?['payloadBytes'] as int? ?? 0)}',
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

class _HistoryAuditPage {
  final events = <Map<String, dynamic>>[];
  String query = '';
  bool hasOlder = false;
  int? revision, cutoff;
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                    style: TextStyle(
                      fontSize: 11,
                      height: 16 / 11,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (open)
              IconButton(
                tooltip: '编辑消息',
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: PrimaryColors.of(context).muted,
            ),
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
            style: TextStyle(
              fontSize: 11,
              height: 16 / 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (message.model.isNotEmpty)
            Text(
              message.model,
              style: TextStyle(
                fontSize: 11,
                height: 16 / 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
    this.query = '',
    super.key,
  });
  final Map<String, dynamic> event;
  final bool open, raw;
  final VoidCallback onTap;
  final ChatController owner;
  final String id;
  final String query;
  @override
  Widget build(BuildContext context) => raw
      ? _raw(context)
      : _DetailsCard(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${event['sequence']}'.padLeft(5, '0'),
                    style: TextStyle(
                      fontSize: 11,
                      height: 16 / 11,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${event['category']} / ${event['eventType']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _eventTime(event['recordedAt'] as int),
                    style: TextStyle(
                      fontSize: 11,
                      height: 16 / 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: PrimaryColors.of(context).muted,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              SelectionArea(
                // Flutter选区的tap会胜过外层InkWell；内层tap保留旧单击展开，长按仍选字。
                child: GestureDetector(
                  onTap: onTap,
                  excludeFromSemantics: true,
                  child: Text(
                    event['summary'] as String,
                    maxLines: open ? null : 2,
                    overflow: open ? TextOverflow.clip : TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 20 / 14),
                  ),
                ),
              ),
              if (event['terminalState'] != null) ...[
                const SizedBox(height: 7),
                Text(
                  event['terminalState'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    height: 16 / 11,
                    color: event['terminalState'] == 'COMPLETED'
                        ? historyTone(context, IconTone.success)
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (open) ...[
                const SizedBox(height: 7),
                const Divider(height: 1),
                const SizedBox(height: 7),
                SelectionArea(
                  child: Text(
                    'eventId=${event['eventId']}\n'
                    'actor=${event['actor'] ?? '—'}\n'
                    'localExecutionId=${event['localExecutionId'] ?? '—'}\n'
                    'providerCallId=${event['providerCallId'] ?? '—'}\n'
                    'parentEventId=${event['parentEventId'] ?? '—'}\n'
                    'occurredAt=${DateTime.fromMillisecondsSinceEpoch(event['recordedAt'] as int, isUtc: true).toIso8601String()}\n'
                    'eventSha256=${event['eventSha256']}\n'
                    'previousEventSha256=${event['previousEventSha256']}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _AuditPayload(owner: owner, id: id, event: event, query: query),
              ],
            ],
          ),
        );

  Widget _raw(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: open
            ? colors.surfaceContainerLow
            : PrimaryColors.of(context).background,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    '${event['sequence']}'.padLeft(5, ' '),
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      fontFamily: 'monospace',
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event['category']} / ${event['eventType']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w500,
                          color: colors.primary,
                        ),
                      ),
                      SelectionArea(
                        child: Text(
                          open
                              ? const JsonEncoder.withIndent('  ')
                                    .convert(event)
                              : jsonEncode(event),
                          maxLines: open ? null : 3,
                          overflow: open
                              ? TextOverflow.clip
                              : TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            fontFamily: 'monospace',
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: PrimaryColors.of(context).muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _eventTime(int timestamp) {
  final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(time.month)}-${pad(time.day)} ${pad(time.hour)}:${pad(time.minute)}:${pad(time.second)}';
}

String _payloadSize(int bytes) {
  const units = ['B', 'kB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value > 900 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final digits = unit == 0 || value >= 100
      ? 0
      : value >= 10
      ? 1
      : 2;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

class _PagedText extends StatefulWidget {
  const _PagedText({required this.text, this.query = ''});
  final String text;
  final String query;
  @override
  State<_PagedText> createState() => _PagedTextState();
}

class _PagedTextState extends State<_PagedText> {
  int page = 0;
  @override
  void initState() {
    super.initState();
    locateMatch();
  }

  @override
  void didUpdateWidget(_PagedText old) {
    super.didUpdateWidget(old);
    if (old.text.length != widget.text.length || old.query != widget.query) {
      locateMatch();
    }
  }

  void locateMatch() {
    final text = widget.text.toLowerCase();
    final matches = widget.query
        .split(RegExp(r'\s+'))
        .where((q) => q.isNotEmpty)
        .map((q) => text.indexOf(q.toLowerCase()))
        .where((index) => index >= 0);
    page = matches.isEmpty
        ? 0
        : matches.reduce((a, b) => a < b ? a : b) ~/ 12000;
  }

  @override
  Widget build(BuildContext context) {
    // 旧页按12000个UTF-16单元计算；相邻页同时左移代理对边界，无丢字/重复。
    final text = widget.text;
    final total = (text.length / 12000).ceil().clamp(1, 1 << 30);
    page = page.clamp(0, total - 1);
    int boundary(int offset) {
      var at = offset.clamp(0, text.length);
      if (at > 0 &&
          at < text.length &&
          text.codeUnitAt(at) >= 0xdc00 &&
          text.codeUnitAt(at) <= 0xdfff &&
          text.codeUnitAt(at - 1) >= 0xd800 &&
          text.codeUnitAt(at - 1) <= 0xdbff) {
        at--;
      }
      return at;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectionArea(
          child: Text(
            text.substring(
              boundary(page * 12000),
              boundary((page + 1) * 12000),
            ),
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (total > 1)
          _PageButtons(
            page: page,
            total: total,
            length: text.length,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    required this.query,
  });
  final ChatController owner;
  final String id;
  final Map<String, dynamic> event;
  final String query;
  @override
  State<_AuditPayload> createState() => _AuditPayloadState();
}

class _AuditPayloadState extends State<_AuditPayload> {
  int epoch = 0;
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
      final client = await widget.owner.connect();
      final buffer = StringBuffer();
      // 传输沿用8192个SQLite字符的有界分片；展示按旧12000个UTF-16单元分页。
      // 读取与缓存随可见展开行存活，收起/离屏后不继续请求和回填。
      final chunks = ((widget.event['characters'] as int) / 8192).ceil().clamp(
        1,
        1 << 30,
      );
      for (var chunk = 0; chunk < chunks; chunk++) {
        if (!mounted || generation != epoch) return;
        final value = await client.conversationAuditPayload(
          widget.id,
          eventSequence,
          chunk,
        );
        if (!mounted || generation != epoch) return;
        buffer.write(value);
      }
      setState(() => text = buffer.toString());
    } catch (failure) {
      if (mounted && generation == epoch) {
        // 只保留异常类型，沿旧源提示重试；不把可能含路径/凭据的异常正文放进界面。
        setState(
          () => error = '读取 payload 失败，可再次展开重试：\n${failure.runtimeType}',
        );
      }
    }
  }

  int get eventSequence => widget.event['sequence'] as int;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (error != null) ...[
          SelectionArea(
            child: Text(
              error!,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: load, child: const Text('重新加载详情')),
        ] else if (text == null)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
          SelectionArea(
            child: Text(
              '[0] 正文（application/json，字节：${widget.event['bytes']}）',
              style: const TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _PagedText(text: text!, query: widget.query),
        ],
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
        input.text.trim(),
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
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: _AuditInput(
              controller: input,
              enabled: !busy,
              onChanged: (_) => setState(() {}),
              placeholder: '注释内容',
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
    if (busy || widget.owner.busy) return;
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.owner,
    builder: (context, _) => PopScope(
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
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: _AuditInput(
                controller: input,
                enabled: !busy,
                onChanged: (_) => setState(() {}),
                placeholder: '当前版本',
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
                    widget.owner.busy ||
                    input.text == widget.message.content
                ? null
                : save,
            child: Text(busy ? '处理中…' : '保存修订'),
          ),
        ],
      ),
    ),
  );
}

class _AuditInput extends StatelessWidget {
  const _AuditInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.placeholder,
  });
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String placeholder;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    expands: true,
    maxLines: null,
    textAlignVertical: TextAlignVertical.top,
    onChanged: onChanged,
    style: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      color: Theme.of(context).colorScheme.onSurface,
    ),
    decoration: InputDecoration(
      hintText: placeholder,
      hintStyle: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      filled: true,
      fillColor: PrimaryColors.of(context).background,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
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
              'kiyori-conversation-${DateTime.now().millisecondsSinceEpoch}.${format == 'zip' ? 'kiyori-audit' : 'md'}',
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
          Text(
            '选择保存位置。包含导出时已落盘的全部记录，不受搜索和分页影响；正在生成的内容可能尚未记录。',
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
    color: PrimaryColors.of(context).background,
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
