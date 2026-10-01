import 'package:flutter/material.dart';

import 'shell_action.dart';

/// 旧 KiyoriSettingsTheme 与 KiyoriCollapsingSettingsHeader 的默认浅色参数。
abstract final class PrimaryColors {
  static const background = Color(0xFFF6F7F9);
  static const text = Color(0xFF20242A);
  static const secondary = Color(0xFF6E747C);
  static const muted = Color(0xFF9AA2AC);
  static const divider = Color(0xFFE9EDF2);
  static const accent = Color(0xFF256DB0);
}

enum IconTone {
  account(0xFF34974E, 0xFFEDF6EF),
  ai(0xFF3D73D9, 0xFFEAF1FF),
  tools(0xFFC76E2E, 0xFFFAF2EC),
  browser(0xFF2584E9, 0xFFEBF4FD),
  download(0xFF079770, 0xFFE9F6F2),
  folder(0xFFB07C07, 0xFFF8F3E9),
  video(0xFFD56432, 0xFFFBF1ED),
  audio(0xFFD74B88, 0xFFFBEFF4),
  security(0xFF7B8D29, 0xFFF3F5EC),
  appearance(0xFFDD5874, 0xFFFCF0F2),
  backup(0xFF676FDF, 0xFFF1F2FC),
  network(0xFF2877B8, 0xFFEAF3FB),
  document(0xFF427FEB, 0xFFEEF3FD),
  image(0xFFBF5EB5, 0xFFF9F1F8),
  success(0xFF30975E, 0xFFECF6F1),
  terminal(0xFF657CA8, 0xFFF1F3F7),
  code(0xFF168E96, 0xFFEAF5F6),
  automation(0xFF17768B, 0xFFE4F5F8),
  storage(0xFF7D7DAE, 0xFFF3F3F8),
  recycle(0xFFBA3A42, 0xFFFDEAEA);

  const IconTone(this.foreground, this.background);
  final int foreground, background;
  Color get icon => Color(foreground);
  Color get container => Color(background);
}

class PrimaryPage extends StatelessWidget {
  const PrimaryPage({
    required this.title,
    required this.actions,
    required this.child,
    this.actionWidth = 96,
    super.key,
  });
  final String title;
  final List<Widget> actions;
  final Widget child;
  final double actionWidth;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: PrimaryColors.background,
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: PrimaryColors.text, letterSpacing: 0),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    right: actionWidth + 16,
                    top: 20,
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    height: 48,
                    child: Row(children: actions),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class PrimaryCard extends StatelessWidget {
  const PrimaryCard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: PrimaryColors.text, letterSpacing: 0),
      child: child,
    ),
  );
}

class ToneBadge extends StatelessWidget {
  const ToneBadge(
    this.icon,
    this.tone, {
    this.size = 34,
    this.iconSize = 17,
    this.glyph,
    super.key,
  });
  final IconData icon;
  final IconTone tone;
  final double size, iconSize;
  final Widget? glyph;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: tone.container,
      borderRadius: BorderRadius.circular(12),
    ),
    child: glyph ?? Icon(icon, size: iconSize, color: tone.icon),
  );
}

class PrimarySectionTitle extends StatelessWidget {
  const PrimarySectionTitle(
    this.title, {
    required this.trailing,
    this.onTap,
    super.key,
  });
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: PrimaryColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          trailing,
        ],
      ),
    ),
  );
}

class PrimaryHeaderActions extends StatelessWidget {
  const PrimaryHeaderActions({
    required this.searchLabel,
    required this.settingsLabel,
    super.key,
  });
  final String searchLabel, settingsLabel;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ShellAction(
        Icons.search,
        searchLabel,
        size: 48,
        iconSize: 24,
        color: IconTone.browser.icon,
      ),
      ShellAction(
        Icons.settings_outlined,
        settingsLabel,
        size: 48,
        iconSize: 24,
        color: IconTone.ai.icon,
      ),
    ],
  );
}
