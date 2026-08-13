import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

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

  const PrestigeLevel({
    required this.badge,
    required this.title,
    required this.minPoints,
  });

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
  if (points >= 10000) return const PrestigeTitle(badge: '👑', title: 'Leyenda DalaiGym');
  if (points >= 5000) return const PrestigeTitle(badge: '💎', title: 'Atleta Diamante');
  if (points >= 2500) return const PrestigeTitle(badge: '💠', title: 'Atleta Elite');
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
      .collection('gyms')
      .doc(gymId)
      .collection('leaderboard');

  CollectionReference<Map<String, dynamic>> get pointsLedgerRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('points_ledger');

  CollectionReference<Map<String, dynamic>> get userStatsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('user_stats');

  CollectionReference<Map<String, dynamic>> get rankingStatsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('ranking_stats');

  String userDocId({required String userId, required String userEmail}) {
    if (userId.trim().isNotEmpty) return userId.trim();
    return userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  String monthKey([DateTime? value]) {
    final date = value ?? DateTime.now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String yearKey([DateTime? value]) {
    final date = value ?? DateTime.now();
    return date.year.toString();
  }

  String ledgerDocId({
    required String userId,
    required String userEmail,
    required String sourceType,
    required String sourceId,
  }) {
    final userKey = userDocId(userId: userId, userEmail: userEmail);
    final sourceKey = '${sourceType}_$sourceId'.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
    return '${userKey}_$sourceKey';
  }

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<int> leaderboardPosition({
    required String userKey,
    required String field,
  }) async {
    final snapshot = await leaderboardRef.get();
    final entries = snapshot.docs.where((doc) => intValue(doc.data()[field]) > 0).toList();
    entries.sort((a, b) => intValue(b.data()[field]).compareTo(intValue(a.data()[field])));
    final index = entries.indexWhere((doc) => doc.id == userKey);
    return index < 0 ? 0 : index + 1;
  }

  String rankingName(String field) {
    switch (field) {
      case 'monthlyPoints':
        return 'mensual';
      case 'yearlyPoints':
        return 'anual';
      case 'allTimePoints':
      default:
        return 'histórico';
    }
  }

  String rankingPeriodKey(String field) {
    switch (field) {
      case 'monthlyPoints':
        return monthKey();
      case 'yearlyPoints':
        return yearKey();
      case 'allTimePoints':
      default:
        return 'alltime';
    }
  }

  Future<void> notifyRankingMilestones({
    required String userId,
    required String userName,
    required String userEmail,
    required String userKey,
    required String sourceType,
    required String sourceId,
  }) async {
    final notifications = NotificationService(gymId: gymId);
    for (final field in ['monthlyPoints', 'yearlyPoints', 'allTimePoints']) {
      final position = await leaderboardPosition(userKey: userKey, field: field);
      if (position <= 0 || position > 10) continue;
      final ranking = rankingName(field);
      final period = rankingPeriodKey(field);
      late final String milestone;
      late final String title;
      late final String message;
      if (position == 1) {
        milestone = 'top1';
        title = '🥇 Nuevo #1 $ranking';
        message = 'Has alcanzado el puesto #1 del ranking $ranking de DalaiGym.';
      } else if (position <= 3) {
        milestone = 'top3';
        title = '🏆 Top 3 $ranking';
        message = 'Has entrado en el Top 3 del ranking $ranking. Ahora estás en el puesto #$position.';
      } else {
        milestone = 'top10';
        title = '📈 Top 10 $ranking';
        message = 'Has entrado en el Top 10 del ranking $ranking. Ahora estás en el puesto #$position.';
      }
      final markerId = '${userKey}_${field}_${period}_$milestone';
      await notifications.createNotificationOnce(
        markerId: markerId,
        userId: userId,
        userEmail: userEmail,
        type: 'ranking_${ranking}_$milestone',
        title: title,
        message: message,
        sourceId: sourceId,
        metadata: {
          'field': field,
          'ranking': ranking,
          'period': period,
          'position': position,
          'sourceType': sourceType,
          'sourceId': sourceId,
        },
      );
    }
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
    if (points <= 0) return false;
    final normalizedEmail = userEmail.trim().toLowerCase();
    final userKey = userDocId(userId: userId, userEmail: normalizedEmail);
    if (userKey.isEmpty) return false;

    final nowMonthKey = monthKey();
    final nowYearKey = yearKey();
    final leaderboardDoc = leaderboardRef.doc(userKey);
    final ledgerDoc = pointsLedgerRef.doc(ledgerDocId(
      userId: userId,
      userEmail: normalizedEmail,
      sourceType: sourceType,
      sourceId: sourceId,
    ));
    final userStatsDoc = userStatsRef.doc(userKey);
    final rankingStatsDoc = rankingStatsRef.doc(userKey);

    final awarded = await FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
      final existingLedger = await transaction.get(ledgerDoc);
      if (existingLedger.exists) return false;

      final leaderboardSnapshot = await transaction.get(leaderboardDoc);
      final currentData = leaderboardSnapshot.data() ?? <String, dynamic>{};
      final storedMonthKey = currentData['monthKey']?.toString() ?? '';
      final storedYearKey = currentData['yearKey']?.toString() ?? '';
      final monthlyBase = storedMonthKey == nowMonthKey ? intValue(currentData['monthlyPoints']) : 0;
      final yearlyBase = storedYearKey == nowYearKey ? intValue(currentData['yearlyPoints']) : 0;
      final allTimeBase = intValue(currentData['allTimePoints']);

      final common = {
        'userId': userId,
        'userName': userName,
        'userEmail': normalizedEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      transaction.set(ledgerDoc, {
        ...common,
        'points': points,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(leaderboardDoc, {
        ...common,
        'monthKey': nowMonthKey,
        'yearKey': nowYearKey,
        'monthlyPoints': monthlyBase + points,
        'yearlyPoints': yearlyBase + points,
        'allTimePoints': allTimeBase + points,
        'lastPointsSourceType': sourceType,
        'lastPointsSourceId': sourceId,
      }, SetOptions(merge: true));

      transaction.set(userStatsDoc, {
        ...common,
        'points': FieldValue.increment(points),
        'lastPointsSourceType': sourceType,
        'lastPointsSourceId': sourceId,
      }, SetOptions(merge: true));

      transaction.set(rankingStatsDoc, {
        ...common,
        'points': FieldValue.increment(points),
        'lastPointsSourceType': sourceType,
        'lastPointsSourceId': sourceId,
      }, SetOptions(merge: true));

      return true;
    });
    if (awarded) {
      await notifyRankingMilestones(
        userId: userId,
        userName: userName,
        userEmail: normalizedEmail,
        userKey: userKey,
        sourceType: sourceType,
        sourceId: sourceId,
      );
    }
    return awarded;
  }
}
