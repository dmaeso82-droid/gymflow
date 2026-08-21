import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/achievement_model.dart';
export '../models/achievement_model.dart';

class AchievementService {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const AchievementService({
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  CollectionReference<Map<String, dynamic>> get communityRef =>
      FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('community_posts');

  CollectionReference<Map<String, dynamic>> get userStatsRef =>
      FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('user_stats');

  CollectionReference<Map<String, dynamic>> get photosRef =>
      FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('progress_photos');

  AchievementUnlockContext get unlockContext => AchievementUnlockContext(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
      );

  bool matchesUser(Map<String, dynamic> data) => unlockContext.matchesUser(data);

  String unlockedDocId(String achievementId) =>
      '${userId.trim()}_$achievementId';

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  Future<AchievementStats> loadStats() async {
    Map<String, dynamic> data = const <String, dynamic>{};
    final uid = userId.trim();

    if (uid.isNotEmpty) {
      final snapshot = await userStatsRef.doc(uid).get();
      data = snapshot.data() ?? const <String, dynamic>{};
    }

    if (data.isEmpty && userEmail.trim().isNotEmpty) {
      final legacySnapshot = await userStatsRef
          .where('userEmail', isEqualTo: userEmail.trim().toLowerCase())
          .limit(1)
          .get();
      if (legacySnapshot.docs.isNotEmpty) {
        data = legacySnapshot.docs.first.data();
      }
    }

    var photos = _intValue(data['photos']);
    if (photos == 0) {
      if (uid.isNotEmpty) {
        final count = await photosRef.where('userId', isEqualTo: uid).count().get();
        photos = count.count ?? 0;
      } else if (userEmail.trim().isNotEmpty) {
        final count = await photosRef
            .where('userEmail', isEqualTo: userEmail.trim().toLowerCase())
            .count()
            .get();
        photos = count.count ?? 0;
      }
    }

    return AchievementStats(
      workouts: _intValue(data['workouts']),
      series: _intValue(data['series']),
      volume: _doubleValue(data['volume']).round(),
      streak: _intValue(data['currentStreak']),
      exercises: _intValue(data['exerciseCount']),
      photos: photos,
      transformations: _intValue(data['transformations']),
    );
  }

  Future<List<UnlockedAchievementData>> evaluateAndUnlock({
    Set<String>? metrics,
  }) async {
    if (gymId.trim().isEmpty || (userId.trim().isEmpty && userEmail.trim().isEmpty)) {
      throw StateError('No se ha podido identificar el gimnasio o el usuario.');
    }
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('evaluateAchievementsSecure');
    final result = await callable.call(<String, dynamic>{
      'gymId': gymId,
      if (metrics != null) 'metrics': metrics.toList(),
    });
    final data = result.data;
    if (data is! Map || data['unlocked'] is! List) {
      throw StateError('Respuesta inválida al evaluar logros.');
    }
    return (data['unlocked'] as List).whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      return UnlockedAchievementData(
        id: map['id']?.toString().trim() ?? '',
        title: map['title']?.toString() ?? 'Logro',
        description: map['description']?.toString() ?? '',
        metric: map['metric']?.toString() ?? '',
        target: (map['target'] as num?)?.round() ?? 0,
        current: (map['current'] as num?)?.round() ?? 0,
        iconKey: map['iconKey']?.toString() ?? 'trophy',
      );
    }).toList();
  }

  Future<List<UnlockedAchievementData>> evaluatePhotoAchievements() =>
      evaluateAndUnlock(metrics: {'photos'});

  Future<List<UnlockedAchievementData>> evaluateTransformationAchievements() =>
      evaluateAndUnlock(metrics: {'transformations'});

  Future<void> shareAchievementToCommunity(
    UnlockedAchievementData achievement,
  ) async {
    await communityRef.add(
      achievement.toCommunityPostMap(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
      ),
    );
  }
}
