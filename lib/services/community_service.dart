import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'notification_service.dart';

class CommunityService {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;

  const CommunityService({
    required this.gymId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
  });

  CollectionReference<Map<String, dynamic>> get postsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('community_posts');

  String get effectiveUserId => currentUserId.isNotEmpty
      ? currentUserId
      : (FirebaseAuth.instance.currentUser?.uid ?? 'anonymous');

  String get effectiveEmail => currentUserEmail.isNotEmpty
      ? currentUserEmail.toLowerCase()
      : (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase();

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month · $hour:$minute';
    }
    return 'Fecha pendiente';
  }

  IconData iconForType(String type) {
    switch (type) {
      case 'challenge_completed':
      case 'duel_completed':
        return Icons.emoji_events;
      case 'personal_record':
        return Icons.workspace_premium;
      case 'goal_completed':
        return Icons.flag;
      case 'measurement_update':
        return Icons.monitor_weight;
      default:
        return Icons.forum;
    }
  }

  String titleForPost(Map<String, dynamic> data) {
    final title = data['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    final type = data['type']?.toString() ?? '';
    switch (type) {
      case 'challenge_completed':
        return 'Reto completado';
      case 'duel_completed':
        return 'Duelo ganado';
      case 'personal_record':
        return 'Nuevo récord personal';
      case 'goal_completed':
        return 'Objetivo completado';
      case 'measurement_update':
        return 'Progreso físico actualizado';
      default:
        return 'Publicación';
    }
  }

  List<String> likeIds(Map<String, dynamic> data) {
    return List<dynamic>.from(data['likes'] ?? [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, String> likeNames(Map<String, dynamic> data) {
    final result = <String, String>{};
    final raw = data['likeUsers'];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          final name = value['name']?.toString().trim() ?? '';
          if (name.isNotEmpty) result[key.toString()] = name;
        }
      });
    }
    return result;
  }

  List<String> resolvedLikeNames(Map<String, dynamic> data) {
    final ids = likeIds(data);
    final names = likeNames(data);
    return ids.map((id) {
      if (names[id]?.isNotEmpty == true) return names[id]!;
      if (id == effectiveUserId && currentUserName.trim().isNotEmpty) return currentUserName;
      return 'Usuario';
    }).toList();
  }

  List<Map<String, String>> resolvedLikeUsers(Map<String, dynamic> data) {
    final ids = likeIds(data);
    final rawUsers = data['likeUsers'];
    final users = <Map<String, String>>[];
    final seen = <String>{};

    for (final id in ids) {
      if (seen.contains(id)) continue;
      seen.add(id);
      String name = 'Usuario';
      String email = '';

      if (rawUsers is Map && rawUsers[id] is Map) {
        final rawUser = rawUsers[id] as Map;
        final rawName = rawUser['name']?.toString().trim() ?? '';
        final rawEmail = rawUser['email']?.toString().trim() ?? '';
        if (rawName.isNotEmpty) name = rawName;
        if (rawEmail.isNotEmpty) email = rawEmail;
      }

      if (id == effectiveUserId && currentUserName.trim().isNotEmpty) {
        name = currentUserName.trim();
        email = effectiveEmail;
      }

      users.add({'id': id, 'name': name, 'email': email});
    }
    return users;
  }

  String likesPreview(Map<String, dynamic> data) {
    final names = resolvedLikeNames(data);
    if (names.isEmpty) return '';

    final unique = <String>[];
    for (final name in names) {
      if (!unique.contains(name)) unique.add(name);
    }

    if (unique.length == 1) return 'A ${unique.first} le gusta esto';
    if (unique.length == 2) return 'A ${unique[0]} y ${unique[1]} les gusta esto';
    return 'A ${unique[0]}, ${unique[1]} y ${unique.length - 2} más les gusta esto';
  }

  String likesTooltip(Map<String, dynamic> data) {
    final names = resolvedLikeNames(data);
    if (names.isEmpty) return 'Sin likes todavía';
    return names.toSet().join('\n');
  }

  bool matchesFilter(Map<String, dynamic> data, String filter) {
    final type = data['type']?.toString() ?? '';
    if (type == 'workout_completed') return false;
    switch (filter) {
      case 'challenges':
        return type == 'challenge_completed' || type == 'duel_completed';
      case 'records':
        return type == 'personal_record';
      case 'goals':
        return type == 'goal_completed';
      case 'manual':
        return type == 'manual_post';
      case 'all':
      default:
        return true;
    }
  }

  Future<void> toggleLike(String postId, Map<String, dynamic> data) async {
    final uid = effectiveUserId;
    final likes = likeIds(data);
    final postRef = postsRef.doc(postId);

    if (likes.contains(uid)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([uid]),
        'likeUsers.$uid': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await postRef.set({
        'likes': FieldValue.arrayUnion([uid]),
        'likeUsers': {
          uid: {'name': currentUserName, 'email': effectiveEmail},
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final ownerId = data['userId']?.toString() ?? '';
      final ownerEmail = (data['userEmail'] ?? '').toString();
      final isOwnPost = (ownerId.isNotEmpty && ownerId == effectiveUserId) ||
          (ownerEmail.isNotEmpty && ownerEmail.toLowerCase() == effectiveEmail);
      if (!isOwnPost) {
        await NotificationService(gymId: gymId).createNotification(
          userId: ownerId,
          userEmail: ownerEmail,
          type: 'post_like',
          title: 'Nuevo like',
          message: '$currentUserName ha dado like a tu publicación.',
          sourceId: postId,
        );
      }
    }
  }

  Future<void> createManualPost(String message) async {
    await postsRef.add({
      'type': 'manual_post',
      'userId': effectiveUserId,
      'userName': currentUserName,
      'userEmail': effectiveEmail,
      'title': 'Publicación de comunidad',
      'message': message,
      'likes': [],
      'likeUsers': {},
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}



