import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/header_card.dart';
import '../widgets/menu_action_card.dart';
import '../widgets/profile_avatar.dart';
import 'user_calendar_page.dart';
import 'user_goals_page.dart';
import 'user_history_page.dart';
import 'user_measurements_page.dart';
import 'user_progress_page.dart';
import 'user_records_page.dart';
import 'user_routines_page.dart';
import 'user_weekly_summary_page.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('GymFlow · $userName'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
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
            MenuActionCard(
              icon: Icons.fitness_center,
              title: 'Mis rutinas',
              subtitle: 'Ver rutinas asignadas y registrar series.',
              onTap: () => openPage(
                context,
                UserRoutinesPage(
                  gymId: gymId,
                  userId: userId,
                  userName: userName,
                  userEmail: userEmail,
                ),
              ),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.calendar_month,
              title: 'Calendario',
              subtitle: 'Ver la planificación semanal de entrenamientos.',
              onTap: () => openPage(
                context,
                UserCalendarPage(gymId: gymId, userEmail: userEmail),
              ),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.flag,
              title: 'Mis objetivos',
              subtitle: 'Consultar objetivos definidos por el entrenador.',
              onTap: () => openPage(
                context,
                UserGoalsPage(gymId: gymId, userEmail: userEmail),
              ),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.monitor_weight,
              title: 'Progreso físico',
              subtitle: 'Registrar peso corporal y medidas.',
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
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.calendar_view_week,
              title: 'Resumen semanal',
              subtitle: 'Ver actividad registrada esta semana.',
              onTap: () => openPage(
                context,
                UserWeeklySummaryPage(gymId: gymId, userId: userId),
              ),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.emoji_events,
              title: 'Récords personales',
              subtitle: 'Consultar mejores marcas por ejercicio.',
              onTap: () => openPage(
                context,
                UserRecordsPage(gymId: gymId, userId: userId),
              ),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.trending_up,
              title: 'Evolución',
              subtitle: 'Ver gráficas de progreso por ejercicio.',
              onTap: () => openPage(
                context,
                UserProgressPage(gymId: gymId, userId: userId),
              ),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.history,
              title: 'Historial',
              subtitle: 'Editar o eliminar entrenamientos registrados.',
              onTap: () => openPage(
                context,
                UserHistoryPage(gymId: gymId, userId: userId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
