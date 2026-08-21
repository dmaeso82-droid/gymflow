import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PointsRules {
  static const int achievementUnlocked = 25;
  static const int manualTransformationShared = 15;
  static const int duelWon = 50;
  static const int challengeCompleted = 75;
  static const int workoutCompleted = 10;
  static const int weeklyRoutineCompleted = 20;
}

class PrestigeLevel {
  final String badge;
  final String title;
  final int minPoints;
  const PrestigeLevel({required this.badge, required this.title, required this.minPoints});
  String get label => '$badge $title';
}

PrestigeLevel prestigeForPoints(int points) {
  if (points >= 10000) return const PrestigeLevel(badge: '👑', title: 'Leyenda', minPoints: 10000);
  if (points >= 5000) return const PrestigeLevel(badge: '💎', title: 'Diamante', minPoints: 5000);
  if (points >= 2500) return const PrestigeLevel(badge: '💠', title: 'Platino', minPoints: 2500);
  if (points >= 1000) return const PrestigeLevel(badge: '🥇', title: 'Oro', minPoints: 1000);
  if (points >= 500) return const PrestigeLevel(badge: '🥈', title: 'Plata', minPoints: 500);
  return const PrestigeLevel(badge: '🥉', title: 'Bronce', minPoints: 0);
}

class PrestigeTitle {
  final String badge;
  final String title;
  const PrestigeTitle({required this.badge, required this.title});
  String get label => '$badge $title';
}

PrestigeTitle titleForPoints(int points) {
  if (points >= 10000) return const PrestigeTitle(badge: '👑', title: 'Leyenda');
  if (points >= 5000) return const PrestigeTitle(badge: '💎', title: 'Atleta Diamante');
  if (points >= 2500) return const PrestigeTitle(badge: '💠', title: 'Atleta Élite');
  if (points >= 1000) return const PrestigeTitle(badge: '🥇', title: 'Veterano');
  if (points >= 500) return const PrestigeTitle(badge: '🥈', title: 'Competidor');
  return const PrestigeTitle(badge: '🥉', title: 'Promesa');
}

PrestigeTitle prestigeTitleForStats({
  required int points,
  int bestStreak = 0,
  int duelWins = 0,
  int challengesCompleted = 0,
  int achievements = 0,
  int transformations = 0,
}) {
  if (duelWins >= 10) return const PrestigeTitle(badge: '🥊', title: 'Campeón');
  if (challengesCompleted >= 10) return const PrestigeTitle(badge: '🎯', title: 'Conquistador');
  if (bestStreak >= 30) return const PrestigeTitle(badge: '🔥', title: 'Imparable');
  if (transformations >= 3) return const PrestigeTitle(badge: '📸', title: 'Transformador');
  if (achievements >= 10) return const PrestigeTitle(badge: '🏅', title: 'Coleccionista');
  return titleForPoints(points);
}

class PointsService {
  final String gymId;
  const PointsService({required this.gymId});

  CollectionReference<Map<String, dynamic>> get leaderboardRef => FirebaseFirestore.instance
      .collection('gyms').doc(gymId).collection('leaderboard');

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String userDocId({required String userId, required String userEmail}) => userId.trim();

  Future<int> leaderboardPosition({required String userKey, required String field}) async {
    final cleanUserKey = userKey.trim();
    if (cleanUserKey.isEmpty) return 0;
    const allowedFields = {'monthlyPoints', 'yearlyPoints', 'allTimePoints'};
    if (!allowedFields.contains(field)) {
      throw ArgumentError('El campo de ranking no es válido.');
    }
    final userDoc = await leaderboardRef.doc(cleanUserKey).get();
    final userData = userDoc.data();
    if (userData == null) return 0;
    final userPoints = intValue(userData[field]);
    final ahead = await leaderboardRef.where(field, isGreaterThan: userPoints).count().get();
    return (ahead.count ?? 0) + 1;
  }

  Future<bool> awardPoints({
    required String userId,
    required String userName,
    required String userEmail,
    required int points,
    required String sourceType,
    required String sourceId,
    Map<String, dynamic>? metadata,
  }) async {
    if (gymId.trim().isEmpty || points <= 0 || sourceType.trim().isEmpty || sourceId.trim().isEmpty) {
      return false;
    }
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('awardPointsSecure');
    final result = await callable.call(<String, dynamic>{
      'gymId': gymId,
      'points': points,
      'sourceType': sourceType.trim(),
      'sourceId': sourceId.trim(),
      'metadata': metadata ?? <String, dynamic>{},
    });
    final data = result.data;
    if (data is! Map) throw StateError('Respuesta inválida al conceder puntos.');
    return data['awarded'] == true;
  }
}
