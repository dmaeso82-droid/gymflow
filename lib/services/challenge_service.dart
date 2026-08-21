import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/challenge_model.dart' as challenge_models;
import '../models/challenge_model.dart';
import 'stats_service.dart';
export '../models/challenge_model.dart'
    hide challengeTypeLabel, challengeUnit, challengeIcon, formatCompact, formatDate, userDocId;

class ChallengeService {
  final String gymId;
  final String userEmail;

  const ChallengeService({required this.gymId, required this.userEmail});

  CollectionReference<Map<String, dynamic>> get challengesRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('challenges');
  CollectionReference<Map<String, dynamic>> get goalsRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('goals');
  CollectionReference<Map<String, dynamic>> get measurementsRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('body_measurements');
  StatsService get statsService => StatsService(gymId: gymId);

  int intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  String formatCompact(num value) => challenge_models.formatCompact(value);
  String formatDate(dynamic value) => challenge_models.formatDate(value);
  String challengeTypeLabel(String type) => challenge_models.challengeTypeLabel(type);
  String challengeUnit(String type) => challenge_models.challengeUnit(type);
  IconData challengeIcon(String type) => challenge_models.challengeIcon(type);

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
    final openDays = days
        .map((day) => DateTime(day.year, day.month, day.day))
        .where((day) => !isClosedDay(day))
        .toSet();
    if (openDays.isEmpty) return 0;

    var current = DateTime.now();
    current = DateTime(current.year, current.month, current.day);
    while (isClosedDay(current)) {
      current = previousOpenDay(current);
    }

    if (!openDays.contains(current)) {
      final previous = previousOpenDay(current);
      if (!openDays.contains(previous)) return 0;
      current = previous;
    }

    var streak = 0;
    while (openDays.contains(current)) {
      streak++;
      current = previousOpenDay(current);
    }
    return streak;
  }

  double progressForType(ChallengeStats stats, String type) =>
      stats.progressForType(type);
  double targetValue(dynamic value) => ChallengeModel.targetValue(value);
  String userDocId({required String userId, required String userEmail}) => userId.trim();
  double challengeProgress(Map<String, dynamic> data, ChallengeStats stats) =>
      ChallengeModel.fromMap(data).progress(stats);

  Future<ChallengeStats> loadUserStats() async {
    final normalizedEmail = userEmail.trim().toLowerCase();
    final precomputed = await statsService.loadUserStats(
      userId: '',
      userEmail: normalizedEmail,
    );

    final goalsSnapshot = normalizedEmail.isEmpty
        ? null
        : await goalsRef
            .where('clientEmail', isEqualTo: normalizedEmail)
            .get();
    final completedGoals = goalsSnapshot?.docs
            .where((doc) => doc.data()['completed'] == true)
            .length ??
        0;

    final measurementsSnapshot = normalizedEmail.isEmpty
        ? null
        : await measurementsRef
            .where('userEmail', isEqualTo: normalizedEmail)
            .get();

    if (precomputed == null) {
      return ChallengeStats(
        workouts: 0,
        series: 0,
        volume: 0,
        streak: 0,
        completedGoals: completedGoals,
        measurements: measurementsSnapshot?.docs.length ?? 0,
      );
    }

    return ChallengeStats(
      workouts: precomputed.workouts,
      series: precomputed.series,
      volume: precomputed.volume,
      streak: precomputed.currentStreak,
      completedGoals: completedGoals,
      measurements: measurementsSnapshot?.docs.length ?? 0,
    );
  }

  Future<void> completeEligibleChallenges({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> challenges,
    required ChallengeStats stats,
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    if (gymId.trim().isEmpty) {
      throw StateError('No se ha podido identificar el gimnasio.');
    }
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('completeChallengesSecure');
    await callable.call(<String, dynamic>{'gymId': gymId});
  }

  Future<void> createChallenge({
    required String title,
    required String description,
    required String type,
    required double target,
  }) async {
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanType = type.trim();
    if (cleanTitle.isEmpty || cleanType.isEmpty || target <= 0 || !target.isFinite) {
      throw ArgumentError('El título, el tipo y un objetivo válido son obligatorios.');
    }
    await challengesRef.add(
      ChallengeModel(
        title: cleanTitle,
        description: cleanDescription,
        type: cleanType,
        target: target,
        active: true,
      ).toCreateMap(),
    );
  }

  Future<void> toggleChallengeActive(String challengeId, bool active) =>
      challengesRef.doc(challengeId).update({
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteChallenge(String challengeId) =>
      challengesRef.doc(challengeId).delete();
}
