import 'package:flutter/material.dart';

export 'src/shell_action.dart';
export 'src/primary_page.dart';

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
