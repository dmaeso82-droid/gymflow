import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/header_card.dart';
import '../widgets/menu_action_card.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GymFlow · $trainerName'),
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
            const HeaderCard(subtitle: 'Panel de entrenador'),
            const SizedBox(height: 16),
            MenuActionCard(
              icon: Icons.people,
              title: 'Clientes',
              subtitle: 'Crear, editar o eliminar clientes.',
              onTap: () => openPage(context, TrainerClientsPage(gymId: gymId)),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.playlist_add_check,
              title: 'Rutinas',
              subtitle: 'Crear rutinas y gestionar ejercicios por cliente.',
              onTap: () => openPage(context, TrainerRoutinesPage(gymId: gymId)),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.calendar_month,
              title: 'Calendario',
              subtitle: 'Ver planificación semanal por cliente.',
              onTap: () => openPage(context, TrainerCalendarPage(gymId: gymId)),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.insights,
              title: 'Progreso',
              subtitle: 'Ver entrenamientos recientes y resumen del cliente.',
              onTap: () => openPage(context, TrainerProgressPage(gymId: gymId)),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.monitor_weight,
              title: 'Medidas',
              subtitle: 'Consultar el progreso físico del cliente.',
              onTap: () => openPage(context, TrainerMeasurementsPage(gymId: gymId)),
            ),
            const SizedBox(height: 12),
            MenuActionCard(
              icon: Icons.flag,
              title: 'Objetivos',
              subtitle: 'Crear y gestionar objetivos del cliente.',
              onTap: () => openPage(context, TrainerGoalsPage(gymId: gymId)),
            ),
          ],
        ),
      ),
    );
  }
}
