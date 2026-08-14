part of '../user_profile_page.dart';

class _AdvancedProfileSummary extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> leaderboardRef;
  final CollectionReference<Map<String, dynamic>> achievementsRef;
  final CollectionReference<Map<String, dynamic>> communityPostsRef;
  final String leaderboardDocId;
  final String userId;
  final String userEmail;
  final int streak;
  final int photos;
  final int transformations;
  final int statsPoints;

  const _AdvancedProfileSummary({
    required this.leaderboardRef,
    required this.achievementsRef,
    required this.communityPostsRef,
    required this.leaderboardDocId,
    required this.userId,
    required this.userEmail,
    required this.streak,
    required this.photos,
    required this.transformations,
    required this.statsPoints,
  });

  Query<Map<String, dynamic>> userScopedQuery(CollectionReference<Map<String, dynamic>> ref) {
    if (userId.trim().isNotEmpty) {
      return ref.where('userId', isEqualTo: userId.trim());
    }
    return ref.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  Query<Map<String, dynamic>> transformationsQuery() {
    final base = communityPostsRef.where('type', isEqualTo: 'transformation_post');
    if (userId.trim().isNotEmpty) {
      return base.where('userId', isEqualTo: userId.trim());
    }
    return base.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  int levelFromPoints(int points) => (points ~/ 500) + 1;
  int pointsInsideLevel(int points) => points % 500;
  double levelProgress(int points) => (pointsInsideLevel(points) / 500).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: leaderboardRef.doc(leaderboardDocId).snapshots(),
      builder: (context, leaderboardSnapshot) {
        final leaderboard = leaderboardSnapshot.data?.data() ?? <String, dynamic>{};
        final allTimePoints = AppFormatters.intValue(leaderboard['allTimePoints']);
        final monthlyPoints = AppFormatters.intValue(leaderboard['monthlyPoints']);
        final yearlyPoints = AppFormatters.intValue(leaderboard['yearlyPoints']);
        final points = allTimePoints > 0 ? allTimePoints : statsPoints;
        final prestige = prestigeForPoints(points);
        final level = levelFromPoints(points);
        final progress = levelProgress(points);
        final levelPoints = pointsInsideLevel(points);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: userScopedQuery(achievementsRef).snapshots(),
          builder: (context, achievementSnapshot) {
            final achievementCount = achievementSnapshot.data?.docs.length ?? 0;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: transformationsQuery().snapshots(),
              builder: (context, transformationSnapshot) {
                final transformationCount = transformationSnapshot.data?.docs.length ?? transformations;
                final prestigeTitle = prestigeTitleForStats(
                  points: points,
                  bestStreak: streak,
                  achievements: achievementCount,
                  transformations: transformationCount,
                );
                return AppCard(
                  padding: const EdgeInsets.all(14),
                  radius: 26,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(icon: Icons.auto_awesome_rounded, title: 'Perfil DalaiGym'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: context.gymHeroGradient,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ProfileChip(icon: Icons.workspace_premium_rounded, text: 'Nivel $level'),
                                _ProfileChip(icon: Icons.emoji_events_rounded, text: '$points puntos'),
                                _ProfileChip(icon: Icons.military_tech_rounded, text: prestige.label),
                                _ProfileChip(icon: Icons.auto_awesome_rounded, text: prestigeTitle.label),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$levelPoints / 500 pts para nivel ${level + 1}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text('${(progress * 100).round()}%', style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: context.gymSubtleSurface.withValues(alpha: 0.72),
                                valueColor: AlwaysStoppedAnimation<Color>(context.gymPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth < 560 ? 2 : 3;
                          const spacing = 8.0;
                          final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.local_fire_department_rounded, value: '$streak', label: 'Racha')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.workspace_premium_rounded, value: '$achievementCount', label: 'Logros')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.photo_library_rounded, value: '$photos', label: 'Fotos')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.compare_rounded, value: '$transformationCount', label: 'Cambios')),
                              if (monthlyPoints > 0) SizedBox(width: width, child: _ProfileMetric(icon: Icons.calendar_month_rounded, value: '$monthlyPoints', label: 'Pts mes')),
                              if (yearlyPoints > 0) SizedBox(width: width, child: _ProfileMetric(icon: Icons.history_edu_rounded, value: '$yearlyPoints', label: 'Pts año')),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
