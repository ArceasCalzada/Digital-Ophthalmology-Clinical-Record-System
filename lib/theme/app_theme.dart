import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global ThemeController for dynamic Light, Dark, and System Default theme switching
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._() {
    _load();
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      if (_themeMode == ThemeMode.system) {
        notifyListeners();
      }
    };
  }

  static const _key = 'docrs_appearance_preference';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    // System Default: match OS-level preference
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      _save();
    }
  }

  void setThemeModeByName(String name) {
    switch (name) {
      case 'Dark':
        setThemeMode(ThemeMode.dark);
        break;
      case 'System Default':
        setThemeMode(ThemeMode.system);
        break;
      case 'Light':
      default:
        setThemeMode(ThemeMode.light);
        break;
    }
  }

  String get currentModeName {
    switch (_themeMode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, currentModeName);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) {
        setThemeModeByName(saved);
      }
    } catch (_) {}
  }
}

class AppTheme {
  // Primary Vibrant Blue & Accent Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color odColor = Color(0xFF2563EB);    // Blue for OD (Right Eye)
  static const Color osColor = Color(0xFFD97706);    // Amber for OS (Left Eye)

  static bool get _isDark => ThemeController.instance.isDarkMode;

  // Dynamic Theme Backgrounds & Surfaces
  static Color get primaryNavy => _isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get cardBg => _isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get lightBg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  // Dynamic Text & Border Colors
  static Color get textPrimary => _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get borderColor => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  // Light Theme Configuration (Modern & Simple UI)
  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardColor: const Color(0xFFFFFFFF),
      primaryColor: primaryBlue,
      dividerColor: const Color(0xFFE2E8F0),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        disabledColor: const Color(0xFFF8FAFC),
        selectedColor: primaryBlue,
        secondarySelectedColor: primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(color: Color(0xFF0F172A)),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        brightness: Brightness.light,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: odColor,
        surface: Color(0xFFFFFFFF),
      ),
    );
  }

  // Dark Theme Configuration (High-Contrast Clinical Slate)
  static ThemeData get darkTheme {
    const darkBg = Color(0xFF0F172A);
    const darkCardBg = Color(0xFF1E293B);
    const darkTextPrimary = Color(0xFFF8FAFC);
    const darkTextSecondary = Color(0xFF94A3B8);
    const darkBorder = Color(0xFF334155);

    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCardBg,
      primaryColor: primaryBlue,
      dividerColor: darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCardBg,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCardBg,
        disabledColor: darkBg,
        selectedColor: primaryBlue,
        secondarySelectedColor: primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(color: darkTextPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        brightness: Brightness.dark,
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: darkBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: odColor,
        surface: darkCardBg,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
    );
  }
}
