import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/routine_templates.dart';
import '../models/exercise_input.dart';
import '../utils/workout_utils.dart';

class TrainerRoutineService {
  final String gymId;

  const TrainerRoutineService({required this.gymId});

  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('clients');

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('routines');

  CollectionReference<Map<String, dynamic>> get customTemplatesRef => FirebaseFirestore.instance
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
    String? targetEmail,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'type': type,
      'target': target,
      'targetId': targetId ?? '',
      'targetEmail': (targetEmail ?? '').toLowerCase(),
      'user': actor['name'] ?? '',
      'userUid': actor['uid'] ?? '',
      'userEmail': actor['email'] ?? '',
      'metadata': metadata ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String cleanGeneratedRoutineTitle(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return 'Rutina';
    if (raw.contains('·')) {
      final last = raw.split('·').last.trim();
      if (last.isNotEmpty) return last;
    }

    final cleanup = raw
        .replaceAll(RegExp(r'Hipertrofia\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Fuerza\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Definición\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Pérdida\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Principiante|Intermedio|Avanzado', caseSensitive: false), '')
        .replaceAll('·', '')
        .trim();
    return cleanup.isEmpty ? raw : cleanup;
  }

  String templateDisplayName(Map<String, dynamic> template, String source) {
    final name = template['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final objective = template['objective']?.toString() ?? 'Plantilla';
    final frequency = template['frequency']?.toString() ?? '-';
    return source == 'system' ? '$objective ${frequency}D' : '$objective ${frequency}D personalizada';
  }

  Future<List<Map<String, dynamic>>> loadAutomaticTemplateOptions() async {
    final options = <Map<String, dynamic>>[];

    for (final objective in templateObjectives()) {
      for (final frequency in templateFrequenciesForObjective(objective)) {
        for (final level in templateLevelsForObjectiveAndFrequency(objective, frequency)) {
          final template = findRoutineTemplate(
            objective: objective,
            frequency: frequency,
            level: level,
          );
          if (template == null) continue;
          options.add({
            'id': 'system_${objective}_${frequency}_$level',
            'source': 'system',
            'name': templateDisplayName(template, 'system'),
            'template': template,
          });
        }
      }
    }

    final customSnapshot = await customTemplatesRef.orderBy('createdAt', descending: true).get();
    for (final doc in customSnapshot.docs) {
      final data = doc.data();
      final days = data['days'];
      if (days is! List || days.isEmpty) continue;
      options.insert(0, {
        'id': doc.id,
        'source': 'custom',
        'name': templateDisplayName(data, 'custom'),
        'template': {...data, 'id': doc.id},
      });
    }

    return options;
  }

  Future<void> archiveActiveRoutinesForClient({
    required String clientId,
    required String clientEmail,
    required Map<String, String> actor,
  }) async {
    final normalizedEmail = clientEmail.toLowerCase().trim();
    final existingRoutines = await routinesRef.get();
    final batch = FirebaseFirestore.instance.batch();
    var routinesToArchive = 0;

    for (final routine in existingRoutines.docs) {
      final data = routine.data();
      final routineClientId = data['clientId']?.toString() ?? '';
      final routineClientEmail = (data['clientEmail'] ?? '').toString().toLowerCase().trim();
      final status = (data['status'] ?? 'active').toString();
      final belongsToClient = routineClientId == clientId ||
          (normalizedEmail.isNotEmpty && routineClientEmail == normalizedEmail);

      if (belongsToClient && status != 'archived') {
        routinesToArchive++;
        batch.update(routine.reference, {
          'status': 'archived',
          'archivedAt': FieldValue.serverTimestamp(),
          ...auditUpdateFields(actor),
        });
      }
    }

    if (routinesToArchive > 0) {
      await batch.commit();
    }
  }

  DateTime startOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    return clean.subtract(Duration(days: clean.weekday - DateTime.monday));
  }

  String currentRoutineWeekKey([DateTime? value]) {
    final start = startOfWeek(value ?? DateTime.now());
    final month = start.month.toString().padLeft(2, '0');
    final day = start.day.toString().padLeft(2, '0');
    return '${start.year}-$month-$day';
  }

  List<Map<String, dynamic>> resetExercisesForNewWeek(List<dynamic> exercises) {
    return exercises.map((item) {
      final exercise = Map<String, dynamic>.from(item as Map);
      return {
        ...exercise,
        'done': false,
        'completedSets': 0,
      };
    }).toList();
  }

