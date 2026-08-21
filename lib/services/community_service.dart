import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../models/community_post_model.dart';
import 'notification_service.dart';
import 'subscription_service.dart';
export '../models/community_post_model.dart';
class CommunityService {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  const CommunityService({required this.gymId, required this.currentUserId, required this.currentUserName, required this.currentUserEmail});
  CollectionReference<Map<String, dynamic>> get postsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('community_posts');
  SubscriptionService get subscriptionService => SubscriptionService(gymId: gymId);
  String get effectiveUserId => currentUserId.trim().isNotEmpty ? currentUserId.trim() : (FirebaseAuth.instance.currentUser?.uid ?? '');
  String get effectiveEmail => currentUserEmail.isNotEmpty ? currentUserEmail.toLowerCase() : (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase();
  CommunityUserIdentity get currentIdentity => CommunityUserIdentity(id: effectiveUserId, name: currentUserName, email: effectiveEmail);
  CommunityPostModel postFromData(Map<String, dynamic> data, {String id = ''}) => CommunityPostModel.fromMap(data, id: id);
  String formatDate(dynamic value) => CommunityPostModel.formatDate(value);
  IconData iconForType(String type) => CommunityPostModel.iconForType(type);
  String titleForPost(Map<String, dynamic> data) => CommunityPostModel.fromMap(data).effectiveTitle;
  List<String> likeIds(Map<String, dynamic> data) => CommunityPostModel.fromMap(data).likes;
  Map<String, String> likeNames(Map<String, dynamic> data) => CommunityPostModel.fromMap(data).likeNamesMap();
  List<String> resolvedLikeNames(Map<String, dynamic> data) => CommunityPostModel.fromMap(data).resolvedLikeNames(currentIdentity);
  List<Map<String, String>> resolvedLikeUsers(Map<String, dynamic> data) => CommunityPostModel.fromMap(data).resolvedLikeUsers(currentIdentity).map((user) => user.toMap()).toList();
  String likesPreview(Map<String, dynamic> data) => CommunityPostModel.fromMap(data).likesPreview(currentIdentity);
  String likesTooltip(Map<String, dynamic> data) => CommunityPostModel.fromMap(data).likesTooltip(currentIdentity);
  bool matchesFilter(Map<String, dynamic> data, String filter) => CommunityPostModel.fromMap(data).matchesFilter(filter);
  bool canDeletePost(Map<String, dynamic> data, {bool trainerMode = false}) {
    if (trainerMode) return true;
    final post = CommunityPostModel.fromMap(data);
    return currentIdentity.ownsPost(post);
  }
  Future<void> toggleLike(String postId, Map<String, dynamic> data) async {
    await subscriptionService.assertActive(feature: 'community');
    final uid = effectiveUserId;
    if (uid.isEmpty || postId.trim().isEmpty) {
      throw StateError('No se ha podido identificar al usuario o la publicación.');
    }
    final post = CommunityPostModel.fromMap(data, id: postId);
    final postRef = postsRef.doc(postId);
    if (post.isLikedBy(uid)) {
      await postRef.update({'likes': FieldValue.arrayRemove([uid]), 'likeUsers.$uid': FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()});
      return;
    }
    await postRef.set({'likes': FieldValue.arrayUnion([uid]), 'likeUsers': {uid: currentIdentity.toLikeUserMap()}, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    if (!currentIdentity.ownsPost(post)) {
      await NotificationService(gymId: gymId).createNotification(userId: post.userId, userEmail: post.userEmail, type: 'post_like', title: 'Nuevo like', message: '$currentUserName ha dado like a tu publicación.', sourceId: postId);
    }
  }
  Future<void> createManualPost(String message) async {
    await subscriptionService.assertActive(feature: 'community');
    final cleanMessage = message.trim();
    if (effectiveUserId.isEmpty || cleanMessage.isEmpty) {
      throw StateError('El usuario y el mensaje son obligatorios.');
    }
    final post = CommunityPostModel.manual(author: currentIdentity, message: cleanMessage);
    final ref = await postsRef.add(post.toCreateMap());
    await subscriptionService.writeAudit(type: 'community_post_created', actorUid: effectiveUserId, actorName: currentUserName, actorEmail: effectiveEmail, target: ref.id, metadata: {'source': 'manual'});
  }
  Future<void> deletePost(String postId, Map<String, dynamic> data, {bool trainerMode = false}) async {
    await subscriptionService.assertActive(feature: 'community');
    if (!canDeletePost(data, trainerMode: trainerMode)) throw StateError('No tienes permisos para eliminar esta publicación.');
    final postRef = postsRef.doc(postId);
    await _deleteKnownStorageFiles(data);
    await _deletePostComments(postRef);
    await postRef.delete();
    await subscriptionService.writeAudit(type: 'community_post_deleted', actorUid: effectiveUserId, actorName: currentUserName, actorEmail: effectiveEmail, target: postId);
  }
  Future<void> _deletePostComments(DocumentReference<Map<String, dynamic>> postRef) async {
    while (true) {
      final comments = await postRef.collection('comments').limit(400).get();
      if (comments.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final comment in comments.docs) {
        batch.delete(comment.reference);
      }
      await batch.commit();
      if (comments.docs.length < 400) return;
    }
  }
  Future<void> _deleteKnownStorageFiles(Map<String, dynamic> data) async {
    final candidates = <String>{};
    for (final key in const ['storagePath', 'imageStoragePath', 'photoStoragePath', 'beforeStoragePath', 'afterStoragePath', 'beforeImageStoragePath', 'afterImageStoragePath']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) candidates.add(value);
    }
    for (final key in const ['imageUrl', 'photoUrl', 'beforeImageUrl', 'afterImageUrl', 'beforeUrl', 'afterUrl', 'beforePhotoUrl', 'afterPhotoUrl']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.startsWith('gs://') || value.startsWith('http')) candidates.add(value);
    }
    for (final candidate in candidates) {
      try {
        if (candidate.startsWith('gs://') || candidate.startsWith('http')) {
          await FirebaseStorage.instance.refFromURL(candidate).delete();
        } else {
          await FirebaseStorage.instance.ref(candidate).delete();
        }
      } catch (error) {
        debugPrint('No se pudo eliminar archivo de Storage asociado a comunidad: $error');
      }
    }
  }
}
