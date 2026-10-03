import 'dart:math' as math;
import 'dart:ui';

/// 纯展示几何在隔离线程计算，不读取数据库，不在指针移动时重新运行物理布局。
class GraphLayoutInput {
  const GraphLayoutInput(this.ids, this.edges, this.previous, this.size);
  final List<String> ids;
  final List<(String, String, double, bool)> edges;
  final Map<String, Offset> previous;
  final Size size;
}

Map<String, Offset> layoutMemoryGraph(GraphLayoutInput input) {
  final ids = input.ids;
  if (ids.isEmpty) return {};
  final center = Offset(input.size.width / 2, input.size.height / 2);
  final index = {for (var i = 0; i < ids.length; i++) ids[i]: i};
  final neighbors = List.generate(ids.length, (_) => <int>[]);
  for (final edge in input.edges) {
    final a = index[edge.$1], b = index[edge.$2];
    if (a == null || b == null || edge.$4) continue;
    neighbors[a].add(b);
    neighbors[b].add(a);
  }
  final cluster = List.filled(ids.length, -1);
  var clusters = 0;
  for (var i = 0; i < ids.length; i++) {
    if (cluster[i] != -1) continue;
    final pending = [i];
    cluster[i] = clusters;
    while (pending.isNotEmpty) {
      for (final next in neighbors[pending.removeLast()]) {
        if (cluster[next] == -1) {
          cluster[next] = clusters;
          pending.add(next);
        }
      }
    }
    clusters++;
  }
  final positions = List.generate(ids.length, (i) {
    final old = input.previous[ids[i]];
    if (old != null) return old;
    final angle = 2 * math.pi * cluster[i] / clusters;
    final origin = clusters == 1
        ? center
        : center +
              Offset(math.cos(angle), math.sin(angle)) *
                  (math.min(input.size.width, input.size.height) * .34);
    // 稳定初始方向避免同一快照每次重开随机跳动；后续仍由连边和斥力求解。
    final seed = ids[i].codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final jitter = (seed % 6283) / 1000;
    return origin +
        Offset(math.cos(jitter), math.sin(jitter)) * (40 + i % 13 * 8);
  });
  final incremental = input.previous.isNotEmpty;
  final iterations = incremental
      ? 46
      : ids.length > 100
      ? 200
      : 300;
  final smoothed = List.filled(ids.length, Offset.zero);
  var stable = 0;
  for (var step = 0; step < iterations; step++) {
    final forces = List.filled(ids.length, Offset.zero);
    for (var a = 0; a < ids.length; a++) {
      for (var b = a + 1; b < ids.length; b++) {
        var delta = positions[a] - positions[b];
        if (delta.distanceSquared < .001) {
          delta = Offset(1, (a + b).isEven ? 1 : -1);
        }
        final distance = math.max(1.0, delta.distance);
        if (distance > 1680) continue;
        final separation = distance < 380
            ? math.pow((380 - distance) / 380, 2.25) * 1200
            : 0;
        final force =
            delta / distance * (380000 / (distance * distance) + separation);
        forces[a] += force;
        forces[b] -= force;
      }
    }
    for (final edge in input.edges) {
      final a = index[edge.$1], b = index[edge.$2];
      if (a == null || b == null) continue;
      final delta = positions[b] - positions[a];
      final distance = math.max(1.0, delta.distance);
      final strength = .07 * (1 + edge.$3 * .35) * (edge.$4 ? .45 : 1.95);
      final force = delta / distance * ((distance - 560) * strength);
      forces[a] += force;
      forces[b] -= force;
    }
    final centers = List.filled(clusters, Offset.zero);
    final counts = List.filled(clusters, 0);
    for (var i = 0; i < ids.length; i++) {
      centers[cluster[i]] += positions[i];
      counts[cluster[i]]++;
    }
    for (var c = 0; c < clusters; c++) {
      centers[c] = centers[c] / counts[c].toDouble();
    }
    var movement = 0.0;
    final temperature = math.max(
      .9,
      560 * (incremental ? .16 : .42) * math.pow(1 - step / iterations, 2.15),
    );
    for (var i = 0; i < ids.length; i++) {
      var force = forces[i] + (center - positions[i]) * .005;
      final toward = centers[cluster[i]] - positions[i];
      final radius = 380 * .42 + math.min(24, counts[cluster[i]] - 1) * 3.2;
      if (toward.distance > radius && counts[cluster[i]] > 1) {
        force +=
            toward /
            toward.distance *
            (math.pow((toward.distance - radius) / radius, 1.2) * 46);
      }
      smoothed[i] = smoothed[i] * .78 + force * .22;
      var move = smoothed[i];
      if (move.distance > temperature) {
        move = move / move.distance * temperature;
      }
      if (move.distance < .18) continue;
      positions[i] += move;
      movement += move.distance;
    }
    stable = movement / ids.length < .42 ? stable + 1 : 0;
    if (stable >= 12) break;
  }
  return {for (var i = 0; i < ids.length; i++) ids[i]: positions[i]};
}
