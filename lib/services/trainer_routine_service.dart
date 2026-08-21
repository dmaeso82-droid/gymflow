import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/routine_templates.dart';
import '../models/exercise_input.dart';
import '../models/routine_exercise_model.dart';
import '../models/routine_model.dart';
import '../utils/workout_utils.dart';

part 'routine_audit_mixin.dart';
part 'routine_template_mixin.dart';

class TrainerRoutineService with RoutineAuditMixin, RoutineTemplateMixin {
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
      final routineModel = RoutineModel.fromDoc(routine);
      final routineClientEmail = routineModel.clientEmail.toLowerCase().trim();
      final belongsToClient = routineModel.clientId == clientId ||
          (normalizedEmail.isNotEmpty && routineClientEmail == normalizedEmail);

      if (belongsToClient && routineModel.status != 'archived') {
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
    return exercises.whereType<Map>().map((item) {
      return RoutineExerciseModel.fromMap(Map<String, dynamic>.from(item)).resetForNewWeek();
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
      final routineModel = RoutineModel.fromDoc(routine);
      return routine.id.isNotEmpty || (normalizedEmail.isNotEmpty && routineModel.clientEmail == normalizedEmail);
    }).toList();

    final alreadyPrepared = routines.any((routine) {
      final data = routine.data();
      final routineModel = RoutineModel.fromMap(data, id: routine.id);
      final key = (data['routineWeekKey'] ?? data['weekKey'] ?? '').toString();
      return routineModel.status != 'archived' && key == currentWeekKey;
    });

    if (alreadyPrepared) {
      return 'La semana actual ya estaba preparada.';
    }

    final activeRoutines = routines.where((routine) {
      final routineModel = RoutineModel.fromDoc(routine);
      return routineModel.status != 'archived';
    }).toList();

    if (activeRoutines.isEmpty) {
      return 'No hay rutinas activas para preparar la nueva semana.';
    }

    activeRoutines.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aOrder = aData['dayOrder'] is int ? aData['dayOrder'] as int : routineDayOrder((aData['day'] ?? '').toString());
      final bOrder = bData['dayOrder'] is int ? bData['dayOrder'] as int : routineDayOrder((bData['day'] ?? '').toString());
      final orderCompare = aOrder.compareTo(bOrder);
      if (orderCompare != 0) return orderCompare;
      return (aData['title'] ?? '').toString().compareTo((bData['title'] ?? '').toString());
    });

    final batch = FirebaseFirestore.instance.batch();

    for (final routine in activeRoutines) {
      final data = routine.data();
      final routineModel = RoutineModel.fromMap(data, id: routine.id);
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
        'title': routineModel.title,
        'clientId': clientId,
        'clientName': clientData['name'] ?? routineModel.clientName,
        'clientEmail': normalizedEmail.isNotEmpty ? normalizedEmail : routineModel.clientEmail,
        'day': routineModel.day,
        'dayOrder': data['dayOrder'] ?? routineDayOrder(routineModel.day),
        'notes': routineModel.notes,
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

    final days = <Map<String, dynamic>>[];
    for (final rawDay in daysRaw) {
      if (rawDay is! Map) {
        throw StateError('La plantilla contiene un día con formato inválido.');
      }
      final day = Map<String, dynamic>.from(rawDay);
      final rawExercises = day['exercises'];
      if (rawExercises != null && rawExercises is! List) {
        throw StateError('La plantilla contiene ejercicios con formato inválido.');
      }
      if (rawExercises is List && rawExercises.any((exercise) => exercise is! Map)) {
        throw StateError('La plantilla contiene un ejercicio con formato inválido.');
      }
      days.add(day);
    }
    if (days.isEmpty) {
      throw StateError('La plantilla seleccionada no tiene días válidos.');
    }

    days.sort((a, b) {
      final aOrder = a['dayOrder'] is int ? a['dayOrder'] as int : routineDayOrder((a['day'] ?? '').toString());
      final bOrder = b['dayOrder'] is int ? b['dayOrder'] as int : routineDayOrder((b['day'] ?? '').toString());
      return aOrder.compareTo(bOrder);
    });

    final actor = await currentActor();
    await archiveActiveRoutinesForClient(
      clientId: clientId,
      clientEmail: (clientData['email'] ?? '').toString(),
      actor: actor,
    );

    final batch = FirebaseFirestore.instance.batch();

    for (final day in days) {
      final exerciseList = day['exercises'] is List ? List<dynamic>.from(day['exercises'] as List) : <dynamic>[];
      final exercises = exerciseList.whereType<Map>().map((item) {
        final exercise = Map<String, dynamic>.from(item);
        return RoutineExerciseModel.fromMap(
          exercise,
          fallbackId: DateTime.now().microsecondsSinceEpoch.toString() + (exercise['name'] ?? '').toString(),
        ).toMap();
      }).toList();

      final summary = routineSetSummary(exercises);
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
        'done': false,
        'completedSets': summary.completedSets,
        'totalSets': summary.totalSets,
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
    final newExercise = RoutineExerciseModel.fromInput(input).toMap();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final routineRef = routinesRef.doc(routineId);
      final routineSnapshot = await transaction.get(routineRef);
      final routineData = routineSnapshot.data() ?? {};
      final updatedExercises = [...exerciseMapsFromDynamicList(currentExercises), newExercise];
      final summary = routineSetSummary(updatedExercises);

      transaction.update(routineRef, {
        'exercises': updatedExercises,
        'completedSets': summary.completedSets,
        'totalSets': summary.totalSets,
        'done': summary.completed,
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
    final updated = exercises.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      final exercise = RoutineExerciseModel.fromMap(map);
      if (exercise.id == exerciseId) {
        return exercise.copyWith(
          name: input.name,
          sets: input.sets,
          reps: input.reps,
          weight: input.weight,
          rest: input.rest,
        ).toMap();
      }
      return exercise.toMap();
    }).toList();

    final summary = routineSetSummary(updated);
    final actor = await currentActor();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final routineRef = routinesRef.doc(routineId);
      final routineSnapshot = await transaction.get(routineRef);
      final routineData = routineSnapshot.data() ?? {};
      transaction.update(routineRef, {
        'exercises': updated,
        'completedSets': summary.completedSets,
        'totalSets': summary.totalSets,
        'done': summary.completed,
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
    final updated = exercises.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      final exercise = RoutineExerciseModel.fromMap(map);
      if (exercise.id == exerciseId) {
        final total = workoutTotalSets(exercise.toMap());
        return exercise.copyWith(done: done, completedSets: done ? total : 0).toMap();
      }
      return exercise.toMap();
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
    final updated = <Map<String, dynamic>>[];

    for (final item in exercises) {
      if (item is! Map) continue;
      final exercise = RoutineExerciseModel.fromMap(Map<String, dynamic>.from(item));
      if (exercise.id == exerciseId) {
        deletedExerciseName = exercise.name;
        continue;
      }
      updated.add(exercise.toMap());
    }

    final summary = routineSetSummary(updated);
    final actor = await currentActor();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final routineRef = routinesRef.doc(routineId);
      final routineSnapshot = await transaction.get(routineRef);
      final routineData = routineSnapshot.data() ?? {};
      transaction.update(routineRef, {
        'exercises': updated,
        'completedSets': summary.completedSets,
        'totalSets': summary.totalSets,
        'done': summary.completed,
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
