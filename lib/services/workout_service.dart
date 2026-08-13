import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/workout_utils.dart';
import 'achievement_service.dart';
import 'challenge_service.dart';
import 'stats_service.dart';

class WorkoutProgressResult {
  final bool routineCompleted;
  final int totalCompletedSets;
  final int totalPlannedSets;
  final int totalExercises;

  const WorkoutProgressResult({
    required this.routineCompleted,
    required this.totalCompletedSets,
    required this.totalPlannedSets,
    required this.totalExercises,
  });
}

class WorkoutService {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const WorkoutService({
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('routines');

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  CollectionReference<Map<String, dynamic>> get communityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('community_posts');

  CollectionReference<Map<String, dynamic>> get challengesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('challenges');

  bool isActiveRoutine(Map<String, dynamic> data) {
    return (data['status'] ?? 'active').toString() != 'archived';
  }

  StatsService get statsService => StatsService(gymId: gymId);

  AchievementService get achievementService => AchievementService(
        gymId: gymId,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
      );

  DateTime startOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    return clean.subtract(Duration(days: clean.weekday - DateTime.monday));
  }

  String currentWeekKey() {
    final weekStart = startOfWeek(DateTime.now());
    final month = weekStart.month.toString().padLeft(2, '0');
    final day = weekStart.day.toString().padLeft(2, '0');
    return '${weekStart.year}-$month-$day';
  }

  Map<String, dynamic> resetExerciseForNewWeek(Map<String, dynamic> exercise) {
    final updated = Map<String, dynamic>.from(exercise);
    updated['done'] = false;
    updated['completedSets'] = 0;
    return updated;
  }

  bool routineNeedsWeeklyReset(Map<String, dynamic> data) {
    if (!isActiveRoutine(data)) return false;
    final weekKey = currentWeekKey();
    final lastResetWeek = data['lastResetWeek']?.toString();
    if (lastResetWeek == weekKey) return false;

    final exercises = List<dynamic>.from(data['exercises'] ?? []);
    if (exercises.isEmpty) return false;

    final hasProgress = exercises.any((item) {
      final exercise = Map<String, dynamic>.from(item as Map);
      return exercise['done'] == true || workoutCompletedSets(exercise) > 0;
    });

    return hasProgress || lastResetWeek == null || lastResetWeek.isEmpty;
  }

  Future<bool> resetRoutineForCurrentWeekIfNeeded(
    QueryDocumentSnapshot<Map<String, dynamic>> routineDoc,
  ) async {
    final data = routineDoc.data();
    if (!routineNeedsWeeklyReset(data)) return false;

    final weekKey = currentWeekKey();
    final exercises = List<dynamic>.from(data['exercises'] ?? []);
    final resetExercises = exercises.map((item) {
      final exercise = Map<String, dynamic>.from(item as Map);
      return resetExerciseForNewWeek(exercise);
    }).toList();
    final summary = routineSetSummary(resetExercises);

    await routineDoc.reference.update({
      'exercises': resetExercises,
      'completedSets': 0,
      'totalSets': summary.totalSets,
      'done': false,
      'lastResetWeek': weekKey,
      'lastWeeklyResetAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<bool> resetRoutinesForCurrentWeekIfNeeded(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> routineDocs,
  ) async {
    var changed = false;
    for (final routineDoc in routineDocs) {
      final didReset = await resetRoutineForCurrentWeekIfNeeded(routineDoc);
      changed = changed || didReset;
    }
    return changed;
  }

  Future<List<UnlockedAchievementData>> saveWorkoutLog({
    required String routineId,
    required String routineTitle,
    required Map<String, dynamic> exercise,
    required double weight,
    required int reps,
    required int setNumber,
    required int plannedSetCount,
  }) async {
    await logsRef.add({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail.toLowerCase(),
      'routineId': routineId,
      'routineTitle': routineTitle,
      'exerciseId': exercise['id'] ?? '',
      'exercise': exercise['name'] ?? 'Ejercicio',
      'plannedSets': exercise['sets'] ?? '',
      'plannedReps': exercise['reps'] ?? '',
      'plannedWeight': exercise['weight'] ?? '',
      'setNumber': setNumber,
      'plannedSetCount': plannedSetCount,
      'weight': weight,
      'reps': reps,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await statsService.recordWorkoutSet(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      routineId: routineId,
      routineTitle: routineTitle,
      exerciseId: exercise['id']?.toString() ?? '',
      exerciseName: exercise['name']?.toString() ?? 'Ejercicio',
      weight: weight,
      reps: reps,
    );
    return achievementService.evaluateAndUnlock();
  }

  Future<void> shareAchievementToCommunity(UnlockedAchievementData achievement) async {
    await achievementService.shareAchievementToCommunity(achievement);
  }

  Future<WorkoutProgressResult> updateExerciseSetProgress(
    String routineId,
    List<dynamic> exercises,
    String exerciseId,
  ) async {
    int totalCompletedSets = 0;
    int totalPlannedSets = 0;
    int totalExercises = 0;
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final plannedSetCount = workoutTotalSets(map);
      var completed = workoutCompletedSets(map);
      if (map['id'] == exerciseId) {
        completed = (completed + 1).clamp(0, plannedSetCount).toInt();
        map['completedSets'] = completed;
        map['done'] = completed >= plannedSetCount;
      }
      totalExercises += 1;
      totalPlannedSets += plannedSetCount;
      totalCompletedSets += completed.clamp(0, plannedSetCount).toInt();
      return map;
    }).toList();
    final routineCompleted = totalPlannedSets > 0 && totalCompletedSets >= totalPlannedSets;
    await routinesRef.doc(routineId).update({
      'exercises': updated,
      'completedSets': totalCompletedSets,
      'totalSets': totalPlannedSets,
      'done': routineCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return WorkoutProgressResult(
      routineCompleted: routineCompleted,
      totalCompletedSets: totalCompletedSets,
      totalPlannedSets: totalPlannedSets,
      totalExercises: totalExercises,
    );
  }

  Future<void> updateExerciseDone(
    String routineId,
    List<dynamic> exercises,
    String exerciseId,
    bool done,
  ) async {
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) {
        final plannedSetCount = workoutTotalSets(map);
        map['done'] = done;
        map['completedSets'] = done ? plannedSetCount : 0;
      }
      return map;
    }).toList();
    final summary = routineSetSummary(updated);
    await routinesRef.doc(routineId).update({
      'exercises': updated,
      'completedSets': summary.completedSets,
      'totalSets': summary.totalSets,
      'done': summary.completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<UnlockedAchievementData>> updateWorkoutChallenges({
    required String routineTitle,
  }) async {
    final challengeService = ChallengeService(gymId: gymId, userEmail: userEmail);
    final activeChallenges = await challengeService.challengesRef.where('active', isEqualTo: true).get();
    final stats = await challengeService.loadUserStats();

    await challengeService.completeEligibleChallenges(
      challenges: activeChallenges.docs,
      stats: stats,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
    );

    return achievementService.evaluateAndUnlock();
  }
}
