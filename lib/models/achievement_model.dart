import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory UnlockedAchievementData.fromDefinition({
    required AchievementDefinitionData definition,
    required int current,
  }) {
    return UnlockedAchievementData(
      id: definition.id,
      title: definition.title,
      description: definition.description,
      metric: definition.metric,
      target: definition.target,
      current: current,
      iconKey: definition.iconKey,
    );
  }

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

  Map<String, dynamic> toUnlockMap({
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    return {
      'achievementId': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail.toLowerCase(),
      'title': title,
      'description': description,
      'metric': metric,
      'target': target,
      'current': current,
      'iconKey': iconKey,
      'unlockedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toCommunityPostMap({
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    return {
      'type': 'achievement_unlocked',
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail.toLowerCase(),
      'title': 'Logro desbloqueado',
      'message': '$userName ha conseguido el logro "$title" en GymFlow.',
      'achievementId': id,
      'achievementTitle': title,
      'achievementDescription': description,
      'achievementMetric': metric,
      'achievementTarget': target,
      'achievementCurrent': current,
      'likes': [],
      'likeUsers': {},
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

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

class AchievementStatsAccumulator {
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> logsById = {};
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> photosById = {};
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> transformationsById = {};

  void addLogs(QuerySnapshot<Map<String, dynamic>>? snapshot) {
    if (snapshot == null) return;
    for (final doc in snapshot.docs) {
      logsById[doc.id] = doc;
    }
  }

  void addPhotos(QuerySnapshot<Map<String, dynamic>>? snapshot) {
    if (snapshot == null) return;
    for (final doc in snapshot.docs) {
      photosById[doc.id] = doc;
    }
  }

  void addTransformations(QuerySnapshot<Map<String, dynamic>>? snapshot) {
    if (snapshot == null) return;
    for (final doc in snapshot.docs) {
      transformationsById[doc.id] = doc;
    }
  }

  AchievementStats build() {
    final workoutKeys = <String>{};
    final trainingDays = <DateTime>{};
    final exerciseNames = <String>{};
    double totalVolume = 0;

    for (final log in logsById.values) {
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

    return AchievementStats(
      workouts: workoutKeys.length,
      series: logsById.length,
      volume: totalVolume.round(),
      streak: calculateOpenDayStreak(trainingDays),
      exercises: exerciseNames.length,
      photos: photosById.length,
      transformations: transformationsById.length,
    );
  }
}

class AchievementUnlockContext {
  final String userId;
  final String userName;
  final String userEmail;

  const AchievementUnlockContext({
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  bool get hasIdentity => userId.trim().isNotEmpty || userEmail.trim().isNotEmpty;

  String unlockedDocId(String achievementId) {
    final normalizedUserId = userId.trim();
    final normalizedEmail = userEmail.trim().toLowerCase();
    final userKey = normalizedUserId.isNotEmpty ? normalizedUserId : normalizedEmail.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${userKey}_$achievementId';
  }

  bool matchesUser(Map<String, dynamic> data) {
    final storedUserId = data['userId']?.toString() ?? '';
    final storedEmail = (data['userEmail'] ?? '').toString().toLowerCase();
    final normalizedEmail = userEmail.toLowerCase();
    final normalizedUserId = userId.trim();
    return (normalizedUserId.isNotEmpty && storedUserId == normalizedUserId) ||
        (normalizedEmail.isNotEmpty && storedEmail == normalizedEmail);
  }
}

const automaticAchievementDefinitions = [
  AchievementDefinitionData(
    id: 'first_workout',
    title: 'Primer entrenamiento',
    description: 'Completa tu primer entrenamiento en GymFlow.',
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
