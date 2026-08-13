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

class NotificationsBell extends StatelessWidget {
  final String gymId;
  const NotificationsBell({super.key, required this.gymId});

  DocumentReference<Map<String, dynamic>> get readRef {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('notification_reads').doc(gymId);
  }

  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('activity');

  void openNotifications(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(gymId: gymId)));
  }

  int unreadCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> activities, Timestamp? lastReadAt) {
    if (lastReadAt == null) return activities.length;
    final lastReadMillis = lastReadAt.millisecondsSinceEpoch;
    return activities.where((doc) {
      final createdAt = doc.data()['createdAt'];
      if (createdAt is! Timestamp) return false;
      return createdAt.millisecondsSinceEpoch > lastReadMillis;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: readRef.snapshots(),
      builder: (context, readSnapshot) {
        final readData = readSnapshot.data?.data();
        final lastReadAt = readData?['lastReadAt'] is Timestamp ? readData!['lastReadAt'] as Timestamp : null;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: activityRef.orderBy('createdAt', descending: true).limit(50).snapshots(),
          builder: (context, activitySnapshot) {
            final activities = activitySnapshot.data?.docs ?? [];
            final count = unreadCount(activities, lastReadAt);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Notificaciones',
                  onPressed: () => openNotifications(context),
                  icon: const Icon(Icons.notifications),
                ),
                if (count > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(999)),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(count > 99 ? '99+' : count.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

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

class _TrainerHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String gymId;
  final VoidCallback onSettings;
  const _TrainerHeader({required this.title, required this.subtitle, required this.gymId, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.86 : 0.98), borderRadius: BorderRadius.circular(26), border: Border.all(color: context.gymBorder)),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GymFlow Trainer', style: TextStyle(color: context.gymPrimary, fontSize: 13, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.0)),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: context.gymMutedText, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          NotificationsBell(gymId: gymId),
          const SizedBox(width: 6),
          IconButton.filled(style: IconButton.styleFrom(backgroundColor: context.gymSubtleSurface), onPressed: onSettings, icon: const Icon(Icons.settings)),
        ],
      ),
    );
  }
}

class TrainerDashboardV2 extends StatelessWidget {
  final String greeting;
  final Stream<QuerySnapshot<Map<String, dynamic>>> trainersStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> clientsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> routinesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> goalsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> userStatsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> activityStream;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenRoutines;
  final void Function(String clientId, String clientName) onOpenRoutineForClient;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenTrainers;

