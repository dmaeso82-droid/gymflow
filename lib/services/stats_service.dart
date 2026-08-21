import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_stats_model.dart';
import 'points_service.dart';

class UserStatsSnapshot extends UserStatsModel {
  const UserStatsSnapshot({required super.userId, required super.userName, required super.userEmail, required super.series, required super.reps, required super.volume, required super.workouts, required super.exerciseCount, required super.recordCount, required super.currentStreak, required super.bestStreak, required super.photos, required super.transformations, required super.points, required super.raw});
  factory UserStatsSnapshot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => UserStatsSnapshot.fromModel(UserStatsModel.fromDoc(doc));
  factory UserStatsSnapshot.fromModel(UserStatsModel model) => UserStatsSnapshot(userId: model.userId, userName: model.userName, userEmail: model.userEmail, series: model.series, reps: model.reps, volume: model.volume, workouts: model.workouts, exerciseCount: model.exerciseCount, recordCount: model.recordCount, currentStreak: model.currentStreak, bestStreak: model.bestStreak, photos: model.photos, transformations: model.transformations, points: model.points, raw: model.raw);
}

class StatsService {
  final String gymId;
  const StatsService({required this.gymId});

  CollectionReference<Map<String, dynamic>> get userStatsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('user_stats');
  CollectionReference<Map<String, dynamic>> get rankingStatsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('ranking_stats');
  String statsDocId({required String userId, required String userEmail}) => userId.trim();
  DateTime startOfWeek(DateTime date) => UserStatsModel.startOfWeek(date);
  String weekKey([DateTime? date]) => UserStatsModel.weekKey(date);
  String dayKey([DateTime? date]) => UserStatsModel.dayKey(date);

  Future<UserStatsSnapshot?> loadUserStats({required String userId, required String userEmail}) async {
    final uid = userId.trim();
    if (uid.isNotEmpty) {
      final snapshot = await userStatsRef.doc(uid).get();
      if (snapshot.exists && snapshot.data() != null) return UserStatsSnapshot.fromDoc(snapshot);
    }
    final normalizedEmail = userEmail.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;
    final legacy = await userStatsRef.where('userEmail', isEqualTo: normalizedEmail).limit(1).get();
    return legacy.docs.isEmpty ? null : UserStatsSnapshot.fromDoc(legacy.docs.first);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStatsStream({required String userId, required String userEmail}) {
    final uid = userId.trim();
    if (uid.isNotEmpty) return userStatsRef.doc(uid).snapshots();
    final fallbackId = userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return userStatsRef.doc(fallbackId).snapshots();
  }

  Future<bool> recordWorkoutSet({
    required String userId,
    required String userName,
    required String userEmail,
    required String routineId,
    required String routineTitle,
    required String exerciseId,
    required String exerciseName,
    required double weight,
    required int reps,
    int setNumber = 1,
    int plannedSetCount = 0,
    DateTime? date,
  }) async {
    if (gymId.trim().isEmpty || routineId.trim().isEmpty || exerciseId.trim().isEmpty) {
      throw ArgumentError('El gimnasio, la rutina y el ejercicio son obligatorios.');
    }
    if (!weight.isFinite || weight < 0 || reps <= 0 || setNumber <= 0 || plannedSetCount < 0) {
      throw ArgumentError('Los valores de la serie no son válidos.');
    }
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('recordWorkoutSetSecure');
    final result = await callable.call(<String, dynamic>{
      'gymId': gymId,
      'routineId': routineId,
      'routineTitle': routineTitle,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'weight': weight,
      'reps': reps,
      'setNumber': setNumber,
      'plannedSetCount': plannedSetCount,
    });
    final data = result.data;
    if (data is! Map) throw StateError('Respuesta inválida al registrar la serie.');
    return data['created'] == true;
  }

  Future<void> addPoints({required String userId, required String userName, required String userEmail, required int points}) async {
    await PointsService(gymId: gymId).awardPoints(userId: userId, userName: userName, userEmail: userEmail, points: points, sourceType: 'legacy_stats_add_points', sourceId: '${userId}_${DateTime.now().microsecondsSinceEpoch}');
  }
}
