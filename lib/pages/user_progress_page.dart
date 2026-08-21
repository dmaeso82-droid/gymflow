import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../features/exercise_progress.dart';
import '../theme/app_theme.dart';

class UserProgressPage extends StatelessWidget {
  final String gymId;
  final String userId;
  const UserProgressPage({super.key, required this.gymId, required this.userId});

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('workout_logs');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi evolución')),
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
                Text('Progreso', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: context.gymText)),
                const SizedBox(height: 4),
                Text('Consulta marcas, cargas y evolución de tus entrenamientos.', style: TextStyle(color: context.gymMutedText)),
              ]),
            ),
            const SizedBox(height: 16),
            ExerciseProgress(logsRef: logsRef, userId: userId),
          ],
        ),
      ),
    );
  }
}
