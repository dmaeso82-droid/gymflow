import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import 'settings_page.dart';
import 'community_page.dart';
import 'challenges_page.dart';
import 'rankings_page.dart';
import 'notifications_page.dart';
import 'conversations_page.dart';
import 'trainer_calendar_page.dart';
import 'trainer_clients_page.dart';
import 'trainer_goals_page.dart';
import 'trainer_measurements_page.dart';
import 'trainer_progress_page.dart';
import 'trainer_routines_page.dart';
import 'trainer_trainers_page.dart';
import 'stats_backfill_page.dart';
import 'user_home_page.dart';

part 'trainer_home/notifications_bell.dart';
part 'trainer_home/trainer_header.dart';
part 'trainer_home/trainer_dashboard_v2.dart';
part 'trainer_home/trainer_recent_activity_card.dart';
part 'trainer_home/trainer_stats_grid.dart';
part 'trainer_home/trainer_quick_actions.dart';
part 'trainer_home/trainer_bottom_nav.dart';

class TrainerHomePage extends StatelessWidget {
  final String gymId;
  final String trainerName;
  final String trainerRole;
  const TrainerHomePage({super.key, required this.gymId, required this.trainerName, this.trainerRole = 'trainer'});

  bool get isGymAdmin => trainerRole == 'gym_admin';

  void openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String firstName() {
    final clean = trainerName.trim();
    if (clean.isEmpty) return 'Entrenador';
    return clean.split(RegExp(r'\s+')).first;
  }

  CollectionReference<Map<String, dynamic>> collection(String name) {
    return FirebaseFirestore.instance.collection('gyms').doc(gymId).collection(name);
  }

  Future<void> ensureTrainerClientProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final email = (user.email ?? '').trim().toLowerCase();
    final name = trainerName.trim().isEmpty ? (user.displayName ?? 'Entrenador') : trainerName.trim();
    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'isClient': true, 'updatedAt': now}, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('clients').doc(user.uid).set({
      'authUid': user.uid,
      'name': name,
      'email': email,
      'isTrainer': true,
      'isTrainerClient': true,
      'active': true,
      'updatedAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> openMyTraining(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await ensureTrainerClientProfile();
    if (!context.mounted) return;
    openPage(context, UserHomePage(gymId: gymId, userId: user.uid, userName: trainerName, userEmail: user.email ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final actions = [
      TrainerQuickAction(icon: Icons.self_improvement, title: 'Mi entreno', priority: true, onTap: () => openMyTraining(context)),
      TrainerQuickAction(icon: Icons.people, title: 'Clientes', priority: true, onTap: () => openPage(context, TrainerClientsPage(gymId: gymId))),
      TrainerQuickAction(icon: Icons.fitness_center, title: 'Rutinas', priority: true, onTap: () => openPage(context, TrainerRoutinesPage(gymId: gymId))),
      TrainerQuickAction(icon: Icons.chat_bubble_outline, title: 'Chat', priority: true, onTap: () => openPage(context, ConversationsPage(gymId: gymId, currentUserId: currentUid, currentUserName: trainerName, currentUserEmail: currentEmail, currentRole: 'trainer'))),
      TrainerQuickAction(icon: Icons.calendar_month, title: 'Agenda', onTap: () => openPage(context, TrainerCalendarPage(gymId: gymId))),
      TrainerQuickAction(icon: Icons.flag, title: 'Objetivos', onTap: () => openPage(context, TrainerGoalsPage(gymId: gymId))),
      TrainerQuickAction(icon: Icons.insights, title: 'Progreso', onTap: () => openPage(context, TrainerProgressPage(gymId: gymId))),
      TrainerQuickAction(icon: Icons.monitor_weight, title: 'Medidas', onTap: () => openPage(context, TrainerMeasurementsPage(gymId: gymId))),
      TrainerQuickAction(icon: Icons.forum, title: 'Muro', onTap: () => openPage(context, CommunityPage(gymId: gymId, currentUserId: currentUid, currentUserName: trainerName, currentUserEmail: currentEmail, trainerMode: true))),
      TrainerQuickAction(icon: Icons.emoji_events, title: 'Retos', onTap: () => openPage(context, ChallengesPage(gymId: gymId, userId: currentUid, userName: trainerName, userEmail: currentEmail, trainerMode: true))),
      TrainerQuickAction(icon: Icons.leaderboard, title: 'Ranking', onTap: () => openPage(context, RankingsPage(gymId: gymId, currentUserId: currentUid, currentUserName: trainerName, currentUserEmail: currentEmail))),
      TrainerQuickAction(icon: Icons.groups, title: 'Equipo', onTap: () => openPage(context, TrainerTrainersPage(gymId: gymId, trainerRole: trainerRole))),
      if (isGymAdmin) TrainerQuickAction(icon: Icons.sync, title: 'Recalcular', onTap: () => openPage(context, StatsBackfillPage(gymId: gymId))),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: _TrainerBottomNav(
        onTraining: () => openMyTraining(context),
        onClients: () => openPage(context, TrainerClientsPage(gymId: gymId)),
        onRoutines: () => openPage(context, TrainerRoutinesPage(gymId: gymId)),
        onCommunity: () => openPage(context, CommunityPage(gymId: gymId, currentUserId: currentUid, currentUserName: trainerName, currentUserEmail: currentEmail, trainerMode: true)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.gymTrainerHomeGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: _TrainerHeader(
                    title: 'Hola, ${firstName()}',
                    subtitle: isGymAdmin ? 'Panel de admin DalaiGym' : 'Panel de entrenador',
                    gymId: gymId,
                    onSettings: () => openPage(context, SettingsPage(userEmail: currentEmail)),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    TrainerDashboardV2(
                      greeting: greeting(),
                      trainersStream: collection('trainers').snapshots(),
                      clientsStream: collection('clients').snapshots(),
                      routinesStream: collection('routines').snapshots(),
                      goalsStream: collection('goals').snapshots(),
                      userStatsStream: collection('user_stats').snapshots(),
                      activityStream: collection('activity').orderBy('createdAt', descending: true).limit(8).snapshots(),
                      onOpenClients: () => openPage(context, TrainerClientsPage(gymId: gymId)),
                      onOpenRoutines: () => openPage(context, TrainerRoutinesPage(gymId: gymId)),
                      onOpenRoutineForClient: (clientId, clientName) => openPage(context, TrainerRoutinesPage(gymId: gymId, initialClientId: clientId, initialClientName: clientName, focusCreation: true)),
                      onOpenGoals: () => openPage(context, TrainerGoalsPage(gymId: gymId)),
                      onOpenTrainers: () => openPage(context, TrainerTrainersPage(gymId: gymId, trainerRole: trainerRole)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: FilledButton.icon(onPressed: () => openMyTraining(context), icon: const Icon(Icons.self_improvement), label: const Text('Mi entreno'))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton.icon(onPressed: () => openPage(context, TrainerRoutinesPage(gymId: gymId)), icon: const Icon(Icons.fitness_center), label: const Text('Rutinas'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.all(12),
                      radius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.grid_view_rounded, color: context.gymPrimary), const SizedBox(width: 8), const Text('Accesos inteligentes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))]),
                          const SizedBox(height: 10),
                          TrainerQuickActionGrid(actions: actions),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TrainerRecentActivityCard(activityStream: collection('activity').orderBy('createdAt', descending: true).limit(8).snapshots()),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
