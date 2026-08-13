import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../data/routine_templates.dart';
import '../services/template_builder_service.dart';
import '../sheets/exercise_sheet.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/section_title.dart';

class TrainerTemplateBuilderPage extends StatefulWidget {
  final String gymId;

  const TrainerTemplateBuilderPage({super.key, required this.gymId});

  @override
  State<TrainerTemplateBuilderPage> createState() => _TrainerTemplateBuilderPageState();
}

class _TrainerTemplateBuilderPageState extends State<TrainerTemplateBuilderPage> {
  String? selectedTemplateId;

  TemplateBuilderService get service => TemplateBuilderService(gymId: widget.gymId);

  void showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> createTemplate() async {
    final nameController = TextEditingController();
    var objective = routineObjectives.first;
    var frequency = routineFrequencies.first;
    var level = routineLevels.first;

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: context.gymSurface,
                title: Text('Crear plantilla automática'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppTextField(controller: nameController, label: 'Nombre de la plantilla', hint: 'Ej: Hipertrofia 5D propia'),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: objective,
                        dropdownColor: context.gymSurface,
                        decoration: InputDecoration(labelText: 'Objetivo', border: OutlineInputBorder()),
                        items: routineObjectives.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => objective = value);
                        },
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: frequency,
                        dropdownColor: context.gymSurface,
                        decoration: InputDecoration(labelText: 'Días por semana', border: OutlineInputBorder()),
                        items: routineFrequencies.map((item) => DropdownMenuItem(value: item, child: Text('$item días'))).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => frequency = value);
                        },
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: level,
                        dropdownColor: context.gymSurface,
                        decoration: InputDecoration(labelText: 'Nivel', border: OutlineInputBorder()),
                        items: routineLevels.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => level = value);
                        },
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Se creará una plantilla base que luego podrás ajustar día por día.',
                        style: TextStyle(color: context.gymMutedText),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
                  FilledButton.icon(
                    onPressed: () {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Introduce un nombre para la plantilla.')));
                        return;
                      }
                      Navigator.pop(dialogContext, {'name': name, 'objective': objective, 'frequency': frequency, 'level': level});
                    },
                    icon: Icon(Icons.save),
                    label: Text('Crear'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == null) return;
      final docId = await service.createTemplate(
        name: result['name'].toString(),
        objective: result['objective'].toString(),
        frequency: result['frequency'] as int,
        level: result['level'].toString(),
      );
      if (!mounted) return;
      setState(() => selectedTemplateId = docId);
      showSnack('Plantilla creada.');
    } on StateError catch (error) {
      showSnack(error.message);
    } finally {
      nameController.dispose();
    }
  }

  Future<void> renameTemplate(String templateId, Map<String, dynamic> data) async {
    final nameController = TextEditingController(text: data['name']?.toString() ?? '');
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: context.gymSurface,
            title: Text('Editar nombre de plantilla'),
            content: AppTextField(controller: nameController, label: 'Nombre'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
              FilledButton.icon(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(dialogContext, name);
                },
                icon: Icon(Icons.save),
                label: Text('Guardar'),
              ),
            ],
          );
        },
      );
      if (result == null) return;
      await service.renameTemplate(templateId, data, result);
      showSnack('Plantilla actualizada.');
    } finally {
      nameController.dispose();
    }
  }

  Future<void> deleteTemplate(String templateId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Text('Eliminar plantilla'),
          content: Text('¿Seguro que quieres eliminar "$name"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(Icons.delete_outline),
              label: Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    await service.deleteTemplate(templateId, name);
    if (!mounted) return;
    if (selectedTemplateId == templateId) setState(() => selectedTemplateId = null);
    showSnack('Plantilla eliminada.');
  }

  Future<void> duplicateTemplate(Map<String, dynamic> data) async {
    final docId = await service.duplicateTemplate(data);
    if (!mounted) return;
    setState(() => selectedTemplateId = docId);
    showSnack('Plantilla duplicada.');
  }

  Future<void> editDayInfo(String templateId, Map<String, dynamic> data, int dayIndex) async {
    final days = service.cloneDays(data);
    final day = days[dayIndex];
    final titleController = TextEditingController(text: day['title']?.toString() ?? '');
    final notesController = TextEditingController(text: day['notes']?.toString() ?? '');

    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: context.gymSurface,
            title: Text('Editar ${day['day'] ?? 'día'}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: titleController, label: 'Título del día'),
                SizedBox(height: 12),
                AppTextField(controller: notesController, label: 'Notas del día'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext, {'title': titleController.text.trim(), 'notes': notesController.text.trim()});
                },
                icon: Icon(Icons.save),
                label: Text('Guardar'),
              ),
            ],
          );
        },
      );
      if (result == null) return;
      await service.editDayInfo(
        templateId: templateId,
        data: data,
        dayIndex: dayIndex,
        title: result['title'] ?? '',
        notes: result['notes'] ?? '',
      );
      showSnack('Día actualizado.');
    } finally {
      titleController.dispose();
      notesController.dispose();
    }
  }

  Future<void> addExerciseToDay(String templateId, Map<String, dynamic> data, int dayIndex) async {
    final result = await showExerciseSheet(context, gymId: widget.gymId);
    if (result == null) return;
    await service.addExerciseToDay(templateId: templateId, data: data, dayIndex: dayIndex, input: result);
    showSnack('Ejercicio añadido.');
  }

  Future<void> editExerciseInDay(String templateId, Map<String, dynamic> data, int dayIndex, String exerciseId) async {
    final days = service.cloneDays(data);
    final exercises = service.cloneExercises(days[dayIndex]);
    final current = exercises.firstWhere((exercise) => exercise['id'] == exerciseId, orElse: () => {});
    if (current.isEmpty) return;

    final result = await showExerciseSheet(context, gymId: widget.gymId, initialExercise: current);
    if (result == null) return;
    await service.editExerciseInDay(templateId: templateId, data: data, dayIndex: dayIndex, exerciseId: exerciseId, input: result);
    showSnack('Ejercicio actualizado.');
  }

  Future<void> deleteExerciseFromDay(String templateId, Map<String, dynamic> data, int dayIndex, String exerciseId) async {
    await service.deleteExerciseFromDay(templateId: templateId, data: data, dayIndex: dayIndex, exerciseId: exerciseId);
    showSnack('Ejercicio eliminado.');
  }

  Future<void> moveExerciseInDay(String templateId, Map<String, dynamic> data, int dayIndex, int exerciseIndex, int direction) async {
    await service.moveExerciseInDay(
      templateId: templateId,
      data: data,
      dayIndex: dayIndex,
      exerciseIndex: exerciseIndex,
      direction: direction,
    );
  }

  Widget buildSelectedTemplateEditor(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = data['name']?.toString() ?? 'Plantilla sin nombre';
    final objective = data['objective']?.toString() ?? '-';
    final level = data['level']?.toString() ?? '-';
    final frequency = data['frequency']?.toString() ?? '-';
    final days = service.cloneDays(data)
      ..sort((a, b) {
        final aOrder = a['dayOrder'] is int ? a['dayOrder'] as int : service.localDayOrder((a['day'] ?? '').toString());
        final bOrder = b['dayOrder'] is int ? b['dayOrder'] as int : service.localDayOrder((b['day'] ?? '').toString());
        return aOrder.compareTo(bOrder);
      });

    return AppCard(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('$objective · $frequency días · $level', style: TextStyle(color: context.gymMutedText)),
                    if ((data['createdBy'] ?? '').toString().isNotEmpty) ...[
                      SizedBox(height: 6),
                      Text('Creada por ${data['createdBy']}', style: TextStyle(color: context.gymMutedText, fontSize: 12)),
                    ],
                    if ((data['updatedBy'] ?? '').toString().isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text('Actualizada por ${data['updatedBy']}', style: TextStyle(color: context.gymMutedText, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              IconButton(tooltip: 'Editar nombre', onPressed: () => renameTemplate(doc.id, data), icon: Icon(Icons.edit, color: context.gymPrimary)),
              IconButton(tooltip: 'Duplicar plantilla', onPressed: () => duplicateTemplate(data), icon: Icon(Icons.copy, color: context.gymPrimary)),
              IconButton(tooltip: 'Eliminar plantilla', onPressed: () => deleteTemplate(doc.id, name), icon: Icon(Icons.delete_outline, color: Colors.redAccent)),
            ],
          ),
          SizedBox(height: 12),
          ...days.asMap().entries.map((entry) {
            final dayIndex = entry.key;
            final day = entry.value;
            final exercises = service.cloneExercises(day);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.gymSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.gymBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('${day['day'] ?? 'Sin día'} · ${day['title'] ?? 'Rutina'}', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      IconButton(tooltip: 'Editar día', onPressed: () => editDayInfo(doc.id, data, dayIndex), icon: Icon(Icons.notes, color: context.gymPrimary)),
                      Text('${exercises.length} ejercicios', style: TextStyle(color: context.gymMutedText)),
                    ],
                  ),
                  SizedBox(height: 8),
                  if ((day['notes'] ?? '').toString().trim().isNotEmpty) ...[
                    Text(day['notes'].toString(), style: TextStyle(color: context.gymMutedText)),
                    SizedBox(height: 8),
                  ],
                  if (exercises.isEmpty)
                    Text('Sin ejercicios configurados.', style: TextStyle(color: context.gymMutedText))
                  else
                    ...exercises.asMap().entries.map((exerciseEntry) {
                      final exerciseIndex = exerciseEntry.key;
                      final exercise = exerciseEntry.value;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(exercise['name']?.toString() ?? 'Ejercicio'),
                        subtitle: Text(
                          '${exercise['sets'] ?? '-'} series · ${exercise['reps'] ?? '-'} reps · Descanso ${exercise['rest'] ?? '-'}',
                          style: TextStyle(color: context.gymMutedText),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Subir ejercicio',
                              onPressed: exerciseIndex == 0 ? null : () => moveExerciseInDay(doc.id, data, dayIndex, exerciseIndex, -1),
                              icon: Icon(Icons.arrow_upward, color: context.gymMutedText),
                            ),
                            IconButton(
                              tooltip: 'Bajar ejercicio',
                              onPressed: exerciseIndex >= exercises.length - 1 ? null : () => moveExerciseInDay(doc.id, data, dayIndex, exerciseIndex, 1),
                              icon: Icon(Icons.arrow_downward, color: context.gymMutedText),
                            ),
                            IconButton(
                              tooltip: 'Editar ejercicio',
                              onPressed: () => editExerciseInDay(doc.id, data, dayIndex, exercise['id'].toString()),
                              icon: Icon(Icons.edit, color: context.gymPrimary),
                            ),
                            IconButton(
                              tooltip: 'Eliminar ejercicio',
                              onPressed: () => deleteExerciseFromDay(doc.id, data, dayIndex, exercise['id'].toString()),
                              icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                            ),
                          ],
                        ),
                      );
                    }),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => addExerciseToDay(doc.id, data, dayIndex),
                      icon: Icon(Icons.add),
                      label: Text('Añadir ejercicio a este día'),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Plantillas automáticas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createTemplate,
        icon: Icon(Icons.add),
        label: Text('Nueva plantilla'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.templatesRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            final templates = snapshot.data?.docs ?? [];
            if (templates.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle(icon: Icons.tune, title: 'Plantillas personalizadas'),
                        SizedBox(height: 12),
                        Text(
                          'Todavía no hay plantillas propias. Crea una plantilla para que el entrenador pueda generar rutinas automáticas personalizadas.',
                          style: TextStyle(color: context.gymMutedText),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final selectedExists = templates.any((doc) => doc.id == selectedTemplateId);
            final currentTemplateId = selectedExists ? selectedTemplateId! : templates.first.id;
            final selectedTemplate = templates.firstWhere((doc) => doc.id == currentTemplateId);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(icon: Icons.tune, title: 'Plantillas personalizadas'),
                      SizedBox(height: 12),
                      Text(
                        'Selecciona una plantilla existente para editarla. También puedes crear una nueva, duplicarla o eliminarla.',
                        style: TextStyle(color: context.gymMutedText),
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: currentTemplateId,
                        dropdownColor: context.gymSurface,
                        decoration: InputDecoration(labelText: 'Plantilla seleccionada', border: OutlineInputBorder()),
                        items: templates.map((doc) {
                          final data = doc.data();
                          final name = data['name']?.toString() ?? 'Plantilla sin nombre';
                          final objective = data['objective']?.toString() ?? '-';
                          final frequency = data['frequency']?.toString() ?? '-';
                          final level = data['level']?.toString() ?? '-';
                          return DropdownMenuItem(value: doc.id, child: Text('$name · $objective · ${frequency}D · $level'));
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => selectedTemplateId = value);
                        },
                      ),
                    ],
                  ),
                ),
                buildSelectedTemplateEditor(selectedTemplate),
              ],
            );
          },
        ),
      ),
    );
  }
}



