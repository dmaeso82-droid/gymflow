import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/exercise_progress.dart';
import '../features/personal_records.dart';
import '../features/recent_workout_history.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/header_card.dart';
import '../widgets/routine_card.dart';

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

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('routines');

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  Future<void> saveWorkoutLog({
    required String routineId,
    required String routineTitle,
    required Map<String, dynamic> exercise,
    required int weight,
    required int reps,
  }) async {
    await logsRef.add({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail.toLowerCase(),
      'routineId': routineId,
      'routineTitle': routineTitle,
      'exerciseId': exercise['id'] ?? '',
      'exercise': exercise['name'] ?? 'Ejercicio',
      'plannedSets': exercise['sets'] ?? '',
      'plannedReps': exercise['reps'] ?? '',
      'plannedWeight': exercise['weight'] ?? '',
      'weight': weight,
      'reps': reps,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> showWorkoutLogDialog(
    BuildContext context,
    String routineId,
    String routineTitle,
    List<dynamic> exercises,
    String exerciseId,
  ) async {
    final exercise = exercises
        .map((item) => Map<String, dynamic>.from(item as Map))
        .firstWhere((item) => item['id'] == exerciseId);

    final weightText = (exercise['weight'] ?? '').toString();
    final repsText = (exercise['reps'] ?? '').toString();
    final suggestedWeight = RegExp(r'\d+').firstMatch(weightText)?.group(0) ?? '';
    final suggestedReps = RegExp(r'\d+').firstMatch(repsText)?.group(0) ?? '';

    final weightController = TextEditingController(text: suggestedWeight);
    final repsController = TextEditingController(text: suggestedReps);

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text('Registrar ${exercise['name'] ?? 'ejercicio'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: weightController,
                label: 'Peso realizado (kg)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: repsController,
                label: 'Repeticiones realizadas',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final weight = int.tryParse(weightController.text.trim());
                final reps = int.tryParse(repsController.text.trim());

                if (weight == null || reps == null || weight < 0 || reps <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce peso y repeticiones válidas.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, {'weight': weight, 'reps': reps});
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar serie'),
            ),
          ],
        );
      },
    );

    weightController.dispose();
    repsController.dispose();

    if (result == null) return;

    await saveWorkoutLog(
      routineId: routineId,
      routineTitle: routineTitle,
      exercise: exercise,
      weight: result['weight']!,
      reps: result['reps']!,
    );

    await updateExerciseDone(routineId, exercises, exerciseId, true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serie guardada en el historial.')),
      );
    }
  }

  Future<void> updateExerciseDone(String routineId, List<dynamic> exercises, String exerciseId, bool done) async {
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) map['done'] = done;
      return map;
    }).toList();

    await routinesRef.doc(routineId).update({'exercises': updated});
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
              child: Text(
                'Mostrando solo rutinas asignadas a: $userEmail',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: routinesRef.where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final routines = snapshot.data?.docs ?? [];

                if (routines.isEmpty) {
                  return const AppCard(
                    child: Center(
                      child: Text(
                        'Todavía no tienes rutinas asignadas. Comprueba que el entrenador haya creado el cliente con este mismo email.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Column(
                  children: routines.map((doc) {
                    final data = doc.data();
                    final exercises = List<dynamic>.from(data['exercises'] ?? []);

                    return RoutineCard(
                      title: data['title'] ?? 'Sin título',
                      day: data['day'] ?? 'Sin día',
                      notes: data['notes'] ?? '',
                      clientName: 'Mi rutina',
                      exercises: exercises,
                      trainerMode: false,
                      onToggleExercise: (exerciseId, done) => updateExerciseDone(doc.id, exercises, exerciseId, done),
                      onLogWorkout: (exerciseId) => showWorkoutLogDialog(
                        context,
                        doc.id,
                        data['title'] ?? 'Sin título',
                        exercises,
                        exerciseId,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            PersonalRecords(
              logsRef: logsRef,
              userId: userId,
            ),
            const SizedBox(height: 16),
            ExerciseProgress(
              logsRef: logsRef,
              userId: userId,
            ),
            const SizedBox(height: 16),
            RecentWorkoutHistory(
              logsRef: logsRef,
              userId: userId,
            ),
          ],
        ),
      ),
    );
  }
}
