import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutLogModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String routineId;
  final String routineTitle;
  final String exerciseId;
  final String exercise;
  final String exerciseNormalized;
  final dynamic plannedSets;
  final dynamic plannedReps;
  final dynamic plannedWeight;
  final int setNumber;
  final int plannedSetCount;
  final double weight;
  final int reps;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkoutLogModel({
    this.id = '',
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.routineId,
    required this.routineTitle,
    required this.exerciseId,
    required this.exercise,
    required this.exerciseNormalized,
    required this.plannedSets,
    required this.plannedReps,
    required this.plannedWeight,
    required this.setNumber,
    required this.plannedSetCount,
    required this.weight,
    required this.reps,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkoutLogModel.fromExercise({
    required String userId,
    required String userName,
    required String userEmail,
    required String routineId,
    required String routineTitle,
    required Map<String, dynamic> exercise,
    required double weight,
    required int reps,
    required int setNumber,
    required int plannedSetCount,
  }) {
    final exerciseName = exercise['name']?.toString() ?? 'Ejercicio';

    return WorkoutLogModel(
      userId: userId,
      userName: userName,
      userEmail: userEmail.toLowerCase(),
      routineId: routineId,
      routineTitle: routineTitle,
      exerciseId: exercise['id']?.toString() ?? '',
      exercise: exerciseName,
      exerciseNormalized: normalizeText(exerciseName),
      plannedSets: exercise['sets'] ?? '',
      plannedReps: exercise['reps'] ?? '',
      plannedWeight: exercise['weight'] ?? '',
      setNumber: setNumber,
      plannedSetCount: plannedSetCount,
      weight: weight,
      reps: reps,
    );
  }

  factory WorkoutLogModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return WorkoutLogModel.fromMap(doc.data(), id: doc.id);
  }

  factory WorkoutLogModel.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final exerciseName = data['exercise']?.toString() ?? 'Ejercicio';

    return WorkoutLogModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? 'Usuario',
      userEmail: (data['userEmail'] ?? '').toString().toLowerCase(),
      routineId: data['routineId']?.toString() ?? '',
      routineTitle: data['routineTitle']?.toString() ?? 'Rutina',
      exerciseId: data['exerciseId']?.toString() ?? '',
      exercise: exerciseName,
      exerciseNormalized: (data['exerciseNormalized']?.toString().trim().isNotEmpty ?? false)
          ? data['exerciseNormalized'].toString()
          : normalizeText(exerciseName),
      plannedSets: data['plannedSets'] ?? '',
      plannedReps: data['plannedReps'] ?? '',
      plannedWeight: data['plannedWeight'] ?? '',
      setNumber: intValue(data['setNumber']),
      plannedSetCount: intValue(data['plannedSetCount']),
      weight: doubleValue(data['weight']),
      reps: intValue(data['reps']),
      createdAt: dateTimeValue(data['createdAt']),
      updatedAt: dateTimeValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail.toLowerCase(),
      'routineId': routineId,
      'routineTitle': routineTitle,
      'exerciseId': exerciseId,
      'exercise': exercise,
      'exerciseNormalized': exerciseNormalized,
      'plannedSets': plannedSets,
      'plannedReps': plannedReps,
      'plannedWeight': plannedWeight,
      'setNumber': setNumber,
      'plannedSetCount': plannedSetCount,
      'weight': weight,
      'reps': reps,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'weight': weight,
      'reps': reps,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool matchesExerciseQuery(String query) {
    final normalizedQuery = normalizeText(query);
    if (normalizedQuery.isEmpty) return true;
    return exerciseNormalized.contains(normalizedQuery);
  }

  String get formattedWeight {
    if (weight == weight.roundToDouble()) return weight.round().toString();
    return weight.toStringAsFixed(1).replaceAll('.', ',');
  }

  String get formattedDate {
    final date = createdAt;
    if (date == null) return 'Fecha pendiente';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String get setText {
    if (setNumber > 0 && plannedSetCount > 0) {
      return 'Serie $setNumber/$plannedSetCount';
    }
    return 'Serie registrada';
  }

  static String normalizeText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  static int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ?? 0.0;
  }

  static DateTime? dateTimeValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