  const TrainerDashboardV2({
    super.key,
    required this.greeting,
    required this.trainersStream,
    required this.clientsStream,
    required this.routinesStream,
    required this.goalsStream,
    required this.userStatsStream,
    required this.activityStream,
    required this.onOpenClients,
    required this.onOpenRoutines,
    required this.onOpenRoutineForClient,
    required this.onOpenGoals,
    required this.onOpenTrainers,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: clientsStream,
      builder: (context, clientsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: routinesStream,
          builder: (context, routinesSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: goalsStream,
              builder: (context, goalsSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: trainersStream,
                  builder: (context, trainersSnapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: userStatsStream,
                      builder: (context, statsSnapshot) {
                        final clients = clientsSnapshot.data?.docs ?? [];
                        final routines = routinesSnapshot.data?.docs ?? [];
                        final goals = goalsSnapshot.data?.docs ?? [];
                        final trainers = trainersSnapshot.data?.docs ?? [];
                        final stats = statsSnapshot.data?.docs ?? [];
                        final activeClients = clients.where((doc) => doc.data()['active'] != false).toList();
                        final activeRoutines = routines.where((doc) => (doc.data()['status'] ?? 'active').toString() != 'archived').toList();
                        final pendingGoals = goals.where((doc) => doc.data()['completed'] != true).toList();
                        final activeTrainers = trainers.where((doc) => doc.data()['active'] != false).length;
                        final clientsWithRoutine = activeRoutines.map((doc) => (doc.data()['clientId'] ?? '').toString()).where((id) => id.isNotEmpty).toSet();
                        final clientsWithoutRoutine = activeClients.where((doc) => !clientsWithRoutine.contains(doc.id)).toList();
                        final completion = activeClients.isEmpty ? 0.0 : (clientsWithRoutine.length / activeClients.length).clamp(0.0, 1.0);
                        final statsByKey = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
                        for (final doc in stats) {
                          final data = doc.data();
                          final userId = data['userId']?.toString() ?? '';
                          final email = (data['userEmail'] ?? '').toString().toLowerCase();
                          statsByKey[doc.id] = doc;
                          if (userId.isNotEmpty) statsByKey[userId] = doc;
                          if (email.isNotEmpty) statsByKey[email] = doc;
                        }
                        Timestamp? timestampValue(dynamic value) => value is Timestamp ? value : null;
                        QueryDocumentSnapshot<Map<String, dynamic>>? statForClient(QueryDocumentSnapshot<Map<String, dynamic>> client) {
                          final data = client.data();
                          final authUid = data['authUid']?.toString() ?? '';
                          final email = (data['email'] ?? '').toString().toLowerCase();
                          if (authUid.isNotEmpty && statsByKey.containsKey(authUid)) return statsByKey[authUid];
                          if (statsByKey.containsKey(client.id)) return statsByKey[client.id];
                          if (email.isNotEmpty && statsByKey.containsKey(email)) return statsByKey[email];
                          return null;
                        }
                        final now = DateTime.now();
                        final riskClients = <_ClientRiskEntry>[];
                        for (final client in activeClients) {
                          final data = client.data();
                          final name = data['name']?.toString() ?? 'Cliente';
                          final stat = statForClient(client);
                          final lastWorkout = timestampValue(stat?.data()['lastWorkout']);
                          final reasons = <String>[];
                          var score = 0;
                          final hasRoutine = clientsWithRoutine.contains(client.id);
                          if (!hasRoutine) {
                            reasons.add('Sin rutina');
                            score += 2;
                          }
                          if (lastWorkout == null) {
                            reasons.add('Sin entrenos registrados');
                            score += 3;
                          } else {
                            final days = now.difference(lastWorkout.toDate()).inDays;
                            if (days >= 14) {
                              reasons.add('$days días sin entrenar');
                              score += 3;
                            } else if (days >= 7) {
                              reasons.add('$days días sin entrenar');
                              score += 2;
                            }
                          }
                          if (score > 0) riskClients.add(_ClientRiskEntry(clientId: client.id, name: name, score: score, reasons: reasons, needsRoutine: !hasRoutine));
                        }
                        riskClients.sort((a, b) => b.score.compareTo(a.score));
                        return AppCard(
                          padding: const EdgeInsets.all(18),
                          radius: 30,
                          gradient: context.gymTrainerHeroGradient,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: context.gymFitnessAccent.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: context.gymStrongBorder),
                                    ),
                                    child: Icon(Icons.bolt_rounded, color: context.gymPrimary, size: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(greeting, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.0)),
                                        const SizedBox(height: 5),
                                        Text('Resumen rápido de tu gimnasio', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  const spacing = 8.0;
                                  final width = (constraints.maxWidth - spacing) / 2;
                                  return Wrap(spacing: spacing, runSpacing: spacing, children: [
                                    SizedBox(width: width, child: TrainerStatTile(icon: Icons.people, value: activeClients.length.toString(), label: 'Clientes activos', onTap: onOpenClients)),
                                    SizedBox(width: width, child: TrainerStatTile(icon: Icons.fitness_center, value: activeRoutines.length.toString(), label: 'Rutinas activas', onTap: onOpenRoutines)),
                                    SizedBox(width: width, child: TrainerStatTile(icon: Icons.flag, value: pendingGoals.length.toString(), label: 'Objetivos pendientes', onTap: onOpenGoals)),
                                    SizedBox(width: width, child: TrainerStatTile(icon: Icons.groups, value: activeTrainers.toString(), label: 'Entrenadores', onTap: onOpenTrainers)),
                                  ]);
                                },
                              ),
                              const SizedBox(height: 14),
                              _GymHealthBar(value: completion, missingClients: clientsWithoutRoutine.length),
                              const SizedBox(height: 12),
                              _TrainerClientRiskCenter(riskClients: riskClients, onOpenClients: onOpenClients, onOpenRoutineForClient: onOpenRoutineForClient),
                              const SizedBox(height: 12),
                              _NeedsAttentionSection(
                                clientsWithoutRoutine: clientsWithoutRoutine,
                                pendingGoals: pendingGoals,
                                activityStream: activityStream,
                                onOpenClients: onOpenClients,
                                onOpenRoutines: onOpenRoutines,
                                onOpenGoals: onOpenGoals,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ClientRiskEntry {
  final String clientId;
  final String name;
  final int score;
  final List<String> reasons;
  final bool needsRoutine;
  const _ClientRiskEntry({required this.clientId, required this.name, required this.score, required this.reasons, required this.needsRoutine});

  bool get needsFollowUp => reasons.any((reason) => reason.contains('entren'));
  String get recommendedAction => needsRoutine ? 'Asignar rutina' : 'Ver cliente';
  String get actionText => needsRoutine ? 'Crear rutina para este cliente' : 'Revisar seguimiento del cliente';
}

class _TrainerClientRiskCenter extends StatelessWidget {
  final List<_ClientRiskEntry> riskClients;
  final VoidCallback onOpenClients;
  final void Function(String clientId, String clientName) onOpenRoutineForClient;
  const _TrainerClientRiskCenter({required this.riskClients, required this.onOpenClients, required this.onOpenRoutineForClient});

  Color scoreColor(BuildContext context, int score) {
    if (score >= 5) return Colors.redAccent;
    if (score >= 3) return Colors.orangeAccent;
    return context.gymFitnessAccent;
  }

  String scoreLabel(int score) {
    if (score >= 5) return 'Alto';
    if (score >= 3) return 'Medio';
    return 'Bajo';
  }

  void openRecommendedAction(_ClientRiskEntry entry) {
    if (entry.needsRoutine) {
      onOpenRoutineForClient(entry.clientId, entry.name);
    } else {
      onOpenClients();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routineCount = riskClients.where((entry) => entry.needsRoutine).length;
    final followUpCount = riskClients.where((entry) => !entry.needsRoutine).length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.74 : 0.94), borderRadius: BorderRadius.circular(24), border: Border.all(color: context.gymBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.health_and_safety_rounded, color: riskClients.isEmpty ? Colors.green : Colors.orangeAccent, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Clientes en riesgo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            Text('${riskClients.length}', style: TextStyle(color: riskClients.isEmpty ? Colors.green : Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
          const SizedBox(height: 8),
          if (riskClients.isEmpty)
            Text('No hay clientes activos con señales de abandono ahora mismo.', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700))
          else ...[
            Text('$routineCount requieren rutina · $followUpCount requieren seguimiento', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...riskClients.take(6).map((entry) {
              final color = scoreColor(context, entry.score);
              final reasonAndAction = '${entry.reasons.join(' · ')} · ${entry.recommendedAction}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => openRecommendedAction(entry),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.70 : 0.82), borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
                    child: Row(children: [
                      Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)), child: Icon(entry.needsRoutine ? Icons.fitness_center_rounded : Icons.person_search_rounded, color: color, size: 19)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text(reasonAndAction, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ])),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                        child: Text(scoreLabel(entry.score), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                      Icon(Icons.chevron_right_rounded, color: color, size: 22),
                    ]),
                  ),
                ),
              );
            }),
            if (riskClients.length > 6)
              TextButton.icon(onPressed: onOpenClients, icon: const Icon(Icons.list_alt_rounded), label: Text('Ver ${riskClients.length - 6} más')),
          ],
        ],
      ),
    );
  }
}

class _GymHealthBar extends StatelessWidget {
  final double value;
  final int missingClients;
  const _GymHealthBar({required this.value, required this.missingClients});

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    final statusText = missingClients == 0 ? 'Todos los clientes activos tienen rutina' : '$missingClients clientes activos sin rutina';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.74 : 0.92), borderRadius: BorderRadius.circular(22), border: Border.all(color: context.gymBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: context.gymFitnessAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Estado del gimnasio', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              Text('$percent%', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: value,
              backgroundColor: context.gymProgressTrack,
              valueColor: AlwaysStoppedAnimation<Color>(context.gymFitnessAccent),
            ),
          ),
          const SizedBox(height: 8),
          Text(statusText, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _NeedsAttentionSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> clientsWithoutRoutine;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingGoals;
  final Stream<QuerySnapshot<Map<String, dynamic>>> activityStream;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenRoutines;
  final VoidCallback onOpenGoals;

  const _NeedsAttentionSection({required this.clientsWithoutRoutine, required this.pendingGoals, required this.activityStream, required this.onOpenClients, required this.onOpenRoutines, required this.onOpenGoals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(Icons.tips_and_updates_rounded, color: context.gymPrimary, size: 20), const SizedBox(width: 8), const Text('Qué revisar hoy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 10),
        if (clientsWithoutRoutine.isEmpty && pendingGoals.isEmpty)
          _AttentionItem(
            icon: Icons.check_circle_rounded,
            color: Colors.green,
            title: 'Todo está bajo control',
            subtitle: 'No hay avisos importantes ahora mismo.',
            onTap: onOpenClients,
          )
        else ...[
          if (clientsWithoutRoutine.isNotEmpty)
            _AttentionItem(
              icon: Icons.assignment_late_rounded,
              color: Colors.orangeAccent,
              title: '${clientsWithoutRoutine.length} clientes sin rutina',
              subtitle: _clientNames(clientsWithoutRoutine),
              onTap: onOpenRoutines,
            ),
          if (pendingGoals.isNotEmpty)
            _AttentionItem(
              icon: Icons.flag_rounded,
              color: context.gymPrimary,
              title: '${pendingGoals.length} objetivos pendientes',
              subtitle: 'Revisa objetivos abiertos y próximos avances.',
              onTap: onOpenGoals,
            ),
        ],
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: activityStream,
          builder: (context, snapshot) {
            final recent = snapshot.data?.docs.length ?? 0;
            return _AttentionItem(
              icon: Icons.history_rounded,
              color: context.gymFitnessAccent,
              title: '$recent movimientos recientes',
              subtitle: 'Últimas actualizaciones registradas en el gimnasio.',
              onTap: null,
            );
          },
        ),
      ],
    );
  }

  String _clientNames(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final names = docs.take(3).map((doc) => (doc.data()['name'] ?? 'Cliente').toString()).toList();
    if (docs.length > 3) names.add('+${docs.length - 3} más');
    return names.join(' · ');
  }
}