  Future<String> prepareCurrentWeekForClient({
    required String clientId,
    required Map<String, dynamic> clientData,
  }) async {
    final actor = await currentActor();
    final normalizedEmail = (clientData['email'] ?? '').toString().toLowerCase().trim();
    final currentWeekKey = currentRoutineWeekKey();
    final weekStart = startOfWeek(DateTime.now());

    final snapshot = await routinesRef.where('clientId', isEqualTo: clientId).get();
    final routines = snapshot.docs.where((routine) {
      final data = routine.data();
      final routineClientEmail = (data['clientEmail'] ?? '').toString().toLowerCase().trim();
      return routine.id.isNotEmpty || (normalizedEmail.isNotEmpty && routineClientEmail == normalizedEmail);
    }).toList();

    final alreadyPrepared = routines.any((routine) {
      final data = routine.data();
      final status = (data['status'] ?? 'active').toString();
      final key = (data['routineWeekKey'] ?? data['weekKey'] ?? '').toString();
      return status != 'archived' && key == currentWeekKey;
    });
    if (alreadyPrepared) {
      return 'La semana actual ya estaba preparada.';
    }

    final activeRoutines = routines.where((routine) {
      final data = routine.data();
      final status = (data['status'] ?? 'active').toString();
      return status != 'archived';
    }).toList();
    if (activeRoutines.isEmpty) {
      return 'No hay rutinas activas para preparar la nueva semana.';
    }

    activeRoutines.sort((a, b) {
      final aOrder = a.data()['dayOrder'] is int ? a.data()['dayOrder'] as int : routineDayOrder((a.data()['day'] ?? '').toString());
      final bOrder = b.data()['dayOrder'] is int ? b.data()['dayOrder'] as int : routineDayOrder((b.data()['day'] ?? '').toString());
      final orderCompare = aOrder.compareTo(bOrder);
      if (orderCompare != 0) return orderCompare;
      return (a.data()['title'] ?? '').toString().compareTo((b.data()['title'] ?? '').toString());
    });

    final batch = FirebaseFirestore.instance.batch();
    for (final routine in activeRoutines) {
      final data = routine.data();
      batch.update(routine.reference, {
        'status': 'archived',
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedReason': 'weekly_reset',
        'nextRoutineWeekKey': currentWeekKey,
        ...auditUpdateFields(actor),
      });

      final newRoutineRef = routinesRef.doc();
      final exercises = resetExercisesForNewWeek(List<dynamic>.from(data['exercises'] ?? []));
      batch.set(newRoutineRef, {
        'title': data['title'] ?? 'Rutina',
        'clientId': clientId,
        'clientName': clientData['name'] ?? data['clientName'] ?? 'Sin cliente',
        'clientEmail': normalizedEmail.isNotEmpty ? normalizedEmail : (data['clientEmail'] ?? '').toString().toLowerCase(),
        'day': data['day'] ?? 'Sin día',
        'dayOrder': data['dayOrder'] ?? routineDayOrder((data['day'] ?? '').toString()),
        'notes': data['notes'] ?? '',
        'exercises': exercises,
        'generated': data['generated'] ?? false,
        'generatedTemplateName': data['generatedTemplateName'] ?? '',
        'generatedTemplateSource': data['generatedTemplateSource'] ?? '',
        'generatedObjective': data['generatedObjective'] ?? '',
        'generatedFrequency': data['generatedFrequency'] ?? '',
        'generatedLevel': data['generatedLevel'] ?? '',
        'status': 'active',
        'done': false,
        'completedSets': 0,
        'totalSets': routineSetSummary(exercises).totalSets,
        'routineWeekKey': currentWeekKey,
        'weekKey': currentWeekKey,
        'weekStart': Timestamp.fromDate(weekStart),
        'createdFromRoutineId': routine.id,
        'weeklyReset': true,
        ...auditCreateFields(actor),
      });
    }

    batch.set(activityRef.doc(), activityFields(
      type: 'weekly_routines_prepared',
      target: clientData['name']?.toString() ?? 'Cliente',
      targetId: clientId,
      targetEmail: normalizedEmail,
      actor: actor,
      metadata: {
        'weekKey': currentWeekKey,
        'routinesCreated': activeRoutines.length,
      },
    ));
    await batch.commit();
    return 'Semana creada: ${activeRoutines.length} rutinas preparadas para ${clientData['name'] ?? 'el cliente'}.';
  }

