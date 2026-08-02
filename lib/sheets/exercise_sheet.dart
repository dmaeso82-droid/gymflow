
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/exercise_library.dart';
import '../models/exercise_input.dart';
import '../widgets/app_text_field.dart';
import '../widgets/section_title.dart';

Future<ExerciseInput?> showExerciseSheet(
  BuildContext context, {
  Map<String, dynamic>? initialExercise,
  String? gymId,
}) async {
  final isEditing = initialExercise != null;
  final initialName = initialExercise?['name']?.toString() ?? '';
  final canUseDynamicFavorites = gymId != null && gymId.trim().isNotEmpty;
  final favoritesDoc = canUseDynamicFavorites
      ? FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('settings')
          .doc('exercise_favorites')
      : null;

  List<String> favoriteNames = List<String>.from(favoriteExerciseNames);
  if (favoritesDoc != null) {
    final snapshot = await favoritesDoc.get();
    final names = snapshot.data()?['names'];
    if (names is List) {
      favoriteNames = names.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toSet().toList()..sort();
    }
  }

  String selectedGroup = favoriteExerciseGroup;
  String selectedExercise = favoriteNames.isNotEmpty ? favoriteNames.first : allExerciseNames().first;
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
    if (!foundInitialExercise && favoriteNames.contains(initialName.trim())) {
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

  Future<void> persistFavorites() async {
    if (favoritesDoc == null) return;
    await favoritesDoc.set({
      'names': favoriteNames,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  final result = await showModalBottomSheet<ExerciseInput>(
    context: context,
    backgroundColor: const Color(0xFF0F172A),
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final baseOptions = selectedGroup == favoriteExerciseGroup
              ? favoriteNames
              : exercisesForGroup(selectedGroup, favoriteNames: favoriteNames);
          final searchText = searchController.text.trim().toLowerCase();
          final filteredOptions = baseOptions
              .where((exercise) => exercise.toLowerCase().contains(searchText))
              .toList();
          final exerciseOptions = [
            ...filteredOptions,
            customExerciseOption,
          ];

          if (!exerciseOptions.contains(selectedExercise)) {
            selectedExercise = exerciseOptions.isEmpty ? customExerciseOption : exerciseOptions.first;
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
                        final options = selectedGroup == favoriteExerciseGroup
                            ? favoriteNames
                            : exercisesForGroup(selectedGroup, favoriteNames: favoriteNames);
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
                  Container(
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: exerciseOptions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No hay ejercicios para mostrar.', style: TextStyle(color: Colors.white70)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: exerciseOptions.length,
                            itemBuilder: (context, index) {
                              final exercise = exerciseOptions[index];
                              final isCustom = exercise == customExerciseOption;
                              final isSelected = selectedExercise == exercise;
                              final isFavorite = favoriteNames.contains(exercise);

                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: Colors.greenAccent.withOpacity(0.08),
                                title: Text(exercise),
                                leading: isCustom
                                    ? const Icon(Icons.edit, color: Colors.white54)
                                    : IconButton(
                                        tooltip: isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
                                        icon: Icon(
                                          isFavorite ? Icons.star : Icons.star_border,
                                          color: isFavorite ? Colors.amberAccent : Colors.white54,
                                        ),
                                        onPressed: () async {
                                          setSheetState(() {
                                            if (isFavorite) {
                                              favoriteNames.remove(exercise);
                                            } else {
                                              favoriteNames.add(exercise);
                                              favoriteNames = favoriteNames.toSet().toList()..sort();
                                            }
                                          });
                                          await persistFavorites();
                                        },
                                      ),
                                trailing: isSelected ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                                onTap: () {
                                  setSheetState(() {
                                    selectedExercise = exercise;
                                    if (selectedExercise != customExerciseOption) {
                                      nameController.clear();
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  if (selectedGroup == favoriteExerciseGroup && favoriteNames.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Marca ejercicios con la estrella para que aparezcan aquí.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
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
