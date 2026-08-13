import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';
import 'stats_service.dart';
import 'points_service.dart';
import '../utils/workout_utils.dart';

class AchievementDefinitionData {
  final String id;
  final String title;
  final String description;
  final String metric;
  final int target;
  final String iconKey;

  const AchievementDefinitionData({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.iconKey,
  });
}

class UnlockedAchievementData {
  final String id;
  final String title;
  final String description;
  final String metric;
  final int target;
  final int current;
  final String iconKey;

  const UnlockedAchievementData({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.current,
    required this.iconKey,
  });

  Map<String, dynamic> toMetadata() {
    return {
      'achievementId': id,
      'title': title,
      'description': description,
      'metric': metric,
      'target': target,
      'current': current,
      'iconKey': iconKey,
    };
  }
}

const automaticAchievementDefinitions = [
  AchievementDefinitionData(
    id: 'first_workout',
    title: 'Primer entrenamiento',
    description: 'Completa tu primer entrenamiento en DalaiGym.',
    metric: 'workouts',
    target: 1,
    iconKey: 'workout',
  ),
  AchievementDefinitionData(
    id: 'workouts_10',
    title: '10 entrenamientos',
    description: 'Completa 10 entrenamientos.',
    metric: 'workouts',
    target: 10,
    iconKey: 'workout',
  ),
  AchievementDefinitionData(
    id: 'workouts_50',
    title: '50 entrenamientos',
    description: 'Completa 50 entrenamientos.',
    metric: 'workouts',
    target: 50,
    iconKey: 'trophy',
  ),
  AchievementDefinitionData(
    id: 'workouts_100',
    title: '100 entrenamientos',
    description: 'Completa 100 entrenamientos.',
    metric: 'workouts',
    target: 100,
    iconKey: 'trophy',
  ),
  AchievementDefinitionData(
    id: 'series_10',
    title: '10 series registradas',
    description: 'Registra 10 series de entrenamiento.',
    metric: 'series',
    target: 10,
    iconKey: 'series',
  ),
  AchievementDefinitionData(
    id: 'series_50',
    title: '50 series registradas',
    description: 'Registra 50 series de entrenamiento.',
    metric: 'series',
    target: 50,
    iconKey: 'series',
  ),
  AchievementDefinitionData(
    id: 'series_100',
    title: '100 series registradas',
    description: 'Registra 100 series de entrenamiento.',
    metric: 'series',
    target: 100,
    iconKey: 'series',
  ),
  AchievementDefinitionData(
    id: 'volume_10000',
    title: '10.000 kg movidos',
    description: 'Acumula 10.000 kg de volumen total.',
    metric: 'volume',
    target: 10000,
    iconKey: 'volume',
  ),
  AchievementDefinitionData(
    id: 'volume_50000',
    title: '50.000 kg movidos',
    description: 'Acumula 50.000 kg de volumen total.',
    metric: 'volume',
    target: 50000,
    iconKey: 'volume',
  ),
  AchievementDefinitionData(
    id: 'volume_100000',
    title: '100.000 kg movidos',
    description: 'Acumula 100.000 kg de volumen total.',
    metric: 'volume',
    target: 100000,
    iconKey: 'volume',
  ),
  AchievementDefinitionData(
    id: 'streak_7',
    title: 'Racha de 7 días',
    description: 'Entrena durante 7 días de apertura seguidos.',
    metric: 'streak',
    target: 7,
    iconKey: 'streak',
  ),
  AchievementDefinitionData(
    id: 'streak_30',
    title: 'Racha de 30 días',
    description: 'Entrena durante 30 días de apertura seguidos.',
    metric: 'streak',
    target: 30,
    iconKey: 'streak',
  ),
  AchievementDefinitionData(
    id: 'exercises_10',
    title: '10 ejercicios diferentes',
    description: 'Registra marcas en 10 ejercicios diferentes.',
    metric: 'exercises',
    target: 10,
    iconKey: 'exercise',
  ),
  AchievementDefinitionData(
    id: 'first_progress_photo',
    title: 'Primera foto de progreso',
    description: 'Sube tu primera foto de progreso físico.',
    metric: 'photos',
    target: 1,
    iconKey: 'photo',
  ),
  AchievementDefinitionData(
    id: 'progress_photos_10',
    title: '10 fotos de progreso',
    description: 'Sube 10 fotos de progreso físico.',
    metric: 'photos',
    target: 10,
    iconKey: 'photo',
  ),
  AchievementDefinitionData(
    id: 'progress_photos_25',
    title: '25 fotos de progreso',
    description: 'Sube 25 fotos de progreso físico.',
    metric: 'photos',
    target: 25,
    iconKey: 'photo',
  ),
  AchievementDefinitionData(
    id: 'first_transformation_shared',
    title: 'Primera transformación compartida',
    description: 'Comparte tu primera transformación en Comunidad.',
    metric: 'transformations',
    target: 1,
    iconKey: 'transformation',
  ),
  AchievementDefinitionData(
    id: 'transformations_3',
    title: '3 transformaciones compartidas',
    description: 'Comparte 3 transformaciones en Comunidad.',
    metric: 'transformations',
    target: 3,
    iconKey: 'transformation',
  ),
  AchievementDefinitionData(
    id: 'transformations_10',
    title: '10 transformaciones compartidas',
    description: 'Comparte 10 transformaciones en Comunidad.',
    metric: 'transformations',
    target: 10,
    iconKey: 'transformation',
  ),
];

