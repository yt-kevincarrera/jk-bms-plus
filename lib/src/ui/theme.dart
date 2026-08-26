import 'package:flutter/material.dart';

/// The app's palette and type.
///
/// An instrument cluster, not a settings screen. The ground is a cool near-black
/// so the numbers carry, and the status language is deliberately three steps:
/// blue means normal, amber means look at this, red means stop. Green is absent
/// on purpose — "healthy" reads perfectly well as calm blue, and reserving
/// colour for genuine warnings keeps a normal screen from shouting.
abstract final class AppTheme {
  static const Color ink = Color(0xFF080A0F);
  static const Color surface = Color(0xFF0E1219);
  static const Color surfaceRaised = Color(0xFF151A23);
  static const Color surfaceHigh = Color(0xFF1D2431);
  static const Color hairline = Color(0xFF272F3D);

  /// Normal. Also the app's brand accent.
  static const Color good = Color(0xFF4C9AFF);
  static const Color goodDim = Color(0xFF1F4E8C);

  /// A second cool tone, for the lines that share a chart with [good] and for
  /// the balancer, which is a thing happening rather than a thing wrong.
  static const Color cool = Color(0xFF22D3EE);

  /// Look at this.
  static const Color watch = Color(0xFFF5A623);

  /// Stop.
  static const Color bad = Color(0xFFEF4444);

  /// Cold, for sub-zero temperatures.
  static const Color cold = Color(0xFF818CF8);

  static const Color textPrimary = Color(0xFFE7EBF2);
  static const Color textSecondary = Color(0xFF8B95A6);
  static const Color textFaint = Color(0xFF5B6474);

  /// Every number here is a measurement, and measurements should not jitter
  /// sideways as their digits change.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: good,
      onPrimary: ink,
      primaryContainer: goodDim,
      secondary: cool,
      tertiary: watch,
      onTertiary: ink,
      tertiaryContainer: Color(0xFF3A2E14),
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
      outline: hairline,
      outlineVariant: hairline,
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: hairline),
        ),
      ),
      dividerTheme: const DividerThemeData(color: hairline, thickness: 1),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: textSecondary,
        collapsedIconColor: textSecondary,
        textColor: textSecondary,
        collapsedTextColor: textSecondary,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.only(bottom: 8),
        shape: Border(),
        collapsedShape: Border(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ink,
        surfaceTintColor: Colors.transparent,
        indicatorColor: goodDim.withValues(alpha: 0.45),
        elevation: 0,
        height: 64,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? good : textFaint,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: hairline),
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }

  /// Caption above a readout: small, wide-tracked, quiet.
  static TextStyle caption(BuildContext context) => const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.3,
        color: textSecondary,
      );

  /// A measurement.
  static TextStyle readout(double size, {Color? color}) => TextStyle(
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.0,
        color: color ?? textPrimary,
        fontFeatures: tabular,
      );
}
