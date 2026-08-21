import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/notification_model.dart' as notification_models;
import '../models/notification_model.dart';
import 'subscription_service.dart';
export '../models/notification_model.dart' hide notificationGroupForType, notificationIconForType, notificationColorForType;

class NotificationService {
  final String gymId;
  const NotificationService({required this.gymId});

  CollectionReference<Map<String, dynamic>> get notificationsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('notifications');
  CollectionReference<Map<String, dynamic>> get notificationMarkersRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('notification_markers');
  SubscriptionService get subscriptionService => SubscriptionService(gymId: gymId);

  Future<bool> notificationsAllowed() async {
    final plan = await subscriptionService.loadPlan();
    return plan.isActive;
  }

  Future<void> createNotification({required String userId, required String userEmail, required String type, required String title, required String message, String sourceId = '', Map<String, dynamic>? metadata}) async {
    if (!await notificationsAllowed()) return;
    final notification = GymNotificationModel.create(userId: userId, userEmail: userEmail, type: type, title: title, message: message, sourceId: sourceId, metadata: metadata);
    final recipient = NotificationRecipient(userId: userId, userEmail: userEmail);
    if (!recipient.hasIdentity) return;
    await notificationsRef.add(notification.toCreateMap());
  }

  Future<bool> createNotificationOnce({required String markerId, required String userId, required String userEmail, required String type, required String title, required String message, String sourceId = '', Map<String, dynamic>? metadata}) async {
    if (!await notificationsAllowed()) return false;
    if (markerId.trim().isEmpty) return false;
    final recipient = NotificationRecipient(userId: userId, userEmail: userEmail);
    if (!recipient.hasIdentity) return false;
    final notification = GymNotificationModel.create(userId: userId, userEmail: userEmail, type: type, title: title, message: message, sourceId: sourceId, metadata: metadata);
    final markerRef = notificationMarkersRef.doc(markerId);
    return FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
      final marker = await transaction.get(markerRef);
      if (marker.exists) return false;
      final notificationRef = notificationsRef.doc();
      transaction.set(notificationRef, notification.toCreateMap());
      transaction.set(markerRef, notification.toMarkerMap(notificationId: notificationRef.id));
      return true;
    });
  }

  Future<void> markAllAsRead({required String userId, required String userEmail}) async {
    final recipient = NotificationRecipient(userId: userId, userEmail: userEmail);
    Future<void> markQuery(Query<Map<String, dynamic>> query) async {
      while (true) {
        final snapshot = await query.limit(400).get();
        if (snapshot.docs.isEmpty) return;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, GymNotificationModel.fromDoc(doc).toReadMap());
        }
        await batch.commit();
        if (snapshot.docs.length < 400) return;
      }
    }
    if (recipient.userId.trim().isNotEmpty) await markQuery(notificationsRef.where('userId', isEqualTo: recipient.userId).where('read', isEqualTo: false));
    if (recipient.normalizedEmail.trim().isNotEmpty) await markQuery(notificationsRef.where('userEmail', isEqualTo: recipient.normalizedEmail).where('read', isEqualTo: false));
  }

  bool isForCurrentUser(Map<String, dynamic> data, String userId, String userEmail) => NotificationRecipient(userId: userId, userEmail: userEmail).matches(data);
  String groupForType(String type) => notification_models.notificationGroupForType(type);
  IconData iconForType(String type) => notification_models.notificationIconForType(type);
  Color colorForType(String type) => notification_models.notificationColorForType(type);
  String formatDate(dynamic value) => GymNotificationModel.fromMap({'createdAt': value}).formattedDate;
  String userDocId({required String userId, required String userEmail}) => NotificationRecipient(userId: userId, userEmail: userEmail).docKey();
  int intValue(dynamic value) => SmartRetentionContext.intValue(value);
  DateTime? dateFromTimestamp(dynamic value) => GymNotificationModel.dateTimeValue(value);
  bool isToday(dynamic value) => SmartRetentionContext.isToday(value);
  String dayKey([DateTime? value]) => SmartRetentionContext.dayKey(value);
  int nextLevelTarget(int points) => SmartRetentionContext.nextLevelTarget(points);

  Future<DocumentSnapshot<Map<String, dynamic>>?> firstExistingUserDoc({required CollectionReference<Map<String, dynamic>> ref, required String userId, required String userEmail}) async {
    final recipient = NotificationRecipient(userId: userId, userEmail: userEmail);
    final keys = <String>{if (recipient.userId.trim().isNotEmpty) recipient.userId.trim(), if (recipient.normalizedEmail.trim().isNotEmpty) recipient.docKey()};
    for (final key in keys) {
      final doc = await ref.doc(key).get();
      if (doc.exists) return doc;
    }
    return null;
  }

  Future<int> countUserDocs({required CollectionReference<Map<String, dynamic>> ref, required String userId, required String userEmail, String userIdField = 'userId', String emailField = 'userEmail'}) async {
    var total = 0;
    final recipient = NotificationRecipient(userId: userId, userEmail: userEmail);
    if (recipient.userId.trim().isNotEmpty) {
      final snapshot = await ref.where(userIdField, isEqualTo: recipient.userId.trim()).limit(2).get();
      total += snapshot.size;
    }
    if (recipient.normalizedEmail.isNotEmpty) {
      final snapshot = await ref.where(emailField, isEqualTo: recipient.normalizedEmail).limit(2).get();
      total += snapshot.size;
    }
    return total;
  }

  Future<void> generateSmartRetentionNotifications({required String userId, required String userName, required String userEmail}) async {
    final plan = await subscriptionService.loadPlan();
    if (!plan.isActive) return;
    final recipient = NotificationRecipient(userId: userId, userEmail: userEmail);
    final userKey = recipient.docKey();
    if (userKey.isEmpty) return;
    final gymRef = FirebaseFirestore.instance.collection('gyms').doc(gymId);
    final statsDoc = await firstExistingUserDoc(ref: gymRef.collection('user_stats'), userId: userId, userEmail: recipient.normalizedEmail);
    final rankingDoc = await firstExistingUserDoc(ref: gymRef.collection('ranking_stats'), userId: userId, userEmail: recipient.normalizedEmail);
    final leaderboardDoc = await firstExistingUserDoc(ref: gymRef.collection('leaderboard'), userId: userId, userEmail: recipient.normalizedEmail);
    final photoCount = await countUserDocs(ref: gymRef.collection('progress_photos'), userId: userId, userEmail: recipient.normalizedEmail);
    final context = SmartRetentionContext(userId: userId, userName: userName, userEmail: recipient.normalizedEmail, stats: statsDoc?.data() ?? <String, dynamic>{}, ranking: rankingDoc?.data() ?? <String, dynamic>{}, leaderboard: leaderboardDoc?.data() ?? <String, dynamic>{}, photoCount: photoCount, now: DateTime.now());
    if (!context.trainedToday && context.currentStreak >= 3) {
      await createNotificationOnce(markerId: '${context.userKey}_${context.today}_smart_streak_danger', userId: userId, userEmail: context.normalizedEmail, type: 'smart_streak_danger', title: '🔥 No pierdas tu racha', message: 'Tienes una racha de ${context.currentStreak} días. Entrena hoy para mantenerla activa.', sourceId: context.today, metadata: {'currentStreak': context.currentStreak, 'suggestedAction': 'open_routines'});
    } else if (!context.trainedToday) {
      await createNotificationOnce(markerId: '${context.userKey}_${context.today}_smart_daily_workout', userId: userId, userEmail: context.normalizedEmail, type: 'smart_daily_workout', title: '💪 Misión del día', message: 'Completa un entrenamiento hoy y suma progreso en GymFlow.', sourceId: context.today, metadata: {'suggestedAction': 'open_routines'});
    }
    if (context.weeklyWorkouts >= 2 && context.weeklyWorkouts < 3) {
      await createNotificationOnce(markerId: '${context.userKey}_${context.today}_smart_weekly_goal_close', userId: userId, userEmail: context.normalizedEmail, type: 'smart_weekly_goal_close', title: '🎯 Objetivo semanal cerca', message: 'Llevas ${context.weeklyWorkouts}/3 entrenos esta semana. Te falta solo uno para completar el objetivo.', sourceId: context.today, metadata: {'weeklyWorkouts': context.weeklyWorkouts, 'weeklyTarget': 3});
    }
    if (context.remaining > 0 && context.remaining <= 50) {
      await createNotificationOnce(markerId: '${context.userKey}_${context.target}_smart_level_close', userId: userId, userEmail: context.normalizedEmail, type: 'smart_level_close', title: '🏆 Próximo nivel cerca', message: 'Te faltan ${context.remaining} puntos para alcanzar el siguiente nivel.', sourceId: context.target.toString(), metadata: {'points': context.points, 'nextTarget': context.target, 'remaining': context.remaining});
    }
    if (context.photoCount == 0) {
      await createNotificationOnce(markerId: '${context.userKey}_smart_first_progress_photo', userId: userId, userEmail: context.normalizedEmail, type: 'smart_first_progress_photo', title: '📸 Primer punto de partida', message: 'Sube tu primera foto de progreso para comparar tu evolución más adelante.', sourceId: context.userKey, metadata: {'suggestedAction': 'open_progress_photos'});
    }
  }
}
