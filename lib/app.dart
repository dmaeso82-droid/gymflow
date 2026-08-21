import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pages/auth_page.dart';
import 'pages/loading_page.dart';
import 'pages/role_gate_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/premium_rewards_listener.dart';

class GymFlowApp extends StatelessWidget {
  const GymFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GymFlowThemePreference>(
      valueListenable: ThemeController.preference,
      builder: (context, preference, _) {
        return ValueListenableBuilder<GymBranding>(
          valueListenable: ThemeController.branding,
          builder: (context, branding, __) {
            return MaterialApp(
              title: branding.gymName.trim().isEmpty ? 'GymFlow' : branding.gymName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightThemeFor(branding),
              darkTheme: AppTheme.darkThemeFor(branding),
              themeMode: ThemeController.themeMode,
              home: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const LoadingPage();
                  if (snapshot.hasData) return const _GymBrandingBootstrap(child: PremiumRewardsListener(child: RoleGatePage()));
                  ThemeController.clearGymBranding();
                  return const AuthPage();
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _GymBrandingBootstrap extends StatefulWidget {
  final Widget child;
  const _GymBrandingBootstrap({required this.child});

  @override
  State<_GymBrandingBootstrap> createState() => _GymBrandingBootstrapState();
}

class _GymBrandingBootstrapState extends State<_GymBrandingBootstrap> {
  @override
  void initState() {
    super.initState();
    ThemeController.loadBrandingForCurrentUser();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
