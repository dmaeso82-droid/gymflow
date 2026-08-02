
import 'package:flutter/material.dart';

import '../data/exercise_library.dart';
import '../models/exercise_input.dart';
import '../widgets/app_text_field.dart';
import '../widgets/section_title.dart';

Future<ExerciseInput?> showExerciseSheet(
  BuildContext context, {
  Map<String, dynamic>? initialExercise,
}) async {
  final isEditing = initialExercise != null;
  final initialName = initialExercise?['name']?.toString() ?? '';

  String selectedGroup = favoriteExerciseGroup;
  String selectedExercise = favoriteExerciseNames.first;
  bool foundInitialExercise = false;

  if (initialName.trim().isNotEmpty) {
    for (final entry in exerciseLibrary.entries) {
      if (entry.value.contains(initialName.trim())) {
        selectedGroup = entry.key;
        selectedExercise = initialName.trim();
        foundInitialExercise = true;
        break;
      }
    }

    if (!foundInitialExercise && favoriteExerciseNames.contains(initialName.trim())) {
      selectedGroup = favoriteExerciseGroup;
      selectedExercise = initialName.trim();
      foundInitialExercise = true;
    }
  }

  final searchController = TextEditingController();
  final nameController = TextEditingController(text: foundInitialExercise ? '' : initialName);
  final setsController = TextEditingController(text: initialExercise?['sets']?.toString() ?? '3');
  final repsController = TextEditingController(text: initialExercise?['reps']?.toString() ?? '10');
  final weightController = TextEditingController(text: initialExercise?['weight']?.toString() ?? '');
  final restController = TextEditingController(text: initialExercise?['rest']?.toString() ?? '60 s');

  if (!foundInitialExercise && initialName.trim().isNotEmpty) {
    selectedExercise = customExerciseOption;
  }

  final result = await showModalBottomSheet<ExerciseInput>(
    context: context,
    backgroundColor: const Color(0xFF0F172A),
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final baseOptions = exercisesForGroup(selectedGroup);
          final searchText = searchController.text.trim().toLowerCase();
          final filteredOptions = baseOptions
              .where((exercise) => exercise.toLowerCase().contains(searchText))
              .toList();

          final exerciseOptions = [
            ...filteredOptions,
            customExerciseOption,
          ];

          if (!exerciseOptions.contains(selectedExercise)) {
            selectedExercise = exerciseOptions.first;
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    icon: Icons.fitness_center,
                    title: isEditing ? 'Editar ejercicio' : 'Añadir ejercicio',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedGroup,
                    dropdownColor: const Color(0xFF0F172A),
                    decoration: const InputDecoration(
                      labelText: 'Grupo muscular',
                      border: OutlineInputBorder(),
                    ),
                    items: exerciseGroupsWithFavorites().map((group) {
                      return DropdownMenuItem(value: group, child: Text(group));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        selectedGroup = value;
                        final options = exercisesForGroup(selectedGroup);
                        selectedExercise = options.isEmpty ? customExerciseOption : options.first;
                        nameController.clear();
                        searchController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Buscar ejercicio',
                      filled: true,
                      fillColor: const Color(0xFF020617),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedExercise,
                    dropdownColor: const Color(0xFF0F172A),
                    decoration: const InputDecoration(
                      labelText: 'Ejercicio',
                      border: OutlineInputBorder(),
                    ),
                    items: exerciseOptions.map((exercise) {
                      return DropdownMenuItem(value: exercise, child: Text(exercise));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        selectedExercise = value;
                        if (selectedExercise != customExerciseOption) {
                          nameController.clear();
                        }
                      });
                    },
                  ),
                  if (selectedExercise == customExerciseOption) ...[
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: nameController,
                      label: 'Nombre del ejercicio personalizado',
                    ),
                  ],
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
                      final name = selectedExercise == customExerciseOption
                          ? nameController.text.trim()
                          : selectedExercise.trim();

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
                    icon: Icon(isEditing ? Icons.save : Icons.add),
                    label: Text(isEditing ? 'Guardar cambios' : 'Añadir ejercicio'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  searchController.dispose();
  nameController.dispose();
  setsController.dispose();
  repsController.dispose();
  weightController.dispose();
  restController.dispose();

  return result;
}
