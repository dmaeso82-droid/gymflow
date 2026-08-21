import 'package:cloud_firestore/cloud_firestore.dart';
import 'routine_exercise_model.dart';

class RoutineModel {
  final String id;
  final String title;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String day;
  final int dayOrder;
  final String notes;
  final List<RoutineExerciseModel> exercises;
  final String status;
  final bool done;
  final int completedSets;
  final int totalSets;
  final String routineWeekKey;
  final String weekKey;
  final bool generated;
  final Map<String, dynamic> raw;

  const RoutineModel({
    this.id = '',
    required this.title,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.day,
    required this.dayOrder,
    required this.notes,
    required this.exercises,
    this.status = 'active',
    this.done = false,
    this.completedSets = 0,
    this.totalSets = 0,
    this.routineWeekKey = '',
    this.weekKey = '',
    this.generated = false,
    this.raw = const {},
  });

  factory RoutineModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return RoutineModel.fromMap(doc.data(), id: doc.id);
  }

  factory RoutineModel.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final rawExercises = data['exercises'];
    final exercises = <RoutineExerciseModel>[];
    if (rawExercises is List) {
      for (var index = 0; index < rawExercises.length; index++) {
        final item = rawExercises[index];
        if (item is! Map) continue;
        exercises.add(RoutineExerciseModel.fromMap(
          Map<String, dynamic>.from(item),
          fallbackId: '${id.isEmpty ? 'routine' : id}_exercise_$index',
        ));
      }
    }

    return RoutineModel(
      id: id,
      title: nonEmptyText(data['title'], 'Rutina'),
      clientId: data['clientId']?.toString() ?? '',
      clientName: nonEmptyText(data['clientName'], 'Sin cliente'),
      clientEmail: (data['clientEmail'] ?? '').toString().trim().toLowerCase(),
      day: nonEmptyText(data['day'], 'Sin día'),
      dayOrder: nonNegativeIntValue(data['dayOrder']),
      notes: data['notes']?.toString() ?? '',
      exercises: exercises,
      status: data['status']?.toString() ?? 'active',
      done: data['done'] == true,
      completedSets: nonNegativeIntValue(data['completedSets']),
      totalSets: nonNegativeIntValue(data['totalSets']),
      routineWeekKey: data['routineWeekKey']?.toString() ?? '',
      weekKey: data['weekKey']?.toString() ?? '',
      generated: data['generated'] == true,
      raw: data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'clientId': clientId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'day': day,
      'dayOrder': dayOrder,
      'notes': notes,
      'exercises': exercises.map((exercise) => exercise.toMap()).toList(),
      'status': status,
      'done': done,
      'completedSets': completedSets,
      'totalSets': totalSets,
      'routineWeekKey': routineWeekKey,
      'weekKey': weekKey,
      'generated': generated,
    };
  }

  List<Map<String, dynamic>> get exerciseMaps => exercises.map((exercise) => exercise.toMap()).toList();

  static String nonEmptyText(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int nonNegativeIntValue(dynamic value) {
    final parsed = intValue(value);
    return parsed < 0 ? 0 : parsed;
  }

  static int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
