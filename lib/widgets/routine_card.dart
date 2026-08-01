import 'package:flutter/material.dart';

import '../utils/routine_progress.dart';
import 'app_card.dart';
import 'exercise_tile.dart';

class RoutineCard extends StatelessWidget {
  final String title;
  final String day;
  final String notes;
  final String clientName;
  final List<dynamic> exercises;
  final bool trainerMode;
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
    final progress = routineProgress(exercises);

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
                    onToggleExercise(
                      exerciseId,
                      !(exercise['done'] == true),
                    );
                  } else if (onLogWorkout != null) {
                    onLogWorkout!(exerciseId);
                  } else {
                    onToggleExercise(
                      exerciseId,
                      !(exercise['done'] == true),
                    );
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
