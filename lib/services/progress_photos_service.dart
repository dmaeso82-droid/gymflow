import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'achievement_service.dart';

class ProgressPhotoCategory {
  final String id;
  final String label;
  final IconData icon;

  const ProgressPhotoCategory({required this.id, required this.label, required this.icon});
}

const progressPhotoCategories = [
  ProgressPhotoCategory(id: 'front', label: 'Frontal', icon: Icons.accessibility_new),
  ProgressPhotoCategory(id: 'side', label: 'Lateral', icon: Icons.view_sidebar),
  ProgressPhotoCategory(id: 'back', label: 'Espalda', icon: Icons.accessibility),
  ProgressPhotoCategory(id: 'free', label: 'Libre', icon: Icons.photo_camera),
];

class ProgressPhotosService {
  final String gymId;

  const ProgressPhotosService({required this.gymId});

  CollectionReference<Map<String, dynamic>> get photosRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('progress_photos');

  CollectionReference<Map<String, dynamic>> get communityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('community_posts');

  Reference get storageRoot => FirebaseStorage.instance.ref().child('progress_photos').child(gymId);

  String categoryLabel(String category) {
    for (final item in progressPhotoCategories) {
      if (item.id == category) return item.label;
    }
    return 'Libre';
  }

  IconData categoryIcon(String category) {
    for (final item in progressPhotoCategories) {
      if (item.id == category) return item.icon;
    }
    return Icons.photo_camera;
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

  bool matchesUser(Map<String, dynamic> data, String userId, String userEmail) {
    final storedUserId = (data['userId'] ?? '').toString();
    final storedEmail = (data['userEmail'] ?? '').toString().toLowerCase();
    final normalizedEmail = userEmail.toLowerCase();
    return (userId.isNotEmpty && storedUserId == userId) ||
        (normalizedEmail.isNotEmpty && storedEmail == normalizedEmail);
  }

  AchievementService achievementService({
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    return AchievementService(
      gymId: gymId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
    );
  }

  Future<List<UnlockedAchievementData>> pickAndUploadPhoto({
    required String userId,
    required String userName,
    required String userEmail,
    required String category,
  }) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 86);
    if (image == null) return [];

    final bytes = await image.readAsBytes();
    final extension = image.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final safeUserKey = userId.isNotEmpty ? userId : userEmail.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$category.$extension';
    final ref = storageRoot.child(safeUserKey).child(fileName);

    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    await photosRef.add({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail.toLowerCase(),
      'category': category,
      'imageUrl': url,
      'storagePath': ref.fullPath,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return achievementService(userId: userId, userName: userName, userEmail: userEmail).evaluatePhotoAchievements();
  }

  Future<List<UnlockedAchievementData>> shareTransformationToCommunity({
    required String userId,
    required String userName,
    required String userEmail,
    required String beforeImageUrl,
    required String afterImageUrl,
    required String beforeDate,
    required String afterDate,
    required String category,
    required String message,
  }) async {
    await communityRef.add({
      'type': 'transformation_post',
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail.toLowerCase(),
      'title': 'Transformación física',
      'message': message.trim().isEmpty ? 'He actualizado mi transformación física.' : message.trim(),
      'beforeImageUrl': beforeImageUrl,
      'afterImageUrl': afterImageUrl,
      'beforeDate': beforeDate,
      'afterDate': afterDate,
      'category': category,
      'likes': [],
      'likeUsers': {},
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return achievementService(userId: userId, userName: userName, userEmail: userEmail).evaluateTransformationAchievements();
  }

  Future<void> shareAchievementToCommunity({
    required String userId,
    required String userName,
    required String userEmail,
    required UnlockedAchievementData achievement,
  }) async {
    await achievementService(userId: userId, userName: userName, userEmail: userEmail).shareAchievementToCommunity(achievement);
  }

  Future<void> deletePhoto(Map<String, dynamic> data, String photoId) async {
    final storagePath = data['storagePath']?.toString() ?? '';
    if (storagePath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(storagePath).delete();
      } catch (_) {
        // Si la foto ya no existe en Storage, igualmente eliminamos el documento.
      }
    }
    await photosRef.doc(photoId).delete();
  }
}



