part of '../user_profile_page.dart';

class _PersonalHallOfFameCard extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> leaderboardRef;
  final CollectionReference<Map<String, dynamic>> achievementsRef;
  final CollectionReference<Map<String, dynamic>> communityPostsRef;
  final String leaderboardDocId;
  final String userId;
  final String userEmail;
  final int points;
  final int workouts;
  final int bestStreak;
  final int records;
  final int exerciseCount;
  final int transformations;

  const _PersonalHallOfFameCard({
    required this.leaderboardRef,
    required this.achievementsRef,
    required this.communityPostsRef,
    required this.leaderboardDocId,
    required this.userId,
    required this.userEmail,
    required this.points,
    required this.workouts,
    required this.bestStreak,
    required this.records,
    required this.exerciseCount,
    required this.transformations,
  });

  bool matchesUser(Map<String, dynamic> data) {
    final dataUserId = data['userId']?.toString() ?? '';
    final dataEmail = (data['userEmail'] ?? '').toString().toLowerCase();
    final normalizedEmail = userEmail.trim().toLowerCase();
    return (userId.trim().isNotEmpty && dataUserId == userId.trim()) ||
        (normalizedEmail.isNotEmpty && dataEmail == normalizedEmail);
  }

  Query<Map<String, dynamic>> userScopedQuery(CollectionReference<Map<String, dynamic>> ref) {
    if (userId.trim().isNotEmpty) return ref.where('userId', isEqualTo: userId.trim());
    return ref.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  Query<Map<String, dynamic>> transformationsQuery() {
    final base = communityPostsRef.where('type', isEqualTo: 'transformation_post');
    if (userId.trim().isNotEmpty) return base.where('userId', isEqualTo: userId.trim());
    return base.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  int intValue(dynamic value) => AppFormatters.intValue(value);

  int positionFor(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String field) {
    final entries = docs.where((doc) => intValue(doc.data()[field]) > 0).toList();
    entries.sort((a, b) => intValue(b.data()[field]).compareTo(intValue(a.data()[field])));
    final index = entries.indexWhere((doc) => matchesUser(doc.data()));
    return index < 0 ? 0 : index + 1;
  }

  String bestRankingLabel(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final positions = <int>[
      positionFor(docs, 'monthlyPoints'),
      positionFor(docs, 'yearlyPoints'),
      positionFor(docs, 'allTimePoints'),
    ].where((position) => position > 0).toList();
    if (positions.isEmpty) return 'Sin ranking';
    final best = positions.reduce((a, b) => a < b ? a : b);
    if (best == 1) return '🥇 Nº1';
    if (best <= 3) return '🏆 Top 3';
    if (best <= 10) return '📈 Top 10';
    return '#$best';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: leaderboardRef.doc(leaderboardDocId).snapshots(),
      builder: (context, leaderboardSnapshot) {
        final leaderboard = leaderboardSnapshot.data?.data() ?? <String, dynamic>{};
        final allTimePoints = intValue(leaderboard['allTimePoints']);
        final effectivePoints = allTimePoints > 0 ? allTimePoints : points;
        final prestige = prestigeForPoints(effectivePoints);
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: leaderboardRef.snapshots(),
          builder: (context, rankingSnapshot) {
            final rankingDocs = rankingSnapshot.data?.docs ?? [];
            final bestRank = bestRankingLabel(rankingDocs);
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: userScopedQuery(achievementsRef).snapshots(),
              builder: (context, achievementSnapshot) {
                final achievementCount = achievementSnapshot.data?.docs.length ?? 0;
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: transformationsQuery().snapshots(),
                  builder: (context, transformationSnapshot) {
                    final transformationCount = transformationSnapshot.data?.docs.length ?? transformations;
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      radius: 26,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(icon: Icons.emoji_events_rounded, title: 'Mi Hall Of Fame'),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: context.gymHeroGradient,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.20)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.24)),
                                  ),
                                  child: const Icon(Icons.workspace_premium_rounded, color: Colors.amberAccent, size: 30),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(prestige.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 21, fontWeight: FontWeight.w900, height: 1.0)),
                                      const SizedBox(height: 5),
                                      Text('$effectivePoints puntos históricos', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800)),
                                    ],
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
                                  SizedBox(width: width, child: _PersonalFameTile(icon: Icons.local_fire_department_rounded, value: '$bestStreak', label: 'Mejor racha', accent: Colors.orangeAccent)),
                                  SizedBox(width: width, child: _PersonalFameTile(icon: Icons.fitness_center_rounded, value: '$workouts', label: 'Entrenos', accent: context.gymFitnessAccent)),
                                  SizedBox(width: width, child: _PersonalFameTile(icon: Icons.workspace_premium_rounded, value: '$achievementCount', label: 'Logros', accent: Colors.amberAccent)),
                                  SizedBox(width: width, child: _PersonalFameTile(icon: Icons.leaderboard_rounded, value: bestRank, label: 'Mejor ranking', accent: context.gymPrimary)),
                                  SizedBox(width: width, child: _PersonalFameTile(icon: Icons.compare_rounded, value: '$transformationCount', label: 'Transformaciones', accent: Colors.lightBlueAccent)),
                                  SizedBox(width: width, child: _PersonalFameTile(icon: Icons.analytics_rounded, value: records > 0 ? '$records' : '$exerciseCount', label: records > 0 ? 'Récords' : 'Ejercicios', accent: Colors.purpleAccent)),
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
      },
    );
  }
}

class _PersonalFameTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _PersonalFameTile({required this.icon, required this.value, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.gymBorder.withValues(alpha: 0.78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(height: 10),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
