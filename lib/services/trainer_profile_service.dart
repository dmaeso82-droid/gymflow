import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrainerPersonalTrainingProfile {
  final String userId;
  final String name;
  final String email;

  const TrainerPersonalTrainingProfile({
    required this.userId,
    required this.name,
    required this.email,
  });
}

class TrainerProfileService {
  final String gymId;

  const TrainerProfileService({required this.gymId});

  Future<TrainerPersonalTrainingProfile?> ensurePersonalTrainingProfile({
    required String trainerName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final email = (user.email ?? '').trim().toLowerCase();
    final name = trainerName.trim().isEmpty
        ? (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Entrenador')
        : trainerName.trim();
    final now = FieldValue.serverTimestamp();
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(user.uid);
    final profileRef = db
        .collection('gyms')
        .doc(gymId)
        .collection('clients')
        .doc(user.uid);

    await db.runTransaction((transaction) async {
      final existingProfile = await transaction.get(profileRef);
      transaction.set(
        userRef,
        {'isClient': true, 'updatedAt': now},
        SetOptions(merge: true),
      );
      transaction.set(
        profileRef,
        {
          'authUid': user.uid,
          'name': name,
          'email': email,
          'isTrainer': true,
          'isTrainerClient': true,
          'active': true,
          'updatedAt': now,
          if (!existingProfile.exists) 'createdAt': now,
        },
        SetOptions(merge: true),
      );
    });

    return TrainerPersonalTrainingProfile(
      userId: user.uid,
      name: name,
      email: email,
    );
  }
}
