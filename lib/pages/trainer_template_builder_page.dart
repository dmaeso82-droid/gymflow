
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/routine_templates.dart';
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

  CollectionReference<Map<String, dynamic>> get templatesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('routine_templates');


  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('activity');

  void showSnack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }


  Future<Map<String, String>> currentActor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'uid': '', 'name': 'Sistema', 'email': ''};
    }

    var name = user.displayName ?? '';
    final email = (user.email ?? '').toLowerCase();

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      final storedName = data?['name']?.toString() ?? '';
      if (storedName.trim().isNotEmpty) name = storedName.trim();
    } catch (_) {
      // Si no se puede leer el perfil, usamos el email para no bloquear la operación.
    }

    if (name.trim().isEmpty) name = email.isEmpty ? 'Entrenador' : email;
    return {'uid': user.uid, 'name': name, 'email': email};
  }

  Map<String, dynamic> auditCreateFields(Map<String, String> actor) {
    return {
      'createdBy': actor['name'] ?? '',
      'createdByUid': actor['uid'] ?? '',
      'updatedBy': actor['name'] ?? '',
      'updatedByUid': actor['uid'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> auditUpdateFields(Map<String, String> actor) {
    return {
      'updatedBy': actor['name'] ?? '',
      'updatedByUid': actor['uid'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> activityFields({
    required String type,
    required String target,
    required Map<String, String> actor,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'type': type,
      'target': target,
      'targetId': targetId ?? '',
      'user': actor['name'] ?? '',
      'userUid': actor['uid'] ?? '',
      'userEmail': actor['email'] ?? '',
      'metadata': metadata ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  int localDayOrder(String day) => dayOrder(day);

  Map<String, dynamic> normalizeTemplate(Map<String, dynamic> template) {
    final days = List<Map<String, dynamic>>.from(
      (template['days'] as List).map((day) {
        final map = Map<String, dynamic>.from(day as Map);
        final exercises = List<Map<String, dynamic>>.from(
          (map['exercises'] as List).map((exercise) {
            final item = Map<String, dynamic>.from(exercise as Map);
            return {
              'id': DateTime.now().microsecondsSinceEpoch.toString() + (item['name'] ?? '').toString(),
              'name': item['name'] ?? 'Ejercicio',
              'sets': item['sets'] ?? 3,
              'reps': item['reps'] ?? '10',
              'weight': item['weight'] ?? '',
              'rest': item['rest'] ?? '60 s',
            };
          }),
        );
        return {
          'day': map['day'] ?? 'Sin día',
          'dayOrder': map['dayOrder'] ?? localDayOrder((map['day'] ?? '').toString()),
          'title': map['title'] ?? 'Rutina',
          'notes': map['notes'] ?? '',
          'exercises': exercises,
        };
      }),
    );

    return {
      ...template,
      'days': days,
    };
  }

  Future<void> createTemplate(BuildContext context) async {
    final nameController = TextEditingController();
    var objective = routineObjectives.first;
    var frequency = routineFrequencies.first;
    var level = routineLevels.first;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text('Crear plantilla automática'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(
                      controller: nameController,
                      label: 'Nombre de la plantilla',
                      hint: 'Ej: Hipertrofia 5D propia',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: objective,
                      dropdownColor: const Color(0xFF0F172A),
                      decoration: const InputDecoration(labelText: 'Objetivo', border: OutlineInputBorder()),
                      items: routineObjectives.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => objective = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: frequency,
                      dropdownColor: const Color(0xFF0F172A),
                      decoration: const InputDecoration(labelText: 'Días por semana', border: OutlineInputBorder()),
                      items: routineFrequencies.map((item) => DropdownMenuItem(value: item, child: Text('$item días'))).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => frequency = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: level,
                      dropdownColor: const Color(0xFF0F172A),
                      decoration: const InputDecoration(labelText: 'Nivel', border: OutlineInputBorder()),
                      items: routineLevels.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => level = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Se creará una plantilla base que luego podrás ajustar día por día.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
                FilledButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Introduce un nombre para la plantilla.')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, {
                      'name': name,
                      'objective': objective,
                      'frequency': frequency,
                      'level': level,
                    });
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    if (result == null) return;

    final template = findRoutineTemplate(
      objective: result['objective'].toString(),
      frequency: result['frequency'] as int,
      level: result['level'].toString(),
    );

    if (template == null) {
      showSnack(context, 'No se pudo crear la plantilla base.');
      return;
    }

    final actor = await currentActor();
    final normalized = normalizeTemplate({
      ...template,
      'name': result['name'],
      ...auditCreateFields(actor),
    });

    final docRef = templatesRef.doc();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(docRef, normalized);
    batch.set(activityRef.doc(), activityFields(
      type: 'template_created',
      target: result['name'].toString(),
      targetId: docRef.id,
      actor: actor,
      metadata: {
        'objective': result['objective'],
        'frequency': result['frequency'],
        'level': result['level'],
      },
    ));
    await batch.commit();

    if (mounted) setState(() => selectedTemplateId = docRef.id);
    if (context.mounted) showSnack(context, 'Plantilla creada.');
  }

  Future<void> renameTemplate(BuildContext context, String templateId, Map<String, dynamic> data) async {
    final nameController = TextEditingController(text: data['name']?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Editar nombre de plantilla'),
          content: AppTextField(controller: nameController, label: 'Nombre'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(dialogContext, name);
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    if (result == null) return;

    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {
      'name': result,
      ...auditUpdateFields(actor),
    });
    batch.set(activityRef.doc(), activityFields(
      type: 'template_renamed',
      target: result,
      targetId: templateId,
      actor: actor,
      metadata: {'previousName': data['name'] ?? ''},
    ));
    await batch.commit();
  }

  Future<void> deleteTemplate(BuildContext context, String templateId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Eliminar plantilla'),
          content: Text('¿Seguro que quieres eliminar "$name"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(templatesRef.doc(templateId));
    batch.set(activityRef.doc(), activityFields(
      type: 'template_deleted',
      target: name,
      targetId: templateId,
      actor: actor,
    ));
    await batch.commit();

    if (mounted && selectedTemplateId == templateId) setState(() => selectedTemplateId = null);
    if (context.mounted) showSnack(context, 'Plantilla eliminada.');
  }

  Future<void> duplicateTemplate(BuildContext context, Map<String, dynamic> data) async {
    final actor = await currentActor();
    final copy = Map<String, dynamic>.from(data);
    copy.remove('id');
    copy['name'] = '${copy['name'] ?? 'Plantilla'} (copia)';
    copy.addAll(auditCreateFields(actor));

    final docRef = templatesRef.doc();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(docRef, copy);
    batch.set(activityRef.doc(), activityFields(
      type: 'template_duplicated',
      target: copy['name']?.toString() ?? 'Plantilla duplicada',
      targetId: docRef.id,
      actor: actor,
      metadata: {'sourceName': data['name'] ?? ''},
    ));
    await batch.commit();

    if (mounted) setState(() => selectedTemplateId = docRef.id);
    if (context.mounted) showSnack(context, 'Plantilla duplicada.');
  }

  Future<void> editDayInfo(BuildContext context, String templateId, Map<String, dynamic> data, int dayIndex) async {
    final days = List<Map<String, dynamic>>.from((data['days'] as List).map((day) => Map<String, dynamic>.from(day as Map)));
    final day = days[dayIndex];
    final titleController = TextEditingController(text: day['title']?.toString() ?? '');
    final notesController = TextEditingController(text: day['notes']?.toString() ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text('Editar ${day['day'] ?? 'día'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: titleController, label: 'Título del día'),
              const SizedBox(height: 12),
              AppTextField(controller: notesController, label: 'Notas del día'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, {
                  'title': titleController.text.trim(),
                  'notes': notesController.text.trim(),
                });
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    notesController.dispose();
    if (result == null) return;

    days[dayIndex]['title'] = result['title']!.isEmpty ? days[dayIndex]['title'] : result['title'];
    days[dayIndex]['notes'] = result['notes'];
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {
      'days': days,
      ...auditUpdateFields(actor),
    });
    batch.set(activityRef.doc(), activityFields(
      type: 'template_day_updated',
      target: data['name']?.toString() ?? 'Plantilla',
      targetId: templateId,
      actor: actor,
      metadata: {
        'day': day['day'] ?? '',
        'title': days[dayIndex]['title'] ?? '',
      },
    ));
    await batch.commit();
  }

  Future<void> addExerciseToDay(BuildContext context, String templateId, Map<String, dynamic> data, int dayIndex) async {
    final result = await showExerciseSheet(context, gymId: widget.gymId);
    if (result == null) return;

    final days = List<Map<String, dynamic>>.from((data['days'] as List).map((day) => Map<String, dynamic>.from(day as Map)));
    final exercises = List<Map<String, dynamic>>.from(
      (days[dayIndex]['exercises'] as List? ?? []).map((exercise) => Map<String, dynamic>.from(exercise as Map)),
    );
    exercises.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': result.name,
      'sets': result.sets,
      'reps': result.reps,
      'weight': result.weight,
      'rest': result.rest,
    });
    days[dayIndex]['exercises'] = exercises;
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {
      'days': days,
      ...auditUpdateFields(actor),
    });
    batch.set(activityRef.doc(), activityFields(
      type: 'template_exercise_added',
      target: result.name,
      targetId: templateId,
      actor: actor,
      metadata: {
        'templateName': data['name'] ?? '',
        'day': days[dayIndex]['day'] ?? '',
      },
    ));
    await batch.commit();
  }

  Future<void> editExerciseInDay(
    BuildContext context,
    String templateId,
    Map<String, dynamic> data,
    int dayIndex,
    String exerciseId,
  ) async {
    final days = List<Map<String, dynamic>>.from((data['days'] as List).map((day) => Map<String, dynamic>.from(day as Map)));
    final exercises = List<Map<String, dynamic>>.from(
      (days[dayIndex]['exercises'] as List? ?? []).map((exercise) => Map<String, dynamic>.from(exercise as Map)),
    );
    final current = exercises.firstWhere((exercise) => exercise['id'] == exerciseId, orElse: () => {});
    if (current.isEmpty) return;

    final result = await showExerciseSheet(context, gymId: widget.gymId, initialExercise: current);
    if (result == null) return;

    final updated = exercises.map((exercise) {
      if (exercise['id'] == exerciseId) {
        return {
          ...exercise,
          'name': result.name,
          'sets': result.sets,
          'reps': result.reps,
          'weight': result.weight,
          'rest': result.rest,
        };
      }
      return exercise;
    }).toList();

    days[dayIndex]['exercises'] = updated;
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {
      'days': days,
      ...auditUpdateFields(actor),
    });
    batch.set(activityRef.doc(), activityFields(
      type: 'template_exercise_updated',
      target: result.name,
      targetId: templateId,
      actor: actor,
      metadata: {
        'templateName': data['name'] ?? '',
        'day': days[dayIndex]['day'] ?? '',
      },
    ));
    await batch.commit();
  }

  Future<void> deleteExerciseFromDay(String templateId, Map<String, dynamic> data, int dayIndex, String exerciseId) async {
    final days = List<Map<String, dynamic>>.from((data['days'] as List).map((day) => Map<String, dynamic>.from(day as Map)));
    final exercises = List<Map<String, dynamic>>.from(
      (days[dayIndex]['exercises'] as List? ?? []).map((exercise) => Map<String, dynamic>.from(exercise as Map)),
    );
    var deletedExerciseName = exerciseId;
    days[dayIndex]['exercises'] = exercises.where((exercise) {
      if (exercise['id'] == exerciseId) deletedExerciseName = exercise['name']?.toString() ?? exerciseId;
      return exercise['id'] != exerciseId;
    }).toList();

    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {
      'days': days,
      ...auditUpdateFields(actor),
    });
    batch.set(activityRef.doc(), activityFields(
      type: 'template_exercise_deleted',
      target: deletedExerciseName,
      targetId: templateId,
      actor: actor,
      metadata: {
        'templateName': data['name'] ?? '',
        'day': days[dayIndex]['day'] ?? '',
      },
    ));
    await batch.commit();
  }

  Future<void> moveExerciseInDay(
    String templateId,
    Map<String, dynamic> data,
    int dayIndex,
    int exerciseIndex,
    int direction,
  ) async {
    final days = List<Map<String, dynamic>>.from((data['days'] as List).map((day) => Map<String, dynamic>.from(day as Map)));
    final exercises = List<Map<String, dynamic>>.from(
      (days[dayIndex]['exercises'] as List? ?? []).map((exercise) => Map<String, dynamic>.from(exercise as Map)),
    );
    final newIndex = exerciseIndex + direction;
    if (newIndex < 0 || newIndex >= exercises.length) return;
    final item = exercises.removeAt(exerciseIndex);
    exercises.insert(newIndex, item);
    days[dayIndex]['exercises'] = exercises;
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {
      'days': days,
      ...auditUpdateFields(actor),
    });
    batch.set(activityRef.doc(), activityFields(
      type: 'template_exercise_moved',
      target: item['name']?.toString() ?? 'Ejercicio',
      targetId: templateId,
      actor: actor,
      metadata: {
        'templateName': data['name'] ?? '',
        'day': days[dayIndex]['day'] ?? '',
        'from': exerciseIndex,
        'to': newIndex,
      },
    ));
    await batch.commit();
  }

  Widget buildSelectedTemplateEditor(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name = data['name']?.toString() ?? 'Plantilla sin nombre';
    final objective = data['objective']?.toString() ?? '-';
    final level = data['level']?.toString() ?? '-';
    final frequency = data['frequency']?.toString() ?? '-';
    final days = List<Map<String, dynamic>>.from(
      (data['days'] as List? ?? []).map((day) => Map<String, dynamic>.from(day as Map)),
    );
    days.sort((a, b) {
      final aOrder = a['dayOrder'] is int ? a['dayOrder'] as int : localDayOrder((a['day'] ?? '').toString());
      final bOrder = b['dayOrder'] is int ? b['dayOrder'] as int : localDayOrder((b['day'] ?? '').toString());
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
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('$objective · $frequency días · $level', style: const TextStyle(color: Colors.white70)),
                    if ((data['createdBy'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Creada por ${data['createdBy']}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                    if ((data['updatedBy'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Actualizada por ${data['updatedBy']}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar nombre',
                onPressed: () => renameTemplate(context, doc.id, data),
                icon: const Icon(Icons.edit, color: Colors.greenAccent),
              ),
              IconButton(
                tooltip: 'Duplicar plantilla',
                onPressed: () => duplicateTemplate(context, data),
                icon: const Icon(Icons.copy, color: Colors.lightBlueAccent),
              ),
              IconButton(
                tooltip: 'Eliminar plantilla',
                onPressed: () => deleteTemplate(context, doc.id, name),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...days.asMap().entries.map((entry) {
            final dayIndex = entry.key;
            final day = entry.value;
            final exercises = List<Map<String, dynamic>>.from(
              (day['exercises'] as List? ?? []).map((exercise) => Map<String, dynamic>.from(exercise as Map)),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${day['day'] ?? 'Sin día'} · ${day['title'] ?? 'Rutina'}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar día',
                        onPressed: () => editDayInfo(context, doc.id, data, dayIndex),
                        icon: const Icon(Icons.notes, color: Colors.greenAccent),
                      ),
                      Text('${exercises.length} ejercicios', style: const TextStyle(color: Colors.white60)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if ((day['notes'] ?? '').toString().trim().isNotEmpty) ...[
                    Text(day['notes'].toString(), style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 8),
                  ],
                  if (exercises.isEmpty)
                    const Text('Sin ejercicios configurados.', style: TextStyle(color: Colors.white60))
                  else
                    ...exercises.asMap().entries.map((exerciseEntry) {
                      final exerciseIndex = exerciseEntry.key;
                      final exercise = exerciseEntry.value;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(exercise['name']?.toString() ?? 'Ejercicio'),
                        subtitle: Text(
                          '${exercise['sets'] ?? '-'} series · ${exercise['reps'] ?? '-'} reps · Descanso ${exercise['rest'] ?? '-'}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Subir ejercicio',
                              onPressed: exerciseIndex == 0
                                  ? null
                                  : () => moveExerciseInDay(doc.id, data, dayIndex, exerciseIndex, -1),
                              icon: const Icon(Icons.arrow_upward, color: Colors.white70),
                            ),
                            IconButton(
                              tooltip: 'Bajar ejercicio',
                              onPressed: exerciseIndex >= exercises.length - 1
                                  ? null
                                  : () => moveExerciseInDay(doc.id, data, dayIndex, exerciseIndex, 1),
                              icon: const Icon(Icons.arrow_downward, color: Colors.white70),
                            ),
                            IconButton(
                              tooltip: 'Editar ejercicio',
                              onPressed: () => editExerciseInDay(context, doc.id, data, dayIndex, exercise['id'].toString()),
                              icon: const Icon(Icons.edit, color: Colors.greenAccent),
                            ),
                            IconButton(
                              tooltip: 'Eliminar ejercicio',
                              onPressed: () => deleteExerciseFromDay(doc.id, data, dayIndex, exercise['id'].toString()),
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => addExerciseToDay(context, doc.id, data, dayIndex),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir ejercicio a este día'),
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
      appBar: AppBar(title: const Text('Plantillas automáticas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => createTemplate(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva plantilla'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: templatesRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final templates = snapshot.data?.docs ?? [];
            if (templates.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle(icon: Icons.tune, title: 'Plantillas personalizadas'),
                        SizedBox(height: 12),
                        Text(
                          'Todavía no hay plantillas propias. Crea una plantilla para que el entrenador pueda generar rutinas automáticas personalizadas.',
                          style: TextStyle(color: Colors.white70),
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
                      const SectionTitle(icon: Icons.tune, title: 'Plantillas personalizadas'),
                      const SizedBox(height: 12),
                      const Text(
                        'Selecciona una plantilla existente para editarla. También puedes crear una nueva, duplicarla o eliminarla.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: currentTemplateId,
                        dropdownColor: const Color(0xFF0F172A),
                        decoration: const InputDecoration(
                          labelText: 'Plantilla seleccionada',
                          border: OutlineInputBorder(),
                        ),
                        items: templates.map((doc) {
                          final data = doc.data();
                          final name = data['name']?.toString() ?? 'Plantilla sin nombre';
                          final objective = data['objective']?.toString() ?? '-';
                          final frequency = data['frequency']?.toString() ?? '-';
                          final level = data['level']?.toString() ?? '-';
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text('$name · $objective · ${frequency}D · $level'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => selectedTemplateId = value);
                        },
                      ),
                    ],
                  ),
                ),
                buildSelectedTemplateEditor(context, selectedTemplate),
              ],
            );
          },
        ),
      ),
    );
  }
}
