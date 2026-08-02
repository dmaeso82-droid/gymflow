
import 'package:flutter/material.dart';

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

  int intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    final text = value?.toString() ?? '';
    final match = RegExp(r'\d+').firstMatch(text);
    return int.tryParse(match?.group(0) ?? '') ?? fallback;
  }

  int totalSets() {
    final parsed = intValue(exercise['sets'], fallback: 1);
    return parsed <= 0 ? 1 : parsed;
  }

  int completedSets() {
    final total = totalSets();
    final rawCompleted = intValue(exercise['completedSets'], fallback: -1);

    if (rawCompleted >= 0) return rawCompleted.clamp(0, total).toInt();
    if (exercise['done'] == true) return total;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final total = totalSets();
    final completed = completedSets();
    final done = completed >= total || exercise['done'] == true;
    final name = exercise['name'] as String? ?? 'Ejercicio';
    final reps = exercise['reps']?.toString() ?? '-';
    final weight = exercise['weight']?.toString() ?? '';
    final rest = exercise['rest']?.toString() ?? '-';
    final progressValue = total == 0 ? 0.0 : (completed / total).clamp(0, 1).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? Colors.greenAccent.withOpacity(0.28) : Colors.white10),
      ),
      child: ListTile(
        onTap: onToggle,
        leading: IconButton(
          onPressed: onToggle,
          icon: Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? Colors.greenAccent : Colors.white54,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
            color: done ? Colors.greenAccent : Colors.white,
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
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  color: done ? Colors.greenAccent : Colors.lightGreenAccent,
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
                    icon: const Icon(Icons.edit, color: Colors.greenAccent),
                  ),
                  IconButton(
                    tooltip: 'Eliminar ejercicio',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                ],
              )
            : const Icon(Icons.play_circle_outline, color: Colors.white54),
      ),
    );
  }
}
