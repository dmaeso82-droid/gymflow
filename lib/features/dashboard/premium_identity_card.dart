part of '../user_dashboard.dart';

class _PremiumIdentityCard extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> leaderboardRef;
  final CollectionReference<Map<String, dynamic>> achievementsRef;
  final String statsDocId;
  final String userId;
  final String userEmail;
  final String userName;
  final int currentStreak;

  const _PremiumIdentityCard({
    required this.leaderboardRef,
    required this.achievementsRef,
    required this.statsDocId,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.currentStreak,
  });

  int nextLevelTarget(int points) {
    if (points < 500) return 500;
    if (points < 1000) return 1000;
    if (points < 2500) return 2500;
    if (points < 5000) return 5000;
    if (points < 10000) return 10000;
    return points;
  }

  String nextLevelName(int points) {
    if (points < 500) return 'Plata';
    if (points < 1000) return 'Oro';
    if (points < 2500) return 'Platino';
    if (points < 5000) return 'Diamante';
    if (points < 10000) return 'Leyenda';
    return 'Nivel máximo';
  }

  Query<Map<String, dynamic>> achievementsQuery() {
    if (userId.trim().isNotEmpty) return achievementsRef.where('userId', isEqualTo: userId.trim());
    return achievementsRef.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: leaderboardRef.doc(statsDocId).snapshots(),
      builder: (context, leaderboardSnapshot) {
        final leaderboard = leaderboardSnapshot.data?.data() ?? <String, dynamic>{};
        final points = AppFormatters.intValue(leaderboard['allTimePoints']);
        final prestige = prestigeForPoints(points);
        final title = prestigeTitleForStats(points: points, bestStreak: currentStreak);
        final target = nextLevelTarget(points);
        final remaining = target > points ? target - points : 0;
        final progress = target > 0 ? (points / target).clamp(0.0, 1.0) : 1.0;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: achievementsQuery().snapshots(),
          builder: (context, achievementSnapshot) {
            final achievementDocs = [...(achievementSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])];
            achievementDocs.sort((a, b) => AppFormatters.timestampSortValue(b.data()['unlockedAt'] ?? b.data()['createdAt']).compareTo(AppFormatters.timestampSortValue(a.data()['unlockedAt'] ?? a.data()['createdAt'])));
            final latestAchievement = achievementDocs.isEmpty ? null : achievementDocs.first.data();
            final latestTitle = latestAchievement?['title']?.toString() ?? 'Desbloquea tu próximo logro';
            return AppCard(
              padding: const EdgeInsets.all(14),
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${prestige.label} · ${title.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text('$points puntos históricos · $currentStreak días de racha', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag, color: context.gymFitnessAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(remaining > 0 ? 'Próximo nivel: ${nextLevelName(points)}' : 'Nivel máximo alcanzado', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900))),
                            Text(remaining > 0 ? '$remaining pts' : 'Top', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: context.gymProgressTrack, valueColor: AlwaysStoppedAnimation<Color>(context.gymFitnessAccent)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.workspace_premium, color: context.gymFitnessAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Último logro: $latestTitle', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
                    ],
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
