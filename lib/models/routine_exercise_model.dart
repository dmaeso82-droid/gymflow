import 'exercise_input.dart';

class RoutineExerciseModel {
  final String id;
  final String name;
  final dynamic sets;
  final dynamic reps;
  final dynamic weight;
  final dynamic rest;
  final bool done;
  final int completedSets;

  const RoutineExerciseModel({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.rest,
    this.done = false,
    this.completedSets = 0,
  });

  factory RoutineExerciseModel.fromInput(ExerciseInput input, {String? id}) {
    return RoutineExerciseModel(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: input.name,
      sets: input.sets,
      reps: input.reps,
      weight: input.weight,
      rest: input.rest,
      done: false,
      completedSets: 0,
    );
  }

  factory RoutineExerciseModel.fromMap(Map<String, dynamic> data, {String? fallbackId}) {
    return RoutineExerciseModel(
      id: _nonEmptyText(data['id'], fallbackId ?? DateTime.now().microsecondsSinceEpoch.toString()),
      name: _nonEmptyText(data['name'], 'Ejercicio'),
      sets: data['sets'] ?? 3,
      reps: data['reps'] ?? '10',
      weight: data['weight'] ?? '',
      rest: data['rest'] ?? '60 s',
      done: data['done'] == true,
      completedSets: nonNegativeIntValue(data['completedSets']),
    );
  }

  RoutineExerciseModel copyWith({
    String? id,
    String? name,
    dynamic sets,
    dynamic reps,
    dynamic weight,
    dynamic rest,
    bool? done,
    int? completedSets,
  }) {
    return RoutineExerciseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      rest: rest ?? this.rest,
      done: done ?? this.done,
      completedSets: completedSets ?? this.completedSets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'rest': rest,
      'done': done,
      'completedSets': completedSets,
    };
  }

  Map<String, dynamic> resetForNewWeek() {
    return copyWith(done: false, completedSets: 0).toMap();
  }

  static String _nonEmptyText(dynamic value, String fallback) {
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
