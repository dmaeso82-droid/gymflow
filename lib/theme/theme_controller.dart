import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

enum GymFlowThemePreference { system, light, dark }

class ThemeController {
  static const String _storageKey = 'gymflow_theme_preference';
  static const String _brandingGymIdKey = 'gymflow_branding_gym_id';
  static const String _brandingGymNameKey = 'gymflow_branding_gym_name';
  static const String _brandingLogoUrlKey = 'gymflow_branding_logo_url';
  static const String _brandingPrimaryColorKey = 'gymflow_branding_primary_color';
  static const String _brandingSecondaryColorKey = 'gymflow_branding_secondary_color';

  static final ValueNotifier<GymFlowThemePreference> preference = ValueNotifier<GymFlowThemePreference>(GymFlowThemePreference.system);
  static final ValueNotifier<GymBranding> branding = ValueNotifier<GymBranding>(const GymBranding());
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _gymBrandingSubscription;
  static String? _activeGymId;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    preference.value = _fromStorage(stored);
    branding.value = GymBranding(
      gymId: prefs.getString(_brandingGymIdKey) ?? '',
      gymName: prefs.getString(_brandingGymNameKey) ?? 'GymFlow',
      logoUrl: prefs.getString(_brandingLogoUrlKey) ?? '',
      primaryColor: AppTheme.parseColor(prefs.getString(_brandingPrimaryColorKey), fallback: AppTheme.skyBlue),
      secondaryColor: AppTheme.parseColor(prefs.getString(_brandingSecondaryColorKey), fallback: AppTheme.skyBlueLight),
    );
  }

  static ThemeMode get themeMode {
    switch (preference.value) {
      case GymFlowThemePreference.light:
        return ThemeMode.light;
      case GymFlowThemePreference.dark:
        return ThemeMode.dark;
      case GymFlowThemePreference.system:
        return ThemeMode.system;
    }
  }

  static Future<void> setPreference(GymFlowThemePreference value) async {
    preference.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value.name);
  }

  static void clearGymBranding() {
    _activeGymId = null;
    _gymBrandingSubscription?.cancel();
    _gymBrandingSubscription = null;
    branding.value = const GymBranding();
  }

  static Future<void> loadBrandingForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      clearGymBranding();
      return;
    }
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final gymId = userDoc.data()?['gymId']?.toString() ?? '';
    if (gymId.isEmpty) {
      clearGymBranding();
      return;
    }
    listenToGymBranding(gymId);
  }

  static void listenToGymBranding(String gymId) {
    if (_activeGymId == gymId && _gymBrandingSubscription != null) return;
    _activeGymId = gymId;
    _gymBrandingSubscription?.cancel();
    _gymBrandingSubscription = FirebaseFirestore.instance.collection('gyms').doc(gymId).snapshots().listen((snapshot) async {
      final next = GymBranding.fromMap(snapshot.data(), gymId: gymId);
      branding.value = next;
      await _persistBranding(next);
    });
  }

  static Future<void> _persistBranding(GymBranding value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brandingGymIdKey, value.gymId);
    await prefs.setString(_brandingGymNameKey, value.gymName);
    await prefs.setString(_brandingLogoUrlKey, value.logoUrl);
    await prefs.setString(_brandingPrimaryColorKey, '#${value.primaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}');
    await prefs.setString(_brandingSecondaryColorKey, '#${value.secondaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}');
  }

  static GymFlowThemePreference _fromStorage(String? value) {
    for (final option in GymFlowThemePreference.values) {
      if (option.name == value) return option;
    }
    return GymFlowThemePreference.system;
  }
}
