import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SchoolDrop design tokens. A calm, neutral base with one confident blue for actions and
/// a school-bus amber used sparingly for brand moments.
class AppColors {
  static const brand = Color(0xFF2347D9); // primary actions, links, focus
  static const brandDark = Color(0xFF14286E); // gradients, brand panel
  static const ink = Color(0xFF0B1220); // sidebar, headings on light
  static const amber = Color(0xFFF5A524); // brand accent only
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFDC2626);

  // Light neutrals (slate)
  static const background = Color(0xFFF6F7FB);
  static const surface = Colors.white;
  static const border = Color(0xFFE3E7EF);
  static const muted = Color(0xFF64748B);
  static const text = Color(0xFF0F172A);

  // Dark neutrals
  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF121A2B);
  static const darkBorder = Color(0xFF243049);
}

class AppTheme {
  // Kept for existing call sites
  static const navy = AppColors.brandDark;
  static const amber = AppColors.amber;

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.brand,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE6ECFF),
          onPrimaryContainer: Color(0xFF0F2A8A),
          secondary: AppColors.amber,
          onSecondary: AppColors.ink,
          secondaryContainer: Color(0xFFFFF3DC),
          onSecondaryContainer: Color(0xFF6B4300),
          tertiary: AppColors.success,
          onTertiary: Colors.white,
          error: AppColors.danger,
          onError: Colors.white,
          errorContainer: Color(0xFFFDECEC),
          onErrorContainer: Color(0xFF8A1C1C),
          surface: AppColors.surface,
          onSurface: AppColors.text,
          onSurfaceVariant: AppColors.muted,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Color(0xFFFAFBFD),
          surfaceContainer: AppColors.background,
          surfaceContainerHigh: Color(0xFFEFF2F7),
          surfaceContainerHighest: Color(0xFFE8ECF3),
          outline: Color(0xFFCBD3E1),
          outlineVariant: AppColors.border,
          inverseSurface: AppColors.ink,
          onInverseSurface: Colors.white,
          shadow: Color(0x14000000),
        ),
        background: AppColors.background,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF7D98FF),
          onPrimary: Color(0xFF0A1A55),
          primaryContainer: Color(0xFF1E2F6E),
          onPrimaryContainer: Color(0xFFDDE4FF),
          secondary: AppColors.amber,
          onSecondary: AppColors.ink,
          secondaryContainer: Color(0xFF4A3300),
          onSecondaryContainer: Color(0xFFFFE2A8),
          tertiary: Color(0xFF4ADE80),
          onTertiary: Color(0xFF052E16),
          error: Color(0xFFF87171),
          onError: Color(0xFF450A0A),
          errorContainer: Color(0xFF4C1515),
          onErrorContainer: Color(0xFFFECACA),
          surface: AppColors.darkSurface,
          onSurface: Color(0xFFE6EAF2),
          onSurfaceVariant: Color(0xFF94A3B8),
          surfaceContainerLowest: Color(0xFF0E1525),
          surfaceContainerLow: Color(0xFF111827),
          surfaceContainer: AppColors.darkBackground,
          surfaceContainerHigh: Color(0xFF1A2438),
          surfaceContainerHighest: Color(0xFF212C43),
          outline: Color(0xFF3A4763),
          outlineVariant: AppColors.darkBorder,
          inverseSurface: Color(0xFFE6EAF2),
          onInverseSurface: AppColors.ink,
          shadow: Colors.black,
        ),
        background: AppColors.darkBackground,
      );

  static ThemeData _build({required Brightness brightness, required ColorScheme scheme, required Color background}) {
    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true);
    final text = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final radius = BorderRadius.circular(12);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.error)),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: text.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
          textStyle: text.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelMedium,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outline),
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: scheme.onSurfaceVariant,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: scheme.outlineVariant)),
      ),
    );
  }
}
