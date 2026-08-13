import 'package:cloud_firestore/cloud_firestore.dart';

class UserStatsSnapshot {
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

  const UserStatsSnapshot({
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

  factory UserStatsSnapshot.fromMap(Map<String, dynamic> data) {
    int intValue(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double doubleValue(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ?? 0.0;
    }

    final workoutDays = data['workoutDays'];
    final workoutsFromDays = workoutDays is Map ? workoutDays.length : 0;
    final exerciseNames = data['exerciseNames'];
    final exercisesFromMap = exerciseNames is Map ? exerciseNames.length : 0;

    return UserStatsSnapshot(
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? 'Usuario',
      userEmail: (data['userEmail'] ?? '').toString().toLowerCase(),
      series: intValue(data['series']),
      reps: intValue(data['reps']),
      volume: doubleValue(data['volume']),
      workouts: intValue(data['workouts']) > 0 ? intValue(data['workouts']) : workoutsFromDays,
      exerciseCount: intValue(data['exerciseCount']) > 0 ? intValue(data['exerciseCount']) : exercisesFromMap,
      recordCount: intValue(data['recordCount']),
      currentStreak: intValue(data['currentStreak']),
      bestStreak: intValue(data['bestStreak']),
      photos: intValue(data['photos']),
      transformations: intValue(data['transformations']),
      points: intValue(data['points']),
      raw: data,
    );
  }
}

class StatsService {
  final String gymId;

  const StatsService({required this.gymId});

  CollectionReference<Map<String, dynamic>> get userStatsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('user_stats');

  CollectionReference<Map<String, dynamic>> get rankingStatsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('ranking_stats');

  String statsDocId({required String userId, required String userEmail}) {
    if (userId.trim().isNotEmpty) return userId.trim();
    return userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  DateTime startOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    return clean.subtract(Duration(days: clean.weekday - DateTime.monday));
  }

  String weekKey([DateTime? date]) {
    final weekStart = startOfWeek(date ?? DateTime.now());
    final month = weekStart.month.toString().padLeft(2, '0');
    final day = weekStart.day.toString().padLeft(2, '0');
    return '${weekStart.year}-$month-$day';
  }

  String dayKey([DateTime? date]) {
    final value = date ?? DateTime.now();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<UserStatsSnapshot?> loadUserStats({required String userId, required String userEmail}) async {
    final docId = statsDocId(userId: userId, userEmail: userEmail);
    if (docId.isNotEmpty) {
      final snapshot = await userStatsRef.doc(docId).get();
      if (snapshot.exists && snapshot.data() != null) {
        return UserStatsSnapshot.fromMap(snapshot.data()!);
      }
    }
    final normalizedEmail = userEmail.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;
    final byEmail = await userStatsRef.where('userEmail', isEqualTo: normalizedEmail).limit(1).get();
    if (byEmail.docs.isEmpty) return null;
    return UserStatsSnapshot.fromMap(byEmail.docs.first.data());
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStatsStream({required String userId, required String userEmail}) {
    final docId = statsDocId(userId: userId, userEmail: userEmail);
    return userStatsRef.doc(docId).snapshots();
  }

  Future<void> recordWorkoutSet({
    required String userId,
    required String userName,
    required String userEmail,
    required String routineId,
    required String routineTitle,
    required String exerciseId,
    required String exerciseName,
    required double weight,
    required int reps,
    DateTime? date,
  }) async {
    final normalizedEmail = userEmail.trim().toLowerCase();
    final docId = statsDocId(userId: userId, userEmail: normalizedEmail);
    if (docId.isEmpty) return;

    final now = date ?? DateTime.now();
    final todayKey = dayKey(now);
    final currentWeekKey = weekKey(now);
    final volume = weight * reps;
    final exerciseKey = exerciseName.trim().isEmpty ? 'Ejercicio' : exerciseName.trim();

    final userDoc = userStatsRef.doc(docId);
    final rankingDoc = rankingStatsRef.doc(docId);

    final common = {
      'userId': userId,
      'userName': userName,
      'userEmail': normalizedEmail,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastWorkout': FieldValue.serverTimestamp(),
    };

    final batch = FirebaseFirestore.instance.batch();
    batch.set(userDoc, {
      ...common,
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
    }, SetOptions(merge: true));

    batch.set(rankingDoc, {
      ...common,
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
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> addPoints({
    required String userId,
    required String userName,
    required String userEmail,
    required int points,
  }) async {
    final normalizedEmail = userEmail.trim().toLowerCase();
    final docId = statsDocId(userId: userId, userEmail: normalizedEmail);
    if (docId.isEmpty || points == 0) return;
    final batch = FirebaseFirestore.instance.batch();
    final userDoc = userStatsRef.doc(docId);
    final rankingDoc = rankingStatsRef.doc(docId);
    final data = {
      'userId': userId,
      'userName': userName,
      'userEmail': normalizedEmail,
      'points': FieldValue.increment(points),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(userDoc, {...data, 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    batch.set(rankingDoc, {...data, 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await batch.commit();
  }
}
