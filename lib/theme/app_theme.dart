import 'package:flutter/material.dart';

@immutable
class GymBranding {
  final String gymId;
  final String gymName;
  final String logoUrl;
  final Color primaryColor;
  final Color secondaryColor;

  const GymBranding({
    this.gymId = '',
    this.gymName = 'GymFlow',
    this.logoUrl = '',
    this.primaryColor = AppTheme.skyBlue,
    this.secondaryColor = AppTheme.skyBlueLight,
  });

  GymBranding copyWith({
    String? gymId,
    String? gymName,
    String? logoUrl,
    Color? primaryColor,
    Color? secondaryColor,
  }) {
    return GymBranding(
      gymId: gymId ?? this.gymId,
      gymName: gymName ?? this.gymName,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
    );
  }

  factory GymBranding.fromMap(Map<String, dynamic>? data, {String gymId = ''}) {
    if (data == null) return GymBranding(gymId: gymId);
    final primary = AppTheme.parseColor(data['primaryColor']?.toString(), fallback: AppTheme.skyBlue);
    return GymBranding(
      gymId: gymId,
      gymName: data['name']?.toString().trim().isNotEmpty == true ? data['name'].toString().trim() : 'GymFlow',
      logoUrl: data['logoUrl']?.toString().trim() ?? '',
      primaryColor: primary,
      secondaryColor: AppTheme.parseColor(data['secondaryColor']?.toString(), fallback: AppTheme.lighten(primary, 0.22)),
    );
  }
}

@immutable
class GymBrandThemeExtension extends ThemeExtension<GymBrandThemeExtension> {
  final String gymId;
  final String gymName;
  final String logoUrl;
  final Color primaryColor;
  final Color secondaryColor;

  const GymBrandThemeExtension({
    required this.gymId,
    required this.gymName,
    required this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
  });

  factory GymBrandThemeExtension.fromBranding(GymBranding branding) {
    return GymBrandThemeExtension(
      gymId: branding.gymId,
      gymName: branding.gymName,
      logoUrl: branding.logoUrl,
      primaryColor: branding.primaryColor,
      secondaryColor: branding.secondaryColor,
    );
  }

  @override
  GymBrandThemeExtension copyWith({
    String? gymId,
    String? gymName,
    String? logoUrl,
    Color? primaryColor,
    Color? secondaryColor,
  }) {
    return GymBrandThemeExtension(
      gymId: gymId ?? this.gymId,
      gymName: gymName ?? this.gymName,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
    );
  }

