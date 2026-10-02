import 'package:flutter/material.dart';

import 'shell_action.dart';

/// 固定浅色快照只用于初始颜色草稿；渲染使用 of(context) 跟随宿主主题。
abstract final class PrimaryColors {
  static const background = Color(0xFFF6F7F9);
  static const text = Color(0xFF20242A);
  static const secondary = Color(0xFF6E747C);
  static const muted = Color(0xFF9AA2AC);
  static const divider = Color(0xFFE9EDF2);
  static const accent = Color(0xFF256DB0);

  static PrimaryPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? PrimaryPalette.dark
      : PrimaryPalette.light;
}

/// 旧 KiyoriSettingsTheme 的设置表面色表，不持有主题偏好或业务状态。
class PrimaryPalette {
  const PrimaryPalette({
    required this.background,
    required this.card,
    required this.text,
    required this.secondary,
    required this.muted,
    required this.divider,
    required this.accent,
    required this.accentContent,
    required this.disabledTrack,
  });
  final Color background, card, text, secondary, muted, divider;
  final Color accent, accentContent, disabledTrack;

  static const light = PrimaryPalette(
    background: PrimaryColors.background,
    card: Colors.white,
    text: PrimaryColors.text,
    secondary: PrimaryColors.secondary,
    muted: PrimaryColors.muted,
    divider: PrimaryColors.divider,
    accent: PrimaryColors.accent,
    accentContent: Colors.white,
    disabledTrack: Color(0xFFD5DAE1),
  );
  static const dark = PrimaryPalette(
    background: Color(0xFF101215),
    card: Color(0xFF1B1F24),
    text: Color(0xFFF2F5F8),
    secondary: Color(0xFFAAB2BC),
    muted: Color(0xFF7F8995),
    divider: Color(0xFF2A3037),
    accent: Color(0xFF90CAF9),
    accentContent: Color(0xFF0A2638),
    disabledTrack: Color(0xFF444B54),
  );
}

