part of '../user_home_page.dart';

class _GamificationRetentionCard extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final VoidCallback onOpenRoutines;
  final VoidCallback onOpenChallenges;
  final VoidCallback onOpenAchievements;
  final VoidCallback onOpenGoals;

  const _GamificationRetentionCard({
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.onOpenRoutines,
    required this.onOpenChallenges,
    required this.onOpenAchievements,
    required this.onOpenGoals,
  });

  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  String get normalizedEmail => userEmail.trim().toLowerCase();
  String get safeEmailKey => normalizedEmail.replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  String primaryUserKey() {
    if (userId.trim().isNotEmpty) return userId.trim();
    return safeEmailKey;
  }

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  DateTime? timestampDate(dynamic value) => value is Timestamp ? value.toDate() : null;

  bool isToday(dynamic value) {
    final date = timestampDate(value);
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool isThisWeek(dynamic value) {
    final date = timestampDate(value);
    if (date == null) return false;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return !date.isBefore(startOfWeek) && date.isBefore(endOfWeek);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> openFirstExistingDoc(CollectionReference<Map<String, dynamic>> ref) async {
    final keys = <String>{if (userId.trim().isNotEmpty) userId.trim(), if (safeEmailKey.isNotEmpty) safeEmailKey};
    for (final key in keys) {
      final doc = await ref.doc(key).get();
      if (doc.exists) return doc;
    }
    return null;
  }

  Future<int> queryCount(Query<Map<String, dynamic>> query) async {
    try {
      final snapshot = await query.limit(20).get();
      return snapshot.size;
    } catch (_) {
      return 0;
    }
  }

  Future<Set<String>> unlockedAchievementIds(CollectionReference<Map<String, dynamic>> ref) async {
    final ids = <String>{};
    Future<void> addFrom(Query<Map<String, dynamic>> query) async {
      try {
        final snapshot = await query.get();
        for (final doc in snapshot.docs) {
          final id = doc.data()['achievementId']?.toString() ?? '';
          if (id.isNotEmpty) ids.add(id);
        }
      } catch (_) {}
    }
    if (userId.trim().isNotEmpty) {
      await addFrom(ref.where('userId', isEqualTo: userId.trim()));
    }
    if (normalizedEmail.isNotEmpty) {
      await addFrom(ref.where('userEmail', isEqualTo: normalizedEmail));
    }
    return ids;
  }

  int metricValue(String metric, Map<String, dynamic> stats, int photos, int transformations) {
    switch (metric) {
      case 'workouts':
        return intValue(stats['workouts']);
      case 'series':
        return intValue(stats['series']);
      case 'volume':
        return doubleValue(stats['volume']).round();
      case 'streak':
        return intValue(stats['currentStreak']);
      case 'exercises':
        return intValue(stats['exerciseCount']);
      case 'photos':
        return photos;
      case 'transformations':
        return transformations;
      default:
        return 0;
    }
  }

  AchievementDefinitionData? nextAchievementFor({
    required Set<String> unlockedIds,
    required Map<String, dynamic> stats,
    required int photos,
    required int transformations,
  }) {
    final candidates = automaticAchievementDefinitions.where((achievement) => !unlockedIds.contains(achievement.id)).toList();
    candidates.sort((a, b) {
      final aCurrent = metricValue(a.metric, stats, photos, transformations);
      final bCurrent = metricValue(b.metric, stats, photos, transformations);
      final aProgress = a.target <= 0 ? 0.0 : (aCurrent / a.target).clamp(0.0, 1.0);
      final bProgress = b.target <= 0 ? 0.0 : (bCurrent / b.target).clamp(0.0, 1.0);
      return bProgress.compareTo(aProgress);
    });
    return candidates.isEmpty ? null : candidates.first;
  }

  Future<_GamificationData> loadData() async {
    final statsRef = firestore.collection('gyms').doc(gymId).collection('user_stats');
    final rankingRef = firestore.collection('gyms').doc(gymId).collection('ranking_stats');
    final leaderboardRef = firestore.collection('gyms').doc(gymId).collection('leaderboard');
    final achievementsRef = firestore.collection('gyms').doc(gymId).collection('user_achievements');
    final photosRef = firestore.collection('gyms').doc(gymId).collection('progress_photos');
    final communityRef = firestore.collection('gyms').doc(gymId).collection('community_posts');
    final statsDoc = await openFirstExistingDoc(statsRef);
    final rankingDoc = await openFirstExistingDoc(rankingRef);
    final leaderboardDoc = await openFirstExistingDoc(leaderboardRef);
    final stats = statsDoc?.data() ?? <String, dynamic>{};
    final ranking = rankingDoc?.data() ?? <String, dynamic>{};
    final leaderboard = leaderboardDoc?.data() ?? <String, dynamic>{};
    var photos = 0;
    if (userId.trim().isNotEmpty) photos += await queryCount(photosRef.where('userId', isEqualTo: userId.trim()));
    if (normalizedEmail.isNotEmpty) photos += await queryCount(photosRef.where('userEmail', isEqualTo: normalizedEmail));
    var transformations = 0;
    if (userId.trim().isNotEmpty) transformations += await queryCount(communityRef.where('type', isEqualTo: 'transformation_post').where('userId', isEqualTo: userId.trim()));
    if (normalizedEmail.isNotEmpty) transformations += await queryCount(communityRef.where('type', isEqualTo: 'transformation_post').where('userEmail', isEqualTo: normalizedEmail));
    final unlockedIds = await unlockedAchievementIds(achievementsRef);
    final nextAchievement = nextAchievementFor(unlockedIds: unlockedIds, stats: stats, photos: photos, transformations: transformations);
    final nextCurrent = nextAchievement == null ? 0 : metricValue(nextAchievement.metric, stats, photos, transformations);
    final points = intValue(leaderboard['allTimePoints'] ?? stats['points']);
    final levelTarget = points < 500 ? 500 : points < 1000 ? 1000 : points < 2500 ? 2500 : points < 5000 ? 5000 : points < 10000 ? 10000 : points;
    final remainingPoints = levelTarget > points ? levelTarget - points : 0;
    final weeklyWorkouts = intValue(ranking['weeklyWorkouts']);
    final weeklySeries = intValue(ranking['weeklySeries']);
    final lastWorkout = stats['lastWorkout'];
    final trainedToday = isToday(lastWorkout);
    final nextAchievementProgress = nextAchievement == null || nextAchievement.target <= 0 ? 0.0 : (nextCurrent / nextAchievement.target).clamp(0.0, 1.0).toDouble();
    final hasPendingAchievement = nextAchievement != null && nextAchievementProgress < 1.0;

    late final _MissionData mission;
    if (!trainedToday) {
      mission = _MissionData(
        icon: Icons.fitness_center_rounded,
        title: 'Completa 1 entrenamiento',
        subtitle: '+${PointsRules.workoutCompleted} pts y mantén tu progreso activo.',
        actionLabel: 'Entrenar ahora',
        onTap: onOpenRoutines,
      );
    } else if (weeklyWorkouts < 3) {
      mission = _MissionData(
        icon: Icons.calendar_view_week_rounded,
        title: 'Suma otro entreno esta semana',
        subtitle: 'Vas $weeklyWorkouts/3 entrenos. Mantén el ritmo.',
        actionLabel: 'Ver rutinas',
        onTap: onOpenRoutines,
      );
    } else if (hasPendingAchievement) {
      mission = _MissionData(
        icon: Icons.workspace_premium_rounded,
        title: 'Acércate a ${nextAchievement.title}',
        subtitle: '$nextCurrent/${nextAchievement.target} completado.',
        actionLabel: 'Ver logros',
        onTap: onOpenAchievements,
      );
    } else {
      mission = _MissionData(
        icon: Icons.emoji_events_rounded,
        title: 'Busca un nuevo reto',
        subtitle: 'Tus objetivos visibles están completados. Mantén la motivación.',
        actionLabel: 'Ver retos',
        onTap: onOpenChallenges,
      );
    }
    await NotificationService(gymId: gymId).generateSmartRetentionNotifications(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
    );
    return _GamificationData(
      mission: mission,
      points: points,
      levelTarget: levelTarget,
      remainingPoints: remainingPoints,
      weeklyWorkouts: weeklyWorkouts,
      weeklySeries: weeklySeries,
      nextAchievement: nextAchievement,
      nextAchievementCurrent: nextCurrent,
      photos: photos,
      transformations: transformations,
      trainedToday: trainedToday,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GamificationData>(
      future: loadData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(
            child: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.gymPrimary)),
                const SizedBox(width: 12),
                Expanded(child: Text('Preparando misiones...', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
              ],
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final levelProgress = data.levelTarget <= 0 ? 1.0 : (data.points / data.levelTarget).clamp(0.0, 1.0).toDouble();
        final achievement = data.nextAchievement;
        final achievementProgress = achievement == null || achievement.target <= 0 ? 0.0 : (data.nextAchievementCurrent / achievement.target).clamp(0.0, 1.0).toDouble();
        final weeklyTarget = 3;
        final weeklyProgress = (data.weeklyWorkouts / weeklyTarget).clamp(0.0, 1.0).toDouble();
        final visibleProgressItems = <Widget>[
          if (levelProgress < 1.0)
            _CompactRetentionMini(
              icon: Icons.workspace_premium_rounded,
              title: data.remainingPoints > 0 ? 'Próximo nivel' : 'Nivel máximo',
              subtitle: data.remainingPoints > 0 ? 'Faltan ${data.remainingPoints} pts' : '${data.points} pts históricos',
              progress: levelProgress,
              value: '${(levelProgress * 100).round()}%',
              onTap: onOpenAchievements,
            ),
          if (weeklyProgress < 1.0)
            _CompactRetentionMini(
              icon: Icons.calendar_view_week_rounded,
              title: 'Objetivo semanal',
              subtitle: '${data.weeklyWorkouts}/$weeklyTarget entrenos · ${data.weeklySeries} series',
              progress: weeklyProgress,
              value: '${(weeklyProgress * 100).round()}%',
              onTap: onOpenGoals,
            ),
          if (achievement != null && achievementProgress < 1.0)
            _CompactRetentionMini(
              icon: Icons.emoji_events_rounded,
              title: 'Próximo logro',
              subtitle: '${achievement.title} · ${data.nextAchievementCurrent}/${achievement.target}',
              progress: achievementProgress,
              value: '${(achievementProgress * 100).round()}%',
              onTap: onOpenAchievements,
            ),
        ];
        return AppCard(
          padding: const EdgeInsets.all(12),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.bolt_rounded, color: context.gymPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Centro de progreso', style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          data.trainedToday ? 'Hoy ya hay progreso registrado.' : 'Una acción clara para avanzar hoy.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.gymPrimary.withValues(alpha: 0.20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                      child: Icon(data.mission.icon, color: context.gymPrimary, size: 20),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data.mission.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 14.5, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(data.mission.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: data.mission.onTap,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(data.mission.actionLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              if (visibleProgressItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (var i = 0; i < visibleProgressItems.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  visibleProgressItems[i],
                ],
              ] else ...[
                const SizedBox(height: 8),
                _CompletedProgressState(onOpenChallenges: onOpenChallenges),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CompletedProgressState extends StatelessWidget {
  final VoidCallback onOpenChallenges;

  const _CompletedProgressState({required this.onOpenChallenges});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpenChallenges,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: context.gymFitnessAccent.withValues(alpha: context.gymIsDark ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.check_circle_rounded, color: context.gymFitnessAccent, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Objetivos actuales completados', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text('Busca un nuevo reto para seguir progresando.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactRetentionMini extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double progress;
  final String value;
  final VoidCallback onTap;

  const _CompactRetentionMini({required this.icon, required this.title, required this.subtitle, required this.progress, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: context.gymSubtleSurface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.gymBorder.withValues(alpha: 0.80)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: context.gymFitnessAccent, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900, fontSize: 13.5))),
                      Text(value, style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: progress,
                      backgroundColor: context.gymProgressTrack,
                      valueColor: AlwaysStoppedAnimation<Color>(context.gymFitnessAccent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GamificationData {
  final _MissionData mission;
  final int points;
  final int levelTarget;
  final int remainingPoints;
  final int weeklyWorkouts;
  final int weeklySeries;
  final AchievementDefinitionData? nextAchievement;
  final int nextAchievementCurrent;
  final int photos;
  final int transformations;
  final bool trainedToday;

  const _GamificationData({
    required this.mission,
    required this.points,
    required this.levelTarget,
    required this.remainingPoints,
    required this.weeklyWorkouts,
    required this.weeklySeries,
    required this.nextAchievement,
    required this.nextAchievementCurrent,
    required this.photos,
    required this.transformations,
    required this.trainedToday,
  });
}

class _MissionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _MissionData({required this.icon, required this.title, required this.subtitle, required this.actionLabel, required this.onTap});
}