  Future<String> generateAutomaticRoutine({
    required String clientId,
    required Map<String, dynamic> clientData,
    required Map<String, dynamic> selectedOption,
  }) async {
    final template = Map<String, dynamic>.from(selectedOption['template'] as Map);
    final daysRaw = template['days'];
    if (daysRaw is! List || daysRaw.isEmpty) {
      throw StateError('La plantilla seleccionada no tiene días configurados.');
    }

    final actor = await currentActor();
    await archiveActiveRoutinesForClient(
      clientId: clientId,
      clientEmail: (clientData['email'] ?? '').toString(),
      actor: actor,
    );

    final days = List<Map<String, dynamic>>.from(
      daysRaw.map((day) => Map<String, dynamic>.from(day as Map)),
    );
    days.sort((a, b) {
      final aOrder = a['dayOrder'] is int ? a['dayOrder'] as int : routineDayOrder((a['day'] ?? '').toString());
      final bOrder = b['dayOrder'] is int ? b['dayOrder'] as int : routineDayOrder((b['day'] ?? '').toString());
      return aOrder.compareTo(bOrder);
    });

    final batch = FirebaseFirestore.instance.batch();

    for (final day in days) {
      final exerciseList = day['exercises'] is List ? List<dynamic>.from(day['exercises'] as List) : <dynamic>[];
      final exercises = exerciseList.map((item) {
        final exercise = Map<String, dynamic>.from(item as Map);
        return {
          'id': DateTime.now().microsecondsSinceEpoch.toString() + (exercise['name'] ?? '').toString(),
          'name': exercise['name'] ?? 'Ejercicio',
          'sets': exercise['sets'] ?? 3,
          'reps': exercise['reps'] ?? '10',
          'weight': exercise['weight'] ?? '',
          'rest': exercise['rest'] ?? '60 s',
          'done': false,
          'completedSets': 0,
        };
      }).toList();

      final docRef = routinesRef.doc();
      batch.set(docRef, {
        'title': cleanGeneratedRoutineTitle(day['title'] ?? day['day'] ?? 'Rutina'),
        'clientId': clientId,
        'clientName': clientData['name'] ?? 'Sin cliente',
        'clientEmail': (clientData['email'] ?? '').toString().toLowerCase(),
        'day': day['day'] ?? 'Sin día',
        'dayOrder': day['dayOrder'] ?? routineDayOrder((day['day'] ?? '').toString()),
        'notes': '',
        'exercises': exercises,
        'generated': true,
        'generatedTemplateName': template['name'] ?? templateDisplayName(template, selectedOption['source'].toString()),
        'generatedTemplateSource': selectedOption['source'],
        'generatedObjective': template['objective'],
        'generatedFrequency': template['frequency'],
        'generatedLevel': template['level'],
        'status': 'active',
        ...auditCreateFields(actor),
      });
    }

    batch.set(activityRef.doc(), activityFields(
      type: 'routine_generated',
      target: template['name']?.toString() ?? 'Rutina automática',
      targetId: clientId,
      targetEmail: (clientData['email'] ?? '').toString(),
      actor: actor,
      metadata: {
        'clientName': clientData['name'] ?? 'Sin cliente',
        'templateSource': selectedOption['source'],
        'objective': template['objective'],
        'frequency': template['frequency'],
        'level': template['level'],
        'days': days.length,
      },
    ));

    await batch.commit();
    return 'Rutina automática generada para ${clientData['name'] ?? 'el cliente'}.';
  }

  Future<void> updateRoutine({
    required String routineId,
    required Map<String, dynamic> routineData,
    required String title,
    required String day,
    required String notes,
  }) async {
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();

    batch.update(routinesRef.doc(routineId), {
      'title': title,
      'day': day,
      'dayOrder': routineDayOrder(day),
      'notes': notes,
      ...auditUpdateFields(actor),
    });

    batch.set(activityRef.doc(), activityFields(
      type: 'routine_updated',
      target: title,
      targetId: routineId,
      targetEmail: routineData['clientEmail']?.toString(),
      actor: actor,
      metadata: {
        'clientName': routineData['clientName'] ?? '',
        'previousTitle': routineData['title'] ?? '',
      },
    ));

    await batch.commit();
  }

