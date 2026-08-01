import 'package:flutter/material.dart';

import 'info_chip.dart';

class ExerciseTile extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final bool trainerMode;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  const ExerciseTile({
    super.key,
    required this.exercise,
    required this.trainerMode,
    required this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = exercise['done'] == true;
    final name = exercise['name'] as String? ?? 'Ejercicio';
    final sets = exercise['sets']?.toString() ?? '-';
    final reps = exercise['reps']?.toString() ?? '-';
    final weight = exercise['weight']?.toString() ?? '';
    final rest = exercise['rest']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
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
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              InfoChip(text: '$sets series'),
              InfoChip(text: '$reps reps'),
              if (weight.trim().isNotEmpty) InfoChip(text: weight),
              InfoChip(text: 'Descanso $rest'),
            ],
          ),
        ),
        trailing: trainerMode
            ? IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              )
            : const Icon(Icons.play_circle_outline, color: Colors.white54),
      ),
    );
  }
}
