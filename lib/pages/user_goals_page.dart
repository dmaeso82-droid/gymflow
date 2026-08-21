import 'package:flutter/material.dart';
import '../features/client_goals_user.dart';
import '../theme/app_theme.dart';

class UserGoalsPage extends StatelessWidget {
  final String gymId;
  final String userEmail;

  const UserGoalsPage({super.key, required this.gymId, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis objetivos')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Objetivos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: context.gymText)),
                const SizedBox(height: 4),
                Text('Haz seguimiento de tus metas y celebra cada avance.', style: TextStyle(color: context.gymMutedText)),
              ]),
            ),
            const SizedBox(height: 16),
            ClientGoalsUserPanel(gymId: gymId, userEmail: userEmail),
          ],
        ),
      ),
    );
  }
}
