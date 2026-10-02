import 'package:flutter/material.dart';

import 'primary_page.dart';
import 'shell_action.dart';

/// KiyoriCollapsingSettingsPage: scroll changes only the overlay header.
/// The list keeps its original 128px header spacer and 14px item gaps.
class SettingsDetailPage extends StatefulWidget {
  const SettingsDetailPage({
    required this.title,
    required this.children,
    this.actions,
    this.actionWidth = 48,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? actions;
  final double actionWidth;

  @override
  State<SettingsDetailPage> createState() => _SettingsDetailPageState();
}

class _SettingsDetailPageState extends State<SettingsDetailPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: PrimaryColors.background,
      body: DefaultTextStyle.merge(
        style: const TextStyle(color: PrimaryColors.text, letterSpacing: 0),
        child: Stack(
          children: [
            ListView.separated(
              controller: _scroll,
              padding: EdgeInsets.zero,
              itemCount: widget.children.length + 2,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, index) {
                if (index == 0) return SizedBox(height: top + 128);
                if (index == widget.children.length + 1) {
                  return SizedBox(height: 28 + bottom);
                }
                return widget.children[index - 1];
              },
            ),
            AnimatedBuilder(
              animation: _scroll,
              builder: (context, _) {
                final progress = _scroll.hasClients
                    ? (_scroll.offset / 72).clamp(0.0, 1.0)
                    : 0.0;
                return Container(
                  key: const Key('settings-detail-header'),
                  height: top + 128 - 64 * progress,
                  decoration: const BoxDecoration(
                    color: PrimaryColors.background,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      Positioned(
                        top: top + 8,
                        left: 4,
                        child: ShellAction(
                          Icons.arrow_back,
                          '返回',
                          size: 48,
                          iconSize: 21,
                          color: PrimaryColors.text,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      Positioned(
                        top: top + 60 - 40 * progress,
                        left: 32 + 22 * progress,
                        right: widget.actions == null
                            ? 16
                            : widget.actionWidth + 16,
                        child: Semantics(
                          header: true,
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 26 - 6 * progress,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (widget.actions != null)
                        Positioned(
                          top: top + 8,
                          right: 8,
                          width: widget.actionWidth,
                          height: 48,
                          child: widget.actions!,
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Groups use the old title/description outside the white card.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.title,
    required this.description,
    required this.children,
    super.key,
  });

  final String title, description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 17 / 12,
              color: PrimaryColors.secondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: PrimaryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    ),
  );
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});
  @override
  Widget build(BuildContext context) =>
      const Divider(height: .6, thickness: .6, color: PrimaryColors.divider);
}

/// 子页原样无 leading icon；开关由整行唯一点击与语义 owner 控制。
/// checked == null is a navigation row, otherwise a switch row.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.title,
    required this.description,
    this.value,
    this.checked,
    this.enabled = true,
    this.onTap = emptyAction,
    super.key,
  });

  final String title, description;
  final String? value;
  final bool? checked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: checked == null,
    toggled: checked,
    enabled: enabled,
    child: Opacity(
      opacity: enabled ? 1 : .42,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 17 / 12,
                          color: PrimaryColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (checked != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: Switch(
                        value: checked!,
                        onChanged: (_) {},
                        thumbColor: const WidgetStatePropertyAll(Colors.white),
                        trackColor: WidgetStatePropertyAll(
                          checked!
                              ? PrimaryColors.accent
                              : const Color(0xFFD5DAE1),
                        ),
                        trackOutlineColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                )
              else ...[
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PrimaryColors.secondary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.keyboard_arrow_right,
                  size: 18,
                  color: PrimaryColors.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

InputDecoration settingsFieldDecoration({
  required String label,
  String? hint,
  String? helper,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  helperText: helper,
  helperMaxLines: 4,
  filled: true,
  fillColor: PrimaryColors.background,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: PrimaryColors.divider),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: PrimaryColors.accent),
  ),
);
