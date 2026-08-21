import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationRecipient {
  final String userId;
  final String userEmail;

  const NotificationRecipient({
    required this.userId,
    required this.userEmail,
  });

  String get normalizedEmail => userEmail.trim().toLowerCase();
  bool get hasIdentity => userId.trim().isNotEmpty || normalizedEmail.isNotEmpty;

  String docKey() {
    if (userId.trim().isNotEmpty) return userId.trim();
    return normalizedEmail.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  bool matches(Map<String, dynamic> data) {
    final notificationUserId = data['userId']?.toString() ?? '';
    final notificationEmail = (data['userEmail'] ?? '').toString().toLowerCase();
    return (userId.isNotEmpty && notificationUserId == userId) ||
        (normalizedEmail.isNotEmpty && notificationEmail == normalizedEmail);
  }
}

class GymNotificationModel {
  final String id;
  final String userId;
  final String userEmail;
  final String type;
  final String title;
  final String message;
  final String sourceId;
  final Map<String, dynamic> metadata;
  final bool read;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? readAt;
  final Map<String, dynamic> raw;

  const GymNotificationModel({
    this.id = '',
    required this.userId,
    required this.userEmail,
    required this.type,
    required this.title,
    required this.message,
    this.sourceId = '',
    this.metadata = const {},
    this.read = false,
    this.createdAt,
    this.updatedAt,
    this.readAt,
    this.raw = const {},
  });

  factory GymNotificationModel.create({
    required String userId,
    required String userEmail,
    required String type,
    required String title,
    required String message,
    String sourceId = '',
    Map<String, dynamic>? metadata,
  }) {
    return GymNotificationModel(
      userId: userId.trim(),
      userEmail: userEmail.trim().toLowerCase(),
      type: type.trim(),
      title: title.trim(),
      message: message.trim(),
      sourceId: sourceId.trim(),
      metadata: metadata ?? const {},
      read: false,
    );
  }

  factory GymNotificationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return GymNotificationModel.fromMap(doc.data() ?? const {}, id: doc.id);
  }

  factory GymNotificationModel.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return GymNotificationModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      userEmail: (data['userEmail'] ?? '').toString().toLowerCase(),
      type: data['type']?.toString() ?? 'notification',
      title: data['title']?.toString() ?? 'Notificación',
      message: data['message']?.toString() ?? '',
      sourceId: data['sourceId']?.toString() ?? '',
      metadata: data['metadata'] is Map ? Map<String, dynamic>.from(data['metadata'] as Map) : const {},
      read: data['read'] == true,
      createdAt: dateTimeValue(data['createdAt']),
      updatedAt: dateTimeValue(data['updatedAt']),
      readAt: dateTimeValue(data['readAt']),
      raw: data,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'userId': userId,
      'userEmail': userEmail.toLowerCase(),
      'type': type,
      'title': title,
      'message': message,
      'sourceId': sourceId,
      'metadata': metadata,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMarkerMap({required String notificationId}) {
    return {
      ...toCreateMap(),
      'notificationId': notificationId,
    };
  }

  Map<String, dynamic> toReadMap() {
    return {
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get group => notificationGroupForType(type);
  IconData get icon => notificationIconForType(type);
  Color get color => notificationColorForType(type);

  String get formattedDate {
    final date = createdAt;
    if (date == null) return 'Fecha pendiente';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year · $hour:$minute';
  }

  static DateTime? dateTimeValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class SmartRetentionContext {
  final String userId;
  final String userName;
  final String userEmail;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> ranking;
  final Map<String, dynamic> leaderboard;
  final int photoCount;
  final DateTime now;

  const SmartRetentionContext({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.stats,
    required this.ranking,
    required this.leaderboard,
    required this.photoCount,
    required this.now,
  });

  String get normalizedEmail => userEmail.trim().toLowerCase();
  NotificationRecipient get recipient => NotificationRecipient(userId: userId, userEmail: normalizedEmail);
  String get userKey => recipient.docKey();
  String get today => dayKey(now);
  bool get trainedToday => isToday(stats['lastWorkout'], now: now);
  int get currentStreak => intValue(stats['currentStreak']);
  int get weeklyWorkouts => intValue(ranking['weeklyWorkouts']);
  int get points => intValue(leaderboard['allTimePoints'] ?? stats['points']);
  int get target => nextLevelTarget(points);
  int get remaining => target > points ? target - points : 0;

  static String dayKey([DateTime? value]) {
    final date = value ?? DateTime.now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static bool isToday(dynamic value, {DateTime? now}) {
    final date = GymNotificationModel.dateTimeValue(value);
    if (date == null) return false;
    final current = now ?? DateTime.now();
    return date.year == current.year && date.month == current.month && date.day == current.day;
  }

  static int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int nextLevelTarget(int points) {
    if (points < 500) return 500;
    if (points < 1000) return 1000;
    if (points < 2500) return 2500;
    if (points < 5000) return 5000;
    if (points < 10000) return 10000;
    return points;
  }
}

String notificationGroupForType(String type) {
  if (type.startsWith('chat_')) return 'messages';
  if (type.startsWith('duel_') || type.startsWith('challenge_')) return 'challenges';
  if (type.startsWith('ranking_')) return 'rankings';
  if (type.startsWith('post_') || type.startsWith('comment_')) return 'community';
  if (type.startsWith('goal_')) return 'goals';
  if (type.startsWith('achievement_')) return 'achievements';
  return 'other';
}

IconData notificationIconForType(String type) {
  if (type.startsWith('chat_')) return Icons.chat_bubble_outline;
  if (type == 'duel_created') return Icons.sports_mma;
  if (type == 'duel_won') return Icons.emoji_events;
  if (type == 'duel_lost') return Icons.sentiment_neutral;
  if (type.startsWith('duel_') || type.startsWith('challenge_')) return Icons.emoji_events;
  if (type.startsWith('ranking_')) return Icons.leaderboard;
  if (type == 'post_like') return Icons.favorite;
  if (type == 'post_comment' || type.startsWith('comment_')) return Icons.mode_comment;
  if (type.startsWith('goal_')) return Icons.flag;
  if (type.startsWith('achievement_')) return Icons.military_tech;
  return Icons.notifications;
}

Color notificationColorForType(String type) {
  if (type.startsWith('chat_')) return Colors.lightBlueAccent;
  if (type == 'duel_won') return Colors.amberAccent;
  if (type == 'duel_lost') return Colors.orangeAccent;
  if (type.startsWith('duel_') || type.startsWith('challenge_')) return Colors.greenAccent;
  if (type.startsWith('ranking_')) return Colors.amberAccent;
  if (type == 'post_like') return Colors.redAccent;
  if (type == 'post_comment' || type.startsWith('comment_')) return Colors.purpleAccent;
  if (type.startsWith('goal_')) return Colors.greenAccent;
  if (type.startsWith('achievement_')) return Colors.amberAccent;
  return Colors.greenAccent;
}
