import 'package:cloud_firestore/cloud_firestore.dart';

class UserStatsModel {
  final String userId;
  final String userName;
  final String userEmail;
  final int series;
  final int reps;
  final double volume;
  final int workouts;
  final int exerciseCount;
  final int recordCount;
  final int currentStreak;
  final int bestStreak;
  final int photos;
  final int transformations;
  final int points;
  final Map<String, dynamic> raw;

  const UserStatsModel({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.series,
    required this.reps,
    required this.volume,
    required this.workouts,
    required this.exerciseCount,
    required this.recordCount,
    required this.currentStreak,
    required this.bestStreak,
    required this.photos,
    required this.transformations,
    required this.points,
    required this.raw,
  });

  factory UserStatsModel.empty({
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    return UserStatsModel(
      userId: userId,
      userName: userName,
      userEmail: userEmail.toLowerCase(),
      series: 0,
      reps: 0,
      volume: 0,
      workouts: 0,
      exerciseCount: 0,
      recordCount: 0,
      currentStreak: 0,
      bestStreak: 0,
      photos: 0,
      transformations: 0,
      points: 0,
      raw: const {},
    );
  }

  factory UserStatsModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserStatsModel.fromMap(doc.data() ?? const {}, fallbackUserId: doc.id);
  }

  factory UserStatsModel.fromMap(Map<String, dynamic> data, {String fallbackUserId = ''}) {
    final workoutDays = data['workoutDays'];
    final workoutsFromDays = workoutDays is Map ? workoutDays.length : 0;
    final exerciseNames = data['exerciseNames'];
    final exercisesFromMap = exerciseNames is Map ? exerciseNames.length : 0;
    final parsedWorkouts = intValue(data['workouts']);
    final parsedExerciseCount = intValue(data['exerciseCount']);

    return UserStatsModel(
      userId: data['userId']?.toString() ?? fallbackUserId,
      userName: data['userName']?.toString() ?? 'Usuario',
      userEmail: (data['userEmail'] ?? '').toString().toLowerCase(),
      series: intValue(data['series']),
      reps: intValue(data['reps']),
      volume: doubleValue(data['volume']),
      workouts: parsedWorkouts > 0 ? parsedWorkouts : workoutsFromDays,
      exerciseCount: parsedExerciseCount > 0 ? parsedExerciseCount : exercisesFromMap,
      recordCount: intValue(data['recordCount']),
      currentStreak: intValue(data['currentStreak']),
      bestStreak: intValue(data['bestStreak']),
      photos: intValue(data['photos']),
      transformations: intValue(data['transformations']),
      points: intValue(data['points']),
      raw: data,
    );
  }

  static String statsDocId({required String userId, required String userEmail}) {
    if (userId.trim().isNotEmpty) return userId.trim();
    return userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  static String weekKey([DateTime? date]) {
    final weekStart = startOfWeek(date ?? DateTime.now());
    final month = weekStart.month.toString().padLeft(2, '0');
    final day = weekStart.day.toString().padLeft(2, '0');
    return '${weekStart.year}-$month-$day';
  }

  static String dayKey([DateTime? date]) {
    final value = date ?? DateTime.now();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static DateTime startOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    return clean.subtract(Duration(days: clean.weekday - DateTime.monday));
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
}

class WorkoutStatsUpdate {
  final String userId;
  final String userName;
  final String userEmail;
  final String routineId;
  final String routineTitle;
  final String exerciseId;
  final String exerciseName;
  final double weight;
  final int reps;
  final DateTime date;

  const WorkoutStatsUpdate({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.routineId,
    required this.routineTitle,
    required this.exerciseId,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.date,
  });

  String get normalizedEmail => userEmail.trim().toLowerCase();
  String get docId => UserStatsModel.statsDocId(userId: userId, userEmail: normalizedEmail);
  String get todayKey => UserStatsModel.dayKey(date);
  String get currentWeekKey => UserStatsModel.weekKey(date);
  double get volume => weight * reps;
  String get exerciseKey => exerciseName.trim().isEmpty ? 'Ejercicio' : exerciseName.trim();

  Map<String, dynamic> commonFields() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': normalizedEmail,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastWorkout': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> userStatsFields() {
    return {
      ...commonFields(),
      'series': FieldValue.increment(1),
      'reps': FieldValue.increment(reps),
      'volume': FieldValue.increment(volume),
      'workoutDays.$todayKey': true,
      'exerciseNames.$exerciseKey': true,
      'lastRoutineId': routineId,
      'lastRoutineTitle': routineTitle,
      'lastExerciseId': exerciseId,
      'lastExercise': exerciseName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> rankingStatsFields() {
    return {
      ...commonFields(),
      'weekKey': currentWeekKey,
      'weeklySeries': FieldValue.increment(1),
      'weeklyReps': FieldValue.increment(reps),
      'weeklyVolume': FieldValue.increment(volume),
      'totalSeries': FieldValue.increment(1),
      'totalReps': FieldValue.increment(reps),
      'totalVolume': FieldValue.increment(volume),
      'workoutDays.$todayKey': true,
      'exerciseNames.$exerciseKey': true,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class PointsStatsUpdate {
  final String userId;
  final String userName;
  final String userEmail;
  final int points;

  const PointsStatsUpdate({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.points,
  });

  String get normalizedEmail => userEmail.trim().toLowerCase();
  String get docId => UserStatsModel.statsDocId(userId: userId, userEmail: normalizedEmail);

  Map<String, dynamic> fields() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': normalizedEmail,
      'points': FieldValue.increment(points),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
