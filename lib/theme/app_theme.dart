import 'package:flutter/material.dart';

class AppTheme {
  static const Color skyBlue = Color(0xFF0EA5E9);
  static const Color skyBlueDark = Color(0xFF0284C7);
  static const Color skyBlueLight = Color(0xFF38BDF8);
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF475569);

  static const Color darkBackground = Color(0xFF020617);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF111827);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextMuted = Color(0xFFCBD5E1);

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: skyBlue,
      brightness: Brightness.light,
      primary: skyBlue,
      secondary: skyBlueLight,
      surface: lightSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightCard,
      canvasColor: lightBackground,
      dividerColor: const Color(0xFFE2E8F0),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightText,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightText),
        bodySmall: TextStyle(color: lightTextMuted),
        titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.w900),
        titleMedium: TextStyle(color: lightText, fontWeight: FontWeight.w800),
        titleSmall: TextStyle(color: lightText, fontWeight: FontWeight.w800),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: skyBlue,
          foregroundColor: Colors.white,
          textStyle: TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: skyBlueDark,
          side: BorderSide(color: skyBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: skyBlueDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: lightTextMuted),
        hintStyle: TextStyle(color: lightTextMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: skyBlue, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightText,
        contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: skyBlueLight,
      brightness: Brightness.dark,
      primary: skyBlueLight,
      secondary: skyBlue,
      surface: darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      canvasColor: darkBackground,
      dividerColor: darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: darkText),
        bodySmall: TextStyle(color: darkTextMuted),
        titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w900),
        titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w800),
        titleSmall: TextStyle(color: darkText, fontWeight: FontWeight.w800),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: skyBlueLight,
          foregroundColor: darkBackground,
          textStyle: TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: skyBlueLight,
          side: BorderSide(color: skyBlueLight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: skyBlueLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        labelStyle: TextStyle(color: darkTextMuted),
        hintStyle: TextStyle(color: darkTextMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: skyBlueLight, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurface,
        contentTextStyle: TextStyle(color: darkText, fontWeight: FontWeight.w700),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}


extension GymFlowThemeColors on BuildContext {
  bool get gymIsDark => Theme.of(this).brightness == Brightness.dark;
  Color get gymPrimary => Theme.of(this).colorScheme.primary;
  Color get gymPrimaryStrong => gymIsDark ? AppTheme.skyBlueLight : AppTheme.skyBlueDark;
  Color get gymFitnessAccent => gymIsDark ? const Color(0xFF34D399) : AppTheme.skyBlue;
  Color get gymText => gymIsDark ? AppTheme.darkText : AppTheme.lightText;
  Color get gymMutedText => gymIsDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
  Color get gymSurface => Theme.of(this).cardColor;
  Color get gymInsetSurface => gymIsDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
  Color get gymSubtleSurface => gymIsDark ? const Color(0xFF050A18) : const Color(0xFFF1F5F9);
  Color get gymElevatedSurface => gymIsDark ? const Color(0xFF06111D) : Colors.white;
  Color get gymBorder => gymIsDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
  Color get gymStrongBorder => gymIsDark ? gymFitnessAccent.withValues(alpha: 0.28) : gymPrimary.withValues(alpha: 0.28);
  Color get gymProgressTrack => gymIsDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0);

  LinearGradient get gymHomeGradient => gymIsDark
      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF052014), Color(0xFF071024), Color(0xFF020617)], stops: [0.0, 0.24, 1.0])
      : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE0F2FE), Color(0xFFF8FAFC), Color(0xFFFFFFFF)], stops: [0.0, 0.34, 1.0]);

  LinearGradient get gymTrainerHomeGradient => gymIsDark
      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF102015), Color(0xFF071024), Color(0xFF020617)], stops: [0.0, 0.25, 1.0])
      : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE0F2FE), Color(0xFFF8FAFC), Color(0xFFFFFFFF)], stops: [0.0, 0.34, 1.0]);

  LinearGradient get gymHeroGradient => gymIsDark
      ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF082717), Color(0xFF06111D)])
      : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFE0F2FE)]);

  LinearGradient get gymTrainerHeroGradient => gymIsDark
      ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF133B27), Color(0xFF08101F)])
      : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFE0F2FE)]);
}



