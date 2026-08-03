
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/header_card.dart';
import '../widgets/profile_avatar.dart';
import '../features/user_dashboard.dart';
import 'user_achievements_page.dart';
import 'user_calendar_page.dart';
import 'user_goals_page.dart';
import 'user_history_page.dart';
import 'user_measurements_page.dart';
import 'user_progress_page.dart';
import 'user_records_page.dart';
import 'user_weekly_summary_page.dart';
import 'settings_page.dart';
import 'community_page.dart';
import 'challenges_page.dart';

class UserHomePage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const UserHomePage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  void openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      QuickAction(
        icon: Icons.groups,
        title: 'Comunidad',
        subtitle: 'DalaiGym',
        onTap: () => openPage(
          context,
          CommunityPage(
            gymId: gymId,
            currentUserId: userId,
            currentUserName: userName,
            currentUserEmail: userEmail,
          ),
        ),
      ),
      QuickAction(
        icon: Icons.emoji_events,
        title: 'Retos',
        subtitle: 'Gimnasio',
        onTap: () => openPage(
          context,
          ChallengesPage(
            gymId: gymId,
            userId: userId,
            userName: userName,
            userEmail: userEmail,
          ),
        ),
      ),
      QuickAction(
        icon: Icons.military_tech,
        title: 'Logros',
        subtitle: 'Medallas',
        onTap: () => openPage(
          context,
          UserAchievementsPage(
            gymId: gymId,
            userId: userId,
            userEmail: userEmail,
          ),
        ),
      ),
      QuickAction(
        icon: Icons.calendar_month,
        title: 'Calendario',
        subtitle: 'Semana',
        onTap: () => openPage(
          context,
          UserCalendarPage(gymId: gymId, userEmail: userEmail),
        ),
      ),
      QuickAction(
        icon: Icons.flag,
        title: 'Objetivos',
        subtitle: 'Pendientes',
        onTap: () => openPage(
          context,
          UserGoalsPage(gymId: gymId, userEmail: userEmail),
        ),
      ),
      QuickAction(
        icon: Icons.monitor_weight,
        title: 'Progreso',
        subtitle: 'Medidas',
        onTap: () => openPage(
          context,
          UserMeasurementsPage(
            gymId: gymId,
            userId: userId,
            userName: userName,
            userEmail: userEmail,
          ),
        ),
      ),
      QuickAction(
        icon: Icons.calendar_view_week,
        title: 'Resumen',
        subtitle: 'Semanal',
        onTap: () => openPage(
          context,
          UserWeeklySummaryPage(gymId: gymId, userId: userId),
        ),
      ),
      QuickAction(
        icon: Icons.emoji_events,
        title: 'Récords',
        subtitle: 'Marcas',
        onTap: () => openPage(
          context,
          UserRecordsPage(gymId: gymId, userId: userId),
        ),
      ),
      QuickAction(
        icon: Icons.trending_up,
        title: 'Evolución',
        subtitle: 'Gráficas',
        onTap: () => openPage(
          context,
          UserProgressPage(gymId: gymId, userId: userId),
        ),
      ),
      QuickAction(
        icon: Icons.history,
        title: 'Historial',
        subtitle: 'Registros',
        onTap: () => openPage(
          context,
          UserHistoryPage(gymId: gymId, userId: userId),
        ),
      ),
      QuickAction(
        icon: Icons.settings,
        title: 'Cuenta',
        subtitle: 'Ajustes',
        onTap: () => openPage(
          context,
          SettingsPage(userEmail: userEmail),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('GymFlow · $userName'),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            onPressed: () => openPage(
              context,
              SettingsPage(userEmail: userEmail),
            ),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HeaderCard(subtitle: 'Panel de usuario'),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  ProfileAvatar(name: userName, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            UserDashboard(
              gymId: gymId,
              userId: userId,
              userName: userName,
              userEmail: userEmail,
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.apps, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text(
                        'Accesos rápidos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  QuickActionGrid(actions: actions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class QuickActionGrid extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth < 520 ? 2 : 3;
        const spacing = 10.0;
        final tileWidth = (maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((action) {
            return SizedBox(
              width: tileWidth,
              child: QuickActionTile(action: action),
            );
          }).toList(),
        );
      },
    );
  }
}

class QuickActionTile extends StatelessWidget {
  final QuickAction action;

  const QuickActionTile({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF020617),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: action.onTap,
        child: Container(
			constraints: const BoxConstraints(
				minHeight: 104,
			),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(action.icon, color: Colors.greenAccent, size: 21),
              ),
              const SizedBox(height: 10),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
