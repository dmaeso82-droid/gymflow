import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
  final normalizedGymId = gymId?.trim() ?? '';
  final favoritesDoc = normalizedGymId.isNotEmpty
      ? FirebaseFirestore.instance.collection('gyms').doc(normalizedGymId).collection('settings').doc('exercise_favorites')
      : null;
  final customExercisesRef = normalizedGymId.isNotEmpty
      ? FirebaseFirestore.instance.collection('gyms').doc(normalizedGymId).collection('custom_exercises')
      : null;

  String normalizeExerciseName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String customExerciseDocId(String value) {
    final normalized = normalizeExerciseName(value)
        .replaceAll('/', '-')
        .replaceAll('\\', '-')
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñÁÉÍÓÚÜÑ _.-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return normalized.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : normalized;
  }

  List<String> favoriteNames = List<String>.from(favoriteExerciseNames);
  if (favoritesDoc != null) {
    final snapshot = await favoritesDoc.get();
    if (!context.mounted) return null;
    final names = snapshot.data()?['names'];
    if (names is List) {
      favoriteNames = names.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toSet().toList()..sort();
    }
  }

  List<String> customExerciseNames = <String>[];
  if (customExercisesRef != null) {
    final snapshot = await customExercisesRef.orderBy('nameLower').get();
    if (!context.mounted) return null;
    customExerciseNames = snapshot.docs
        .map((doc) => doc.data()['name']?.toString() ?? '')
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  final availableGroups = <String>[
    favoriteExerciseGroup,
    customExerciseGroup,
    ...exerciseLibrary.keys,
  ];

  String selectedGroup = favoriteExerciseGroup;
  String selectedExercise = favoriteNames.isNotEmpty
      ? favoriteNames.first
      : customExerciseNames.isNotEmpty
          ? customExerciseNames.first
          : allExerciseNames().first;
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
    if (!foundInitialExercise && customExerciseNames.contains(initialName.trim())) {
      selectedGroup = customExerciseGroup;
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
  if (!foundInitialExercise && initialName.trim().isNotEmpty) selectedExercise = customExerciseOption;

  Future<void> persistFavorites() async {
    if (favoritesDoc == null) return;
    await favoritesDoc.set({'names': favoriteNames, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> persistCustomExercise(String rawName) async {
    if (customExercisesRef == null) return;
    final name = rawName.trim();
    if (name.isEmpty) return;

    final normalized = normalizeExerciseName(name);
    final knownNames = <String>{
      ...allExerciseNames().map(normalizeExerciseName),
      ...favoriteNames.map(normalizeExerciseName),
      ...customExerciseNames.map(normalizeExerciseName),
    };
    if (knownNames.contains(normalized)) return;

    await customExercisesRef.doc(customExerciseDocId(name)).set({
      'name': name,
      'nameLower': normalized,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    customExerciseNames = [...customExerciseNames, name].toSet().toList()..sort();
  }

  try {
    return await showModalBottomSheet<ExerciseInput>(
      context: context,
      backgroundColor: context.gymSurface,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final baseOptions = selectedGroup == favoriteExerciseGroup
                ? favoriteNames
                : selectedGroup == customExerciseGroup
                    ? customExerciseNames
                    : exercisesForGroup(selectedGroup, favoriteNames: favoriteNames);
            final searchText = searchController.text.trim().toLowerCase();
            final filteredOptions = baseOptions.where((exercise) => exercise.toLowerCase().contains(searchText)).toList();
            final exerciseOptions = [...filteredOptions, customExerciseOption];
            if (!exerciseOptions.contains(selectedExercise)) selectedExercise = exerciseOptions.isEmpty ? customExerciseOption : exerciseOptions.first;
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle(icon: Icons.fitness_center, title: isEditing ? 'Editar ejercicio' : 'Añadir ejercicio'),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGroup,
                      dropdownColor: context.gymSurface,
                      decoration: InputDecoration(labelText: 'Grupo muscular', border: OutlineInputBorder()),
                      items: availableGroups.map((group) => DropdownMenuItem(value: group, child: Text(group))).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedGroup = value;
                          final options = selectedGroup == favoriteExerciseGroup
                              ? favoriteNames
                              : selectedGroup == customExerciseGroup
                                  ? customExerciseNames
                                  : exercisesForGroup(selectedGroup, favoriteNames: favoriteNames);
                          selectedExercise = options.isEmpty ? customExerciseOption : options.first;
                          nameController.clear();
                          searchController.clear();
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar ejercicio',
                        filled: true,
                        fillColor: context.gymSubtleSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.gymBorder)),
                      child: exerciseOptions.isEmpty
                          ? Padding(padding: EdgeInsets.all(16), child: Text('No hay ejercicios para mostrar.', style: TextStyle(color: context.gymMutedText)))
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
                                  selectedTileColor: context.gymPrimary.withValues(alpha: 0.08),
                                  title: Text(exercise),
                                  leading: isCustom
                                      ? Icon(Icons.edit, color: context.gymMutedText.withValues(alpha: 0.85))
                                      : IconButton(
                                          tooltip: isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
                                          icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? Colors.amberAccent : context.gymMutedText.withValues(alpha: 0.85)),
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
                                  trailing: isSelected ? Icon(Icons.check, color: context.gymPrimary) : null,
                                  onTap: () {
                                    setSheetState(() {
                                      selectedExercise = exercise;
                                      if (selectedExercise != customExerciseOption) nameController.clear();
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    if (selectedGroup == favoriteExerciseGroup && favoriteNames.isEmpty) ...[
                      SizedBox(height: 8),
                      Text('Marca ejercicios con la estrella para que aparezcan aquí.', style: TextStyle(color: context.gymMutedText, fontSize: 12)),
                    ],
                    if (selectedGroup == customExerciseGroup && customExerciseNames.isEmpty) ...[
                      SizedBox(height: 8),
                      Text('Los ejercicios personalizados que crees se guardarán aquí para reutilizarlos.', style: TextStyle(color: context.gymMutedText, fontSize: 12)),
                    ],
                    if (selectedExercise == customExerciseOption) ...[
                      SizedBox(height: 12),
                      AppTextField(controller: nameController, label: 'Nombre del ejercicio personalizado'),
                    ],
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: AppTextField(controller: setsController, label: 'Series', keyboardType: TextInputType.number)),
                        SizedBox(width: 12),
                        Expanded(child: AppTextField(controller: repsController, label: 'Reps')),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: AppTextField(controller: weightController, label: 'Peso', hint: 'Ej: 40 kg')),
                        SizedBox(width: 12),
                        Expanded(child: AppTextField(controller: restController, label: 'Descanso')),
                      ],
                    ),
                    SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () async {
                        final name = selectedExercise == customExerciseOption ? nameController.text.trim() : selectedExercise.trim();
                        if (name.isEmpty) return;
                        if (selectedExercise == customExerciseOption) {
                          await persistCustomExercise(name);
                        }
                        if (!context.mounted) return;
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
  } finally {
    searchController.dispose();
    nameController.dispose();
    setsController.dispose();
    repsController.dispose();
    weightController.dispose();
    restController.dispose();
  }
}



