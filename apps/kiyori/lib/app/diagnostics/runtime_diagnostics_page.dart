import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import '../runtime_controller.dart';

class CoreStatus extends StatelessWidget {
  const CoreStatus({required this.controller, super.key});
  final RuntimeController controller;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        controller.error != null
            ? Icons.error_outline
            : controller.starting
            ? Icons.hourglass_top
            : Icons.check_circle_outline,
        size: 20,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          controller.error ?? (controller.starting ? '正在准备工作空间…' : '应用核心已连接'),
        ),
      ),
    ],
  );
}

class RuntimeDiagnosticsPage extends StatelessWidget {
  const RuntimeDiagnosticsPage({required this.controller, super.key});
  final RuntimeController controller;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = controller.lastEvent;
    final status = controller.cancelling
        ? '正在取消…'
        : switch (event?.phase) {
            TaskPhase.completed => '检查完成，运行正常',
            TaskPhase.cancelled => '检查已取消',
            TaskPhase.started || TaskPhase.running => '检查进行中',
            null => '尚未开始检查',
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('运行检查', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('应用信息与运行状态'),
        const SizedBox(height: 28),
        _Section(
          title: '关于 Kiyori Flutter',
          children: [
            Text('开发版本 ${controller.info?.coreVersion ?? '—'}'),
            const SizedBox(height: 16),
            CoreStatus(controller: controller),
          ],
        ),
        const SizedBox(height: 20),
        _Section(
          title: '运行检查',
          children: [
            const Text('检查应用核心的响应与任务控制。不会访问网络或读取你的文件。'),
            const SizedBox(height: 20),
            Semantics(liveRegion: true, child: Text(status)),
            if (controller.checking) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: event == null
                    ? null
                    : event.completedSteps / event.totalSteps,
                semanticsLabel: '运行检查进度',
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: controller.info == null || controller.checking
                      ? null
                      : () => unawaited(controller.runCheck()),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始检查'),
                ),
                if (controller.checking)
                  OutlinedButton(
                    onPressed: controller.cancelling
                        ? null
                        : () => unawaited(controller.cancelCheck()),
                    child: const Text('取消检查'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Section(
          title: '功能状态',
          children: [
            for (final capability
                in controller.info?.capabilities ?? <Capability>[])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(switch (capability.id) {
                        'kiyori.runtime.diagnostics' => '运行检查',
                        'kiyori.assistant' => 'AI 助手',
                        'kiyori.browser' => '网页浏览',
                        'kiyori.files' => '文件管理',
                        _ => capability.id,
                      }),
                    ),
                    Text(
                      capability.available ? '可用' : '尚未实现',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}
