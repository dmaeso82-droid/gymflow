part of '../user_home_page.dart';

class _AdaptiveHomeSections extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final List<QuickAction> primaryActions;
  final List<QuickAction> secondaryActions;
  final VoidCallback onOpenCommunity;

  const _AdaptiveHomeSections({
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.primaryActions,
    required this.secondaryActions,
    required this.onOpenCommunity,
  });

  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  String get normalizedEmail => userEmail.trim().toLowerCase();

  String get userKey {
    if (userId.trim().isNotEmpty) return userId.trim();
    return normalizedEmail.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<int> queryCount(Query<Map<String, dynamic>> query) async {
    try {
      final snapshot = await query.limit(3).get();
      return snapshot.size;
    } catch (_) {
      return 0;
    }
  }

  Future<_AdaptiveHomeData> loadData() async {
    final statsDoc = await firestore.collection('gyms').doc(gymId).collection('user_stats').doc(userKey).get();
    final stats = statsDoc.data() ?? {};
    final workouts = intValue(stats['workouts']);
    final points = intValue(stats['points']);
    final currentStreak = intValue(stats['currentStreak']);
    final series = intValue(stats['series']);
    final exercises = intValue(stats['exerciseCount']);
    var photoCount = 0;

    if (userId.trim().isNotEmpty) {
      photoCount += await queryCount(
        firestore.collection('gyms').doc(gymId).collection('progress_photos').where('userId', isEqualTo: userId.trim()),
      );
    }
    if (normalizedEmail.isNotEmpty) {
      photoCount += await queryCount(
        firestore.collection('gyms').doc(gymId).collection('progress_photos').where('userEmail', isEqualTo: normalizedEmail),
      );
    }

    return _AdaptiveHomeData(
      workouts: workouts,
      points: points,
      currentStreak: currentStreak,
      series: series,
      exercises: exercises,
      photoCount: photoCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdaptiveHomeData>(
      future: loadData(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _AdaptiveHomeData.empty();
        final isNewUser = !snapshot.hasData || data.isNewUser;
        final showSecondaryTools = !isNewUser;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSecondaryTools) ...[
              const SizedBox(height: 12),
              _SecondaryActionsCard(actions: secondaryActions),
            ],
          ],
        );
      },
    );
  }
}

class _AdaptiveHomeData {
  final int workouts;
  final int points;
  final int currentStreak;
  final int series;
  final int exercises;
  final int photoCount;

  const _AdaptiveHomeData({
    required this.workouts,
    required this.points,
    required this.currentStreak,
    required this.series,
    required this.exercises,
    required this.photoCount,
  });

  const _AdaptiveHomeData.empty()
      : workouts = 0,
        points = 0,
        currentStreak = 0,
        series = 0,
        exercises = 0,
        photoCount = 0;

  bool get hasTrainingSignal => workouts > 0 || series > 0 || exercises > 0 || currentStreak > 0;
  bool get hasPhotos => photoCount > 0;
  bool get hasPoints => points > 0;
  bool get isNewUser => !hasTrainingSignal && !hasPhotos && !hasPoints;
}
