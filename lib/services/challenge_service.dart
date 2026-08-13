import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'stats_service.dart';
import 'notification_service.dart';
import 'points_service.dart';

class ChallengeStats {
  final int workouts;
  final int series;
  final double volume;
  final int streak;
  final int completedGoals;
  final int measurements;

  const ChallengeStats({
    required this.workouts,
    required this.series,
    required this.volume,
    required this.streak,
    required this.completedGoals,
    required this.measurements,
  });

  factory ChallengeStats.empty() => const ChallengeStats(
        workouts: 0,
        series: 0,
        volume: 0,
        streak: 0,
        completedGoals: 0,
        measurements: 0,
      );
}

class ChallengeService {
  final String gymId;
  final String userEmail;

  const ChallengeService({
    required this.gymId,
    required this.userEmail,
  });

  CollectionReference<Map<String, dynamic>> get challengesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('challenges');

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  CollectionReference<Map<String, dynamic>> get goalsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('goals');

  CollectionReference<Map<String, dynamic>> get challengeCompletionsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('challenge_completions');

  CollectionReference<Map<String, dynamic>> get communityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('community_posts');

  PointsService get pointsService => PointsService(gymId: gymId);

  StatsService get statsService => StatsService(gymId: gymId);

  CollectionReference<Map<String, dynamic>> get measurementsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('body_measurements');

