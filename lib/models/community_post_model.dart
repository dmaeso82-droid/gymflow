import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CommunityUserIdentity {
  final String id;
  final String name;
  final String email;

  const CommunityUserIdentity({
    required this.id,
    required this.name,
    required this.email,
  });

  Map<String, String> toLikeUserMap() {
    return {'name': name, 'email': email};
  }

  bool ownsPost(CommunityPostModel post) {
    final normalizedEmail = email.toLowerCase();
    return (id.isNotEmpty && post.userId == id) ||
        (normalizedEmail.isNotEmpty && post.userEmail.toLowerCase() == normalizedEmail);
  }
}

class CommunityLikeUserModel {
  final String id;
  final String name;
  final String email;

  const CommunityLikeUserModel({
    required this.id,
    required this.name,
    required this.email,
  });

  Map<String, String> toMap() {
    return {'id': id, 'name': name, 'email': email};
  }
}

class CommunityPostModel {
  final String id;
  final String type;
  final String userId;
  final String userName;
  final String userEmail;
  final String title;
  final String message;
  final List<String> likes;
  final Map<String, dynamic> likeUsers;
  final int commentsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> raw;

  const CommunityPostModel({
    this.id = '',
    required this.type,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.title,
    required this.message,
    required this.likes,
    required this.likeUsers,
    required this.commentsCount,
    this.createdAt,
    this.updatedAt,
    this.raw = const {},
  });

  factory CommunityPostModel.manual({
    required CommunityUserIdentity author,
    required String message,
  }) {
    return CommunityPostModel(
      type: 'manual_post',
      userId: author.id,
      userName: author.name,
      userEmail: author.email.toLowerCase(),
      title: 'Publicación de comunidad',
      message: message.trim(),
      likes: const [],
      likeUsers: const {},
      commentsCount: 0,
    );
  }

  factory CommunityPostModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return CommunityPostModel.fromMap(doc.data(), id: doc.id);
  }

  factory CommunityPostModel.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return CommunityPostModel(
      id: id,
      type: data['type']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString().trim().isNotEmpty == true
          ? data['userName'].toString().trim()
          : 'Usuario',
      userEmail: (data['userEmail'] ?? '').toString().trim().toLowerCase(),
      title: data['title']?.toString().trim() ?? '',
      message: data['message']?.toString().trim() ?? '',
      likes: likeIdsFromMap(data),
      likeUsers: data['likeUsers'] is Map ? Map<String, dynamic>.from(data['likeUsers'] as Map) : const {},
      commentsCount: intValue(data['commentsCount']),
      createdAt: dateTimeValue(data['createdAt']),
      updatedAt: dateTimeValue(data['updatedAt']),
      raw: data,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'type': type,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail.toLowerCase(),
      'title': effectiveTitle,
      'message': message,
      'likes': likes,
      'likeUsers': likeUsers,
      'commentsCount': commentsCount,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get effectiveTitle {
    final cleanTitle = title.trim();
    if (cleanTitle.isNotEmpty) return cleanTitle;
    return titleForType(type);
  }

  bool get shouldShowInCommunity {
    return type != 'workout_completed';
  }

  bool isLikedBy(String uid) {
    return likes.contains(uid);
  }

  List<String> resolvedLikeNames(CommunityUserIdentity currentUser) {
    final names = likeNamesMap();
    return likes.map((id) {
      if (names[id]?.isNotEmpty == true) return names[id]!;
      if (id == currentUser.id && currentUser.name.trim().isNotEmpty) return currentUser.name;
      return 'Usuario';
    }).toList();
  }

  List<CommunityLikeUserModel> resolvedLikeUsers(CommunityUserIdentity currentUser) {
    final users = <CommunityLikeUserModel>[];
    final seen = <String>{};

    for (final id in likes) {
      if (seen.contains(id)) continue;
      seen.add(id);

      var name = 'Usuario';
      var email = '';

      if (likeUsers[id] is Map) {
        final rawUser = likeUsers[id] as Map;
        final rawName = rawUser['name']?.toString().trim() ?? '';
        final rawEmail = rawUser['email']?.toString().trim() ?? '';
        if (rawName.isNotEmpty) name = rawName;
        if (rawEmail.isNotEmpty) email = rawEmail;
      }

      if (id == currentUser.id && currentUser.name.trim().isNotEmpty) {
        name = currentUser.name.trim();
        email = currentUser.email;
      }

      users.add(CommunityLikeUserModel(id: id, name: name, email: email));
    }

    return users;
  }

  String likesPreview(CommunityUserIdentity currentUser) {
    final names = resolvedLikeNames(currentUser);
    if (names.isEmpty) return '';

    final unique = <String>[];
    for (final name in names) {
      if (!unique.contains(name)) unique.add(name);
    }

    if (unique.length == 1) return 'A ${unique.first} le gusta esto';
    if (unique.length == 2) return 'A ${unique[0]} y ${unique[1]} les gusta esto';
    return 'A ${unique[0]}, ${unique[1]} y ${unique.length - 2} más les gusta esto';
  }

  String likesTooltip(CommunityUserIdentity currentUser) {
    final names = resolvedLikeNames(currentUser);
    if (names.isEmpty) return 'Sin likes todavía';
    return names.toSet().join('\n');
  }

  bool matchesFilter(String filter) {
    if (!shouldShowInCommunity) return false;

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

  Map<String, String> likeNamesMap() {
    final result = <String, String>{};
    likeUsers.forEach((key, value) {
      if (value is Map) {
        final name = value['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) result[key.toString()] = name;
      }
    });
    return result;
  }

  static List<String> likeIdsFromMap(Map<String, dynamic> data) {
    final rawLikes = data['likes'];
    if (rawLikes is! Iterable) return <String>[];
    return rawLikes
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static String titleForType(String type) {
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

  static IconData iconForType(String type) {
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

  static String formatDate(dynamic value) {
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

  static int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? dateTimeValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
