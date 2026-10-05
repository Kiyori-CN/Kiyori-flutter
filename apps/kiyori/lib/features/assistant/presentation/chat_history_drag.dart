part of 'chat_history_list.dart';

/// 一次拖动的顺序与几何投影；松手才提交，取消/目录变化回到唯一业务快照。
/// Flutter框架列表没有让位前校验入口，不能让非法置顶落点先挤动再回跳。
class _HistoryDragList extends StatefulWidget {
  const _HistoryDragList({
    required this.controller,
    required this.rows,
    required this.enabled,
    required this.canMove,
    required this.onDrop,
    required this.builder,
  });
  final ScrollController controller;
  final List<_Row> rows;
  final bool enabled;
  final bool Function(List<_Row>, Conversation) canMove;
  final Future<void> Function(Conversation, List<_Row>) onDrop;
  final Widget Function(_Row, Widget Function(Widget)?, bool) builder;
  @override
  State<_HistoryDragList> createState() => _HistoryDragListState();
}

class _HistoryDragListState extends State<_HistoryDragList>
    with TickerProviderStateMixin {
  final viewport = GlobalKey();
  final tiles = <String, _HistoryDragTileState>{};
  late List<_Row> rows;
  late List<_Row> baseline;
  _Row? origin;
  Rect? originalRect;
  Offset? start, pointer;
  OverlayEntry? proxy;
  bool active = false, layoutPending = false;
  Duration? previousTick;
  late final autoScroll = createTicker(scrollFrame);
  late final returning = AnimationController.unbounded(vsync: this)
    ..addListener(() => proxy?.markNeedsBuild())
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) clearProxy();
    });
  Offset returnFrom = Offset.zero, returnTo = Offset.zero;

  @override
  void initState() {
    super.initState();
    // 必须在首帧冻结；late求值到首次更新会把新目录误当成旧基线。
    rows = List.of(widget.rows);
    baseline = List.of(widget.rows);
  }

  @override
  void didUpdateWidget(_HistoryDragList old) {
    super.didUpdateWidget(old);
    final changed = !listEquals(baseline, widget.rows);
    if (changed || !widget.enabled && active) {
      // 等值通知不撤草稿；外部实体/分组/模式变化不能继续使用旧索引。
      baseline = List.of(widget.rows);
      final sameOrder = listEquals(
        rows.map((r) => r.key).toList(),
        widget.rows.map((r) => r.key).toList(),
      );
      // 松手后的busy和同顺序仓储回流不截断700弹簧；失败/外部重排则撤销代理。
      if (origin != null && (active || !sameOrder)) {
        abortForDirectoryChange();
      }
      rows = List.of(widget.rows);
    }
  }

  void abortForDirectoryChange() {
    active = false;
    autoScroll.stop();
    returning.stop();
    final entry = proxy;
    proxy = null;
    origin = null;
    originalRect = null;
    start = pointer = null;
    // didUpdateWidget可能在Overlay的构建过程中，帧尾释放所属代理。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      entry?.remove();
      entry?.dispose();
    });
  }

  @override
  void dispose() {
    proxy?.remove();
    proxy?.dispose();
    proxy = null;
    returning.dispose();
    autoScroll.dispose();
    super.dispose();
  }

  Rect? get viewportRect {
    final box = viewport.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  Rect? get dragRect => originalRect == null || pointer == null || start == null
      ? null
      : originalRect!.shift(pointer! - start!);

  void begin(_Row row, DragStartDetails details) {
    if (!widget.enabled || origin != null || row.item == null) return;
    final rect = tiles[row.key]?.rect;
    if (rect == null) return;
    widget.controller.jumpTo(widget.controller.offset);
    origin = row;
    originalRect = rect;
    start = pointer = details.globalPosition;
    active = true;
    returning.stop();
    unawaited(KiyoriHaptics.longPress());
    proxy = OverlayEntry(
      builder: (_) {
        final rect = dragRect;
        final bounds = viewportRect;
        if (rect == null || bounds == null || origin == null) {
          return const SizedBox.shrink();
        }
        final position = active
            ? rect.topLeft
            : returnTo + (returnFrom - returnTo) * returning.value;
        // 根Overlay仅借用绘制顺序，仍保持旧LazyColumn的内容视口裁剪。
        return Positioned.fromRect(
          rect: bounds,
          child: ClipRect(
            key: const Key('history-drag-viewport'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: position.dx - bounds.left,
                  top: position.dy - bounds.top,
                  width: rect.width,
                  height: rect.height,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Material(
                        color: Colors.transparent,
                        child: RepaintBoundary(
                          key: const Key('history-drag-proxy'),
                          child: widget.builder(origin!, null, true),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(proxy!);
    setState(() {});
    refreshAutoScroll();
  }

  void update(DragUpdateDetails details) {
    if (!active) return;
    pointer = details.globalPosition;
    proxy?.markNeedsBuild();
    moveIfNeeded();
    refreshAutoScroll();
  }

  void refreshAutoScroll() {
    final bounds = viewportRect;
    final c = widget.controller;
    final canScroll =
        active &&
        bounds != null &&
        pointer != null &&
        c.hasClients &&
        ((pointer!.dy - bounds.top < 48 &&
                c.offset > c.position.minScrollExtent) ||
            (bounds.bottom - pointer!.dy < 48 &&
                c.offset < c.position.maxScrollExtent));
    if (canScroll && !autoScroll.isActive) {
      previousTick = null;
      autoScroll.start();
    } else if (!canScroll && autoScroll.isActive) {
      autoScroll.stop();
    }
  }

  void moveIfNeeded({double edgeDirection = 0}) {
    if (!active || layoutPending) return;
    final rect = dragRect, bounds = viewportRect;
    if (rect == null || bounds == null) return;
    final from = rows.indexWhere((r) => r.key == origin!.key);
    if (from < 0) return;
    // 旧Reorderable2.5.1：拖动矩形覆盖条目中点才让位，header参与归属解析。
    final targets = <int>[];
    for (var to = 0; to < rows.length; to++) {
      if (to == from) continue;
      final target = tiles[rows[to].key]?.rect;
      if (target == null ||
          !bounds.overlaps(target) ||
          !(edgeDirection == 0
              ? rect.contains(target.center)
              : target.center.dy >= bounds.top &&
                    target.center.dy <= bounds.bottom)) {
        continue;
      }
      targets.add(to);
    }
    if (edgeDirection > 0) targets.sort((a, b) => b.compareTo(a));
    for (final to in targets) {
      if (edgeDirection > 0 && to <= from || edgeDirection < 0 && to >= from) {
        continue;
      }
      final proposed = List<_Row>.of(rows);
      proposed.insert(to, proposed.removeAt(from));
      if (!widget.canMove(proposed, origin!.item!)) continue;
      final before = positions();
      setState(() => rows = proposed);
      unawaited(KiyoriHaptics.textHandleMove());
      layoutPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        layoutPending = false;
        if (!mounted) return;
        animateNeighbours(before);
      });
      return;
    }
  }

  Map<String, double> positions() => {
    for (final entry in tiles.entries)
      if (entry.value.rect != null)
        entry.key: entry.value.rect!.top + entry.value.shift.value,
  };

  void animateNeighbours(Map<String, double> before) {
    for (final entry in before.entries) {
      final tile = tiles[entry.key];
      final now = tile?.rect;
      if (now != null && entry.key != origin?.key) {
        tile!.animateFrom(entry.value - now.top);
      }
    }
  }

  void scrollFrame(Duration elapsed) {
    final prior = previousTick;
    previousTick = elapsed;
    if (!active || prior == null || !widget.controller.hasClients) return;
    final bounds = viewportRect, stationary = tiles[origin!.key]?.rect;
    if (bounds == null || stationary == null || pointer == null) {
      autoScroll.stop();
      return;
    }
    // 旧库48dp边界：阈值处0倍、边缘5倍、越出48dp为10倍，基速viewport*0.5。
    final distanceStart = pointer!.dy - bounds.top;
    final distanceEnd = bounds.bottom - pointer!.dy;
    final direction = distanceStart < 48
        ? -1.0
        : distanceEnd < 48
        ? 1.0
        : 0.0;
    if (direction == 0) {
      refreshAutoScroll();
      return;
    }
    // 旧库滚动前把源项让到可见边缘；否则源进入keepAlive桶就丢失坐标。
    if (layoutPending) return;
    final previousRows = rows;
    moveIfNeeded(edgeDirection: direction);
    if (!identical(previousRows, rows)) return;
    final distance = direction < 0 ? distanceStart : distanceEnd;
    final multiplier = (1 - ((distance + 48) / 96).clamp(0.0, 1.0)) * 10;
    final seconds = math.min((elapsed - prior).inMicroseconds / 1e6, .1);
    final limit = direction > 0
        ? stationary.bottom - bounds.top - 1
        : bounds.bottom - stationary.top - 1;
    final amount = math.min(
      bounds.height * .5 * multiplier * seconds,
      math.max(0.0, limit),
    );
    final c = widget.controller;
    final next = (c.offset + direction * amount).clamp(
      c.position.minScrollExtent,
      c.position.maxScrollExtent,
    );
    if ((next - c.offset).abs() < .01) {
      autoScroll.stop();
      return;
    }
    c.jumpTo(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && active) {
        moveIfNeeded();
        refreshAutoScroll();
      }
    });
  }

  void finish({bool cancelled = false}) {
    if (!active) return;
    active = false;
    autoScroll.stop();
    final item = origin!;
    final changed = !listEquals(
      rows.map((r) => r.key).toList(),
      baseline.map((r) => r.key).toList(),
    );
    returnFrom = dragRect!.topLeft;
    returning.value = 1;
    final before = cancelled ? positions() : const <String, double>{};
    if (cancelled) rows = List.of(widget.rows);
    setState(() {});
    if (!cancelled && changed) {
      unawaited(widget.onDrop(item.item!, List.of(rows)));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || origin?.key != item.key) return;
      if (cancelled) animateNeighbours(before);
      final target = tiles[item.key]?.rect;
      if (target == null) {
        clearProxy();
        return;
      }
      returnTo = target.topLeft;
      final distance = (returnFrom - returnTo).distance;
      // 旧库释放spring(700, critical)，1px停止阈值；无循环空闲帧。
      returning.animateWith(
        SpringSimulation(
          SpringDescription(
            mass: 1,
            stiffness: 700,
            damping: 2 * math.sqrt(700),
          ),
          1,
          0,
          0,
          tolerance: Tolerance(
            distance: 1 / math.max(1, distance),
            velocity: 62.5 / math.max(1, distance),
          ),
        ),
      );
    });
  }

  void clearProxy() {
    proxy?.remove();
    proxy?.dispose();
    proxy = null;
    if (!mounted) return;
    setState(() {
      origin = null;
      originalRect = null;
      start = pointer = null;
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    key: viewport,
    child: ListView.builder(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rows.length,
      findChildIndexCallback: (key) {
        final index = rows.indexWhere((r) => ValueKey(r.key) == key);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) {
        final row = rows[index];
        return _HistoryDragTile(
          key: ValueKey(row.key),
          owner: this,
          row: row,
          hidden: origin?.key == row.key,
          child: widget.builder(
            row,
            (child) => RawGestureDetector(
              excludeFromSemantics: true,
              gestures:
                  widget.enabled && (origin == null || origin?.key == row.key)
                  ? {
                      _HistoryDragRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            _HistoryDragRecognizer
                          >(_HistoryDragRecognizer.new, (recognizer) {
                            recognizer.dragStartBehavior =
                                DragStartBehavior.down;
                            recognizer.onStart = (details) =>
                                begin(row, details);
                            recognizer.onUpdate = (details) {
                              if (origin?.key == row.key) update(details);
                            };
                            recognizer.onEnd = (_) {
                              if (origin?.key == row.key) {
                                finish(cancelled: recognizer.cancelled);
                              }
                            };
                            recognizer.onCancel = () {
                              if (origin?.key == row.key) {
                                finish(cancelled: true);
                              }
                            };
                          }),
                    }
                  : const {},
              child: child,
            ),
            false,
          ),
        );
      },
    ),
  );
}

/// 手柄只跟随首指；框架将已接受的PointerCancel转成onEnd，须保留取消事实。
class _HistoryDragRecognizer extends PanGestureRecognizer {
  int? pointer;
  bool cancelled = false;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      computeHitSlop(pointerDeviceKind, gestureSettings);

  @override
  bool isPointerAllowed(PointerEvent event) =>
      pointer == null && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    pointer = event.pointer;
    cancelled = false;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerCancelEvent && event.pointer == pointer) {
      cancelled = true;
    }
    super.handleEvent(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    this.pointer = null;
  }
}

class _HistoryDragTile extends StatefulWidget {
  const _HistoryDragTile({
    required this.owner,
    required this.row,
    required this.hidden,
    required this.child,
    super.key,
  });
  final _HistoryDragListState owner;
  final _Row row;
  final bool hidden;
  final Widget child;
  @override
  State<_HistoryDragTile> createState() => _HistoryDragTileState();
}

class _HistoryDragTileState extends State<_HistoryDragTile>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final shift = AnimationController.unbounded(vsync: this);
  Rect? get rect {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final position = box.localToGlobal(Offset.zero);
    // 惰性列表的keepAlive桶没有可绘制坐标；不能将NaN传给返回弹簧。
    if (!position.dx.isFinite || !position.dy.isFinite) return null;
    return position & box.size;
  }

  @override
  bool get wantKeepAlive => widget.hidden;
  @override
  void initState() {
    super.initState();
    widget.owner.tiles[widget.row.key] = this;
  }

  @override
  void didUpdateWidget(_HistoryDragTile old) {
    super.didUpdateWidget(old);
    updateKeepAlive();
  }

  void animateFrom(double offset) {
    final velocity = shift.velocity;
    shift.value = offset;
    shift.animateWith(
      SpringSimulation(
        SpringDescription(
          mass: 1,
          stiffness: 1500,
          damping: 2 * math.sqrt(1500),
        ),
        offset,
        0,
        velocity,
        tolerance: const Tolerance(distance: 1, velocity: 62.5),
      ),
    );
  }

  @override
  void dispose() {
    if (widget.owner.tiles[widget.row.key] == this) {
      widget.owner.tiles.remove(widget.row.key);
    }
    shift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: shift,
      child: IgnorePointer(
        ignoring: widget.hidden,
        child: ExcludeSemantics(
          excluding: widget.hidden,
          child: Opacity(opacity: widget.hidden ? 0 : 1, child: widget.child),
        ),
      ),
      builder: (_, child) => Transform.translate(
        offset: Offset(0, widget.hidden ? 0 : shift.value),
        child: child,
      ),
    );
  }
}