class SettingsTheme extends StatelessWidget {
  const SettingsTheme({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final parent = Theme.of(context);
    final palette = PrimaryColors.of(context);
    final dark = parent.brightness == Brightness.dark;
    final colors = parent.colorScheme.copyWith(
      primary: palette.accent,
      onPrimary: palette.accentContent,
      surface: palette.card,
      onSurface: palette.text,
      onSurfaceVariant: palette.secondary,
      outline: palette.muted,
      outlineVariant: palette.divider,
      surfaceContainerLowest: palette.card,
      surfaceContainerLow: palette.card,
      surfaceContainer: palette.card,
      surfaceContainerHigh: Color(dark ? 0xFF22272D : 0xFFF2F4F7),
      surfaceContainerHighest: palette.divider,
    );
    return Theme(
      data: parent.copyWith(
        colorScheme: colors,
        textTheme: parent.textTheme.apply(
          bodyColor: palette.text,
          displayColor: palette.text,
        ),
        scaffoldBackgroundColor: palette.background,
      ),
      child: child,
    );
  }
}

enum IconTone {
  account(0xFF34974E, 0xFFEDF6EF, 0xFF8BDC87, 0xFF293729),
  ai(0xFF3D73D9, 0xFFEAF1FF, 0xFF8CB5FF, 0xFF26364F),
  memory(0xFF6255A5, 0xFFF0EFFA, 0xFFB9B0F0, 0xFF302F43),
  tools(0xFFC76E2E, 0xFFFAF2EC, 0xFFFFB978, 0xFF3D3126),
  browser(0xFF2584E9, 0xFFEBF4FD, 0xFF7DBAFF, 0xFF27313D),
  download(0xFF079770, 0xFFE9F6F2, 0xFF58DDB0, 0xFF213730),
  folder(0xFFB07C07, 0xFFF8F3E9, 0xFFFFD16A, 0xFF3D3524),
  video(0xFFD56432, 0xFFFBF1ED, 0xFFFFA57E, 0xFF3D2E27),
  audio(0xFFD74B88, 0xFFFBEFF4, 0xFFFF94C5, 0xFF3D2B33),
  security(0xFF7B8D29, 0xFFF3F5EC, 0xFFC6DE75, 0xFF343826),
  appearance(0xFFDD5874, 0xFFFCF0F2, 0xFFFFA0B4, 0xFF3D2D30),
  favorite(0xFFD64F73, 0xFFFDEBF0, 0xFFFF9EB8, 0xFF452833),
  backup(0xFF676FDF, 0xFFF1F2FC, 0xFFAEB4FF, 0xFF2F303D),
  network(0xFF2877B8, 0xFFEAF3FB, 0xFF7EB8F0, 0xFF263746),
  document(0xFF427FEB, 0xFFEEF3FD, 0xFF92B8FF, 0xFF2B313D),
  image(0xFFBF5EB5, 0xFFF9F1F8, 0xFFF09DDF, 0xFF3B2D38),
  success(0xFF30975E, 0xFFECF6F1, 0xFF7DDD9F, 0xFF27372D),
  terminal(0xFF657CA8, 0xFFF1F3F7, 0xFFA9BFEA, 0xFF2F323A),
  code(0xFF168E96, 0xFFEAF5F6, 0xFF6FD5D9, 0xFF253637),
  automation(0xFF17768B, 0xFFE4F5F8, 0xFF65D3E8, 0xFF173942),
  storage(0xFF7D7DAE, 0xFFF3F3F8, 0xFFC1BBED, 0xFF33323A),
  recycle(0xFFBA3A42, 0xFFFDEAEA, 0xFFFF8A8A, 0xFF472323),
  neutral(0xFF607080, 0xFFF1F2F4, 0xFFCBD5E1, 0xFF343638),
  warning(0xFFA77F10, 0xFFF7F3E9, 0xFFF7D66C, 0xFF3C3624),
  reading(0xFF40937D, 0xFFEEF5F3, 0xFF87D8BA, 0xFF293731),
  link(0xFF1491B0, 0xFFEAF5F8, 0xFF68D4EE, 0xFF24363A),
  settings(0xFF6B7585, 0xFFF0F2F5, 0xFFB9C1CD, 0xFF333840);

  const IconTone(
    this.foreground,
    this.background,
    this.darkForeground,
    this.darkBackground,
  );
  final int foreground, background, darkForeground, darkBackground;
  Color iconFor(BuildContext context) => Color(
    Theme.of(context).brightness == Brightness.dark
        ? darkForeground
        : foreground,
  );
  Color containerFor(BuildContext context) => Color(
    Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : background,
  );
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
  Widget build(BuildContext context) => SettingsTheme(
    child: ColoredBox(
      color: PrimaryColors.of(context).background,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: PrimaryColors.of(context).text,
          letterSpacing: 0,
        ),
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
    ),
  );
}

class PrimaryCard extends StatelessWidget {
  const PrimaryCard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: PrimaryColors.of(context).card,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: DefaultTextStyle.merge(
      style: TextStyle(color: PrimaryColors.of(context).text, letterSpacing: 0),
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
      color: tone.containerFor(context),
      borderRadius: BorderRadius.circular(12),
    ),
    child: glyph ?? Icon(icon, size: iconSize, color: tone.iconFor(context)),
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
          Container(
            width: 3,
            height: 18,
            color: PrimaryColors.of(context).accent,
          ),
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
    this.onSettings = emptyAction,
    this.onSearch = emptyAction,
    super.key,
  });
  final String searchLabel, settingsLabel;
  final VoidCallback onSettings, onSearch;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ShellAction(
        Icons.search,
        searchLabel,
        onTap: onSearch,
        size: 48,
        iconSize: 24,
        color: IconTone.browser.iconFor(context),
      ),
      ShellAction(
        Icons.settings_outlined,
        settingsLabel,
        onTap: onSettings,
        size: 48,
        iconSize: 24,
        color: IconTone.ai.iconFor(context),
      ),
    ],
  );
}
