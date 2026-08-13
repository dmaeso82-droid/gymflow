import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final String gymId;

  const NotificationService({required this.gymId});

  CollectionReference<Map<String, dynamic>> get notificationsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('notifications');
  CollectionReference<Map<String, dynamic>> get notificationMarkersRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('notification_markers');

  Future<void> createNotification({
    required String userId,
    required String userEmail,
    required String type,
    required String title,
    required String message,
    String sourceId = '',
    Map<String, dynamic>? metadata,
  }) async {
    if (userId.trim().isEmpty && userEmail.trim().isEmpty) return;

    await notificationsRef.add({
      'userId': userId,
      'userEmail': userEmail.toLowerCase(),
      'type': type,
      'title': title,
      'message': message,
      'sourceId': sourceId,
      'metadata': metadata ?? {},
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  Future<bool> createNotificationOnce({
    required String markerId,
    required String userId,
    required String userEmail,
    required String type,
    required String title,
    required String message,
    String sourceId = '',
    Map<String, dynamic>? metadata,
  }) async {
    if (markerId.trim().isEmpty) return false;
    if (userId.trim().isEmpty && userEmail.trim().isEmpty) return false;
    final markerRef = notificationMarkersRef.doc(markerId);
    return FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
      final marker = await transaction.get(markerRef);
      if (marker.exists) return false;
      final notificationRef = notificationsRef.doc();
      final normalizedEmail = userEmail.toLowerCase();
      final data = {
        'userId': userId,
        'userEmail': normalizedEmail,
        'type': type,
        'title': title,
        'message': message,
        'sourceId': sourceId,
        'metadata': metadata ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(notificationRef, data);
      transaction.set(markerRef, {
        ...data,
        'notificationId': notificationRef.id,
      });
      return true;
    });
  }
  Future<void> markAllAsRead({
    required String userId,
    required String userEmail,
  }) async {
    final normalizedEmail = userEmail.toLowerCase();
    final batches = <WriteBatch>[];

    Future<void> markQuery(Query<Map<String, dynamic>> query) async {
      final snapshot = await query.limit(400).get();
      if (snapshot.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batches.add(batch);
    }

    if (userId.trim().isNotEmpty) {
      await markQuery(notificationsRef.where('userId', isEqualTo: userId).where('read', isEqualTo: false));
    }
    if (normalizedEmail.trim().isNotEmpty) {
      await markQuery(notificationsRef.where('userEmail', isEqualTo: normalizedEmail).where('read', isEqualTo: false));
    }

    for (final batch in batches) {
      await batch.commit();
    }
  }

  bool isForCurrentUser(Map<String, dynamic> data, String userId, String userEmail) {
    final notificationUserId = data['userId']?.toString() ?? '';
    final notificationEmail = (data['userEmail'] ?? '').toString().toLowerCase();
    final normalizedEmail = userEmail.toLowerCase();
    return (userId.isNotEmpty && notificationUserId == userId) ||
        (normalizedEmail.isNotEmpty && notificationEmail == normalizedEmail);
  }

  String groupForType(String type) {
    if (type.startsWith('chat_')) return 'messages';
    if (type.startsWith('duel_') || type.startsWith('challenge_')) return 'challenges';
    if (type.startsWith('ranking_')) return 'rankings';
    if (type.startsWith('post_') || type.startsWith('comment_')) return 'community';
    if (type.startsWith('goal_')) return 'goals';
    if (type.startsWith('achievement_')) return 'achievements';
    return 'other';
  }

  IconData iconForType(String type) {
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

  Color colorForType(String type) {
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

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year · $hour:$minute';
    }
    return 'Fecha pendiente';
  }
}