class _AttentionItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _AttentionItem({required this.icon, required this.color, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
            child: Row(
              children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color, size: 21)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (onTap != null) Icon(Icons.chevron_right_rounded, color: context.gymMutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TrainerRecentActivityCard extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> activityStream;
  const TrainerRecentActivityCard({super.key, required this.activityStream});

  String activityTitle(Map<String, dynamic> data) {
    final user = data['user']?.toString() ?? 'Alguien';
    final target = data['target']?.toString() ?? 'un elemento';
    final type = data['type']?.toString() ?? '';
    if (type == 'client_created') return '$user creó a $target';
    if (type == 'client_updated') return '$user actualizó a $target';
    if (type == 'client_deleted') return '$user eliminó a $target';
    if (type.startsWith('routine_')) return '$user actualizó la rutina $target';
    if (type.startsWith('goal_')) return '$user revisó el objetivo $target';
    if (type.startsWith('measurement_')) return '$user registró medidas de $target';
    return '$user actualizó $target';
  }

  IconData activityIcon(String type) {
    if (type == 'client_deleted') return Icons.person_remove_alt_1_rounded;
    if (type.startsWith('client_')) return Icons.person_rounded;
    if (type.startsWith('routine_')) return Icons.fitness_center_rounded;
    if (type.startsWith('template_')) return Icons.tune_rounded;
    if (type.startsWith('measurement_')) return Icons.monitor_weight_rounded;
    if (type.startsWith('goal_')) return Icons.flag_rounded;
    return Icons.history_rounded;
  }

  Color activityColor(BuildContext context, String type) {
    if (type == 'client_deleted') return Colors.redAccent;
    if (type.startsWith('client_')) return context.gymPrimary;
    if (type.startsWith('routine_')) return context.gymFitnessAccent;
    if (type.startsWith('measurement_')) return Colors.purpleAccent;
    if (type.startsWith('goal_')) return Colors.orangeAccent;
    return context.gymMutedText;
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Fecha pendiente';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.history, color: context.gymPrimary), const SizedBox(width: 8), const Text('Actividad reciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: activityStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator()));
            final activities = snapshot.data?.docs ?? [];
            if (activities.isEmpty) return Text('Todavía no hay actividad registrada.', style: TextStyle(color: context.gymMutedText));
            return Column(
              children: activities.map((doc) {
                final data = doc.data();
                final type = data['type']?.toString() ?? '';
                final color = activityColor(context, type);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.gymBorder)),
                  child: Row(children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(13)), child: Icon(activityIcon(type), color: color, size: 19)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(activityTitle(data), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                    const SizedBox(width: 8),
                    Text(formatDate(data['createdAt']), style: TextStyle(color: context.gymMutedText, fontSize: 11)),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }
}

class TrainerStatsGrid extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> trainersStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> clientsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> routinesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> goalsStream;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenRoutines;
  final VoidCallback onOpenGoals;
  const TrainerStatsGrid({super.key, required this.trainersStream, required this.clientsStream, required this.routinesStream, required this.goalsStream, required this.onOpenTrainers, required this.onOpenClients, required this.onOpenRoutines, required this.onOpenGoals});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: trainersStream,
      builder: (context, trainersSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: clientsStream,
          builder: (context, clientsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: routinesStream,
              builder: (context, routinesSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: goalsStream,
                  builder: (context, goalsSnapshot) {
                    final trainersCount = (trainersSnapshot.data?.docs ?? []).where((doc) => doc.data()['active'] != false).length;
                    final clientsCount = clientsSnapshot.data?.docs.length ?? 0;
                    final activeRoutinesCount = (routinesSnapshot.data?.docs ?? []).where((doc) => (doc.data()['status'] ?? 'active').toString() != 'archived').length;
                    final pendingGoalsCount = (goalsSnapshot.data?.docs ?? []).where((doc) => doc.data()['completed'] != true).length;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 8.0;
                        final width = (constraints.maxWidth - spacing) / 2;
                        return Wrap(spacing: spacing, runSpacing: spacing, children: [
                          SizedBox(width: width, child: TrainerStatTile(icon: Icons.groups, value: trainersCount.toString(), label: 'Entrenadores', onTap: onOpenTrainers)),
                          SizedBox(width: width, child: TrainerStatTile(icon: Icons.people, value: clientsCount.toString(), label: 'Clientes', onTap: onOpenClients)),
                          SizedBox(width: width, child: TrainerStatTile(icon: Icons.playlist_add_check, value: activeRoutinesCount.toString(), label: 'Rutinas', onTap: onOpenRoutines)),
                          SizedBox(width: width, child: TrainerStatTile(icon: Icons.flag, value: pendingGoalsCount.toString(), label: 'Objetivos', onTap: onOpenGoals)),
                        ]);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class TrainerStatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;
  const TrainerStatTile({super.key, required this.icon, required this.value, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 84,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.gymBorder)),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: context.gymPrimary, size: 21)),
            const SizedBox(width: 10),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, height: 1.0)),
              const SizedBox(height: 5),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class TrainerQuickAction {
  final IconData icon;
  final String title;
  final bool priority;
  final VoidCallback onTap;
  const TrainerQuickAction({required this.icon, required this.title, required this.onTap, this.priority = false});
}

class TrainerQuickActionGrid extends StatelessWidget {
  final List<TrainerQuickAction> actions;
  const TrainerQuickActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 3 : 5;
        const spacing = 8.0;
        final sorted = [...actions]..sort((a, b) => b.priority.toString().compareTo(a.priority.toString()));
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(spacing: spacing, runSpacing: spacing, children: sorted.map((action) => SizedBox(width: tileWidth, child: TrainerQuickActionTile(action: action))).toList());
      },
    );
  }
}