  int intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  String formatCompact(num value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }
    return 'Fecha pendiente';
  }

  String challengeTypeLabel(String type) {
    switch (type) {
      case 'volume_total':
        return 'Volumen movido';
      case 'series_count':
        return 'Series completadas';
      case 'streak_days':
        return 'Racha de días';
      case 'goals_completed':
        return 'Objetivos completados';
      case 'measurements_count':
        return 'Mediciones registradas';
      case 'workout_count':
      default:
        return 'Entrenamientos completados';
    }
  }

  String challengeUnit(String type) {
    switch (type) {
      case 'volume_total':
        return 'kg';
      case 'series_count':
        return 'series';
      case 'streak_days':
        return 'días';
      case 'goals_completed':
        return 'objetivos';
      case 'measurements_count':
        return 'mediciones';
      case 'workout_count':
      default:
        return 'entrenamientos';
    }
  }

  IconData challengeIcon(String type) {
    switch (type) {
      case 'volume_total':
        return Icons.monitor_weight;
      case 'series_count':
        return Icons.format_list_numbered;
      case 'streak_days':
        return Icons.local_fire_department;
      case 'goals_completed':
        return Icons.flag_circle;
      case 'measurements_count':
        return Icons.straighten;
      case 'workout_count':
      default:
        return Icons.fitness_center;
    }
  }

  DateTime? dayFromTimestamp(dynamic value) {
    if (value is! Timestamp) return null;
    final date = value.toDate();
    return DateTime(date.year, date.month, date.day);
  }

  bool isClosedDay(DateTime day) => day.weekday == DateTime.sunday;

  DateTime previousOpenDay(DateTime day) {
    var candidate = day.subtract(const Duration(days: 1));
    while (isClosedDay(candidate)) {
      candidate = candidate.subtract(const Duration(days: 1));
    }
    return candidate;
  }

  int calculateStreak(Set<DateTime> days) {
    final openTrainingDays = days.where((day) => !isClosedDay(day)).toSet();
    if (openTrainingDays.isEmpty) return 0;

    var currentDay = DateTime.now();
    currentDay = DateTime(currentDay.year, currentDay.month, currentDay.day);
    while (isClosedDay(currentDay)) {
      currentDay = previousOpenDay(currentDay);
    }

    var streak = 0;
    if (!openTrainingDays.contains(currentDay)) {
      final previous = previousOpenDay(currentDay);
      if (openTrainingDays.contains(previous)) {
        currentDay = previous;
      } else {
        return 0;
      }
    }

    while (openTrainingDays.contains(currentDay)) {
      streak += 1;
      currentDay = previousOpenDay(currentDay);
    }
    return streak;
  }

  Future<ChallengeStats> loadUserStats() async {
    final normalizedEmail = userEmail.toLowerCase();
    final precomputed = await statsService.loadUserStats(userId: '', userEmail: normalizedEmail);
    if (precomputed != null && precomputed.series > 0) {
      final goalsSnapshot = await goalsRef.where('clientEmail', isEqualTo: normalizedEmail).get();
      final completedGoals = goalsSnapshot.docs.where((doc) => doc.data()['completed'] == true).length;
      final measurementsSnapshot = await measurementsRef.where('userEmail', isEqualTo: normalizedEmail).get();
      return ChallengeStats(
        workouts: precomputed.workouts,
        series: precomputed.series,
        volume: precomputed.volume,
        streak: precomputed.currentStreak,
        completedGoals: completedGoals,
        measurements: measurementsSnapshot.docs.length,
      );
    }
    final logsSnapshot = await logsRef.where('userEmail', isEqualTo: normalizedEmail).get();
    final logs = logsSnapshot.docs;

    final trainingDays = <DateTime>{};
    final workoutKeys = <String>{};
    double volume = 0;
    int series = 0;

    for (final doc in logs) {
      final data = doc.data();
      final weight = doubleValue(data['weight']);
      final reps = intValue(data['reps']);
      volume += weight * reps;
      series += 1;

      final day = dayFromTimestamp(data['createdAt']);
      if (day != null) {
        if (!isClosedDay(day)) trainingDays.add(day);
        final routineId = data['routineId']?.toString() ?? data['routineTitle']?.toString() ?? 'routine';
        workoutKeys.add('$routineId-${day.toIso8601String()}');
      }
    }

    final goalsSnapshot = await goalsRef.where('clientEmail', isEqualTo: normalizedEmail).get();
    final completedGoals = goalsSnapshot.docs.where((doc) => doc.data()['completed'] == true).length;

    final measurementsSnapshot = await measurementsRef.where('userEmail', isEqualTo: normalizedEmail).get();
    final measurementsCount = measurementsSnapshot.docs.length;

    return ChallengeStats(
      workouts: workoutKeys.length,
      series: series,
      volume: volume,
      streak: calculateStreak(trainingDays),
      completedGoals: completedGoals,
      measurements: measurementsCount,
    );
  }

  double progressForType(ChallengeStats stats, String type) {
    switch (type) {
      case 'volume_total':
        return stats.volume;
      case 'series_count':
        return stats.series.toDouble();
      case 'streak_days':
        return stats.streak.toDouble();
      case 'goals_completed':
        return stats.completedGoals.toDouble();
      case 'measurements_count':
        return stats.measurements.toDouble();
      case 'workout_count':
      default:
        return stats.workouts.toDouble();
    }
  }

  double targetValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  String userDocId({required String userId, required String userEmail}) {
    if (userId.trim().isNotEmpty) return userId.trim();
    return userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  double challengeProgress(Map<String, dynamic> data, ChallengeStats stats) {
    final type = data['type']?.toString() ?? 'workout_count';
    return progressForType(stats, type);
  }

  Future<void> completeEligibleChallenges({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> challenges,
    required ChallengeStats stats,
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    final normalizedEmail = userEmail.trim().toLowerCase();
    if (userId.trim().isEmpty && normalizedEmail.isEmpty) return;
    final userKey = userDocId(userId: userId, userEmail: normalizedEmail);
    final notificationService = NotificationService(gymId: gymId);

    for (final challenge in challenges) {
      final data = challenge.data();
      if (data['active'] == false) continue;
      final target = targetValue(data['target']);
      if (target <= 0) continue;
      final progress = challengeProgress(data, stats);
      if (progress < target) continue;

      final completionId = '${userKey}_${challenge.id}';
      final completionRef = challengeCompletionsRef.doc(completionId);
      final existing = await completionRef.get();
      if (existing.exists) continue;

      final title = data['title']?.toString() ?? 'Reto completado';
      final type = data['type']?.toString() ?? 'workout_count';
      final unit = challengeUnit(type);
      final progressLabel = '${formatCompact(progress)} / ${formatCompact(target)} $unit';

      await completionRef.set({
        'challengeId': challenge.id,
        'challengeTitle': title,
        'challengeType': type,
        'target': target,
        'progress': progress,
        'progressLabel': progressLabel,
        'userId': userId,
        'userName': userName,
        'userEmail': normalizedEmail,
        'points': PointsRules.challengeCompleted,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await communityRef.add({
        'type': 'challenge_completed',
        'userId': userId,
        'userName': userName,
        'userEmail': normalizedEmail,
        'title': 'Reto completado',
        'message': '$userName ha completado el reto "$title" en DalaiGym.',
        'challengeId': challenge.id,
        'challengeTitle': title,
        'challengeType': type,
        'progressLabel': progressLabel,
        'points': PointsRules.challengeCompleted,
        'likes': [],
        'likeUsers': {},
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await notificationService.createNotification(
        userId: userId,
        userEmail: normalizedEmail,
        type: 'challenge_completed',
        title: 'Reto completado',
        message: 'Has completado "$title" y sumas ${PointsRules.challengeCompleted} puntos.',
        sourceId: challenge.id,
        metadata: {
          'challengeId': challenge.id,
          'challengeTitle': title,
          'challengeType': type,
          'progress': progress,
          'target': target,
          'points': PointsRules.challengeCompleted,
        },
      );

      await pointsService.awardPoints(
        userId: userId,
        userName: userName,
        userEmail: normalizedEmail,
        points: PointsRules.challengeCompleted,
        sourceType: 'challenge_completed',
        sourceId: challenge.id,
        metadata: {
          'challengeId': challenge.id,
          'challengeTitle': title,
          'challengeType': type,
          'progress': progress,
          'target': target,
        },
      );
    }
  }

  Future<void> createChallenge({
    required String title,
    required String description,
    required String type,
    required double target,
  }) async {
    await challengesRef.add({
      'title': title,
      'description': description,
      'type': type,
      'target': target,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleChallengeActive(String challengeId, bool active) async {
    await challengesRef.doc(challengeId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteChallenge(String challengeId) async {
    await challengesRef.doc(challengeId).delete();
  }
}



