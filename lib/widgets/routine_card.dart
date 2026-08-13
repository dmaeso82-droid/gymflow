
import 'package:flutter/material.dart';
import '../utils/workout_utils.dart';
import '../theme/app_theme.dart';

import 'app_card.dart';
import 'exercise_tile.dart';

class RoutineCard extends StatelessWidget {
  final String title;
  final String day;
  final String notes;
  final String clientName;
  final List<dynamic> exercises;
  final bool trainerMode;
  final bool archived;
  final int commentsCount;
  final VoidCallback? onOpenComments;
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
    this.commentsCount = 0,
    this.onOpenComments,
    required this.onToggleExercise,
    this.onAddExercise,
    this.onEditRoutine,
    this.onDeleteRoutine,
    this.onEditExercise,
    this.onDeleteExercise,
    this.onLogWorkout,
  });

  String displayTitle() {
    final raw = title.trim();
    if (raw.contains('·')) {
      final last = raw.split('·').last.trim();
      if (last.isNotEmpty) return last;
    }
    final cleanup = raw
        .replaceAll(RegExp(r'Hipertrofia\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Fuerza\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Definición\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Pérdida\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Principiante|Intermedio|Avanzado', caseSensitive: false), '')
        .replaceAll('·', '')
        .trim();
    return cleanup.isEmpty ? raw : cleanup;
  }

  @override
  Widget build(BuildContext context) {
    final progress = routineSetSummary(exercises).progressPercent;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final titleSize = isCompact ? 18.0 : 22.0;
    final cardBottomMargin = isCompact ? 10.0 : 16.0;
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
                  displayTitle(),
                  maxLines: isCompact ? 2 : null,
                  overflow: isCompact ? TextOverflow.ellipsis : TextOverflow.visible,
                  style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, height: 1.15),
                ),
              ),
              if (archived) ...[
                SizedBox(width: isCompact ? 6 : 8),
                Chip(
                  visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
                  label: Text('ARCHIVADA'),
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
                  icon: Icon(Icons.edit, color: context.gymPrimary, size: isCompact ? 21 : 24),
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
              Icon(Icons.calendar_month, size: 16, color: context.gymMutedText),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  day,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.gymMutedText),
                ),
              ),
              if (onOpenComments != null) ...[
                SizedBox(width: 6),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 10,
                      vertical: isCompact ? 4 : 6,
                    ),
                  ),
                  onPressed: onOpenComments,
                  icon: Icon(Icons.chat_bubble_outline, size: 17),
                  label: Text('$commentsCount'),
                ),
              ],
              SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 12,
                  vertical: isCompact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: context.gymFitnessAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$progress%',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: isCompact ? 12 : 14),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 12),
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: progressHeight,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: context.gymProgressTrack,
            color: context.gymFitnessAccent,
          ),
          SizedBox(height: exerciseTopSpacing),
          if (exercises.isEmpty)
            Text('Esta rutina todavía no tiene ejercicios.', style: TextStyle(color: context.gymMutedText))
          else
            ...exercises.map((item) {
              final exercise = Map<String, dynamic>.from(item as Map);
              return ExerciseTile(
                exercise: exercise,
                trainerMode: trainerMode,
                onToggle: () {
                  final exerciseId = exercise['id']?.toString() ?? '';
                  if (trainerMode) {
                    onToggleExercise(exerciseId, !(exercise['done'] == true));
                  } else if (onLogWorkout != null) {
                    onLogWorkout!(exerciseId);
                  } else {
                    onToggleExercise(exerciseId, !(exercise['done'] == true));
                  }
                },
                onEdit: onEditExercise == null ? null : () => onEditExercise!(exercise['id']?.toString() ?? ''),
                onDelete: onDeleteExercise == null ? null : () => onDeleteExercise!(exercise['id']?.toString() ?? ''),
              );
            }),
          if (trainerMode) ...[
            SizedBox(height: isCompact ? 8 : 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddExercise,
                icon: Icon(Icons.add),
                label: Text('Añadir ejercicio'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}



