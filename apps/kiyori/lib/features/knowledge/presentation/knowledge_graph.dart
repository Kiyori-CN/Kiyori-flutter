import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'graph_layout.dart';
import 'knowledge_controller.dart';
import 'memory_link_editor.dart';

class KnowledgeGraphView extends StatefulWidget {
  const KnowledgeGraphView({
    required this.controller,
    required this.onNode,
    super.key,
  });
  final KnowledgeController controller;
  final void Function(String space, String id) onNode;
  @override
  State<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView> {
  final routes = <DialogRoute<dynamic>>[];
  final labels = <String, TextPainter>{};
  final edgeLabels = <String, TextPainter>{};
  Map<String, Offset> positions = {};
  MemoryGraph? laidOut;
  Size size = Size.zero;
  Size laidOutSize = Size.zero;
  bool layoutRunning = false, modal = false, linking = false, selecting = false;
  String? layoutError;
  final selected = <String>{};
  String? first;
  Offset offset = Offset.zero,
      gestureOffset = Offset.zero,
      gestureFocal = Offset.zero;
  Offset? boxStart, boxEnd;
  double scale = 1, gestureScale = 1;
  KnowledgeController get state => widget.controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final painter in labels.values) {
      painter.dispose();
    }
    labels.clear();
    for (final painter in edgeLabels.values) {
      painter.dispose();
    }
    edgeLabels.clear();
  }

  @override
  void didUpdateWidget(covariant KnowledgeGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final graph = state.graph;
    final valid = {...?graph?.nodes.map((n) => n.id)};
    selected.removeWhere((id) => !valid.contains(id));
    if (!valid.contains(first)) first = null;
    for (final id in labels.keys.where((id) => !valid.contains(id)).toList()) {
      labels.remove(id)?.dispose();
    }
    final relations = {...?graph?.edges.map((e) => e.draft.relation)};
    for (final relation
        in edgeLabels.keys.where((r) => !relations.contains(r)).toList()) {
      edgeLabels.remove(relation)?.dispose();
    }
  }

  Future<T?> dialog<T>(WidgetBuilder builder) async {
    if (!mounted) return null;
    final route = DialogRoute<T>(context: context, builder: builder);
    routes.add(route);
    final result = await Navigator.of(context).push(route);
    await route.completed;
    routes.remove(route);
    return mounted ? result : null;
  }

  void scheduleLayout(Size value) {
    final graph = state.graph;
    if (graph == null || value.isEmpty) return;
    if (laidOutSize == value && sameTopology(laidOut, graph)) return;
    size = value;
    if (layoutRunning) return;
    layoutRunning = true;
    layoutError = null;
    final request = graph;
    final viewport = size;
    unawaited(
      compute(
        layoutMemoryGraph,
        GraphLayoutInput(
          graph.nodes.map((n) => n.id).toList(),
          graph.edges
              .map(
                (e) => (
                  e.draft.sourceId,
                  e.draft.targetId,
                  e.draft.weight,
                  e.crossFolder,
                ),
              )
              .toList(),
          positions,
          viewport,
        ),
      ).then(
        (value) {
          if (!mounted) return;
          layoutRunning = false;
          if (sameTopology(state.graph, request)) {
            setState(() {
              positions = value;
              laidOut = state.graph;
              laidOutSize = viewport;
            });
          }
          if (!sameTopology(state.graph, request) || size != viewport) {
            scheduleLayout(size);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!mounted) return;
          layoutRunning = false;
          setState(() {
            laidOut = request;
            laidOutSize = viewport;
            layoutError = '图谱布局失败，请重试。';
          });
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'knowledge graph layout',
            ),
          );
        },
      ),
    );
  }

  TextPainter label(GraphNode node) {
    final old = labels[node.id];
    if (old?.text?.toPlainText() == node.title) return old!;
    old?.dispose();
    final painter = TextPainter(
      text: TextSpan(
        text: node.title,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          fontSize: 11.5,
          height: 12.5 / 11.5,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFE5E7EB)
              : const Color(0xFF1F2937),
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    painter.layout(maxWidth: 280);
    labels[node.id] = painter;
    return painter;
  }

  Rect rect(GraphNode node) {
    final painter = label(node);
    final center =
        (positions[node.id] ?? Offset(size.width / 2, size.height / 2)) *
            scale +
        offset;
    final visual = scale.clamp(.15, 2.2);
    return Rect.fromCenter(
      center: center,
      width: (painter.width + 28) * visual,
      height: (painter.height + 8) * visual,
    );
  }

  void transform(double value, Offset focal) {
    final next = value.clamp(.2, 5.0);
    setState(() {
      offset = (offset - focal) * (next / scale) + focal;
      scale = next;
    });
  }

  Future<void> tap(Offset point) async {
    final graph = state.graph;
    if (graph == null || state.saving || state.loading || modal) return;
    for (final node in graph.nodes.reversed) {
      if (!rect(node).inflate(12).contains(point)) continue;
      if (selecting) {
        setState(() {
          if (!selected.remove(node.id)) selected.add(node.id);
        });
        return;
      }
      if (!linking) {
        widget.onNode(graph.spaceId, node.id);
        return;
      }
      if (first == node.id) {
        setState(() => first = null);
        return;
      }
      if (first == null) {
        setState(() => first = node.id);
        return;
      }
      final source = graph.nodes.where((n) => n.id == first).firstOrNull;
      if (source == null) return;
      modal = true;
      final saved = await dialog<bool>(
        (_) => MemoryLinkEditor(
          controller: state,
          space: graph.spaceId,
          source: source,
          target: node,
        ),
      );
      if (!mounted) return;
      setState(() {
        modal = false;
        if (saved == true) {
          first = null;
          linking = false;
        }
      });
      return;
    }
    if (linking || selecting) return;
    for (final edge in graph.edges.reversed) {
      final a = positions[edge.draft.sourceId],
          b = positions[edge.draft.targetId];
      if (a == null || b == null) continue;
      if (distanceToSegment(point, a * scale + offset, b * scale + offset) >
          10) {
        continue;
      }
      await edgeInfo(graph, edge);
      return;
    }
  }

  Future<void> edgeInfo(MemoryGraph graph, MemoryLink edge) async {
    final source = graph.nodes
        .where((n) => n.id == edge.draft.sourceId)
        .firstOrNull;
    final target = graph.nodes
        .where((n) => n.id == edge.draft.targetId)
        .firstOrNull;
    if (source == null || target == null) return;
    modal = true;
    final action = await dialog<String>(
      (context) => AlertDialog(
        title: const Text('关联详情'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text('从：${source.title}'),
              Text('到：${target.title}'),
              const Divider(),
              Text('类型：${edge.draft.relation}'),
              Text('权重：${edge.draft.weight}'),
              if (edge.draft.description.isNotEmpty)
                Text(edge.draft.description),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'edit'),
            child: const Text('编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('删除'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await dialog<bool>(
        (_) => MemoryLinkEditor(
          controller: state,
          space: graph.spaceId,
          source: source,
          target: target,
          link: edge,
        ),
      );
    } else if (action == 'delete') {
      await state.deleteLink(graph.spaceId, edge.id);
    }
    if (mounted) setState(() => modal = false);
  }

  Future<void> deleteSelected() async {
    final graph = state.graph;
    if (graph == null || selected.isEmpty || state.saving || modal) return;
    final ids = selected.toList();
    modal = true;
    final accepted = await dialog<bool>(
      (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除选中的 ${ids.length} 个条目及关联？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      final saved = await state.deleteNodes(graph.spaceId, ids);
      if (saved && mounted) setState(selected.clear);
    }
    if (mounted) setState(() => modal = false);
  }

  @override
  void dispose() {
    final owned = routes.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in owned) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    for (final painter in labels.values) {
      painter.dispose();
    }
    for (final painter in edgeLabels.values) {
      painter.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final graph = state.graph;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '图谱显示当前结果的前 200 项；完整结果可在列表查看。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              scheduleLayout(constraints.biggest);
              if (graph == null) {
                return state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : const SizedBox.shrink();
              }
              final rectangles = {for (final n in graph.nodes) n.id: rect(n)};
              for (final edge in graph.edges) {
                edgeLabels.putIfAbsent(
                  edge.draft.relation,
                  () => TextPainter(
                    text: TextSpan(
                      text: edge.draft.relation,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: 240),
                );
              }
              final blocked = state.saving || state.loading || modal;
              return Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent &&
                            !blocked &&
                            !selecting) {
                          transform(
                            scale * math.exp(-event.scrollDelta.dy * .001),
                            event.localPosition,
                          );
                        }
                      },
                      child: GestureDetector(
                        dragStartBehavior: DragStartBehavior.down,
                        behavior: HitTestBehavior.opaque,
                        onTapUp: blocked
                            ? null
                            : (details) =>
                                  unawaited(tap(details.localPosition)),
                        onScaleStart: blocked || selecting
                            ? null
                            : (d) {
                                gestureScale = scale;
                                gestureOffset = offset;
                                gestureFocal = d.localFocalPoint;
                              },
                        onScaleUpdate: blocked || selecting
                            ? null
                            : (d) {
                                setState(() {
                                  scale = (gestureScale * d.scale).clamp(
                                    .2,
                                    5.0,
                                  );
                                  offset =
                                      (gestureOffset - gestureFocal) *
                                          (scale / gestureScale) +
                                      d.localFocalPoint;
                                });
                              },
                        onPanStart: blocked || !selecting
                            ? null
                            : (d) => setState(() {
                                boxStart = d.localPosition;
                                boxEnd = d.localPosition;
                              }),
                        onPanUpdate: blocked || !selecting
                            ? null
                            : (d) => setState(() => boxEnd = d.localPosition),
                        onPanCancel: blocked || !selecting
                            ? null
                            : () => setState(() {
                                boxStart = null;
                                boxEnd = null;
                              }),
                        onPanEnd: blocked || !selecting
                            ? null
                            : (_) {
                                setState(() {
                                  if (boxStart != null && boxEnd != null) {
                                    final box = Rect.fromPoints(
                                      boxStart!,
                                      boxEnd!,
                                    );
                                    selected.addAll(
                                      rectangles.entries
                                          .where((e) => box.overlaps(e.value))
                                          .map((e) => e.key),
                                    );
                                  }
                                  boxStart = null;
                                  boxEnd = null;
                                });
                              },
                        child: CustomPaint(
                          painter: _GraphPainter(
                            graph,
                            rectangles,
                            labels,
                            edgeLabels,
                            colors,
                            selected,
                            first,
                            scale,
                            boxStart == null || boxEnd == null
                                ? null
                                : Rect.fromPoints(boxStart!, boxEnd!),
                            (point) => unawaited(tap(point)),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  if (graph.nodes.isEmpty) const Center(child: Text('没有找到内容')),
                  if (layoutError != null)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(layoutError!),
                          TextButton(
                            onPressed: () => setState(() => laidOut = null),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  if (state.loading)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (graph.nodes.isNotEmpty)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Column(
                        spacing: 8,
                        children: [
                          if (selecting && selected.isNotEmpty)
                            action(
                              '删除选中节点',
                              Icons.delete_outline,
                              colors.errorContainer,
                              blocked ? null : deleteSelected,
                            ),
                          action(
                            '框选节点',
                            Icons.select_all,
                            selecting
                                ? colors.tertiaryContainer
                                : colors.secondaryContainer,
                            blocked
                                ? null
                                : () => setState(() {
                                    selecting = !selecting;
                                    linking = false;
                                    first = null;
                                    selected.clear();
                                  }),
                          ),
                          action(
                            '连接节点',
                            Icons.link,
                            linking
                                ? colors.secondaryContainer
                                : colors.primaryContainer,
                            blocked
                                ? null
                                : () => setState(() {
                                    linking = !linking;
                                    selecting = false;
                                    selected.clear();
                                    first = null;
                                  }),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget action(
    String label,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) => SizedBox.square(
    dimension: 48,
    child: FloatingActionButton.small(
      heroTag: null,
      tooltip: label,
      backgroundColor: color,
      onPressed: onPressed,
      child: Icon(icon),
    ),
  );
}

double distanceToSegment(Offset p, Offset a, Offset b) {
  final delta = b - a;
  if (delta.distanceSquared < .001) return (p - a).distance;
  final t =
      (((p - a).dx * delta.dx + (p - a).dy * delta.dy) / delta.distanceSquared)
          .clamp(0.0, 1.0);
  return (p - a - delta * t).distance;
}

bool sameTopology(MemoryGraph? a, MemoryGraph? b) {
  if (a != null && identical(a, b)) return true;
  return a != null &&
      b != null &&
      a.spaceId == b.spaceId &&
      listEquals(
        a.nodes.map((n) => n.id).toList(),
        b.nodes.map((n) => n.id).toList(),
      ) &&
      listEquals(
        a.edges
            .map(
              (e) => (
                e.id,
                e.draft.sourceId,
                e.draft.targetId,
                e.draft.weight,
                e.crossFolder,
              ),
            )
            .toList(),
        b.edges
            .map(
              (e) => (
                e.id,
                e.draft.sourceId,
                e.draft.targetId,
                e.draft.weight,
                e.crossFolder,
              ),
            )
            .toList(),
      );
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(
    this.graph,
    this.rects,
    this.labels,
    this.edgeLabels,
    this.colors,
    this.selected,
    this.first,
    this.scale,
    this.box,
    this.onTap,
  );
  final MemoryGraph graph;
  final Map<String, Rect> rects;
  final Map<String, TextPainter> labels;
  final Map<String, TextPainter> edgeLabels;
  final ColorScheme colors;
  final Set<String> selected;
  final String? first;
  final double scale;
  final Rect? box;
  final ValueChanged<Offset> onTap;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final edge in graph.edges) {
      final a = rects[edge.draft.sourceId]?.center,
          b = rects[edge.draft.targetId]?.center;
      if (a == null || b == null) continue;
      final paint = Paint()
        ..color = colors.outline
        ..strokeWidth = math.max(
          .5,
          math.min(
            edge.crossFolder ? 8.0 : 18.0,
            edge.draft.weight * (edge.crossFolder ? 2.6 : 5.8) * scale,
          ),
        );
      if (edge.crossFolder) {
        final distance = (b - a).distance;
        for (var d = 0.0; d < distance; d += 12) {
          canvas.drawLine(
            a + (b - a) * (d / distance),
            a + (b - a) * (math.min(d + 6, distance) / distance),
            paint,
          );
        }
      } else {
        canvas.drawLine(a, b, paint);
      }
      final label = edgeLabels[edge.draft.relation]!;
      canvas.save();
      canvas.translate((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      canvas.scale(scale.clamp(.25, 2.0));
      label.paint(
        canvas,
        Offset(-label.width / 2, b.dx >= a.dx ? -label.height : 0),
      );
      canvas.restore();
    }
    for (final node in graph.nodes) {
      final rect = rects[node.id]!;
      if (!rect.inflate(6).overlaps(Offset.zero & size)) continue;
      final radius = Radius.circular(
        math.min(rect.height * .48, 20 * scale.clamp(.15, 2.2)),
      );
      final round = RRect.fromRectAndRadius(rect, radius);
      final dark = colors.brightness == Brightness.dark;
      canvas.drawRRect(
        round.shift(const Offset(0, 1.2)),
        Paint()..color = Color(dark ? 0xFF1F2530 : 0xFFD1D5DB),
      );
      canvas.drawRRect(
        round,
        Paint()..color = Color(dark ? 0xFF2B313D : 0xFFE5E7EB),
      );
      canvas.drawRRect(
        round,
        Paint()
          ..color = node.id == first ? colors.error : const Color(0xFF9CA3AF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = node.id == first ? 2.8 : 1.8,
      );
      if (selected.contains(node.id)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(5), radius),
          Paint()
            ..color = colors.tertiary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8,
        );
      }
      canvas.save();
      canvas.translate(rect.left, rect.top);
      canvas.scale(scale.clamp(.15, 2.2));
      labels[node.id]!.paint(canvas, const Offset(14, 4));
      canvas.restore();
    }
    if (box != null) {
      canvas.drawRect(
        box!,
        Paint()..color = colors.primary.withValues(alpha: .12),
      );
      canvas.drawRect(
        box!,
        Paint()
          ..color = colors.primary
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final edge in graph.edges)
          if (rects[edge.draft.sourceId] != null &&
              rects[edge.draft.targetId] != null &&
              (Offset.zero & size).contains(
                (rects[edge.draft.sourceId]!.center +
                        rects[edge.draft.targetId]!.center) /
                    2,
              ))
            CustomPainterSemantics(
              key: ValueKey('edge/${edge.id}'),
              rect: Rect.fromCenter(
                center:
                    (rects[edge.draft.sourceId]!.center +
                        rects[edge.draft.targetId]!.center) /
                    2,
                width: 48,
                height: 48,
              ).intersect(Offset.zero & size),
              properties: SemanticsProperties(
                label: '关联 ${edge.draft.relation}',
                button: true,
                textDirection: TextDirection.ltr,
                onTap: () => onTap(
                  (rects[edge.draft.sourceId]!.center +
                          rects[edge.draft.targetId]!.center) /
                      2,
                ),
              ),
            ),
        for (final node in graph.nodes)
          if (rects[node.id]!.overlaps(Offset.zero & size))
            CustomPainterSemantics(
              key: ValueKey(node.id),
              rect: rects[node.id]!.inflate(12).intersect(Offset.zero & size),
              properties: SemanticsProperties(
                label: node.title,
                button: true,
                selected: selected.contains(node.id) || first == node.id,
                textDirection: TextDirection.ltr,
                onTap: () => onTap(rects[node.id]!.center),
              ),
            ),
      ];
  @override
  bool shouldRebuildSemantics(covariant _GraphPainter oldDelegate) => true;
}
