import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pages/auth_page.dart';
import 'pages/loading_page.dart';
import 'pages/role_gate_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class GymFlowApp extends StatelessWidget {
  const GymFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GymFlowThemePreference>(
      valueListenable: ThemeController.preference,
      builder: (context, preference, _) {
        return MaterialApp(
          title: 'GymFlow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.themeMode,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingPage();
              }
              if (snapshot.hasData) {
                return const RoleGatePage();
              }
              return const AuthPage();
            },
          ),
        );
      },
    );
  }
}



