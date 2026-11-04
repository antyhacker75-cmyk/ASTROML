import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const _lPrimary = Color(0xFF5B6CFF);
  static const _lPrimaryDark = Color(0xFF4354E8);
  static const _lPrimaryLight = Color(0xFFB8C1FF);
  static const _lSecondary = Color(0xFF00C9D8);
  static const _lSecondaryDark = Color(0xFF009EAD);
  static const _lBackground = Color(0xFFF3F5FC);
  static const _lSurface = Color(0xFFFFFFFF);
  static const _lOnSurface = Color(0xFF171B32);
  static const _lOnSurfaceVar = Color(0xFF737B98);
  static const _lOutline = Color(0xFFE2E6F2);
  static const _lError = Color(0xFFEF476F);
  static const _lWarning = Color(0xFFFFB547);
  static const _lSuccess = Color(0xFF18B982);
  static const _lSurfaceVar = Color(0xFFEAEDFA);
  static const _lCardBorder = Color(0xFFE5E9F5);

  static const gradientStart = Color(0xFF5969FF);
  static const gradientMid = Color(0xFF765BFF);
  static const gradientEnd = Color(0xFF00C9D8);
  static const gradientAccent = Color(0xFF9FEFFF);

  static bool _isDark = true;
  static void setThemeBrightness(Brightness b) => _isDark = b == Brightness.dark;

  static Color get primary => _isDark ? DarkColors.primary : _lPrimary;
  static Color get primaryDark => _isDark ? DarkColors.primaryDark : _lPrimaryDark;
  static Color get primaryLight => _isDark ? DarkColors.primaryLight : _lPrimaryLight;
  static Color get secondary => _isDark ? DarkColors.secondary : _lSecondary;
  static Color get secondaryDark => _isDark ? DarkColors.secondaryDark : _lSecondaryDark;
  static Color get background => _isDark ? DarkColors.background : _lBackground;
  static Color get surface => _isDark ? DarkColors.surface : _lSurface;
  static Color get onSurface => _isDark ? DarkColors.onSurface : _lOnSurface;
  static Color get onSurfaceVariant => _isDark ? DarkColors.onSurfaceVariant : _lOnSurfaceVar;
  static Color get outline => _isDark ? DarkColors.outline : _lOutline;
  static Color get error => _isDark ? DarkColors.error : _lError;
  static Color get warning => _isDark ? DarkColors.warning : _lWarning;
  static Color get success => _isDark ? DarkColors.success : _lSuccess;
  static Color get surfaceVariant => _isDark ? DarkColors.surfaceVariant : _lSurfaceVar;
  static Color get cardBorder => _isDark ? DarkColors.cardBorder : _lCardBorder;
}

class DarkColors {
  DarkColors._();
  static const primary = Color(0xFF8B9BFF);
  static const primaryDark = Color(0xFF6578FF);
  static const primaryLight = Color(0xFFC0C9FF);
  static const secondary = Color(0xFF43DCE8);
  static const secondaryDark = Color(0xFF18B9C8);
  static const background = Color(0xFF090D1B);
  static const surface = Color(0xFF121A30);
  static const onSurface = Color(0xFFF1F4FF);
  static const onSurfaceVariant = Color(0xFF929DBB);
  static const outline = Color(0xFF263451);
  static const error = Color(0xFFFF718B);
  static const warning = Color(0xFFFFC36B);
  static const success = Color(0xFF39D9A0);
  static const surfaceVariant = Color(0xFF1A2743);
  static const cardBorder = Color(0xFF263653);
}

ThemeData buildAppTheme() => _buildTheme(Brightness.light);
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final primary = dark ? DarkColors.primary : AppColors._lPrimary;
  final secondary = dark ? DarkColors.secondary : AppColors._lSecondary;
  final background = dark ? DarkColors.background : AppColors._lBackground;
  final surface = dark ? DarkColors.surface : AppColors._lSurface;
  final foreground = dark ? DarkColors.onSurface : AppColors._lOnSurface;
  final muted = dark ? DarkColors.onSurfaceVariant : AppColors._lOnSurfaceVar;
  final outline = dark ? DarkColors.outline : AppColors._lOutline;

  final scheme = (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
    primary: primary,
    secondary: secondary,
    surface: surface,
    onSurface: foreground,
    onSurfaceVariant: muted,
    outline: outline,
    error: dark ? DarkColors.error : AppColors._lError,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: outline.withValues(alpha: 0.75)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 0.6),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: 0.17),
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected) ? primary : muted,
        size: 22,
      )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        color: states.contains(WidgetState.selected) ? primary : muted,
      )),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: BorderSide(color: outline),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? DarkColors.surfaceVariant : AppColors._lSurface,
      hintStyle: TextStyle(color: muted),
      prefixIconColor: muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: outline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: outline.withValues(alpha: 0.7))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: primary, width: 1.5)),
    ),
  );

  return base.copyWith(
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w700, color: foreground),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? DarkColors.surfaceVariant : const Color(0xFF20243A),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
    ),
  );
}

extension AppColorsX on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;
  Color get appSurface => _isDark ? DarkColors.surface : AppColors._lSurface;
  Color get appBackground => _isDark ? DarkColors.background : AppColors._lBackground;
  Color get appOnSurface => _isDark ? DarkColors.onSurface : AppColors._lOnSurface;
  Color get appOnSurfaceVariant => _isDark ? DarkColors.onSurfaceVariant : AppColors._lOnSurfaceVar;
  Color get appSurfaceVariant => _isDark ? DarkColors.surfaceVariant : AppColors._lSurfaceVar;
  Color get appCardBorder => _isDark ? DarkColors.cardBorder : AppColors._lCardBorder;
  Color get appPrimary => _isDark ? DarkColors.primary : AppColors._lPrimary;
  Color get appPrimaryDark => _isDark ? DarkColors.primaryDark : AppColors._lPrimaryDark;
  Color get appPrimaryLight => _isDark ? DarkColors.primaryLight : AppColors._lPrimaryLight;
  Color get appSecondary => _isDark ? DarkColors.secondary : AppColors._lSecondary;
  Color get appSecondaryDark => _isDark ? DarkColors.secondaryDark : AppColors._lSecondaryDark;
  Color get appError => _isDark ? DarkColors.error : AppColors._lError;
  Color get appWarning => _isDark ? DarkColors.warning : AppColors._lWarning;
  Color get appSuccess => _isDark ? DarkColors.success : AppColors._lSuccess;
  Color get appOutline => _isDark ? DarkColors.outline : AppColors._lOutline;
}
