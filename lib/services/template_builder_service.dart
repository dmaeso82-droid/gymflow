import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/routine_templates.dart';
import '../models/exercise_input.dart';

class TemplateBuilderService {
  final String gymId;

  const TemplateBuilderService({required this.gymId});

  CollectionReference<Map<String, dynamic>> get templatesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('routine_templates');

  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('activity');

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
    return {...template, 'days': days};
  }

  Future<String> createTemplate({
    required String name,
    required String objective,
    required int frequency,
    required String level,
  }) async {
    final template = findRoutineTemplate(objective: objective, frequency: frequency, level: level);
    if (template == null) {
      throw StateError('No se pudo crear la plantilla base.');
    }

    final actor = await currentActor();
    final normalized = normalizeTemplate({
      ...template,
      'name': name,
      ...auditCreateFields(actor),
    });

    final docRef = templatesRef.doc();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(docRef, normalized);
    batch.set(activityRef.doc(), activityFields(
      type: 'template_created',
      target: name,
      targetId: docRef.id,
      actor: actor,
      metadata: {'objective': objective, 'frequency': frequency, 'level': level},
    ));
    await batch.commit();
    return docRef.id;
  }

  Future<void> renameTemplate(String templateId, Map<String, dynamic> data, String name) async {
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {
      'name': name,
      ...auditUpdateFields(actor),
    });
    batch.set(activityRef.doc(), activityFields(
      type: 'template_renamed',
      target: name,
      targetId: templateId,
      actor: actor,
      metadata: {'previousName': data['name'] ?? ''},
    ));
    await batch.commit();
  }

  Future<void> deleteTemplate(String templateId, String name) async {
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
  }

  Future<String> duplicateTemplate(Map<String, dynamic> data) async {
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
    return docRef.id;
  }

  List<Map<String, dynamic>> cloneDays(Map<String, dynamic> data) {
    final rawDays = data['days'];
    if (rawDays is! List) return <Map<String, dynamic>>[];
    final days = rawDays.whereType<Map>().map((day) {
      return Map<String, dynamic>.from(day);
    }).toList();
    days.sort((a, b) {
      final aOrder = a['dayOrder'] is int
          ? a['dayOrder'] as int
          : localDayOrder((a['day'] ?? '').toString());
      final bOrder = b['dayOrder'] is int
          ? b['dayOrder'] as int
          : localDayOrder((b['day'] ?? '').toString());
      return aOrder.compareTo(bOrder);
    });
    return days;
  }

  List<Map<String, dynamic>> cloneExercises(Map<String, dynamic> day) {
    final rawExercises = day['exercises'];
    if (rawExercises is! List) return <Map<String, dynamic>>[];
    return rawExercises.whereType<Map>().map((exercise) {
      return Map<String, dynamic>.from(exercise);
    }).toList();
  }

  Future<void> editDayInfo({
    required String templateId,
    required Map<String, dynamic> data,
    required int dayIndex,
    required String title,
    required String notes,
  }) async {
    final days = cloneDays(data);
    final day = days[dayIndex];
    day['title'] = title.trim().isEmpty ? day['title'] : title.trim();
    day['notes'] = notes.trim();

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
      metadata: {'day': day['day'] ?? '', 'title': day['title'] ?? ''},
    ));
    await batch.commit();
  }

  Future<void> addExerciseToDay({
    required String templateId,
    required Map<String, dynamic> data,
    required int dayIndex,
    required ExerciseInput input,
  }) async {
    final days = cloneDays(data);
    final exercises = cloneExercises(days[dayIndex]);
    exercises.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': input.name,
      'sets': input.sets,
      'reps': input.reps,
      'weight': input.weight,
      'rest': input.rest,
    });
    days[dayIndex]['exercises'] = exercises;

    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {'days': days, ...auditUpdateFields(actor)});
    batch.set(activityRef.doc(), activityFields(
      type: 'template_exercise_added',
      target: input.name,
      targetId: templateId,
      actor: actor,
      metadata: {'templateName': data['name'] ?? '', 'day': days[dayIndex]['day'] ?? ''},
    ));
    await batch.commit();
  }

  Future<void> editExerciseInDay({
    required String templateId,
    required Map<String, dynamic> data,
    required int dayIndex,
    required String exerciseId,
    required ExerciseInput input,
  }) async {
    final days = cloneDays(data);
    final exercises = cloneExercises(days[dayIndex]);
    final updated = exercises.map((exercise) {
      if (exercise['id'] == exerciseId) {
        return {
          ...exercise,
          'name': input.name,
          'sets': input.sets,
          'reps': input.reps,
          'weight': input.weight,
          'rest': input.rest,
        };
      }
      return exercise;
    }).toList();
    days[dayIndex]['exercises'] = updated;

    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {'days': days, ...auditUpdateFields(actor)});
    batch.set(activityRef.doc(), activityFields(
      type: 'template_exercise_updated',
      target: input.name,
      targetId: templateId,
      actor: actor,
      metadata: {'templateName': data['name'] ?? '', 'day': days[dayIndex]['day'] ?? ''},
    ));
    await batch.commit();
  }

  Future<void> deleteExerciseFromDay({
    required String templateId,
    required Map<String, dynamic> data,
    required int dayIndex,
    required String exerciseId,
  }) async {
    final days = cloneDays(data);
    final exercises = cloneExercises(days[dayIndex]);
    var deletedExerciseName = exerciseId;
    days[dayIndex]['exercises'] = exercises.where((exercise) {
      if (exercise['id'] == exerciseId) {
        deletedExerciseName = exercise['name']?.toString() ?? exerciseId;
      }
      return exercise['id'] != exerciseId;
    }).toList();

    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {'days': days, ...auditUpdateFields(actor)});
    batch.set(activityRef.doc(), activityFields(
      type: 'template_exercise_deleted',
      target: deletedExerciseName,
      targetId: templateId,
      actor: actor,
      metadata: {'templateName': data['name'] ?? '', 'day': days[dayIndex]['day'] ?? ''},
    ));
    await batch.commit();
  }

  Future<void> moveExerciseInDay({
    required String templateId,
    required Map<String, dynamic> data,
    required int dayIndex,
    required int exerciseIndex,
    required int direction,
  }) async {
    final days = cloneDays(data);
    final exercises = cloneExercises(days[dayIndex]);
    final newIndex = exerciseIndex + direction;
    if (newIndex < 0 || newIndex >= exercises.length) return;

    final item = exercises.removeAt(exerciseIndex);
    exercises.insert(newIndex, item);
    days[dayIndex]['exercises'] = exercises;

    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(templatesRef.doc(templateId), {'days': days, ...auditUpdateFields(actor)});
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
}



