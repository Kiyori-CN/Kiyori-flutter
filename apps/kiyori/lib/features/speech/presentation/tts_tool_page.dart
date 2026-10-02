import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'tts_draft.dart';
import 'tts_presentation.dart';
import 'tts_system_settings.dart';

class TtsToolPresentation {
  const TtsToolPresentation({
    this.initialized = false,
    this.speaking = false,
    this.error,
    this.details,
    this.debug,
  });
  final bool initialized, speaking;
  final String? error, details, debug;
}

/// TextToSpeechScreen 的工具投影；按钮不初始化引擎、播放或停止真实音频。
class TtsToolPage extends StatefulWidget {
  const TtsToolPage({
    this.profile = TtsProfilePresentation.initial,
    this.catalog = const TtsCatalogPresentation(),
    this.snapshot = const TtsToolPresentation(),
    super.key,
  });
  final TtsProfilePresentation profile;
  final TtsCatalogPresentation catalog;
  final TtsToolPresentation snapshot;
  @override
  State<TtsToolPage> createState() => _TtsToolPageState();
}

class _TtsToolPageState extends State<TtsToolPage> {
  final input = TextEditingController();
  late final draft = TtsDraft(widget.profile);
  double rate = 1, pitch = 1;
  bool errorDismissed = false;
  @override
  void dispose() {
    input.dispose();
    draft.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TtsToolPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) errorDismissed = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final snapshot = widget.snapshot;
    Widget card(
      List<Widget> children, {
      Color? color,
      double elevation = 2,
      double radius = 16,
    }) => Card(
      margin: EdgeInsets.zero,
      elevation: elevation,
      color: color ?? colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    Widget title(String label) => Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
    Widget slider(String label, double value, ValueChanged<double> update) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$label: ${value}x', style: const TextStyle(fontSize: 14)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Slider(
                value: value,
                min: .5,
                max: 2,
                divisions: 6,
                onChanged: update,
              ),
            ),
          ],
        );
    Widget stateRow(IconData icon, String text, Color tint) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: tint),
        const SizedBox(width: 8),
        Flexible(child: Text(text)),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back, size: 21),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          '文本转语音',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(.5),
          child: Divider(
            height: .5,
            thickness: .5,
            color: colors.outlineVariant,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '文本转语音演示',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            card([
              title('输入文本'),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120),
                child: TextField(
                  key: const ValueKey('tts-tool-input'),
                  controller: input,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    constraints: const BoxConstraints(minHeight: 120),
                    hintText: '请输入要转换为语音的文本',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            card([
              title('语音设置'),
              const SizedBox(height: 16),
              slider('语速', rate, (v) => setState(() => rate = v)),
              const SizedBox(height: 16),
              slider('音调', pitch, (v) => setState(() => pitch = v)),
              if (widget.profile.engine == TtsEngine.simple) ...[
                const SizedBox(height: 16),
                TtsSystemSettings(
                  draft: draft,
                  catalog: widget.catalog,
                  clearVoiceWithSystemLocale: true,
                ),
              ],
            ]),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: input,
              builder: (context, value, _) => FilledButton.icon(
                onPressed:
                    snapshot.initialized &&
                        !snapshot.speaking &&
                        value.text.trim().isNotEmpty
                    ? emptyAction
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Text('播放语音', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: snapshot.speaking ? emptyAction : null,
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.stop, size: 24),
              label: const Text('停止播放', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            card(
              [
                stateRow(
                  snapshot.initialized ? Icons.check_circle : Icons.error,
                  snapshot.initialized ? '语音引擎已初始化' : '语音引擎未初始化',
                  snapshot.initialized
                      ? IconTone.success.iconFor(context)
                      : colors.error,
                ),
                const SizedBox(height: 8),
                stateRow(
                  snapshot.speaking ? Icons.volume_up : Icons.volume_off,
                  snapshot.speaking ? '正在播放中...' : '未播放',
                  snapshot.speaking
                      ? IconTone.ai.iconFor(context)
                      : colors.onSecondaryContainer,
                ),
              ],
              color: colors.secondaryContainer,
              elevation: 0,
            ),
            if (!errorDismissed && snapshot.error != null) ...[
              const SizedBox(height: 16),
              card(
                [
                  Row(
                    children: [
                      Icon(Icons.error, color: colors.error),
                      const SizedBox(width: 12),
                      Text(
                        '错误',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error!,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                  for (final item in [
                    ('错误详情:', snapshot.details),
                    ('调试信息:', snapshot.debug),
                  ])
                    if (item.$2 != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        item.$1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => errorDismissed = true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                      ),
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('清除错误信息'),
                    ),
                  ),
                ],
                color: colors.errorContainer,
                radius: 8,
                elevation: 0,
              ),
            ],
            const SizedBox(height: 24),
            card(
              [
                title('使用说明'),
                const SizedBox(height: 8),
                Text(
                  '1. 在输入框中输入要转换为语音的文本\n2. 调整语速和音调设置\n3. 点击「播放语音」按钮开始播放\n4. 点击「停止播放」按钮停止播放\n5. 如果出现错误，查看详细的错误信息和调试信息\n6. 使用「清除错误信息」按钮清除错误显示',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '注意：首次使用时需要在系统设置中启用无障碍服务',
                  style: TextStyle(fontSize: 12, color: colors.error),
                ),
              ],
              color: colors.surfaceContainerHighest.withValues(alpha: .5),
              elevation: 0,
            ),
          ],
        ),
      ),
    );
  }
}
