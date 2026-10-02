import 'package:flutter/material.dart';

export 'src/shell_action.dart';
export 'src/ai_sparkle_icon.dart';
export 'src/primary_page.dart';
export 'src/settings_components.dart';
export 'src/settings_selection.dart';
export 'src/modal_drawer.dart';
export 'src/search_field.dart';
export 'src/settings_workspace_page.dart';
export 'src/compact_expand_field.dart';

abstract final class KiyoriTheme {
  static ThemeData light() => _create(Brightness.light);
  static ThemeData dark() => _create(Brightness.dark);

  static ThemeData _create(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF256DB0),
          brightness: brightness,
        ).copyWith(
          primary: Color(dark ? 0xFF90CAF9 : 0xFF256DB0),
          onPrimary: Color(dark ? 0xFF0A2638 : 0xFFFFFFFF),
          primaryContainer: Color(dark ? 0xFF0B5F94 : 0xFFD8ECFF),
          onPrimaryContainer: Color(dark ? 0xFFD8ECFF : 0xFF12324A),
          inversePrimary: Color(dark ? 0xFF256DB0 : 0xFF90CAF9),
          secondary: Color(dark ? 0xFFB9CBD4 : 0xFF536D79),
          onSecondary: Color(dark ? 0xFF20343D : 0xFFFFFFFF),
          secondaryContainer: Color(dark ? 0xFF374D57 : 0xFFE4EDF1),
          onSecondaryContainer: Color(dark ? 0xFFE4EDF1 : 0xFF20343D),
          tertiary: Color(dark ? 0xFF9AA0A6 : 0xFF3C4043),
          onTertiary: Color(dark ? 0xFF202124 : 0xFFFFFFFF),
          tertiaryContainer: Color(dark ? 0xFF282A2D : 0xFFF1F3F4),
          onTertiaryContainer: Color(dark ? 0xFFE8EAED : 0xFF202124),
          error: Color(dark ? 0xFFF2B8B5 : 0xFFB3261E),
          onError: Color(dark ? 0xFF601410 : 0xFFFFFFFF),
          errorContainer: Color(dark ? 0xFF8C1D18 : 0xFFF9DEDC),
          onErrorContainer: Color(dark ? 0xFFF9DEDC : 0xFF410E0B),
          surfaceTint: Colors.transparent,
          surface: Color(dark ? 0xFF121212 : 0xFFFFFFFF),
          onSurface: Color(dark ? 0xFFE8EAED : 0xFF202124),
          onSurfaceVariant: Color(dark ? 0xFFBDC1C6 : 0xFF5F6368),
          surfaceContainerLow: Color(dark ? 0xFF1A1A1A : 0xFFFAFAFA),
          surfaceContainerHighest: Color(dark ? 0xFF303134 : 0xFFE8EAED),
          outline: const Color(0xFF9AA0A6),
          outlineVariant: Color(dark ? 0xFF3C4043 : 0xFFDADCE0),
        );
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.surface,
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface)
          .copyWith(
            bodyMedium: TextStyle(
              fontSize: 14,
              letterSpacing: 0,
              color: colors.onSurface,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
    );
  }
}

class KiyoriPage extends StatelessWidget {
  const KiyoriPage({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960),
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 20 : 36,
        ),
        child: child,
      ),
    ),
  );
}
