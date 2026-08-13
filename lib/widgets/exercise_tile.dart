import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/workout_utils.dart';
import 'info_chip.dart';

class ExerciseTile extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final bool trainerMode;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExerciseTile({
    super.key,
    required this.exercise,
    required this.trainerMode,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  String compactDetails({
    required int completed,
    required int total,
    required String reps,
    required String weight,
    required String rest,
  }) {
    final parts = <String>[
      '$completed/$total series',
      '$reps reps',
    ];
    if (weight.trim().isNotEmpty) parts.add(weight.trim());
    if (rest.trim().isNotEmpty && rest.trim() != '-') {
      parts.add(rest.trim().startsWith('Descanso') ? rest.trim() : 'Descanso $rest');
    }
    return parts.join(' · ');
  }

  Widget buildCompactTile({
    required BuildContext context,
    required bool done,
    required String name,
    required String details,
    required double progressValue,
  }) {
    final titleStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      height: 1.15,
      decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
      color: done ? context.gymFitnessAccent : context.gymText,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.gymInsetSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: done ? context.gymStrongBorder : context.gymBorder),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done ? context.gymFitnessAccent : context.gymMutedText,
                      size: 24,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      SizedBox(height: 4),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.gymMutedText, fontSize: 12, height: 1.2),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6),
                if (trainerMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        tooltip: 'Editar ejercicio',
                        onPressed: onEdit,
                        icon: Icon(Icons.edit, color: context.gymPrimary, size: 21),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        tooltip: 'Eliminar ejercicio',
                        onPressed: onDelete,
                        icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 21),
                      ),
                    ],
                  )
                else
                  Icon(Icons.play_circle_outline, color: context.gymMutedText, size: 24),
              ],
            ),
            SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 3,
                backgroundColor: context.gymProgressTrack,
                color: done ? context.gymFitnessAccent : context.gymPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildExpandedTile({
    required BuildContext context,
    required bool done,
    required String name,
    required String reps,
    required String weight,
    required String rest,
    required int completed,
    required int total,
    required double progressValue,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.gymInsetSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? context.gymStrongBorder : context.gymBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: onToggle,
        leading: IconButton(
          onPressed: onToggle,
          icon: Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? context.gymFitnessAccent : context.gymMutedText,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
            color: done ? context.gymFitnessAccent : context.gymText,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  InfoChip(text: '$completed/$total series'),
                  InfoChip(text: '$reps reps'),
                  if (weight.trim().isNotEmpty) InfoChip(text: weight),
                  InfoChip(text: 'Descanso $rest'),
                ],
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  backgroundColor: context.gymProgressTrack,
                  color: done ? context.gymFitnessAccent : context.gymPrimary,
                ),
              ),
            ],
          ),
        ),
        trailing: trainerMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar ejercicio',
                    onPressed: onEdit,
                    icon: Icon(Icons.edit, color: context.gymPrimary),
                  ),
                  IconButton(
                    tooltip: 'Eliminar ejercicio',
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                ],
              )
            : Icon(Icons.play_circle_outline, color: context.gymMutedText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = workoutTotalSets(exercise);
    final completed = workoutCompletedSets(exercise);
    final done = completed >= total || exercise['done'] == true;
    final name = exercise['name'] as String? ?? 'Ejercicio';
    final reps = exercise['reps']?.toString() ?? '-';
    final weight = exercise['weight']?.toString() ?? '';
    final rest = exercise['rest']?.toString() ?? '-';
    final progressValue = total == 0 ? 0.0 : (completed / total).clamp(0, 1).toDouble();
    final isCompact = MediaQuery.of(context).size.width < 600;

    if (isCompact) {
      return buildCompactTile(
        context: context,
        done: done,
        name: name,
        details: compactDetails(completed: completed, total: total, reps: reps, weight: weight, rest: rest),
        progressValue: progressValue,
      );
    }

    return buildExpandedTile(
      context: context,
      done: done,
      name: name,
      reps: reps,
      weight: weight,
      rest: rest,
      completed: completed,
      total: total,
      progressValue: progressValue,
    );
  }
}



