import 'package:flutter/material.dart';

import '../services/challenge_service.dart';

class ChallengeCreationResult {
  final String title;
  final String description;
  final String type;
  final double target;

  const ChallengeCreationResult({
    required this.title,
    required this.description,
    required this.type,
    required this.target,
  });
}

Future<ChallengeCreationResult?> showChallengeCreationDialog({
  required BuildContext context,
  required ChallengeService service,
}) async {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final targetController = TextEditingController(text: '12');
  String selectedType = 'workout_count';

  try {
    return await showDialog<ChallengeCreationResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final targetLabel = selectedType == 'volume_total'
                ? 'Objetivo en kg'
                : 'Objetivo de ${service.challengeUnit(selectedType)}';
            final targetHint = selectedType == 'volume_total' ? '50000' : '12';

            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: Text('Crear reto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Título',
                        hintText: 'Reto Agosto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Tipo de reto',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'workout_count', child: Text('Entrenamientos completados')),
                        DropdownMenuItem(value: 'volume_total', child: Text('Volumen movido')),
                        DropdownMenuItem(value: 'series_count', child: Text('Series completadas')),
                        DropdownMenuItem(value: 'streak_days', child: Text('Racha de días')),
                        DropdownMenuItem(value: 'goals_completed', child: Text('Objetivos completados')),
                        DropdownMenuItem(value: 'measurements_count', child: Text('Mediciones registradas')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                          targetController.text = value == 'volume_total' ? '50000' : '12';
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Explica en qué consiste el reto.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: targetLabel,
                        hintText: targetHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      selectedType == 'volume_total'
                          ? 'El volumen se calcula como peso × repeticiones de cada serie registrada.'
                          : 'El progreso se calcula automáticamente con los datos que ya registra GymFlow.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();
                    final target = double.tryParse(targetController.text.trim().replaceAll(',', '.')) ?? 0;
                    if (title.isEmpty || target <= 0) return;
                    Navigator.pop(
                      dialogContext,
                      ChallengeCreationResult(
                        title: title,
                        description: description,
                        target: target,
                        type: selectedType,
                      ),
                    );
                  },
                  icon: Icon(Icons.emoji_events),
                  label: Text('Crear reto'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    titleController.dispose();
    descriptionController.dispose();
    targetController.dispose();
  }
}



