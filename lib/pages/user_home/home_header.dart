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
            final currentStreak = intValue(stats['currentStreak']);
            final workouts = intValue(stats['workouts']);
            final level = levelFromPoints(points);
            final nextLevel = level + 1;
            final progress = levelProgress(points);
            final levelPoints = pointsInsideLevel(points);
            final progressPercent = (progress * 100).round();
            final streakText = currentStreak > 0 ? 'Racha $currentStreak' : 'Empieza hoy';
            final workoutText = workouts > 0 ? '$workouts entrenos' : 'Primer entreno';

            return Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              decoration: BoxDecoration(
                color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: context.gymPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.local_fire_department_rounded, color: context.gymPrimary, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Hola, $name',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.gymText,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _HeaderPill(icon: Icons.workspace_premium_rounded, label: 'Nivel $level'),
                            _HeaderPill(icon: Icons.emoji_events_rounded, label: '$points pts'),
                            _HeaderPill(icon: Icons.local_fire_department_rounded, label: streakText),
                            _HeaderPill(icon: Icons.fitness_center_rounded, label: workoutText),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  value: progress,
                                  backgroundColor: context.gymProgressTrack.withValues(alpha: 0.72),
                                  valueColor: AlwaysStoppedAnimation<Color>(context.gymPrimary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$progressPercent%',
                              style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$levelPoints / 500 pts para nivel $nextLevel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Ajustes',
                    onPressed: onSettings,
                    icon: Icon(Icons.settings_rounded, color: context.gymPrimary),
                    style: IconButton.styleFrom(
                      backgroundColor: context.gymSubtleSurface.withValues(alpha: 0.66),
                    ),
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
        color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.52 : 0.76),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.gymPrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
