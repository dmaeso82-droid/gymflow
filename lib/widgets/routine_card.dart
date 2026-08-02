
import 'package:flutter/material.dart';

import 'app_card.dart';
import 'exercise_tile.dart';

int intValue(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  final text = value?.toString() ?? '';
  final match = RegExp(r'\d+').firstMatch(text);
  return int.tryParse(match?.group(0) ?? '') ?? fallback;
}

int exerciseTotalSets(Map<String, dynamic> exercise) {
  final parsed = intValue(exercise['sets'], fallback: 1);
  return parsed <= 0 ? 1 : parsed;
}

int exerciseCompletedSets(Map<String, dynamic> exercise) {
  final total = exerciseTotalSets(exercise);
  final rawCompleted = intValue(exercise['completedSets'], fallback: -1);

  if (rawCompleted >= 0) return rawCompleted.clamp(0, total).toInt();
  if (exercise['done'] == true) return total;
  return 0;
}

int routineProgressBySets(List<dynamic> exercises) {
  if (exercises.isEmpty) return 0;

  var totalSets = 0;
  var completedSets = 0;

  for (final item in exercises) {
    final exercise = Map<String, dynamic>.from(item as Map);
    final total = exerciseTotalSets(exercise);
    totalSets += total;
    completedSets += exerciseCompletedSets(exercise);
  }

  if (totalSets == 0) return 0;
  return ((completedSets / totalSets) * 100).round().clamp(0, 100).toInt();
}

class RoutineCard extends StatelessWidget {
  final String title;
  final String day;
  final String notes;
  final String clientName;
  final List<dynamic> exercises;
  final bool trainerMode;
  final bool archived;
  final VoidCallback? onAddExercise;
  final VoidCallback? onEditRoutine;
  final VoidCallback? onDeleteRoutine;
  final void Function(String exerciseId, bool done) onToggleExercise;
  final void Function(String exerciseId)? onEditExercise;
  final void Function(String exerciseId)? onDeleteExercise;
  final void Function(String exerciseId)? onLogWorkout;

  const RoutineCard({
    super.key,
    required this.title,
    required this.day,
    required this.notes,
    required this.clientName,
    required this.exercises,
    required this.trainerMode,
    this.archived = false,
    required this.onToggleExercise,
    this.onAddExercise,
    this.onEditRoutine,
    this.onDeleteRoutine,
    this.onEditExercise,
    this.onDeleteExercise,
    this.onLogWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final progress = routineProgressBySets(exercises);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              if (archived) ...[
                const SizedBox(width: 8),
                Chip(
                  label: const Text('ARCHIVADA'),
                  backgroundColor: Colors.orangeAccent.withOpacity(0.16),
                  labelStyle: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                  side: BorderSide.none,
                ),
              ],
              if (trainerMode) ...[
                IconButton(
                  tooltip: 'Editar rutina',
                  onPressed: onEditRoutine,
                  icon: const Icon(Icons.edit, color: Colors.greenAccent),
                ),
                IconButton(
                  tooltip: 'Eliminar rutina',
                  onPressed: onDeleteRoutine,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 16, color: Colors.white60),
              const SizedBox(width: 6),
              Expanded(child: Text('$day · $clientName', style: const TextStyle(color: Colors.white60))),
              Chip(
                label: Text('$progress%'),
                backgroundColor: Colors.greenAccent.withOpacity(0.15),
                side: BorderSide.none,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (notes.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(notes, style: const TextStyle(color: Colors.white70)),
            ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white12,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 16),
          if (exercises.isEmpty)
            const Text('Esta rutina todavía no tiene ejercicios.', style: TextStyle(color: Colors.white70))
          else
            ...exercises.map((item) {
              final exercise = Map<String, dynamic>.from(item as Map);
              return ExerciseTile(
                exercise: exercise,
                trainerMode: trainerMode,
                onToggle: () {
                  final exerciseId = exercise['id'] as String;
                  if (trainerMode) {
                    onToggleExercise(exerciseId, !(exercise['done'] == true));
                  } else if (onLogWorkout != null) {
                    onLogWorkout!(exerciseId);
                  } else {
                    onToggleExercise(exerciseId, !(exercise['done'] == true));
                  }
                },
                onEdit: onEditExercise == null ? null : () => onEditExercise!(exercise['id'] as String),
                onDelete: onDeleteExercise == null ? null : () => onDeleteExercise!(exercise['id'] as String),
              );
            }),
          if (trainerMode) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddExercise,
                icon: const Icon(Icons.add),
                label: const Text('Añadir ejercicio'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
