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

  Widget _statusButton(BuildContext context, {required bool done, required double progressValue}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onToggle,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: done ? context.gymFitnessAccent.withValues(alpha: 0.16) : context.gymPrimary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(
          done ? Icons.check_circle_rounded : Icons.bolt_rounded,
          color: done ? context.gymFitnessAccent : context.gymPrimary,
          size: 23,
        ),
      ),
    );
  }

  Widget _actionButtons(BuildContext context) {
    if (!trainerMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: context.gymPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: context.gymPrimary, size: 17),
            const SizedBox(width: 4),
            Text(
              'Registrar',
              style: TextStyle(color: context.gymPrimary, fontSize: 11.5, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          tooltip: 'Editar ejercicio',
          onPressed: onEdit,
          icon: Icon(Icons.edit_rounded, color: context.gymPrimary, size: 21),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          tooltip: 'Eliminar ejercicio',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 21),
        ),
      ],
    );
  }

  Widget buildCompactTile({
    required BuildContext context,
    required bool done,
    required String name,
    required String details,
    required double progressValue,
    required int completed,
    required int total,
  }) {
    final titleStyle = TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w900,
      height: 1.15,
      decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
      color: done ? context.gymFitnessAccent : context.gymText,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onToggle,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
            decoration: BoxDecoration(
              color: done
                  ? context.gymFitnessAccent.withValues(alpha: context.gymIsDark ? 0.12 : 0.08)
                  : context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.68),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _statusButton(context, done: done, progressValue: progressValue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                          const SizedBox(height: 4),
                          Text(
                            details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.gymMutedText, fontSize: 12, height: 1.2, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _actionButtons(context),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 5,
                          backgroundColor: context.gymProgressTrack,
                          color: done ? context.gymFitnessAccent : context.gymPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$completed/$total',
                      style: TextStyle(color: done ? context.gymFitnessAccent : context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      decoration: BoxDecoration(
        color: done
            ? context.gymFitnessAccent.withValues(alpha: context.gymIsDark ? 0.12 : 0.08)
            : context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.68),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _statusButton(context, done: done, progressValue: progressValue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                        color: done ? context.gymFitnessAccent : context.gymText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        InfoChip(text: '$completed/$total series'),
                        InfoChip(text: '$reps reps'),
                        if (weight.trim().isNotEmpty) InfoChip(text: weight),
                        if (rest.trim().isNotEmpty && rest.trim() != '-') InfoChip(text: rest.trim().startsWith('Descanso') ? rest : 'Descanso $rest'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _actionButtons(context),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: context.gymProgressTrack,
              color: done ? context.gymFitnessAccent : context.gymPrimary,
            ),
          ),
        ],
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
        completed: completed,
        total: total,
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