class AchievementStats {
  final int workouts;
  final int series;
  final int volume;
  final int streak;
  final int exercises;
  final int photos;
  final int transformations;

  const AchievementStats({
    required this.workouts,
    required this.series,
    required this.volume,
    required this.streak,
    required this.exercises,
    this.photos = 0,
    this.transformations = 0,
  });

  int valueFor(String metric) {
    switch (metric) {
      case 'workouts':
        return workouts;
      case 'series':
        return series;
      case 'volume':
        return volume;
      case 'streak':
        return streak;
      case 'exercises':
        return exercises;
      case 'photos':
        return photos;
      case 'transformations':
        return transformations;
      default:
        return 0;
    }
  }
}

class AchievementService {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const AchievementService({
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  CollectionReference<Map<String, dynamic>> get unlockedRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('user_achievements');

  CollectionReference<Map<String, dynamic>> get photosRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('progress_photos');

  StatsService get statsService => StatsService(gymId: gymId);
  PointsService get pointsService => PointsService(gymId: gymId);

  CollectionReference<Map<String, dynamic>> get communityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('community_posts');

  bool matchesUser(Map<String, dynamic> data) {
    final storedUserId = data['userId']?.toString() ?? '';
    final storedEmail = (data['userEmail'] ?? '').toString().toLowerCase();
    final normalizedEmail = userEmail.toLowerCase();
    return (userId.isNotEmpty && storedUserId == userId) ||
        (normalizedEmail.isNotEmpty && storedEmail == normalizedEmail);
  }

  Future<AchievementStats> loadStats() async {
    final precomputed = await statsService.loadUserStats(userId: userId, userEmail: userEmail);
    if (precomputed != null && precomputed.series > 0) {
      return AchievementStats(
        workouts: precomputed.workouts,
        series: precomputed.series,
        volume: precomputed.volume.round(),
        streak: precomputed.currentStreak,
        exercises: precomputed.exerciseCount,
        photos: precomputed.photos,
        transformations: precomputed.transformations,
      );
    }
    final normalizedEmail = userEmail.toLowerCase();
    final byUserId = userId.isNotEmpty ? await logsRef.where('userId', isEqualTo: userId).get() : null;
    final byEmail = normalizedEmail.isNotEmpty ? await logsRef.where('userEmail', isEqualTo: normalizedEmail).get() : null;
    final photosByUserId = userId.isNotEmpty ? await photosRef.where('userId', isEqualTo: userId).get() : null;
    final photosByEmail = normalizedEmail.isNotEmpty ? await photosRef.where('userEmail', isEqualTo: normalizedEmail).get() : null;
    final transformationsByUserId = userId.isNotEmpty
        ? await communityRef.where('type', isEqualTo: 'transformation_post').where('userId', isEqualTo: userId).get()
        : null;
    final transformationsByEmail = normalizedEmail.isNotEmpty
        ? await communityRef.where('type', isEqualTo: 'transformation_post').where('userEmail', isEqualTo: normalizedEmail).get()
        : null;

    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    if (byUserId != null) {
      for (final doc in byUserId.docs) {
        docsById[doc.id] = doc;
      }
    }
    if (byEmail != null) {
      for (final doc in byEmail.docs) {
        docsById[doc.id] = doc;
      }
    }
    final logs = docsById.values.toList();
    final workoutKeys = <String>{};
    final trainingDays = <DateTime>{};
    final exerciseNames = <String>{};
    double totalVolume = 0;

    for (final log in logs) {
      final data = log.data();
      final weight = workoutDoubleValue(data['weight']);
      final reps = workoutIntValue(data['reps']);
      totalVolume += weight * reps;

      final exercise = data['exercise']?.toString().trim() ?? '';
      if (exercise.isNotEmpty) exerciseNames.add(exercise);

      final day = dayFromTimestamp(data['createdAt']);
      if (day != null) {
        if (!isClosedTrainingDay(day)) trainingDays.add(day);
        final routineKey = data['routineId']?.toString() ?? data['routineTitle']?.toString() ?? 'routine';
        workoutKeys.add('$routineKey-${day.toIso8601String()}');
      }
    }

    final photoDocsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    if (photosByUserId != null) {
      for (final doc in photosByUserId.docs) {
        photoDocsById[doc.id] = doc;
      }
    }
    if (photosByEmail != null) {
      for (final doc in photosByEmail.docs) {
        photoDocsById[doc.id] = doc;
      }
    }
    final transformationDocsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    if (transformationsByUserId != null) {
      for (final doc in transformationsByUserId.docs) {
        transformationDocsById[doc.id] = doc;
      }
    }
    if (transformationsByEmail != null) {
      for (final doc in transformationsByEmail.docs) {
        transformationDocsById[doc.id] = doc;
      }
    }
    final photos = photoDocsById.length;
    final transformations = transformationDocsById.length;

    return AchievementStats(
      workouts: workoutKeys.length,
      series: logs.length,
      volume: totalVolume.round(),
      streak: calculateOpenDayStreak(trainingDays),
      exercises: exerciseNames.length,
      photos: photos,
      transformations: transformations,
    );
  }

  String unlockedDocId(String achievementId) {
    final userKey = userId.isNotEmpty ? userId : userEmail.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${userKey}_$achievementId';
  }

  Future<List<UnlockedAchievementData>> evaluateAndUnlock({Set<String>? metrics}) async {
    if (userId.trim().isEmpty && userEmail.trim().isEmpty) return [];
    final stats = await loadStats();
    final notificationService = NotificationService(gymId: gymId);
    final newlyUnlocked = <UnlockedAchievementData>[];

    for (final achievement in automaticAchievementDefinitions) {
      if (metrics != null && !metrics.contains(achievement.metric)) continue;
      final current = stats.valueFor(achievement.metric);
      if (current < achievement.target) continue;

      final unlockedDoc = unlockedRef.doc(unlockedDocId(achievement.id));
      final snapshot = await unlockedDoc.get();
      if (snapshot.exists) continue;

      final unlocked = UnlockedAchievementData(
        id: achievement.id,
        title: achievement.title,
        description: achievement.description,
        metric: achievement.metric,
        target: achievement.target,
        current: current,
        iconKey: achievement.iconKey,
      );

      await unlockedDoc.set({
        'achievementId': achievement.id,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail.toLowerCase(),
        'title': achievement.title,
        'description': achievement.description,
        'metric': achievement.metric,
        'target': achievement.target,
        'current': current,
        'iconKey': achievement.iconKey,
        'unlockedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await notificationService.createNotification(
        userId: userId,
        userEmail: userEmail,
        type: 'achievement_unlocked',
        title: 'Logro desbloqueado',
        message: '${achievement.title} conseguido.',
        sourceId: achievement.id,
        metadata: unlocked.toMetadata(),
      );

      await pointsService.awardPoints(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        points: PointsRules.achievementUnlocked,
        sourceType: 'achievement_unlocked',
        sourceId: achievement.id,
        metadata: unlocked.toMetadata(),
      );

      newlyUnlocked.add(unlocked);
    }

    return newlyUnlocked;
  }

  Future<List<UnlockedAchievementData>> evaluatePhotoAchievements() {
    return evaluateAndUnlock(metrics: {'photos'});
  }

  Future<List<UnlockedAchievementData>> evaluateTransformationAchievements() {
    return evaluateAndUnlock(metrics: {'transformations'});
  }

  Future<void> shareAchievementToCommunity(UnlockedAchievementData achievement) async {
    await communityRef.add({
      'type': 'achievement_unlocked',
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail.toLowerCase(),
      'title': 'Logro desbloqueado',
      'message': '$userName ha conseguido el logro "${achievement.title}" en DalaiGym.',
      'achievementId': achievement.id,
      'achievementTitle': achievement.title,
      'achievementDescription': achievement.description,
      'achievementMetric': achievement.metric,
      'achievementTarget': achievement.target,
      'achievementCurrent': achievement.current,
      'likes': [],
      'likeUsers': {},
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}



