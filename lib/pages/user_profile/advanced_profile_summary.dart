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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(icon: Icons.auto_awesome, title: 'Perfil DalaiGym'),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth < 560 ? 2 : 3;
                          const spacing = 8.0;
                          final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.emoji_events, value: '$points', label: 'Puntos')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.military_tech, value: prestige.label, label: 'Nivel')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.auto_awesome, value: prestigeTitle.label, label: 'Título')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.local_fire_department, value: '$streak', label: 'Racha')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.workspace_premium, value: '$achievementCount', label: 'Logros')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.photo_library, value: '$photos', label: 'Fotos')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.compare, value: '$transformationCount', label: 'Cambios')),
                            ],
                          );
                        },
                      ),
                      if (monthlyPoints > 0 || yearlyPoints > 0) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ProfileChip(text: '$monthlyPoints pts este mes'),
                            _ProfileChip(text: '$yearlyPoints pts este año'),
                          ],
                        ),
                      ],
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
