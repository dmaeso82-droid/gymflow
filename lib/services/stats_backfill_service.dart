import 'package:cloud_firestore/cloud_firestore.dart';

class StatsBackfillResult {
  final int logsProcessed;
  final int usersUpdated;
  final int rankingDocsUpdated;

  const StatsBackfillResult({
    required this.logsProcessed,
    required this.usersUpdated,
    required this.rankingDocsUpdated,
  });
}

class _StatsAccumulator {
  final String userId;
  final String userName;
  final String userEmail;
  int series = 0;
  int reps = 0;
  double volume = 0;
  final Map<String, bool> workoutDays = {};
  final Map<String, bool> weeklyWorkoutDays = {};
  final Map<String, bool> exerciseNames = {};
  int weeklySeries = 0;
  int weeklyReps = 0;
  double weeklyVolume = 0;
  Timestamp? lastWorkout;

  _StatsAccumulator({
    required this.userId,
    required this.userName,
    required this.userEmail,
  });
}

class StatsBackfillService {
  final String gymId;

  const StatsBackfillService({required this.gymId});

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  CollectionReference<Map<String, dynamic>> get userStatsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('user_stats');

  CollectionReference<Map<String, dynamic>> get rankingStatsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('ranking_stats');

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

  String safeDocId(String userId, String userEmail) {
    if (userId.trim().isNotEmpty) return userId.trim();
    return userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  String dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime startOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    return clean.subtract(Duration(days: clean.weekday - DateTime.monday));
  }

  String weekKey(DateTime date) {
    final weekStart = startOfWeek(date);
    final month = weekStart.month.toString().padLeft(2, '0');
    final day = weekStart.day.toString().padLeft(2, '0');
    return '${weekStart.year}-$month-$day';
  }

  bool isCurrentWeek(DateTime date) {
    return weekKey(date) == weekKey(DateTime.now());
  }

  Future<StatsBackfillResult> rebuildStatsFromWorkoutLogs() async {
    final snapshot = await logsRef.get();
    final accumulators = <String, _StatsAccumulator>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final userId = data['userId']?.toString() ?? '';
      final userEmail = (data['userEmail'] ?? '').toString().toLowerCase();
      final docId = safeDocId(userId, userEmail);
      if (docId.isEmpty) continue;

      final userName = data['userName']?.toString().trim();
      final accumulator = accumulators.putIfAbsent(
        docId,
        () => _StatsAccumulator(
          userId: userId,
          userName: userName == null || userName.isEmpty ? 'Usuario' : userName,
          userEmail: userEmail,
        ),
      );

      final weight = doubleValue(data['weight']);
      final reps = intValue(data['reps']);
      final volume = weight * reps;
      final exercise = data['exercise']?.toString().trim() ?? '';
      final createdAt = data['createdAt'];

      accumulator.series += 1;
      accumulator.reps += reps;
      accumulator.volume += volume;
      if (exercise.isNotEmpty) accumulator.exerciseNames[exercise] = true;

      if (createdAt is Timestamp) {
        final date = createdAt.toDate();
        final key = dayKey(date);
        accumulator.workoutDays[key] = true;
        if (isCurrentWeek(date)) {
          accumulator.weeklyWorkoutDays[key] = true;
          accumulator.weeklySeries += 1;
          accumulator.weeklyReps += reps;
          accumulator.weeklyVolume += volume;
        }
        final currentLast = accumulator.lastWorkout;
        if (currentLast == null || createdAt.millisecondsSinceEpoch > currentLast.millisecondsSinceEpoch) {
          accumulator.lastWorkout = createdAt;
        }
      }
    }

    var updated = 0;
    var rankingUpdated = 0;
    WriteBatch batch = FirebaseFirestore.instance.batch();
    var batchOps = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (batchOps == 0) return;
      if (!force && batchOps < 430) return;
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      batchOps = 0;
    }

    for (final entry in accumulators.entries) {
      final docId = entry.key;
      final stats = entry.value;
      final common = {
        'userId': stats.userId,
        'userName': stats.userName,
        'userEmail': stats.userEmail,
        'updatedAt': FieldValue.serverTimestamp(),
        'backfilledAt': FieldValue.serverTimestamp(),
        if (stats.lastWorkout != null) 'lastWorkout': stats.lastWorkout,
      };

      batch.set(userStatsRef.doc(docId), {
        ...common,
        'series': stats.series,
        'reps': stats.reps,
        'volume': stats.volume,
        'workouts': stats.workoutDays.length,
        'exerciseCount': stats.exerciseNames.length,
        'workoutDays': stats.workoutDays,
        'exerciseNames': stats.exerciseNames,
      }, SetOptions(merge: true));
      batchOps += 1;
      updated += 1;

      batch.set(rankingStatsRef.doc(docId), {
        ...common,
        'totalSeries': stats.series,
        'totalReps': stats.reps,
        'totalVolume': stats.volume,
        'totalWorkouts': stats.workoutDays.length,
        'weeklySeries': stats.weeklySeries,
        'weeklyReps': stats.weeklyReps,
        'weeklyVolume': stats.weeklyVolume,
        'weeklyWorkouts': stats.weeklyWorkoutDays.length,
        'workoutDays': stats.workoutDays,
        'weeklyWorkoutDays': stats.weeklyWorkoutDays,
        'exerciseNames': stats.exerciseNames,
        'weekKey': weekKey(DateTime.now()),
      }, SetOptions(merge: true));
      batchOps += 1;
      rankingUpdated += 1;

      await commitIfNeeded();
    }

    await commitIfNeeded(force: true);

    return StatsBackfillResult(
      logsProcessed: snapshot.docs.length,
      usersUpdated: updated,
      rankingDocsUpdated: rankingUpdated,
    );
  }
}
