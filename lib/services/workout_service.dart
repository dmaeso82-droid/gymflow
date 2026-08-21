import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_log_model.dart';
import '../utils/workout_utils.dart';
import 'achievement_service.dart';
import 'challenge_service.dart';
import 'stats_service.dart';

class WorkoutProgressResult {
  final bool routineCompleted;
  final int totalCompletedSets;
  final int totalPlannedSets;
  final int totalExercises;
  const WorkoutProgressResult({required this.routineCompleted, required this.totalCompletedSets, required this.totalPlannedSets, required this.totalExercises});
}

class WorkoutService {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  const WorkoutService({required this.gymId, required this.userId, required this.userName, required this.userEmail});

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('routines');
  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('workout_logs');
  CollectionReference<Map<String, dynamic>> get communityRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('community_posts');
  CollectionReference<Map<String, dynamic>> get challengesRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('challenges');
  StatsService get statsService => StatsService(gymId: gymId);
  AchievementService get achievementService => AchievementService(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail);

  bool isActiveRoutine(Map<String, dynamic> data) => (data['status'] ?? 'active').toString() != 'archived';
  DateTime startOfWeek(DateTime date) { final clean = DateTime(date.year, date.month, date.day); return clean.subtract(Duration(days: clean.weekday - DateTime.monday)); }
  String currentWeekKey() { final weekStart = startOfWeek(DateTime.now()); return '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}'; }
  Map<String, dynamic> resetExerciseForNewWeek(Map<String, dynamic> exercise) => {...exercise, 'done': false, 'completedSets': 0};
  bool routineNeedsWeeklyReset(Map<String, dynamic> data) {
    if (!isActiveRoutine(data) || data['lastResetWeek']?.toString() == currentWeekKey()) return false;
    final exercises = List<dynamic>.from(data['exercises'] ?? []);
    if (exercises.isEmpty) return false;
    return exercises.whereType<Map>().any((item) { final exercise = Map<String, dynamic>.from(item); return exercise['done'] == true || workoutCompletedSets(exercise) > 0; }) || (data['lastResetWeek']?.toString().isEmpty ?? true);
  }
  Future<bool> resetRoutineForCurrentWeekIfNeeded(QueryDocumentSnapshot<Map<String, dynamic>> routineDoc) async {
    final data = routineDoc.data();
    if (!routineNeedsWeeklyReset(data)) return false;
    final resetExercises = List<dynamic>.from(data['exercises'] ?? []).whereType<Map>().map((item) => resetExerciseForNewWeek(Map<String, dynamic>.from(item))).toList();
    final summary = routineSetSummary(resetExercises);
    await routineDoc.reference.update({'exercises': resetExercises, 'completedSets': 0, 'totalSets': summary.totalSets, 'done': false, 'lastResetWeek': currentWeekKey(), 'lastWeeklyResetAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    return true;
  }
  Future<bool> resetRoutinesForCurrentWeekIfNeeded(List<QueryDocumentSnapshot<Map<String, dynamic>>> routineDocs) async { var changed = false; for (final doc in routineDocs) { changed = await resetRoutineForCurrentWeekIfNeeded(doc) || changed; } return changed; }

  Future<List<UnlockedAchievementData>> saveWorkoutLog({required String routineId, required String routineTitle, required Map<String, dynamic> exercise, required double weight, required int reps, required int setNumber, required int plannedSetCount}) async {
    final log = WorkoutLogModel.fromExercise(userId: userId, userName: userName, userEmail: userEmail, routineId: routineId, routineTitle: routineTitle, exercise: exercise, weight: weight, reps: reps, setNumber: setNumber, plannedSetCount: plannedSetCount);
    final created = await statsService.recordWorkoutSet(userId: userId, userName: userName, userEmail: userEmail, routineId: routineId, routineTitle: routineTitle, exerciseId: log.exerciseId, exerciseName: log.exercise, weight: log.weight, reps: log.reps, setNumber: setNumber, plannedSetCount: plannedSetCount);
    if (!created) return const <UnlockedAchievementData>[];
    return achievementService.evaluateAndUnlock();
  }

  Future<void> shareAchievementToCommunity(UnlockedAchievementData achievement) => achievementService.shareAchievementToCommunity(achievement);

  Future<WorkoutProgressResult> updateExerciseSetProgress(String routineId, List<dynamic> exercises, String exerciseId) async {
    int completed = 0, planned = 0, totalExercises = 0;
    final updated = <Map<String, dynamic>>[];
    for (final item in exercises) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item); final target = workoutTotalSets(map); var doneSets = workoutCompletedSets(map);
      if (map['id'] == exerciseId) { doneSets = (doneSets + 1).clamp(0, target).toInt(); map['completedSets'] = doneSets; map['done'] = doneSets >= target; }
      totalExercises++; planned += target; completed += doneSets.clamp(0, target).toInt(); updated.add(map);
    }
    final done = planned > 0 && completed >= planned;
    await routinesRef.doc(routineId).update({'exercises': updated, 'completedSets': completed, 'totalSets': planned, 'done': done, 'updatedAt': FieldValue.serverTimestamp()});
    return WorkoutProgressResult(routineCompleted: done, totalCompletedSets: completed, totalPlannedSets: planned, totalExercises: totalExercises);
  }

  Future<void> updateExerciseDone(String routineId, List<dynamic> exercises, String exerciseId, bool done) async {
    final updated = <Map<String, dynamic>>[];
    for (final item in exercises) { if (item is! Map) continue; final map = Map<String, dynamic>.from(item); if (map['id'] == exerciseId) { final count = workoutTotalSets(map); map['done'] = done; map['completedSets'] = done ? count : 0; } updated.add(map); }
    final summary = routineSetSummary(updated);
    await routinesRef.doc(routineId).update({'exercises': updated, 'completedSets': summary.completedSets, 'totalSets': summary.totalSets, 'done': summary.completed, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<List<UnlockedAchievementData>> updateWorkoutChallenges({required String routineTitle}) async {
    final service = ChallengeService(gymId: gymId, userEmail: userEmail);
    final active = await service.challengesRef.where('active', isEqualTo: true).get();
    final stats = await service.loadUserStats();
    await service.completeEligibleChallenges(challenges: active.docs, stats: stats, userId: userId, userName: userName, userEmail: userEmail);
    return achievementService.evaluateAndUnlock();
  }
}