class TrainerQuickActionTile extends StatelessWidget {
  final TrainerQuickAction action;
  const TrainerQuickActionTile({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    final bg = action.priority ? context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.22 : 0.12) : context.gymSubtleSurface;
    final border = action.priority ? context.gymPrimary.withValues(alpha: 0.34) : context.gymBorder;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: action.onTap,
        child: Ink(
          height: action.priority ? 82 : 76,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(action.icon, color: action.priority ? context.gymPrimaryStrong : context.gymPrimary, size: action.priority ? 26 : 24),
            const SizedBox(height: 7),
            Text(action.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

class _TrainerBottomNav extends StatelessWidget {
  final VoidCallback onTraining;
  final VoidCallback onClients;
  final VoidCallback onRoutines;
  final VoidCallback onCommunity;
  const _TrainerBottomNav({required this.onTraining, required this.onClients, required this.onRoutines, required this.onCommunity});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.96 : 0.98), borderRadius: BorderRadius.circular(28), border: Border.all(color: context.gymBorder), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.34), blurRadius: 22, offset: const Offset(0, 10))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          const _TrainerNavItem(icon: Icons.home_rounded, label: 'Inicio', active: true),
          _TrainerNavItem(icon: Icons.self_improvement, label: 'Entreno', onTap: onTraining),
          _TrainerNavItem(icon: Icons.people, label: 'Clientes', onTap: onClients),
          _TrainerNavItem(icon: Icons.fitness_center, label: 'Rutinas', onTap: onRoutines),
          _TrainerNavItem(icon: Icons.groups, label: 'Muro', onTap: onCommunity),
        ]),
      ),
    );
  }
}

class _TrainerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _TrainerNavItem({required this.icon, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? context.gymPrimary : context.gymMutedText;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
