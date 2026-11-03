import 'package:flutter/material.dart';

/// A palette is owned by the theme, never global mutable state.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.scheme,
    required this.textFaint,
    required this.cold,
  });
  final ColorScheme scheme;
  final Color textFaint;
  final Color cold;
  Color get ink => scheme.surfaceContainerLowest;
  Color get surface => scheme.surface;
  Color get surfaceRaised => scheme.surfaceContainer;
  Color get surfaceHigh => scheme.surfaceContainerHigh;
  Color get hairline => scheme.outlineVariant;
  Color get good => scheme.primary;
  Color get goodDim => scheme.primaryContainer;
  Color get cool => scheme.secondary;
  Color get watch => scheme.tertiary;
  Color get bad => scheme.error;
  Color get textPrimary => scheme.onSurface;
  Color get textSecondary => scheme.onSurfaceVariant;
  @override
  AppPalette copyWith({ColorScheme? scheme, Color? textFaint, Color? cold}) =>
      AppPalette(
        scheme: scheme ?? this.scheme,
        textFaint: textFaint ?? this.textFaint,
        cold: cold ?? this.cold,
      );
  @override
  AppPalette lerp(covariant AppPalette? other, double t) => other == null
      ? this
      : AppPalette(
          scheme: ColorScheme.lerp(scheme, other.scheme, t),
          textFaint: Color.lerp(textFaint, other.textFaint, t)!,
          cold: Color.lerp(cold, other.cold, t)!,
        );
}

extension AppThemeContext on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ??
      AppTheme.palette(Theme.of(this).brightness);
}

/// Horizonte R: petroleum surfaces, ice-blue instruments and short corners.
abstract final class AppTheme {
  // Stable defaults for pure classification functions and const arguments.
  // Widgets resolve them against their own BuildContext.
  static const ink = Color(0xFF09171F);
  static const surface = Color(0xFF09171F);
  static const surfaceRaised = Color(0xFF132C36);
  static const surfaceHigh = Color(0xFF203E49);
  static const hairline = Color(0xFF3B5D6B);
  static const good = Color(0xFF82E4EE);
  static const goodDim = Color(0xFF204B58);
  static const cool = Color(0xFFB6D6FA);
  static const watch = Color(0xFFFFD184);
  static const bad = Color(0xFFFFABAB);
  static const cold = Color(0xFFC4BDFF);
  static const textPrimary = Color(0xFFEFF8FA);
  static const textSecondary = Color(0xFFB6CBD3);
  static const textFaint = Color(0xFFA3BCC6);
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static AppPalette palette(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = dark
        ? const ColorScheme.dark(
            primary: good,
            onPrimary: ink,
            primaryContainer: goodDim,
            onPrimaryContainer: textPrimary,
            secondary: cool,
            onSecondary: ink,
            tertiary: watch,
            onTertiary: ink,
            tertiaryContainer: Color(0xFF42351D),
            onTertiaryContainer: watch,
            error: bad,
            onError: ink,
            surface: surface,
            onSurface: textPrimary,
            onSurfaceVariant: textSecondary,
            surfaceContainerLowest: ink,
            surfaceContainerLow: surface,
            surfaceContainer: surfaceRaised,
            surfaceContainerHigh: surfaceHigh,
            surfaceContainerHighest: surfaceHigh,
            outline: Color(0xFF7695A3),
            outlineVariant: hairline,
          )
        : const ColorScheme.light(
            primary: Color(0xFF105C75),
            onPrimary: Colors.white,
            primaryContainer: Color(0xFFCDE4ED),
            onPrimaryContainer: Color(0xFF14323F),
            secondary: Color(0xFF355C90),
            onSecondary: Colors.white,
            tertiary: Color(0xFF865000),
            onTertiary: Colors.white,
            tertiaryContainer: Color(0xFFFFE8BF),
            onTertiaryContainer: Color(0xFF704000),
            error: Color(0xFFA22332),
            onError: Colors.white,
            surface: Color(0xFFEAF1F5),
            onSurface: Color(0xFF14323F),
            onSurfaceVariant: Color(0xFF4C6573),
            surfaceContainerLowest: Color(0xFFEAF1F5),
            surfaceContainerLow: Color(0xFFF3F7F9),
            surfaceContainer: Colors.white,
            surfaceContainerHigh: Color(0xFFD6E5ED),
            surfaceContainerHighest: Color(0xFFD6E5ED),
            outline: Color(0xFF6E8A99),
            outlineVariant: Color(0xFFA3BDCB),
          );
    return AppPalette(
      scheme: scheme,
      textFaint: dark ? textFaint : const Color(0xFF4C6573),
      cold: dark ? cold : const Color(0xFF6351A0),
    );
  }

  static Color resolve(BuildContext context, Color color) {
    final p = context.colors;
    if (color == good) return p.good;
    if (color == goodDim) return p.goodDim;
    if (color == cool) return p.cool;
    if (color == watch) return p.watch;
    if (color == bad) return p.bad;
    if (color == cold) return p.cold;
    if (color == textPrimary) return p.textPrimary;
    if (color == textSecondary) return p.textSecondary;
    if (color == textFaint) return p.textFaint;
    return color;
  }

  static ThemeData build({Brightness brightness = Brightness.dark}) {
    final p = palette(brightness);
    final base = ThemeData(colorScheme: p.scheme, useMaterial3: true);
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );
    return base.copyWith(
      extensions: [p],
      scaffoldBackgroundColor: p.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: p.hairline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: p.textSecondary,
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.textSecondary,
        collapsedIconColor: p.textSecondary,
        textColor: p.textPrimary,
        collapsedTextColor: p.textPrimary,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.goodDim,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? p.good
                : p.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? p.good
                : p.textSecondary,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: p.hairline),
          foregroundColor: p.textPrimary,
          shape: shape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceRaised,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
    );
  }

  static TextStyle caption(BuildContext context) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.25,
    color: context.colors.textSecondary,
  );

  /// Instrument face only for measurements. Null colour inherits the theme.
  static TextStyle readout(double size, {Color? color}) => TextStyle(
    fontFamily: 'BarlowCondensed',
    fontStyle: FontStyle.italic,
    fontSize: size,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.7,
    color: color,
    fontFeatures: tabular,
  );
}
