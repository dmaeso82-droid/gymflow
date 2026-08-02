
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/header_card.dart';
import 'settings_page.dart';
import 'trainer_calendar_page.dart';
import 'trainer_clients_page.dart';
import 'trainer_goals_page.dart';
import 'trainer_measurements_page.dart';
import 'trainer_progress_page.dart';
import 'trainer_routines_page.dart';

class TrainerHomePage extends StatelessWidget {
  final String gymId;
  final String trainerName;

  const TrainerHomePage({super.key, required this.gymId, required this.trainerName});

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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 16, color: Colors.greenAccent),
                        SizedBox(width: 6),
                        Text(
                          'Dashboard del entrenador',
                          style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w800),
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
                    'Gestiona clientes, rutinas automáticas, objetivos y progreso desde un panel más rápido y visual.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  TrainerStatsGrid(
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
          ],
        ),
      ),
    );
  }
}

class TrainerStatsGrid extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> clientsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> routinesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> goalsStream;

  const TrainerStatsGrid({
    super.key,
    required this.clientsStream,
    required this.routinesStream,
    required this.goalsStream,
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
                final clientsCount = clientsSnapshot.data?.docs.length ?? 0;
                final activeRoutinesCount = (routinesSnapshot.data?.docs ?? [])
                    .where((doc) => (doc.data()['status'] ?? 'active').toString() != 'archived')
                    .length;
                final pendingGoalsCount = (goalsSnapshot.data?.docs ?? [])
                    .where((doc) => doc.data()['completed'] != true)
                    .length;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 560 ? 3 : 3;
                    const spacing = 10.0;
                    final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
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
