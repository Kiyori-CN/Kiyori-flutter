import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'wakeup_dialogs.dart';
import 'wakeup_presentation.dart';

class WakeupSettingsPage extends StatefulWidget {
  const WakeupSettingsPage({
    this.snapshot = const WakeupPresentation(),
    super.key,
  });
  final WakeupPresentation snapshot;
  @override
  State<WakeupSettingsPage> createState() => _WakeupSettingsPageState();
}

class _WakeupSettingsPageState extends State<WakeupSettingsPage> {
  late WakeRecognitionMode mode = widget.snapshot.mode;
  late bool regex = widget.snapshot.regex,
      greeting = widget.snapshot.greeting,
      createChat = widget.snapshot.createChat,
      attach = widget.snapshot.attach;
  late final phrase = TextEditingController(text: widget.snapshot.phrase);
  late final timeout = TextEditingController(
    text: '${widget.snapshot.timeout}',
  );
  late final greetingText = TextEditingController(
    text: widget.snapshot.greetingText,
  );
  late final group = TextEditingController(text: widget.snapshot.group);
  late List<WakeAttachmentPresentation> ordered = _sortAttachments();
  List<WakeAttachmentPresentation> _sortAttachments() =>
      [...widget.snapshot.attachments]
        ..sort((a, b) => a.type.index.compareTo(b.type.index));
  @override
  void didUpdateWidget(WakeupSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.attachments != widget.snapshot.attachments) {
      ordered = _sortAttachments();
    }
  }

  @override
  void dispose() {
    for (final c in [phrase, timeout, greetingText, group]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    TextEditingController controller,
    String label,
    String hint, {
    bool enabled = true,
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    child: TextField(
      key: ValueKey('wake-$label'),
      controller: controller,
      enabled: enabled,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly, _WakeTimeoutFormatter()]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '语音唤醒',
    children: [
      SettingsGroup(
        title: '唤醒识别',
        description: '选择识别方式，配置唤醒词，并管理后台监听权限',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: DropdownButtonFormField<WakeRecognitionMode>(
              initialValue: mode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: '唤醒识别模式',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: [
                for (final value in WakeRecognitionMode.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => mode = v);
              },
            ),
          ),
          SettingsRow(
            title: '始终监听',
            description: '后台持续监听唤醒词（需麦克风权限）',
            checked: widget.snapshot.listening,
            onTap: emptyAction,
          ),
          if (mode == WakeRecognitionMode.stt) ...[
            field(phrase, '唤醒词', '例如：小欧'),
            SettingsRow(
              title: '正则表达式',
              description: '将唤醒词按正则匹配识别结果',
              checked: regex,
              onTap: () => setState(() => regex = !regex),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => showDialog<void>(
                        context: context,
                        barrierDismissible:
                            widget.snapshot.enrollment.recordingStep == 0,
                        builder: (_) => WakeEnrollmentDialog(
                          snapshot: widget.snapshot.enrollment,
                        ),
                      ),
                      child: const Text('录入个人化唤醒模板'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.snapshot.templateCount == 0
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('清除个人唤醒模板'),
                                content: const Text(
                                  '清除后需要重新录入三次唤醒词才能使用个人模板识别。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: emptyAction,
                                    child: const Text('清除个人化模板'),
                                  ),
                                ],
                              ),
                            ),
                      child: const Text('清除个人化模板'),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.snapshot.templateCount == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Text(
                  '尚未录入模板，无法使用个人化唤醒。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
      SettingsGroup(
        title: '唤醒响应',
        description: '设置唤醒后的语音反馈、超时和新对话行为',
        children: [
          field(timeout, '语音无响应超时（秒）', '范围：1-600', numeric: true),
          SettingsRow(
            title: '唤醒后说一句',
            description: '进入语音模式前先朗读一句',
            checked: greeting,
            onTap: () => setState(() => greeting = !greeting),
          ),
          field(greetingText, '朗读内容', '例如：我在', enabled: greeting),
          SettingsRow(
            title: '唤醒时新建对话',
            description: '唤醒进入语音后自动新建一个对话',
            checked: createChat,
            onTap: () => setState(() => createChat = !createChat),
          ),
          field(group, '自动新建对话分组', '默认：全局助手', enabled: createChat),
        ],
      ),
      SettingsGroup(
        title: '自动附加内容',
        description: '进入语音模式时，按关键词附加当前设备上下文',
        children: [
          SettingsRow(
            title: '自动附加',
            description: '命中关键词时自动抓取附件',
            checked: attach,
            onTap: () => setState(() => attach = !attach),
          ),
          if (attach) _attachments(context),
        ],
      ),
    ],
  );

  Widget _attachments(BuildContext context) {
    final used = ordered.map((item) => item.type).toSet();
    final missing = WakeAttachmentType.values
        .where((type) => !used.contains(type))
        .toList();
    final colors = Theme.of(context).colorScheme;
    Widget tile(
      IconData icon,
      String title,
      String? preview,
      bool enabled,
      VoidCallback onTap,
    ) => Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(width: .8, color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: enabled ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              if (preview != null) ...[
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + 8) / 104).floor().clamp(1, 12);
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in ordered)
              SizedBox(
                width: width,
                child: tile(
                  item.type.icon,
                  item.type.title,
                  item.keywords.trim().isEmpty
                      ? item.type.description
                      : item.keywords,
                  item.enabled,
                  () => showDialog<void>(
                    context: context,
                    builder: (_) => WakeAttachmentDialog(item: item),
                  ),
                ),
              ),
            if (missing.isNotEmpty)
              SizedBox(
                width: width,
                child: tile(
                  Icons.add,
                  '添加',
                  null,
                  true,
                  () => showDialog<void>(
                    context: context,
                    builder: (_) => WakeAttachmentCreateDialog(types: missing),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WakeTimeoutFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final number = BigInt.tryParse(newValue.text);
    if (number == null) return newValue;
    final bounded = number < BigInt.one
        ? '1'
        : number > BigInt.from(600)
        ? '600'
        : number.toString();
    if (bounded == newValue.text) return newValue;
    return TextEditingValue(
      text: bounded,
      selection: TextSelection.collapsed(offset: bounded.length),
    );
  }
}
