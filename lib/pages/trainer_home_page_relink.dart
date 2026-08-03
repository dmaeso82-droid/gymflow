
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/header_card.dart';
import 'settings_page.dart';
import 'community_page.dart';
import 'challenges_page.dart';
import 'notifications_page.dart';
import 'trainer_calendar_page.dart';
import 'trainer_clients_page.dart';
import 'trainer_goals_page.dart';
import 'trainer_measurements_page.dart';
import 'trainer_progress_page.dart';
import 'trainer_routines_page.dart';
import 'trainer_trainers_page.dart';


class NotificationsBell extends StatelessWidget {
  final String gymId;

  const NotificationsBell({super.key, required this.gymId});

  DocumentReference<Map<String, dynamic>> get readRef {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notification_reads')
        .doc(gymId);
  }

  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('activity');

  void openNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationsPage(gymId: gymId)),
    );
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
                IconButton(
                  tooltip: 'Notificaciones',
                  onPressed: () => openNotifications(context),
                  icon: const Icon(Icons.notifications),
                ),
                if (count > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
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

  const TrainerHomePage({
    super.key,
    required this.gymId,
    required this.trainerName,
    this.trainerRole = 'trainer',
  });

  bool get isGymAdmin => trainerRole == 'gym_admin';

  void openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  CollectionReference<Map<String, dynamic>> collection(String name) {
    return FirebaseFirestore.instance.collection('gyms').doc(gymId).collection(name);
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      TrainerQuickAction(
        icon: Icons.people,
        title: 'Clientes',
        subtitle: 'Altas y edición',
        onTap: () => openPage(context, TrainerClientsPage(gymId: gymId)),
      ),
      TrainerQuickAction(
        icon: Icons.groups,
        title: 'Entrenadores',
        subtitle: isGymAdmin ? 'Equipo y roles' : 'Equipo',
        onTap: () => openPage(context, TrainerTrainersPage(gymId: gymId, trainerRole: trainerRole)),
      ),
      TrainerQuickAction(
        icon: Icons.forum,
        title: 'Comunidad',
        subtitle: 'Muro',
        onTap: () => openPage(
          context,
          CommunityPage(
            gymId: gymId,
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
            currentUserName: trainerName,
            currentUserEmail: FirebaseAuth.instance.currentUser?.email ?? '',
            trainerMode: true,
          ),
        ),
      ),
      TrainerQuickAction(
        icon: Icons.emoji_events,
        title: 'Retos',
        subtitle: 'Comunidad',
        onTap: () => openPage(
          context,
          ChallengesPage(
            gymId: gymId,
            userId: FirebaseAuth.instance.currentUser?.uid ?? '',
            userName: trainerName,
            userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
            trainerMode: true,
          ),
        ),
      ),
      TrainerQuickAction(
        icon: Icons.calendar_month,
        title: 'Calendario',
        subtitle: 'Plan semanal',
        onTap: () => openPage(context, TrainerCalendarPage(gymId: gymId)),
      ),
      TrainerQuickAction(
        icon: Icons.insights,
        title: 'Progreso',
        subtitle: 'Entrenos',
        onTap: () => openPage(context, TrainerProgressPage(gymId: gymId)),
      ),
      TrainerQuickAction(
        icon: Icons.monitor_weight,
        title: 'Medidas',
        subtitle: 'Físico',
        onTap: () => openPage(context, TrainerMeasurementsPage(gymId: gymId)),
      ),
      TrainerQuickAction(
        icon: Icons.flag,
        title: 'Objetivos',
        subtitle: 'Metas',
        onTap: () => openPage(context, TrainerGoalsPage(gymId: gymId)),
      ),
      TrainerQuickAction(
        icon: Icons.settings,
        title: 'Ajustes',
        subtitle: 'Cuenta',
        onTap: () => openPage(
          context,
          SettingsPage(userEmail: FirebaseAuth.instance.currentUser?.email ?? ''),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('GymFlow · $trainerName'),
        actions: [
          NotificationsBell(gymId: gymId),
          IconButton(
            tooltip: 'Configuración',
            onPressed: () => openPage(
              context,
              SettingsPage(userEmail: FirebaseAuth.instance.currentUser?.email ?? ''),
            ),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HeaderCard(subtitle: 'Panel de entrenador'),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, size: 16, color: Colors.greenAccent),
                        const SizedBox(width: 6),
                        Text(
                          isGymAdmin ? 'Admin del gimnasio' : 'Entrenador',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${greeting()}, $trainerName',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gestiona clientes, rutinas automáticas, entrenadores, objetivos y progreso desde un panel más rápido y visual.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  TrainerStatsGrid(
                    trainersStream: collection('trainers').snapshots(),
                    clientsStream: collection('clients').snapshots(),
                    routinesStream: collection('routines').snapshots(),
                    goalsStream: collection('goals').snapshots(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.fitness_center, color: Colors.greenAccent),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GESTIONAR RUTINAS',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Plantillas automáticas, generación por cliente y ejercicios favoritos.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => openPage(context, TrainerRoutinesPage(gymId: gymId)),
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Abrir rutinas'),
                    ),
                  ),
                ],
              ),
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
                  TrainerQuickActionGrid(actions: actions),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TrainerRecentActivityCard(
              activityStream: collection('activity')
                  .orderBy('createdAt', descending: true)
                  .limit(8)
                  .snapshots(),
            ),
          ],
        ),
      ),
    );
  }
}