  Future<void> deleteRoutine({
    required String routineId,
    required String routineTitle,
  }) async {
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();

    batch.delete(routinesRef.doc(routineId));
    batch.set(activityRef.doc(), activityFields(
      type: 'routine_deleted',
      target: routineTitle,
      targetId: routineId,
      actor: actor,
    ));

    await batch.commit();
  }

  Future<void> addExercise({
    required String routineId,
    required List<dynamic> currentExercises,
    required ExerciseInput input,
  }) async {
    final actor = await currentActor();
    final newExercise = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': input.name,
      'sets': input.sets,
      'reps': input.reps,
      'weight': input.weight,
      'rest': input.rest,
      'done': false,
      'completedSets': 0,
    };

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final routineRef = routinesRef.doc(routineId);
      final routineSnapshot = await transaction.get(routineRef);
      final routineData = routineSnapshot.data() ?? {};
      transaction.update(routineRef, {
        'exercises': [...currentExercises, newExercise],
        ...auditUpdateFields(actor),
      });
      transaction.set(activityRef.doc(), activityFields(
        type: 'routine_exercise_added',
        target: input.name,
        targetId: routineId,
        targetEmail: routineData['clientEmail']?.toString(),
        actor: actor,
        metadata: {
          'routineTitle': routineData['title'] ?? '',
          'clientName': routineData['clientName'] ?? '',
        },
      ));
    });
  }

  Future<void> editExercise({
    required String routineId,
    required List<dynamic> exercises,
    required String exerciseId,
    required ExerciseInput input,
  }) async {
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) {
        return {
          ...map,
          'name': input.name,
          'sets': input.sets,
          'reps': input.reps,
          'weight': input.weight,
          'rest': input.rest,
        };
      }
      return map;
    }).toList();

    final actor = await currentActor();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final routineRef = routinesRef.doc(routineId);
      final routineSnapshot = await transaction.get(routineRef);
      final routineData = routineSnapshot.data() ?? {};
      transaction.update(routineRef, {
        'exercises': updated,
        ...auditUpdateFields(actor),
      });
      transaction.set(activityRef.doc(), activityFields(
        type: 'routine_exercise_updated',
        target: input.name,
        targetId: routineId,
        targetEmail: routineData['clientEmail']?.toString(),
        actor: actor,
        metadata: {
          'routineTitle': routineData['title'] ?? '',
          'clientName': routineData['clientName'] ?? '',
        },
      ));
    });
  }

  Future<void> updateExerciseDone({
    required String routineId,
    required List<dynamic> exercises,
    required String exerciseId,
    required bool done,
  }) async {
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) {
        final total = workoutTotalSets(map);
        map['done'] = done;
        map['completedSets'] = done ? total : 0;
      }
      return map;
    }).toList();

    final summary = routineSetSummary(updated);
    final actor = await currentActor();

    await routinesRef.doc(routineId).update({
      'exercises': updated,
      'completedSets': summary.completedSets,
      'totalSets': summary.totalSets,
      'done': summary.completed,
      ...auditUpdateFields(actor),
    });
  }

  Future<void> deleteExercise({
    required String routineId,
    required List<dynamic> exercises,
    required String exerciseId,
  }) async {
    String deletedExerciseName = exerciseId;
    final updated = exercises.where((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) deletedExerciseName = map['name']?.toString() ?? exerciseId;
      return map['id'] != exerciseId;
    }).toList();

    final actor = await currentActor();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final routineRef = routinesRef.doc(routineId);
      final routineSnapshot = await transaction.get(routineRef);
      final routineData = routineSnapshot.data() ?? {};
      transaction.update(routineRef, {
        'exercises': updated,
        ...auditUpdateFields(actor),
      });
      transaction.set(activityRef.doc(), activityFields(
        type: 'routine_exercise_deleted',
        target: deletedExerciseName,
        targetId: routineId,
        targetEmail: routineData['clientEmail']?.toString(),
        actor: actor,
        metadata: {
          'routineTitle': routineData['title'] ?? '',
          'clientName': routineData['clientName'] ?? '',
        },
      ));
    });
  }
}