  @override
  GymBrandThemeExtension lerp(ThemeExtension<GymBrandThemeExtension>? other, double t) {
    if (other is! GymBrandThemeExtension) return this;
    return GymBrandThemeExtension(
      gymId: t < 0.5 ? gymId : other.gymId,
      gymName: t < 0.5 ? gymName : other.gymName,
      logoUrl: t < 0.5 ? logoUrl : other.logoUrl,
      primaryColor: Color.lerp(primaryColor, other.primaryColor, t) ?? primaryColor,
      secondaryColor: Color.lerp(secondaryColor, other.secondaryColor, t) ?? secondaryColor,
    );
  }
}

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

  static ThemeData get lightTheme => lightThemeFor(const GymBranding());
  static ThemeData get darkTheme => darkThemeFor(const GymBranding());

  static Color parseColor(String? raw, {Color fallback = skyBlue}) {
    if (raw == null) return fallback;
    final clean = raw.trim().replaceAll('#', '').replaceAll('0x', '').replaceAll('0X', '');
    if (clean.isEmpty) return fallback;
    final normalized = clean.length == 6 ? 'FF$clean' : clean;
    if (normalized.length != 8) return fallback;
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }

  static Color lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  static ThemeData lightThemeFor(GymBranding branding) {
    final primary = branding.primaryColor;
    final secondary = branding.secondaryColor;
    final primaryStrong = darken(primary, 0.12);
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light, primary: primary, secondary: secondary, surface: lightSurface);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightCard,
      canvasColor: lightBackground,
      dividerColor: const Color(0xFFE2E8F0),
      extensions: [GymBrandThemeExtension.fromBranding(branding)],
      appBarTheme: const AppBarTheme(backgroundColor: lightBackground, foregroundColor: lightText, elevation: 0, centerTitle: false, surfaceTintColor: Colors.transparent, titleTextStyle: TextStyle(color: lightText, fontSize: 20, fontWeight: FontWeight.w900)),
      textTheme: const TextTheme(bodyLarge: TextStyle(color: lightText), bodyMedium: TextStyle(color: lightText), bodySmall: TextStyle(color: lightTextMuted), titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.w900), titleMedium: TextStyle(color: lightText, fontWeight: FontWeight.w800), titleSmall: TextStyle(color: lightText, fontWeight: FontWeight.w800)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, textStyle: const TextStyle(fontWeight: FontWeight.w900), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: primaryStrong, side: BorderSide(color: primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: primaryStrong)),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, labelStyle: const TextStyle(color: lightTextMuted), hintStyle: const TextStyle(color: lightTextMuted), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primary, width: 1.6))),
      snackBarTheme: SnackBarThemeData(backgroundColor: lightText, contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }

  static ThemeData darkThemeFor(GymBranding branding) {
    final primary = lighten(branding.primaryColor, 0.18);
    final secondary = branding.secondaryColor;
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark, primary: primary, secondary: secondary, surface: darkSurface);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      canvasColor: darkBackground,
      dividerColor: darkBorder,
      extensions: [GymBrandThemeExtension.fromBranding(branding.copyWith(primaryColor: primary))],
      appBarTheme: const AppBarTheme(backgroundColor: darkBackground, foregroundColor: darkText, elevation: 0, centerTitle: false, surfaceTintColor: Colors.transparent, titleTextStyle: TextStyle(color: darkText, fontSize: 20, fontWeight: FontWeight.w900)),
      textTheme: const TextTheme(bodyLarge: TextStyle(color: darkText), bodyMedium: TextStyle(color: darkText), bodySmall: TextStyle(color: darkTextMuted), titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w900), titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w800), titleSmall: TextStyle(color: darkText, fontWeight: FontWeight.w800)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: darkBackground, textStyle: const TextStyle(fontWeight: FontWeight.w900), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: primary, side: BorderSide(color: primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: primary)),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: darkSurface, labelStyle: const TextStyle(color: darkTextMuted), hintStyle: const TextStyle(color: darkTextMuted), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: darkBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: darkBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primary, width: 1.6))),
      snackBarTheme: SnackBarThemeData(backgroundColor: darkSurface, contentTextStyle: const TextStyle(color: darkText, fontWeight: FontWeight.w700), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }
}

extension GymFlowThemeColors on BuildContext {
  bool get gymIsDark => Theme.of(this).brightness == Brightness.dark;
  GymBrandThemeExtension get gymBrand => Theme.of(this).extension<GymBrandThemeExtension>() ?? GymBrandThemeExtension.fromBranding(const GymBranding());
  String get gymBrandName => gymBrand.gymName;
  String get gymBrandLogoUrl => gymBrand.logoUrl;
  Color get gymPrimary => Theme.of(this).colorScheme.primary;
  Color get gymPrimaryStrong => gymIsDark ? AppTheme.lighten(gymPrimary, 0.08) : AppTheme.darken(gymPrimary, 0.12);
  Color get gymFitnessAccent => gymIsDark ? AppTheme.lighten(gymPrimary, 0.22) : gymPrimary;
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
      ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.darken(gymPrimary, 0.34), const Color(0xFF071024), const Color(0xFF020617)], stops: const [0.0, 0.24, 1.0])
      : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [gymPrimary.withValues(alpha: 0.18), const Color(0xFFF8FAFC), Colors.white], stops: const [0.0, 0.34, 1.0]);
  LinearGradient get gymTrainerHomeGradient => gymIsDark
      ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.darken(gymPrimary, 0.30), const Color(0xFF071024), const Color(0xFF020617)], stops: const [0.0, 0.25, 1.0])
      : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [gymPrimary.withValues(alpha: 0.18), const Color(0xFFF8FAFC), Colors.white], stops: const [0.0, 0.34, 1.0]);
  LinearGradient get gymHeroGradient => gymIsDark
      ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.darken(gymPrimary, 0.30), const Color(0xFF06111D)])
      : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, gymPrimary.withValues(alpha: 0.14)]);
  LinearGradient get gymTrainerHeroGradient => gymIsDark
      ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.darken(gymPrimary, 0.26), const Color(0xFF08101F)])
      : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, gymPrimary.withValues(alpha: 0.14)]);
}