class TrainerRecentActivityCard extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> activityStream;

  const TrainerRecentActivityCard({super.key, required this.activityStream});

  String activityTitle(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final user = data['user']?.toString() ?? 'Alguien';
    final target = data['target']?.toString() ?? 'un elemento';

    switch (type) {
      case 'client_created':
        return '$user creó el cliente $target';
      case 'client_updated':
        return '$user actualizó el cliente $target';
      case 'client_deleted':
        return '$user eliminó el cliente $target';
      case 'routine_created':
        return '$user creó la rutina $target';
      case 'routine_generated':
        final metadata = data['metadata'];
        final clientName = metadata is Map ? metadata['clientName']?.toString() : null;
        return clientName == null || clientName.isEmpty
            ? '$user generó una rutina automática'
            : '$user generó una rutina para $clientName';
      case 'routine_updated':
        return '$user actualizó la rutina $target';
      case 'routine_deleted':
        return '$user eliminó la rutina $target';
      case 'routine_exercise_added':
        return '$user añadió $target a una rutina';
      case 'routine_exercise_updated':
        return '$user actualizó $target en una rutina';
      case 'routine_exercise_deleted':
        return '$user eliminó $target de una rutina';
      case 'template_created':
        return '$user creó la plantilla $target';
      case 'template_renamed':
        return '$user renombró la plantilla $target';
      case 'template_duplicated':
        return '$user duplicó la plantilla $target';
      case 'template_deleted':
        return '$user eliminó la plantilla $target';
      case 'template_day_updated':
        return '$user actualizó un día de $target';
      case 'template_exercise_added':
        return '$user añadió $target a una plantilla';
      case 'template_exercise_updated':
        return '$user actualizó $target en una plantilla';
      case 'template_exercise_deleted':
        return '$user eliminó $target de una plantilla';
      case 'template_exercise_moved':
        return '$user reordenó $target en una plantilla';
      case 'measurement_created':
        return '$user registró medidas de $target';
      case 'measurement_deleted':
        return '$user eliminó medidas de $target';
      case 'goal_created':
        return '$user creó el objetivo $target';
      case 'goal_updated':
        return '$user actualizó el objetivo $target';
      case 'goal_completed':
        return '$user completó el objetivo $target';
      case 'goal_reopened':
        return '$user reabrió el objetivo $target';
      case 'goal_deleted':
        return '$user eliminó el objetivo $target';
      default:
        return '$user realizó una acción sobre $target';
    }
  }

  IconData activityIcon(String type) {
    if (type.startsWith('client_')) return Icons.person;
    if (type.startsWith('routine_')) return Icons.fitness_center;
    if (type.startsWith('template_')) return Icons.tune;
    if (type.startsWith('measurement_')) return Icons.monitor_weight;
    if (type.startsWith('goal_')) return Icons.flag;
    return Icons.history;
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month · $hour:$minute';
    }
    return 'Fecha pendiente';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Colors.greenAccent),
              SizedBox(width: 8),
              Text(
                'Actividad reciente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: activityStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final activities = snapshot.data?.docs ?? [];
              if (activities.isEmpty) {
                return const Text(
                  'Todavía no hay actividad registrada. Cuando los entrenadores creen clientes, rutinas, plantillas, objetivos o medidas, aparecerá aquí.',
                  style: TextStyle(color: Colors.white70),
                );
              }

              return Column(
                children: activities.map((doc) {
                  final data = doc.data();
                  final type = data['type']?.toString() ?? '';
                  final title = activityTitle(data);
                  final dateText = formatDate(data['createdAt']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(activityIcon(type), color: Colors.greenAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                dateText,
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class TrainerStatsGrid extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> trainersStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> clientsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> routinesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> goalsStream;

  const TrainerStatsGrid({
    super.key,
    required this.trainersStream,
    required this.clientsStream,
    required this.routinesStream,
    required this.goalsStream,
  });

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
                    final trainersCount = (trainersSnapshot.data?.docs ?? [])
                        .where((doc) => doc.data()['active'] != false)
                        .length;
                    final clientsCount = clientsSnapshot.data?.docs.length ?? 0;
                    final activeRoutinesCount = (routinesSnapshot.data?.docs ?? [])
                        .where((doc) => (doc.data()['status'] ?? 'active').toString() != 'archived')
                        .length;
                    final pendingGoalsCount = (goalsSnapshot.data?.docs ?? [])
                        .where((doc) => doc.data()['completed'] != true)
                        .length;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth < 620 ? 2 : 4;
                        const spacing = 10.0;
                        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            SizedBox(
                              width: width,
                              child: TrainerStatTile(
                                icon: Icons.groups,
                                value: trainersCount.toString(),
                                label: 'Entrenadores',
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: TrainerStatTile(
                                icon: Icons.people,
                                value: clientsCount.toString(),
                                label: 'Clientes',
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: TrainerStatTile(
                                icon: Icons.playlist_add_check,
                                value: activeRoutinesCount.toString(),
                                label: 'Rutinas',
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: TrainerStatTile(
                                icon: Icons.flag,
                                value: pendingGoalsCount.toString(),
                                label: 'Objetivos',
                              ),
                            ),
                          ],
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

class TrainerStatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const TrainerStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.greenAccent, size: 22),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class TrainerQuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const TrainerQuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class TrainerQuickActionGrid extends StatelessWidget {
  final List<TrainerQuickAction> actions;

  const TrainerQuickActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620 ? 2 : 3;
        const spacing = 10.0;
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((action) {
            return SizedBox(
              width: tileWidth,
              child: TrainerQuickActionTile(action: action),
            );
          }).toList(),
        );
      },
    );
  }
}

class TrainerQuickActionTile extends StatelessWidget {
  final TrainerQuickAction action;

  const TrainerQuickActionTile({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF020617),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: action.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
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
