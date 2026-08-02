
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/routine_card.dart';

class UserRoutinesPage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const UserRoutinesPage({
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

  static const quickWeights = <double>[
    2.5,
    5,
    7.5,
    10,
    12.5,
    15,
    16,
    17.5,
    18,
    20,
    22.5,
    25,
    27.5,
    30,
    32.5,
    35,
    37.5,
    40,
    45,
    50,
    55,
    60,
    70,
    80,
    90,
    100,
  ];

  static const quickReps = <int>[1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30];

  bool isActiveRoutine(Map<String, dynamic> data) {
    return (data['status'] ?? 'active').toString() != 'archived';
  }

  int intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    final text = value?.toString() ?? '';
    final match = RegExp(r'\d+').firstMatch(text);
    return int.tryParse(match?.group(0) ?? '') ?? fallback;
  }

  double? decimalValue(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String formatWeight(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  int totalSets(Map<String, dynamic> exercise) {
    final parsed = intValue(exercise['sets'], fallback: 1);
    return parsed <= 0 ? 1 : parsed;
  }

  int completedSets(Map<String, dynamic> exercise) {
    final total = totalSets(exercise);
    final rawCompleted = intValue(exercise['completedSets'], fallback: -1);

    if (rawCompleted >= 0) {
      return rawCompleted.clamp(0, total).toInt();
    }

    if (exercise['done'] == true) return total;
    return 0;
  }

  int routineDayOrder(String day) {
    switch (day) {
      case 'Lunes':
        return 1;
      case 'Martes':
        return 2;
      case 'Miércoles':
        return 3;
      case 'Jueves':
        return 4;
      case 'Viernes':
        return 5;
      case 'Sábado':
        return 6;
      case 'Domingo':
        return 7;
      default:
        return 99;
    }
  }

  Future<void> saveWorkoutLog({
    required String routineId,
    required String routineTitle,
    required Map<String, dynamic> exercise,
    required double weight,
    required int reps,
    required int setNumber,
    required int plannedSetCount,
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
      'setNumber': setNumber,
      'plannedSetCount': plannedSetCount,
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

    final plannedSetCount = totalSets(exercise);
    final currentCompletedSets = completedSets(exercise);

    if (currentCompletedSets >= plannedSetCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este ejercicio ya tiene todas las series registradas.')),
      );
      return;
    }

    final nextSetNumber = currentCompletedSets + 1;
    final weightText = (exercise['weight'] ?? '').toString();
    final repsText = (exercise['reps'] ?? '').toString();
    final suggestedWeightRaw = RegExp(r'\d+(?:[\.,]\d+)?').firstMatch(weightText)?.group(0) ?? '';
    final suggestedWeight = suggestedWeightRaw.replaceAll('.', ',');
    final suggestedReps = RegExp(r'\d+').firstMatch(repsText)?.group(0) ?? '';

    final weightController = TextEditingController(text: suggestedWeight);
    final repsController = TextEditingController(text: suggestedReps);


    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: Text('Registrar ${exercise['name'] ?? 'ejercicio'} ($nextSetNumber/$plannedSetCount)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pesos rápidos',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: quickWeights.map((weight) {
                          final text = formatWeight(weight);
                          final selected = weightController.text.trim() == text;
                          return ChoiceChip(
                            label: Text('$text kg'),
                            selected: selected,
                            selectedColor: Colors.greenAccent.withOpacity(0.22),
                            backgroundColor: const Color(0xFF020617),
                            labelStyle: TextStyle(
                              color: selected ? Colors.greenAccent : Colors.white70,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                            side: BorderSide(color: selected ? Colors.greenAccent : Colors.white12),
                            onSelected: (_) {
                              setDialogState(() {
                                weightController.text = text;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: weightController,
                      label: 'Peso realizado (kg)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Repeticiones rápidas',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: quickReps.map((reps) {
                          final text = reps.toString();
                          final selected = repsController.text.trim() == text;
                          return ChoiceChip(
                            label: Text(text),
                            selected: selected,
                            selectedColor: Colors.greenAccent.withOpacity(0.22),
                            backgroundColor: const Color(0xFF020617),
                            labelStyle: TextStyle(
                              color: selected ? Colors.greenAccent : Colors.white70,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                            side: BorderSide(color: selected ? Colors.greenAccent : Colors.white12),
                            onSelected: (_) {
                              setDialogState(() {
                                repsController.text = text;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: repsController,
                      label: 'Repeticiones realizadas',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Puedes usar los chips rápidos o escribir manualmente. Se aceptan pesos con coma o punto, por ejemplo 17,5 o 17.5.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final weight = decimalValue(weightController.text);
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
                  label: Text('Guardar serie $nextSetNumber/$plannedSetCount'),
                ),
              ],
            );
          },
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
      weight: result['weight'] as double,
      reps: result['reps'] as int,
      setNumber: nextSetNumber,
      plannedSetCount: plannedSetCount,
    );

    await updateExerciseSetProgress(routineId, exercises, exerciseId);

    if (context.mounted) {
      final completedMessage = nextSetNumber >= plannedSetCount
          ? 'Ejercicio completado. Has registrado $plannedSetCount/$plannedSetCount series.'
          : 'Serie guardada. Llevas $nextSetNumber/$plannedSetCount series.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(completedMessage)),
      );
    }
  }

  Future<void> updateExerciseSetProgress(String routineId, List<dynamic> exercises, String exerciseId) async {
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) {
        final plannedSetCount = totalSets(map);
        final currentCompletedSets = completedSets(map);
        final nextCompletedSets = (currentCompletedSets + 1).clamp(0, plannedSetCount).toInt();
        map['completedSets'] = nextCompletedSets;
        map['done'] = nextCompletedSets >= plannedSetCount;
      }
      return map;
    }).toList();

    await routinesRef.doc(routineId).update({'exercises': updated});
  }

  Future<void> updateExerciseDone(String routineId, List<dynamic> exercises, String exerciseId, bool done) async {
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) {
        final plannedSetCount = totalSets(map);
        map['done'] = done;
        map['completedSets'] = done ? plannedSetCount : 0;
      }
      return map;
    }).toList();

    await routinesRef.doc(routineId).update({'exercises': updated});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis rutinas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Text(
                'Mostrando solo rutinas activas asignadas a: $userEmail',
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

                final routines = (snapshot.data?.docs ?? [])
                    .where((doc) => isActiveRoutine(doc.data()))
                    .toList();

                routines.sort((a, b) {
                  final aOrder = a.data()['dayOrder'] is int
                      ? a.data()['dayOrder'] as int
                      : routineDayOrder((a.data()['day'] ?? '').toString());
                  final bOrder = b.data()['dayOrder'] is int
                      ? b.data()['dayOrder'] as int
                      : routineDayOrder((b.data()['day'] ?? '').toString());
                  final orderCompare = aOrder.compareTo(bOrder);
                  if (orderCompare != 0) return orderCompare;
                  return (a.data()['title'] ?? '').toString().compareTo((b.data()['title'] ?? '').toString());
                });

                if (routines.isEmpty) {
                  return const AppCard(
                    child: Center(
                      child: Text(
                        'Todavía no tienes rutinas activas asignadas.',
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
          ],
        ),
      ),
    );
  }
}
