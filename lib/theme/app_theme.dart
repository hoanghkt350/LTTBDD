import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFE87855);
  static const Color secondary = Color(0xFF427968);
  static const Color accent = Color(0xFFEFC578);
  static const Color darkBackground = Color(0xFF203E35);
  static const Color lightBackground = Color(0xFFF8F9F5);
  static const Color textDark = Color(0xFF253D35);
  static const Color textLight = Color(0xFF738078);
  static const Color cardColor = Colors.white;
  static const Color line = Color(0xFFE5EAE3);
  static const Color mint = Color(0xFFEAF2E9);

  static ThemeData get lightTheme {
    final base = ThemeData(useMaterial3: true);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: secondary,
        primary: primary,
        secondary: secondary,
        surface: cardColor,
        onSurface: textDark,
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: base.textTheme
          .apply(bodyColor: textDark, displayColor: textDark)
          .copyWith(
            headlineMedium: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: textDark,
              letterSpacing: -1,
            ),
            titleLarge: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: textDark,
              letterSpacing: -.5,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: textDark,
            ),
            bodySmall: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: textLight,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        titleSpacing: 24,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: secondary,
          side: const BorderSide(color: line),
          minimumSize: const Size(48, 48),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        prefixIconColor: textLight,
        labelStyle: const TextStyle(color: textLight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: secondary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        selectedColor: mint,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontSize: 13, color: textDark),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        iconColor: secondary,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: TextStyle(
          color: textLight,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: mint,
        elevation: 0,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? secondary
                : textLight,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? secondary
                : textLight,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkBackground,
        shape: shape,
      ),
    );
  }
}
