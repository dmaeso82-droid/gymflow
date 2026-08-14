part of '../user_home_page.dart';

class _HomeHeader extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userEmail;
  final String name;
  final VoidCallback onSettings;

  const _HomeHeader({
    required this.gymId,
    required this.userId,
    required this.userEmail,
    required this.name,
    required this.onSettings,
  });

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

  DocumentReference<Map<String, dynamic>> get statsRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('user_stats').doc(userKey);

  DocumentReference<Map<String, dynamic>> get leaderboardRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('leaderboard').doc(userKey);

  int levelFromPoints(int points) => (points ~/ 500) + 1;

  int pointsInsideLevel(int points) => points % 500;

  double levelProgress(int points) => (pointsInsideLevel(points) / 500).clamp(0.0, 1.0);

  List<_HeaderBadgeData> badgesFor({
    required int points,
    required int workouts,
    required int currentStreak,
    required int level,
  }) {
    final badges = <_HeaderBadgeData>[];
    if (workouts > 0) {
      badges.add(_HeaderBadgeData(icon: Icons.fitness_center_rounded, label: 'Primer entreno'));
    }
    if (currentStreak >= 3) {
      badges.add(_HeaderBadgeData(icon: Icons.local_fire_department_rounded, label: 'Racha 3 días'));
    }
    if (points >= 250) {
      badges.add(_HeaderBadgeData(icon: Icons.card_giftcard_rounded, label: '+250 pts'));
    }
    if (level >= 2) {
      badges.add(_HeaderBadgeData(icon: Icons.workspace_premium_rounded, label: 'Nivel $level'));
    }
    if (badges.isEmpty) {
      badges.add(_HeaderBadgeData(icon: Icons.rocket_launch_rounded, label: 'Primeros pasos'));
    }
    return badges.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: statsRef.snapshots(),
      builder: (context, statsSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: leaderboardRef.snapshots(),
          builder: (context, leaderboardSnapshot) {
            final stats = statsSnapshot.data?.data() ?? {};
            final leaderboard = leaderboardSnapshot.data?.data() ?? {};
            final points = intValue(leaderboard['allTimePoints'] ?? stats['points']);
            final monthPoints = intValue(leaderboard['monthlyPoints']);
            final currentStreak = intValue(stats['currentStreak']);
            final workouts = intValue(stats['workouts']);
            final level = levelFromPoints(points);
            final nextLevel = level + 1;
            final progress = levelProgress(points);
            final levelPoints = pointsInsideLevel(points);
            final streakLabel = currentStreak > 0 ? 'Racha $currentStreak día${currentStreak == 1 ? '' : 's'}' : 'Empieza hoy';
            final badges = badgesFor(points: points, workouts: workouts, currentStreak: currentStreak, level: level);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: context.gymHeroGradient,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.14)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: context.gymFitnessAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.18)),
                    ),
                    child: Icon(Icons.local_fire_department_rounded, color: context.gymPrimary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: context.gymPrimary, size: 15),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'DALAIGYM PERFORMANCE',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.gymPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Hola, $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.0, color: context.gymText),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _HeaderPill(icon: Icons.workspace_premium_rounded, label: 'Nivel $level'),
                            _HeaderPill(icon: Icons.emoji_events_rounded, label: '$points pts'),
                            _HeaderPill(icon: Icons.local_fire_department_rounded, label: streakLabel),
                            if (monthPoints > 0) _HeaderPill(icon: Icons.calendar_month_rounded, label: '$monthPoints este mes'),
                            if (workouts > 0) _HeaderPill(icon: Icons.fitness_center_rounded, label: '$workouts entrenos'),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$levelPoints / 500 pts para nivel $nextLevel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text('${(progress * 100).round()}%', style: TextStyle(color: context.gymPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 7,
                            value: progress,
                            backgroundColor: context.gymSubtleSurface.withValues(alpha: 0.72),
                            valueColor: AlwaysStoppedAnimation<Color>(context.gymPrimary),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: badges.map((badge) => _HeaderBadge(icon: badge.icon, label: badge.label)).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: context.gymSubtleSurface),
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_rounded),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.gymBorder.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.gymPrimary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _HeaderBadgeData {
  final IconData icon;
  final String label;

  const _HeaderBadgeData({required this.icon, required this.label});
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.gymPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.gymPrimary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.gymPrimary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: context.gymPrimary, fontSize: 10.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
