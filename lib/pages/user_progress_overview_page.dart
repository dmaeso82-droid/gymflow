import 'package:flutter/material.dart';
import '../features/user_dashboard.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import 'user_routines_page.dart';

class UserProgressOverviewPage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const UserProgressOverviewPage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi progreso')),
      body: Container(
        decoration: BoxDecoration(gradient: context.gymHomeGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              AppCard(
                padding: const EdgeInsets.all(14),
                radius: 26,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.gymPrimary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.insights_rounded, color: context.gymPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mi progreso', style: TextStyle(color: context.gymText, fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text('Prestigio, semana, ranking y transformación en una pantalla separada.', style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: context.gymSubtleSurface),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserRoutinesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail),
                        ),
                      ),
                      icon: const Icon(Icons.fitness_center_rounded),
                      tooltip: 'Entrenar',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              UserDashboard(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail),
            ],
          ),
        ),
      ),
    );
  }
}
