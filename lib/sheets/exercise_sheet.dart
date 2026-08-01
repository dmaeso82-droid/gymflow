import 'package:flutter/material.dart';

import '../models/exercise_input.dart';
import '../widgets/app_text_field.dart';
import '../widgets/section_title.dart';

Future<ExerciseInput?> showExerciseSheet(BuildContext context) async {
  final nameController = TextEditingController();
  final setsController = TextEditingController(text: '3');
  final repsController = TextEditingController(text: '10');
  final weightController = TextEditingController();
  final restController = TextEditingController(text: '60 s');

  return showModalBottomSheet<ExerciseInput>(
    context: context,
    backgroundColor: const Color(0xFF0F172A),
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(icon: Icons.fitness_center, title: 'Añadir ejercicio'),
            const SizedBox(height: 16),
            AppTextField(controller: nameController, label: 'Nombre del ejercicio'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: setsController,
                    label: 'Series',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(controller: repsController, label: 'Reps')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: weightController,
                    label: 'Peso',
                    hint: 'Ej: 40 kg',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(controller: restController, label: 'Descanso')),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                Navigator.pop(
                  context,
                  ExerciseInput(
                    name: name,
                    sets: int.tryParse(setsController.text.trim()) ?? 1,
                    reps: repsController.text.trim(),
                    weight: weightController.text.trim(),
                    rest: restController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Añadir ejercicio'),
            ),
          ],
        ),
      );
    },
  );
}
