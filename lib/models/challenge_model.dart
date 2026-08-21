import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/workout_utils.dart';
import '../services/points_service.dart';

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

  double progressForType(String type) {
    switch (type) {
      case 'volume_total':
        return volume;
      case 'series_count':
        return series.toDouble();
      case 'streak_days':
        return streak.toDouble();
      case 'goals_completed':
        return completedGoals.toDouble();
      case 'measurements_count':
        return measurements.toDouble();
      case 'workout_count':
      default:
        return workouts.toDouble();
    }
  }
}

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final String type;
  final double target;
  final bool active;
  final Map<String, dynamic> raw;

  const ChallengeModel({
    this.id = '',
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    this.active = true,
    this.raw = const {},
  });

  factory ChallengeModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return ChallengeModel.fromMap(doc.data(), id: doc.id);
  }

  factory ChallengeModel.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return ChallengeModel(
      id: id,
      title: data['title']?.toString().trim().isNotEmpty == true ? data['title'].toString().trim() : 'Reto',
      description: data['description']?.toString().trim() ?? '',
      type: data['type']?.toString().trim().isNotEmpty == true ? data['type'].toString().trim() : 'workout_count',
      target: targetValue(data['target']),
      active: data['active'] != false,
      raw: data,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'target': target,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  double progress(ChallengeStats stats) => stats.progressForType(type);

  String progressLabel(ChallengeStats stats) {
    return '${formatCompact(progress(stats))} / ${formatCompact(target)} ${challengeUnit(type)}';
  }

  bool isCompletedBy(ChallengeStats stats) {
    return active && target > 0 && progress(stats) >= target;
  }

  static double targetValue(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
    return parsed.isFinite && parsed > 0 ? parsed : 0.0;
  }
}

class ChallengeCompletionModel {
  final String challengeId;
  final String challengeTitle;
  final String challengeType;
  final double target;
  final double progress;
  final String progressLabel;
  final String userId;
  final String userName;
  final String userEmail;
  final int points;

  const ChallengeCompletionModel({
    required this.challengeId,
    required this.challengeTitle,
    required this.challengeType,
    required this.target,
    required this.progress,
    required this.progressLabel,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.points,
  });

  factory ChallengeCompletionModel.fromChallenge({
    required ChallengeModel challenge,
    required ChallengeStats stats,
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    return ChallengeCompletionModel(
      challengeId: challenge.id,
      challengeTitle: challenge.title,
      challengeType: challenge.type,
      target: challenge.target,
      progress: challenge.progress(stats),
      progressLabel: challenge.progressLabel(stats),
      userId: userId,
      userName: userName,
      userEmail: userEmail.trim().toLowerCase(),
      points: PointsRules.challengeCompleted,
    );
  }

  Map<String, dynamic> toCompletionMap() {
    return {
      'challengeId': challengeId,
      'challengeTitle': challengeTitle,
      'challengeType': challengeType,
      'target': target,
      'progress': progress,
      'progressLabel': progressLabel,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'points': points,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toCommunityPostMap() {
    return {
      'type': 'challenge_completed',
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'title': 'Reto completado',
      'message': '$userName ha completado el reto "$challengeTitle" en GymFlow.',
      'challengeId': challengeId,
      'challengeTitle': challengeTitle,
      'challengeType': challengeType,
      'progressLabel': progressLabel,
      'points': points,
      'likes': [],
      'likeUsers': {},
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toNotificationMetadata() {
    return {
      'challengeId': challengeId,
      'challengeTitle': challengeTitle,
      'challengeType': challengeType,
      'progress': progress,
      'target': target,
      'points': points,
    };
  }

  Map<String, dynamic> toPointsMetadata() {
    return {
      'challengeId': challengeId,
      'challengeTitle': challengeTitle,
      'challengeType': challengeType,
      'progress': progress,
      'target': target,
    };
  }
}

class ChallengeStatsAccumulator {
  final Set<DateTime> trainingDays = <DateTime>{};
  final Set<String> workoutKeys = <String>{};
  double volume = 0;
  int series = 0;

  void addWorkoutLogs(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> logs) {
    for (final doc in logs) {
      final data = doc.data();
      final weight = workoutDoubleValue(data['weight']);
      final reps = workoutIntValue(data['reps']);
      volume += weight * reps;
      series += 1;

      final day = dayFromTimestamp(data['createdAt']);
      if (day != null) {
        if (!isClosedTrainingDay(day)) trainingDays.add(day);
        final routineId = data['routineId']?.toString() ?? data['routineTitle']?.toString() ?? 'routine';
        workoutKeys.add('$routineId-${day.toIso8601String()}');
      }
    }
  }

  ChallengeStats build({required int completedGoals, required int measurements}) {
    return ChallengeStats(
      workouts: workoutKeys.length,
      series: series,
      volume: volume,
      streak: calculateOpenDayStreak(trainingDays),
      completedGoals: completedGoals,
      measurements: measurements,
    );
  }
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

String userDocId({required String userId, required String userEmail}) {
  if (userId.trim().isNotEmpty) return userId.trim();
  return userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}
