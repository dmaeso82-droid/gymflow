
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
    final isCompact = MediaQuery.of(context).size.width < 600;
    final titleSize = isCompact ? 18.0 : 22.0;
    final cardBottomMargin = isCompact ? 10.0 : 16.0;
    final notesPadding = isCompact ? 10.0 : 12.0;
    final progressHeight = isCompact ? 5.0 : 8.0;
    final exerciseTopSpacing = isCompact ? 10.0 : 16.0;

    return AppCard(
      margin: EdgeInsets.only(bottom: cardBottomMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: isCompact ? 2 : null,
                  overflow: isCompact ? TextOverflow.ellipsis : TextOverflow.visible,
                  style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, height: 1.15),
                ),
              ),
              if (archived) ...[
                SizedBox(width: isCompact ? 6 : 8),
                Chip(
                  visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
                  label: const Text('ARCHIVADA'),
                  backgroundColor: Colors.orangeAccent.withOpacity(0.16),
                  labelStyle: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 11 : 13,
                  ),
                  side: BorderSide.none,
                ),
              ],
              if (trainerMode) ...[
                IconButton(
                  visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
                  padding: isCompact ? EdgeInsets.zero : const EdgeInsets.all(8),
                  constraints: isCompact ? const BoxConstraints(minWidth: 34, minHeight: 34) : null,
                  tooltip: 'Editar rutina',
                  onPressed: onEditRoutine,
                  icon: Icon(Icons.edit, color: Colors.greenAccent, size: isCompact ? 21 : 24),
                ),
                IconButton(
                  visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
                  padding: isCompact ? EdgeInsets.zero : const EdgeInsets.all(8),
                  constraints: isCompact ? const BoxConstraints(minWidth: 34, minHeight: 34) : null,
                  tooltip: 'Eliminar rutina',
                  onPressed: onDeleteRoutine,
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: isCompact ? 21 : 24),
                ),
              ],
            ],
          ),
          SizedBox(height: isCompact ? 4 : 6),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 16, color: Colors.white60),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$day · $clientName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 12,
                  vertical: isCompact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$progress%',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: isCompact ? 12 : 14),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 10),
          if (notes.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(notesPadding),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
              ),
              child: Text(
                notes,
                maxLines: isCompact ? 2 : null,
                overflow: isCompact ? TextOverflow.ellipsis : TextOverflow.visible,
                style: TextStyle(color: Colors.white70, fontSize: isCompact ? 13 : 14, height: 1.35),
              ),
            ),
          SizedBox(height: isCompact ? 8 : 12),
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: progressHeight,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white12,
            color: Colors.greenAccent,
          ),
          SizedBox(height: exerciseTopSpacing),
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
            SizedBox(height: isCompact ? 8 : 12),
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
